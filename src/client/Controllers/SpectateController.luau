local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)
local UIState = require(script.Parent.Parent.UI.UIState)

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerModule = require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))

local SpectateController = {}

local CurrentPhase: string = "Intermission"
local ParticipantIds: { number } = {}
local EliminatedUserIds: { [number]: boolean } = {}
local IsSpectating = false
local SpectateTargetIndex = 0

local function IsLocalParticipant(): boolean
	for _, Id in ParticipantIds do
		if Id == Player.UserId then
			return true
		end
	end
	return false
end

local function IsLocalEliminated(): boolean
	return EliminatedUserIds[Player.UserId] == true
end

local function GetAliveParticipants(): { Player }
	local Alive = {}
	for _, Id in ParticipantIds do
		if not EliminatedUserIds[Id] and Id ~= Player.UserId then
			local P = Players:GetPlayerByUserId(Id)
			if P and P.Character and P.Character:FindFirstChildOfClass("Humanoid") then
				local Humanoid = P.Character:FindFirstChildOfClass("Humanoid")
				if Humanoid.Health > 0 then
					table.insert(Alive, P)
				end
			end
		end
	end
	return Alive
end

local function CanShowSpectateButton(): boolean
	if CurrentPhase ~= "InProgress" then
		return false
	end
	if IsLocalParticipant() and not IsLocalEliminated() then
		return false
	end
	return true
end

local function GetTargetInfo(Target: Player): (string, string)
	local Name = Target.DisplayName
	local Role = Target:GetAttribute("Role") or "Unknown"
	return Name, Role
end

local function UpdateSpectateTarget()
	local Alive = GetAliveParticipants()

	if #Alive == 0 then
		if IsSpectating then
			UIState.UpdateSpectateTarget("No players alive", "", 0, 0)
		end
		return
	end

	if SpectateTargetIndex < 1 or SpectateTargetIndex > #Alive then
		SpectateTargetIndex = 1
	end

	local Target = Alive[SpectateTargetIndex]
	if Target and Target.Character then
		local Humanoid = Target.Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CameraSubject = Humanoid
			local Name, Role = GetTargetInfo(Target)
			UIState.UpdateSpectateTarget(Name, Role, Target.UserId, #Alive)
		end
	end
end

local function StartSpectate()
	if IsSpectating then
		return
	end
	IsSpectating = true
	SpectateTargetIndex = 1
	ScrollSpeedState.EffectsActive = true

	PlayerModule:GetControls():Disable()

	local Alive = GetAliveParticipants()
	local TargetName = ""
	local TargetRole = ""
	local TargetUserId = 0

	if #Alive > 0 then
		if SpectateTargetIndex < 1 or SpectateTargetIndex > #Alive then
			SpectateTargetIndex = 1
		end
		local Target = Alive[SpectateTargetIndex]
		if Target and Target.Character then
			local Humanoid = Target.Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				Camera.CameraType = Enum.CameraType.Custom
				Camera.CameraSubject = Humanoid
			end
		end
		TargetName, TargetRole = GetTargetInfo(Target)
		TargetUserId = Target.UserId
	end

	UIState.ShowSpectate(TargetName, TargetRole, TargetUserId, #Alive)
end

local function StopSpectate()
	if not IsSpectating then
		return
	end
	IsSpectating = false
	ScrollSpeedState.EffectsActive = false

	PlayerModule:GetControls():Enable()

	Camera.CameraType = Enum.CameraType.Custom
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Camera.CameraSubject = Humanoid
		end
	end

	UIState.HideSpectate(CanShowSpectateButton())
end

local function CycleTarget(Direction: number)
	if not IsSpectating then
		return
	end

	local Alive = GetAliveParticipants()
	if #Alive <= 1 then
		return
	end

	SpectateTargetIndex = SpectateTargetIndex + Direction
	if SpectateTargetIndex < 1 then
		SpectateTargetIndex = #Alive
	elseif SpectateTargetIndex > #Alive then
		SpectateTargetIndex = 1
	end

	UpdateSpectateTarget()
end

RoundNetwork.packets.PhaseChange.listen(function(Data)
	CurrentPhase = Data.Phase

	if Data.Phase == "Intermission" or Data.Phase == "PostRound" then
		StopSpectate()
		UIState.SetSpectateCanSpectate(false)
	elseif Data.Phase == "InProgress" then
		EliminatedUserIds = {}
		if not IsLocalParticipant() then
			UIState.SetSpectateCanSpectate(true)
		end
	elseif Data.Phase == "Teleporting" or Data.Phase == "RoleReveal" then
		UIState.SetSpectateCanSpectate(false)
	end
end)

RoundNetwork.packets.ParticipantList.listen(function(Data)
	ParticipantIds = Data.PlayerIds
	if CanShowSpectateButton() and not IsSpectating then
		UIState.SetSpectateCanSpectate(true)
	end
end)

RoundNetwork.packets.PlayerEliminated.listen(function(Data)
	EliminatedUserIds[Data.UserId] = true

	if Data.UserId == Player.UserId then
		if not IsSpectating and CanShowSpectateButton() then
			UIState.SetSpectateCanSpectate(true)
		end
	end

	if IsSpectating then
		UpdateSpectateTarget()
	end
end)

task.spawn(function()
	local State = RoundNetwork.queries.RequestRoundState.invoke(nil)
	if not State then
		return
	end

	CurrentPhase = State.Phase
	ParticipantIds = State.ParticipantIds or {}

	if State.Eliminated then
		for _, Entry in State.Eliminated do
			EliminatedUserIds[Entry.UserId] = true
		end
	end

	if CanShowSpectateButton() then
		UIState.SetSpectateCanSpectate(true)
	end
end)

UIState.OnSpectateStart = StartSpectate
UIState.OnSpectateStop = StopSpectate
UIState.OnSpectateCycle = CycleTarget

function SpectateController.IsSpectating(): boolean
	return IsSpectating
end

function SpectateController.StartSpectate()
	StartSpectate()
end

function SpectateController.StopSpectate()
	StopSpectate()
end

function SpectateController.CycleTarget(Direction: number)
	CycleTarget(Direction)
end

return SpectateController
