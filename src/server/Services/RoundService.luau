local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local AnnouncementService = require(script.Parent.AnnouncementService)
local SpawnService = require(script.Parent.SpawnService)
local RoleService = require(script.Parent.RoleService)
local CoinService = require(script.Parent.CoinService)
local CoalService = require(script.Parent.CoalService)
local ToolService = require(script.Parent.ToolService)
local WorldScrollService = require(script.Parent.WorldScrollService)

local RoundConst = Constants.Round
local DefaultSpeed = Constants.WorldScroll.DEFAULT_SPEED
local MinPlayers = if Constants.SOLO_TEST_ENABLED then 1 else RoundConst.MIN_PLAYERS
local RoundService = {}

local CurrentPhase: string = "Intermission"
local PhaseEndTime: number = 0
local RoundEndTime: number = 0
local RoundStartTime: number = 0
local TotalCoalCollected: number = 0
local TotalCoalRequired: number = 0
local StopsCompleted: number = 0
local Participants: { Player } = {}
local RoleMap: { [Player]: string } = {}
local EliminatedPlayers: { { Name: string, Role: string, UserId: number } } = {}
local DeathConnections: { [Player]: RBXScriptConnection } = {}
local CharacterAddedConnections: { [Player]: RBXScriptConnection } = {}
local LastResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } }? = nil
local RagdollBodies: { Model } = {}

local function Now(): number
	return workspace:GetServerTimeNow()
end

--[[
    broadcasts the current phase to all clients
]]
local function BroadcastPhaseChange()
	RoundNetwork.packets.PhaseChange.sendToAll({
		Phase = CurrentPhase,
		PhaseEndTime = PhaseEndTime,
		RoundEndTime = if RoundEndTime > 0 then RoundEndTime else nil,
	})
end

--[[
    broadcasts the participant list to all clients
]]
local function BroadcastParticipantList()
	local Ids = {}
	for _, PlayerInstance in Participants do
		table.insert(Ids, PlayerInstance.UserId)
	end
	RoundNetwork.packets.ParticipantList.sendToAll({
		PlayerIds = Ids,
	})
end

--[[
    returns true if the player is a participant in the current round
]]
local function IsParticipant(PlayerInstance: Player): boolean
	for _, P in Participants do
		if P == PlayerInstance then
			return true
		end
	end
	return false
end

--[[
    returns true if the participant has been eliminated
]]
local function IsEliminated(PlayerInstance: Player): boolean
	for _, Entry in EliminatedPlayers do
		if Entry.UserId == PlayerInstance.UserId then
			return true
		end
	end
	return false
end

--[[
    returns all living participants
]]
local function GetAliveParticipants(): { Player }
	local Alive = {}
	for _, PlayerInstance in Participants do
		if not IsEliminated(PlayerInstance) and PlayerInstance.Parent then
			table.insert(Alive, PlayerInstance)
		end
	end
	return Alive
end

--[[
    builds the player result list for the scoreboard, including disconnected players
]]
local function BuildResultPlayerList(): { { Name: string, Role: string, Alive: boolean, UserId: number } }
	local List = {}
	for _, PlayerInstance in Participants do
		local Role = RoleMap[PlayerInstance] or "Innocent"
		table.insert(List, {
			Name = PlayerInstance.Name,
			Role = Role,
			Alive = not IsEliminated(PlayerInstance),
			UserId = PlayerInstance.UserId,
		})
	end
	for _, Entry in EliminatedPlayers do
		local AlreadyListed = false
		for _, ListEntry in List do
			if ListEntry.UserId == Entry.UserId then
				AlreadyListed = true
				break
			end
		end
		if not AlreadyListed then
			table.insert(List, {
				Name = Entry.Name,
				Role = Entry.Role,
				Alive = false,
				UserId = Entry.UserId,
			})
		end
	end
	return List
end

--[[
    checks win conditions and returns the result string, or nil if the round continues
]]
local function CheckWinConditions(): string?
	if CurrentPhase ~= "InProgress" then
		return nil
	end

	local Alive = GetAliveParticipants()
	local MurdererAlive = false
	local DetectiveAlive = false
	local InnocentAlive = false

	for _, PlayerInstance in Alive do
		local Role = RoleMap[PlayerInstance]
		if Role == "Murderer" then
			MurdererAlive = true
		elseif Role == "Detective" then
			DetectiveAlive = true
		else
			InnocentAlive = true
		end
	end

	if not MurdererAlive then
		return "DetectiveWin"
	end

	if not DetectiveAlive and not InnocentAlive then
		return "MurdererWin"
	end

	-- Murderer killed all innocents, only Detective remains
	if not InnocentAlive and DetectiveAlive and #Participants >= 3 then
		return "MurdererWin"
	end

	return nil
end

--[[
    ends the round with the given result, broadcasts results, and transitions to PostRound
]]
local function EndRound(Result: string)
	for PlayerInstance, Connection in DeathConnections do
		Connection:Disconnect()
	end
	table.clear(DeathConnections)

	-- Keep CharacterAdded connections for eliminated players so they respawn to lobby
	for PlayerInstance, Connection in CharacterAddedConnections do
		if not IsEliminated(PlayerInstance) then
			Connection:Disconnect()
			CharacterAddedConnections[PlayerInstance] = nil
		end
	end

	ToolService.CleanupTools(Participants)

	local PlayerList = BuildResultPlayerList()
	LastResultData = {
		Result = Result,
		Players = PlayerList,
	}

	CurrentPhase = "PostRound"
	PhaseEndTime = Now() + RoundConst.POST_ROUND_DURATION
	BroadcastPhaseChange()

	RoundNetwork.packets.RoundResult.sendToAll(LastResultData)

	local ResultText = RoundConst.RESULT_TEXT[Result] or "Round Over!"
	AnnouncementService.AnnounceAll(ResultText, nil, RoundConst.POST_ROUND_DURATION - 2)
end

--[[
    handles a participant dying mid-round, broadcasts elimination, and checks win conditions
]]
local function OnParticipantDied(PlayerInstance: Player)
	if CurrentPhase ~= "InProgress" then
		return
	end
	if IsEliminated(PlayerInstance) then
		return
	end

	local Role = RoleMap[PlayerInstance] or "Innocent"
	table.insert(EliminatedPlayers, {
		Name = PlayerInstance.Name,
		Role = Role,
		UserId = PlayerInstance.UserId,
	})

	RoundNetwork.packets.PlayerEliminated.sendToAll({
		Name = PlayerInstance.Name,
		Role = Role,
		UserId = PlayerInstance.UserId,
	})

	RoundEndTime += RoundConst.KILL_TIME_BONUS
	PhaseEndTime = RoundEndTime
	BroadcastPhaseChange()

	-- Clone character as ragdoll body right before respawn (after ragdoll settles)
	task.spawn(function()
		local Character = PlayerInstance.Character
		if not Character then
			return
		end

		-- Wait for ragdoll to settle (just before auto-respawn)
		local WaitTime = math.max(0, Players.RespawnTime - 0.5)
		task.wait(WaitTime)

		-- Re-check character is still the dead one
		if PlayerInstance.Character ~= Character then
			return
		end

		-- Force Archivable so Clone() captures all instances
		Character.Archivable = true
		for _, Desc in Character:GetDescendants() do
			pcall(function() Desc.Archivable = true end)
		end

		local Ragdoll = Character:Clone()

		-- Remove tools, scripts, and humanoid from the clone
		for _, Desc in Ragdoll:GetDescendants() do
			if Desc:IsA("Tool") or Desc:IsA("BaseScript") then
				Desc:Destroy()
			end
		end

		-- Anchor all parts and disable collision BEFORE removing humanoid
		for _, Desc in Ragdoll:GetDescendants() do
			if Desc:IsA("BasePart") then
				Desc.Anchored = true
				Desc.CanCollide = false
			end
		end

		local RagdollHumanoid = Ragdoll:FindFirstChildOfClass("Humanoid")
		if RagdollHumanoid then
			RagdollHumanoid:Destroy()
		end

		Ragdoll.Name = PlayerInstance.Name .. "_Ragdoll"
		Ragdoll.Parent = workspace
		table.insert(RagdollBodies, Ragdoll)
	end)

	if CharacterAddedConnections[PlayerInstance] then
		CharacterAddedConnections[PlayerInstance]:Disconnect()
	end
	CharacterAddedConnections[PlayerInstance] = PlayerInstance.CharacterAdded:Connect(function(NewCharacter)
		local Humanoid = NewCharacter:WaitForChild("Humanoid")
		NewCharacter:WaitForChild("HumanoidRootPart")
		Humanoid:GetPropertyChangedSignal("RootPart"):Wait()
		task.wait(0.1)
		if CharacterAddedConnections[PlayerInstance] then
			NewCharacter:PivotTo(SpawnService.GetLobbySpawn())
		end
	end)

	if Role == "Detective" then
		local DeathPosition = Vector3.zero
		local DetectiveCharacter = PlayerInstance.Character
		if DetectiveCharacter then
			local Root = DetectiveCharacter:FindFirstChild("HumanoidRootPart")
			if Root then
				DeathPosition = Root.Position
			end
		end

		local SpawnCFrame = SpawnService.GetNearestSafeSpawn(DeathPosition)
		ToolService.SpawnGunPickup(SpawnCFrame, function(Picker: Player)
			if IsEliminated(Picker) then
				return false
			end
			if not IsParticipant(Picker) then
				return false
			end
			local PickerRole = RoleMap[Picker]
			return PickerRole ~= "Murderer"
		end, function(Picker: Player)
			RoleMap[Picker] = "Detective"
			Picker:SetAttribute("Role", "Detective")
			RoundNetwork.packets.RoleAssignment.sendTo({ Role = "Detective" }, Picker)
		end)
	end

	local Result = CheckWinConditions()
	if Result then
		EndRound(Result)
	end
end

--[[
    hooks death detection onto a participant's humanoid
]]
local function HookParticipantDeath(PlayerInstance: Player)
	local function ConnectHumanoid()
		local Character = PlayerInstance.Character
		if not Character then
			return
		end
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		if DeathConnections[PlayerInstance] then
			DeathConnections[PlayerInstance]:Disconnect()
		end

		DeathConnections[PlayerInstance] = Humanoid.Died:Connect(function()
			OnParticipantDied(PlayerInstance)
		end)
	end

	ConnectHumanoid()

	if CharacterAddedConnections[PlayerInstance] then
		CharacterAddedConnections[PlayerInstance]:Disconnect()
	end
end

--[[
    handles a player disconnecting mid-round, marking them eliminated and checking win conditions
]]
local function OnPlayerRemoving(PlayerInstance: Player)
	if not IsParticipant(PlayerInstance) then
		return
	end

	if DeathConnections[PlayerInstance] then
		DeathConnections[PlayerInstance]:Disconnect()
		DeathConnections[PlayerInstance] = nil
	end
	if CharacterAddedConnections[PlayerInstance] then
		CharacterAddedConnections[PlayerInstance]:Disconnect()
		CharacterAddedConnections[PlayerInstance] = nil
	end

	if not IsEliminated(PlayerInstance) then
		local Role = RoleMap[PlayerInstance] or "Innocent"
		table.insert(EliminatedPlayers, {
			Name = PlayerInstance.Name,
			Role = Role,
			UserId = PlayerInstance.UserId,
		})

		RoundNetwork.packets.PlayerEliminated.sendToAll({
			Name = PlayerInstance.Name,
			Role = Role,
			UserId = PlayerInstance.UserId,
		})
	end

	if CurrentPhase == "InProgress" then
		local Result = CheckWinConditions()
		if Result then
			EndRound(Result)
		end
	end
end

--[[
    resets all round state for a fresh start
]]
local function ResetRoundState()
	for _, Connection in DeathConnections do
		Connection:Disconnect()
	end
	table.clear(DeathConnections)

	for _, Connection in CharacterAddedConnections do
		Connection:Disconnect()
	end
	table.clear(CharacterAddedConnections)

	ToolService.CleanupTools(Participants)
	RoleService.ClearRoles(Participants)
	table.clear(Participants)
	table.clear(RoleMap)
	table.clear(EliminatedPlayers)
	TotalCoalCollected = 0
	TotalCoalRequired = 0
	StopsCompleted = 0
	LastResultData = nil

	for _, Ragdoll in RagdollBodies do
		if Ragdoll and Ragdoll.Parent then
			Ragdoll:Destroy()
		end
	end
	table.clear(RagdollBodies)
end

local StrayRayParams = RaycastParams.new()
StrayRayParams.FilterType = Enum.RaycastFilterType.Exclude

--[[
    returns true if the player's character is standing on the train
]]
local function IsPlayerOnTrain(PlayerInstance: Player): boolean
	local Character = PlayerInstance.Character
	if not Character then
		return false
	end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return false
	end

	StrayRayParams.FilterDescendantsInstances = { Character }
	local Result = workspace:Raycast(Root.Position, Vector3.new(0, -15, 0), StrayRayParams)
	if Result and Result.Instance then
		local TrainModel = workspace:FindFirstChild("Train")
		if TrainModel and Result.Instance:IsDescendantOf(TrainModel) then
			return true
		end
	end
	return false
end

--[[
    teleports all alive participants who are not on the train to the nearest car
]]
local function TeleportStrayPlayersToTrain()
	for _, PlayerInstance in GetAliveParticipants() do
		if not IsPlayerOnTrain(PlayerInstance) then
			SpawnService.TeleportToNearestCar(PlayerInstance)
		end
	end
end

--[[
    teleports all surviving participants to the lobby
]]
local function TeleportSurvivorsToLobby()
	for _, PlayerInstance in Participants do
		if PlayerInstance.Parent and not IsEliminated(PlayerInstance) then
			SpawnService.TeleportToLobby(PlayerInstance)
		end
	end
end

--[[
    main loop that drives intermission, teleport, role reveal, and round phases
    (@yields)
]]
local function RoundLoop()
	while true do
		ResetRoundState()
		WorldScrollService.Reset()
		CurrentPhase = "Intermission"
		PhaseEndTime = Now() + (Constants.SOLO_TEST_ENABLED and 6 or RoundConst.INTERMISSION_DURATION)
		RoundEndTime = 0
		BroadcastPhaseChange()

		local WaitingAnnounced = false
		while true do
			local PlayerCount = #Players:GetPlayers()
			if PlayerCount >= MinPlayers then
				AnnouncementService.AnnounceAll("Prepare for Departure", "The train will be leaving shortly...", RoundConst.INTERMISSION_DURATION - 2)
				local EndTime = PhaseEndTime
				while Now() < EndTime do
					task.wait(0.5)
					if #Players:GetPlayers() < MinPlayers then
						break
					end
				end

				if #Players:GetPlayers() >= MinPlayers then
					break
				else
					AnnouncementService.AnnounceAll("Departure Delayed", "Waiting for more passengers...", 3)
					WaitingAnnounced = true
					PhaseEndTime = Now() + RoundConst.INTERMISSION_DURATION
					BroadcastPhaseChange()
				end
			else
				if not WaitingAnnounced then
					AnnouncementService.AnnounceAll("Awaiting Passengers", MinPlayers .. " passengers required to depart", 4)
					WaitingAnnounced = true
				end
				task.wait(2)
			end
		end

		for _, PlayerInstance in Players:GetPlayers() do
			table.insert(Participants, PlayerInstance)
		end

		CurrentPhase = "Teleporting"
		PhaseEndTime = Now() + RoundConst.TELEPORT_FADE_DURATION
		BroadcastPhaseChange()
		BroadcastParticipantList()

		task.wait(RoundConst.TELEPORT_FADE_DURATION)

		SpawnService.TeleportAllToTrain(Participants)

		task.wait(0.5)

		CurrentPhase = "RoleReveal"
		PhaseEndTime = Now() + RoundConst.ROLE_REVEAL_DELAY
		BroadcastPhaseChange()

		RoleMap = RoleService.AssignRoles(Participants)
		RoleService.BroadcastRoles(RoleMap)

		task.wait(RoundConst.ROLE_REVEAL_DELAY)

		CurrentPhase = "InProgress"
		RoundStartTime = Now()
		RoundEndTime = RoundStartTime + RoundConst.ROUND_DURATION
		PhaseEndTime = RoundEndTime
		BroadcastPhaseChange()

		CoinService.SpawnCoins()

		ToolService.GiveTools(RoleMap)

		for _, PlayerInstance in Participants do
			HookParticipantDeath(PlayerInstance)
		end

		-- Spawn stop sequences concurrently
		task.spawn(function()
			local TotalStops = #RoundConst.STOP_TIMES
			local MaxPenalty = (RoundConst.MAX_ROUND_DURATION - RoundConst.ROUND_DURATION) / TotalStops

			for _, StopTime in RoundConst.STOP_TIMES do
				local WaitUntil = RoundStartTime + StopTime
				while Now() < WaitUntil and CurrentPhase == "InProgress" do
					task.wait(0.5)
				end
				if CurrentPhase ~= "InProgress" then
					break
				end

				local TotalBrakeTime = WorldScrollService.StopAtNewSceneWithTunnels(
					{ "LeftStop", "RightMountains", "PowerLines" },
					"Tunnel",
					{ "LeftMountains" }
				)
				task.wait(TotalBrakeTime + 1)
				if CurrentPhase ~= "InProgress" then
					break
				end

				local SceneCFrame = WorldScrollService.GetSceneCFrame("LeftStop")
				CoalService.Activate(nil, SceneCFrame)
				CoinService.SpawnStopCoins(SceneCFrame)

				AnnouncementService.AnnounceAll("Now Stopping", "Load coal and reboard within 1 minute", 4)

				local StopEnd = Now() + RoundConst.STOP_DURATION
				while Now() < StopEnd and CurrentPhase == "InProgress" do
					task.wait(0.5)
				end
				if CurrentPhase ~= "InProgress" then
					break
				end

				-- Tally coal collected this stop
				local CoalThisStop, RequiredThisStop = CoalService.GetState()
				TotalCoalCollected += CoalThisStop
				TotalCoalRequired += RequiredThisStop
				StopsCompleted += 1

				CoalService.Deactivate()
				CoinService.DespawnStopCoins()

				-- Teleport anyone not on the train back aboard
				TeleportStrayPlayersToTrain()

				-- Calculate time penalty based on missing coal
				local CoalRatio = if RequiredThisStop > 0 then CoalThisStop / RequiredThisStop else 1
				local PenaltySeconds = math.round(MaxPenalty * (1 - CoalRatio))

				if PenaltySeconds > 0 then
					RoundEndTime += PenaltySeconds
					PhaseEndTime = RoundEndTime
					BroadcastPhaseChange()

					local PenaltyMinutes = math.floor(PenaltySeconds / 60)
					local PenaltySecs = PenaltySeconds % 60
					local PenaltyText = if PenaltyMinutes > 0
						then string.format("+%d:%02d", PenaltyMinutes, PenaltySecs)
						else string.format("+%ds", PenaltySecs)
					AnnouncementService.AnnounceAll(
						"Coal Shortage",
						"Insufficient coal loaded. " .. PenaltyText .. " added to journey",
						5,
						true
					)
					task.wait(5)
				else
					AnnouncementService.AnnounceAll("All Aboard!", "Full coal loaded — departing at full speed", 3)
				end

				-- Resume speed scales with coal ratio (full coal = default speed, no coal = 60% speed)
				local SpeedMultiplier = 0.6 + 0.4 * CoalRatio
				local ResumeSpeed = math.round(DefaultSpeed * SpeedMultiplier)
				WorldScrollService.ResumeFromScene(nil, ResumeSpeed, 5)
				task.wait(6)
			end
		end)

		local ApproachingAnnounced = false
		while CurrentPhase == "InProgress" and Now() < RoundEndTime do
			local Remaining = RoundEndTime - Now()
			if not ApproachingAnnounced and Remaining <= 60 and Remaining > 0 then
				ApproachingAnnounced = true
				AnnouncementService.AnnounceAll("Approaching Destination", "Less than 1 minute until arrival", 4)
			end
			task.wait(0.5)
		end

		if CurrentPhase == "InProgress" then
			EndRound("PassengersWin")
		end

		local PostEndTime = PhaseEndTime
		while Now() < PostEndTime do
			task.wait(0.5)
		end

		CoinService.DespawnAll()
		CoalService.Deactivate()

		TeleportSurvivorsToLobby()

		task.wait(2)
	end
end

RoundNetwork.queries.RequestRoundState.listen(function(_, Player: Player)
	local Role: string? = nil
	if IsParticipant(Player) then
		Role = RoleMap[Player]
	end

	local Ids = {}
	for _, P in Participants do
		table.insert(Ids, P.UserId)
	end

	return {
		Phase = CurrentPhase,
		PhaseEndTime = PhaseEndTime,
		RoundEndTime = if RoundEndTime > 0 then RoundEndTime else 0,
		Role = Role,
		ParticipantIds = Ids,
		Eliminated = EliminatedPlayers,
		ResultData = LastResultData,
	}
end)

Players.PlayerRemoving:Connect(OnPlayerRemoving)

Players.PlayerAdded:Connect(function(PlayerInstance: Player)
	local Character = PlayerInstance.Character or PlayerInstance.CharacterAdded:Wait()
	Character:WaitForChild("Humanoid")
	SpawnService.TeleportToLobby(PlayerInstance)
end)

task.spawn(RoundLoop)

function RoundService.GetPhase(): string
	return CurrentPhase
end

function RoundService.GetParticipants(): { Player }
	return Participants
end

function RoundService.IsParticipant(PlayerInstance: Player): boolean
	return IsParticipant(PlayerInstance)
end

return RoundService
