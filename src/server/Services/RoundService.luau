local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local AnnouncementService = require(script.Parent.AnnouncementService)
local SpawnService = require(script.Parent.SpawnService)
local RoleService = require(script.Parent.RoleService)

local RoundConst = Constants.Round
local MinPlayers = if RunService:IsStudio() then 1 else RoundConst.MIN_PLAYERS
local RoundService = {}

local CurrentPhase: string = "Intermission"
local PhaseEndTime: number = 0
local RoundEndTime: number = 0
local Participants: { Player } = {}
local RoleMap: { [Player]: string } = {}
local EliminatedPlayers: { { Name: string, Role: string, UserId: number } } = {}
local DeathConnections: { [Player]: RBXScriptConnection } = {}
local CharacterAddedConnections: { [Player]: RBXScriptConnection } = {}
local LastResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } }? = nil

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
	local NonMurdererAlive = false

	for _, PlayerInstance in Alive do
		local Role = RoleMap[PlayerInstance]
		if Role == "Murderer" then
			MurdererAlive = true
		else
			NonMurdererAlive = true
		end
	end

	if not MurdererAlive then
		return "DetectiveWin"
	end

	if not NonMurdererAlive then
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

	for PlayerInstance, Connection in CharacterAddedConnections do
		Connection:Disconnect()
	end
	table.clear(CharacterAddedConnections)

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

	if CharacterAddedConnections[PlayerInstance] then
		CharacterAddedConnections[PlayerInstance]:Disconnect()
	end
	CharacterAddedConnections[PlayerInstance] = PlayerInstance.CharacterAdded:Connect(function()
		task.wait()
		SpawnService.TeleportToLobby(PlayerInstance)
		if CharacterAddedConnections[PlayerInstance] then
			CharacterAddedConnections[PlayerInstance]:Disconnect()
			CharacterAddedConnections[PlayerInstance] = nil
		end
	end)

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

	RoleService.ClearRoles(Participants)
	table.clear(Participants)
	table.clear(RoleMap)
	table.clear(EliminatedPlayers)
	LastResultData = nil
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
		CurrentPhase = "Intermission"
		PhaseEndTime = Now() + (RunService:IsStudio() and 6 or RoundConst.INTERMISSION_DURATION)
		RoundEndTime = 0
		BroadcastPhaseChange()

		local WaitingAnnounced = false
		while true do
			local PlayerCount = #Players:GetPlayers()
			if PlayerCount >= MinPlayers then
				AnnouncementService.AnnounceAll("Round starting!", "Get ready...", RoundConst.INTERMISSION_DURATION - 2)
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
					AnnouncementService.AnnounceAll("Not enough players", "Waiting for more players...", 3)
					WaitingAnnounced = true
					PhaseEndTime = Now() + RoundConst.INTERMISSION_DURATION
					BroadcastPhaseChange()
				end
			else
				if not WaitingAnnounced then
					AnnouncementService.AnnounceAll("Waiting for players", MinPlayers .. " players needed to start", 4)
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
		RoundEndTime = Now() + RoundConst.ROUND_DURATION
		PhaseEndTime = RoundEndTime
		BroadcastPhaseChange()

		for _, PlayerInstance in Participants do
			HookParticipantDeath(PlayerInstance)
		end

		while CurrentPhase == "InProgress" and Now() < RoundEndTime do
			task.wait(0.5)
		end

		if CurrentPhase == "InProgress" then
			EndRound("PassengersWin")
		end

		local PostEndTime = PhaseEndTime
		while Now() < PostEndTime do
			task.wait(0.5)
		end

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
	local _Character = PlayerInstance.Character or PlayerInstance.CharacterAdded:Wait()
	task.wait()
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
