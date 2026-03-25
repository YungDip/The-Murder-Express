local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local Constants = require(ReplicatedStorage.Shared.Constants)
local AnnouncementController = require(script.Parent.AnnouncementController)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)
local SpectateController = require(script.Parent.SpectateController)
local UIState = require(script.Parent.Parent.UI.UIState)

local RoundConst = Constants.Round
local Player = Players.LocalPlayer
local Atmosphere = Lighting:WaitForChild("Atmosphere")

local RoundController = {}

local CurrentPhase: string = "Intermission"
local _PhaseEndTime: number = 0
local RoundEndTime: number = 0
local MyRole: string? = nil
local ParticipantIds: { number } = {}
local EliminatedPlayers: { { Name: string, Role: string, UserId: number } } = {}
local LastResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } }? = nil

local TimerVisible = false
local TimerWarningPulsing = false
local TimerSuppressedByAnnouncement = false

local function ShowTimer()
if TimerVisible then
return
end
if AnnouncementController.IsShowing() then
TimerSuppressedByAnnouncement = true
return
end
TimerVisible = true
TimerWarningPulsing = false
UIState.SetTimerWarning(false)
UIState.SetTimerVisible(true)
end

local function HideTimer()
TimerSuppressedByAnnouncement = false
if not TimerVisible then
return
end
TimerVisible = false
TimerWarningPulsing = false
UIState.SetTimerWarning(false)
UIState.SetTimerVisible(false)
end

AnnouncementController.OnShow(function()
if TimerVisible then
TimerSuppressedByAnnouncement = true
TimerVisible = false
TimerWarningPulsing = false
UIState.SetTimerVisible(false)
end
end)

AnnouncementController.OnHide(function()
if TimerSuppressedByAnnouncement and CurrentPhase == "InProgress" and RoundEndTime > 0 then
TimerSuppressedByAnnouncement = false
TimerVisible = true
TimerWarningPulsing = false
UIState.SetTimerWarning(false)
UIState.SetTimerVisible(true)
end
end)

local function FormatTime(Seconds: number): string
local Clamped = math.max(0, math.ceil(Seconds))
local Minutes = math.floor(Clamped / 60)
local Secs = Clamped % 60
return string.format("%d:%02d", Minutes, Secs)
end

RunService.PreRender:Connect(function()
if not TimerVisible or RoundEndTime <= 0 then
return
end

local Remaining = RoundEndTime - workspace:GetServerTimeNow()
UIState.SetTimerText(FormatTime(Remaining))

if Remaining <= RoundConst.TIMER_WARNING_THRESHOLD and Remaining > 0 then
if not TimerWarningPulsing then
TimerWarningPulsing = true
UIState.SetTimerWarning(true)
end
end
end)

local function PlayRoulette(TargetRole: string)
UIState.PlayRoulette(TargetRole)
end

local function HideRoulette()
UIState.HideRoulette()
end

local function ShowScoreboard(ResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } })
UIState.ShowScoreboard(ResultData)
end

local function HideScoreboard()
UIState.HideScoreboard()
end

local TELEPORT_FADE_COLOR = Color3.fromRGB(30, 20, 12)

local function IsLocalParticipant(): boolean
for _, Id in ParticipantIds do
if Id == Player.UserId then
return true
end
end
return false
end

local function _IsLocalEliminated(): boolean
	for _, Entry in EliminatedPlayers do
		if Entry.UserId == Player.UserId then
			return true
		end
	end
	return false
end

local ACTIVE_PHASES = {
	RoleReveal = true,
	InProgress = true,
}

local function ShouldBeActive(Phase: string): boolean
	return ACTIVE_PHASES[Phase] == true and IsLocalParticipant()
end

local function ShouldEffectsBeActive(Phase: string): boolean
	if not ACTIVE_PHASES[Phase] then
		return false
	end
	if IsLocalParticipant() and not _IsLocalEliminated() then
		return true
	end
	if SpectateController.IsSpectating() then
		return true
	end
	return false
end

local function HandlePhaseChange(Phase: string, NewPhaseEndTime: number, NewRoundEndTime: number?)
CurrentPhase = Phase
_PhaseEndTime = NewPhaseEndTime
if NewRoundEndTime then
RoundEndTime = NewRoundEndTime
end

ScrollSpeedState.Active = ShouldBeActive(Phase)
ScrollSpeedState.EffectsActive = ShouldEffectsBeActive(Phase)
	Atmosphere.Offset = if Phase == "Intermission" or Phase == "PostRound" then 0.04 else 0.4
    print("[RoundController] HandlePhaseChange:", Phase, "| IsParticipant:", IsLocalParticipant(), "| Active:", ScrollSpeedState.Active)

    if Phase == "Intermission" then
        HideTimer()
        HideRoulette()
        HideScoreboard()
        table.clear(EliminatedPlayers)
        MyRole = nil
        if UIState.IsShutterClosed then
            UIState.ShutterOpen(3, TELEPORT_FADE_COLOR)
        end
    elseif Phase == "Teleporting" then
        HideTimer()
        HideScoreboard()
        if IsLocalParticipant() then
            task.spawn(UIState.ShutterClose, 1.5, TELEPORT_FADE_COLOR)
        end
    elseif Phase == "RoleReveal" then
        if IsLocalParticipant() then
            task.spawn(UIState.ShutterOpen, 3, TELEPORT_FADE_COLOR)
            if MyRole then
                task.spawn(PlayRoulette, MyRole)
            end
        end
    elseif Phase == "InProgress" then
        HideScoreboard()
        if IsLocalParticipant() then
            ShowTimer()
        end
    elseif Phase == "PostRound" then
        HideTimer()
    end
end

RoundNetwork.packets.PhaseChange.listen(function(Data)
HandlePhaseChange(Data.Phase, Data.PhaseEndTime, Data.RoundEndTime)
end)

RoundNetwork.packets.RoleAssignment.listen(function(Data)
MyRole = Data.Role
if CurrentPhase == "RoleReveal" then
if MyRole then
task.spawn(PlayRoulette, MyRole)
end
end
end)

RoundNetwork.packets.PlayerEliminated.listen(function(Data)
table.insert(EliminatedPlayers, {
Name = Data.Name,
Role = Data.Role,
UserId = Data.UserId,
})

if Data.UserId == Player.UserId then
HideTimer()
ScrollSpeedState.EffectsActive = SpectateController.IsSpectating()
end
end)

RoundNetwork.packets.RoundResult.listen(function(Data)
LastResultData = Data
task.spawn(ShowScoreboard, Data)
end)

RoundNetwork.packets.ParticipantList.listen(function(Data)
ParticipantIds = Data.PlayerIds
print("[RoundController] ParticipantList received | PlayerIds:", Data.PlayerIds, "| LocalUserId:", Player.UserId, "| Type:", typeof(Player.UserId))
if Data.PlayerIds then
for Idx, Id in Data.PlayerIds do
print("[RoundController]   PlayerIds[" .. Idx .. "] =", Id, "| Type:", typeof(Id), "| Match:", Id == Player.UserId)
end
else
print("[RoundController]   PlayerIds is nil!")
end
	ScrollSpeedState.Active = ShouldBeActive(CurrentPhase)
	ScrollSpeedState.EffectsActive = ShouldEffectsBeActive(CurrentPhase)
	print("[RoundController] ParticipantList result | Phase:", CurrentPhase, "| IsParticipant:", IsLocalParticipant(), "| Active:", ScrollSpeedState.Active)

if CurrentPhase == "Teleporting" and IsLocalParticipant() and not UIState.IsShutterClosed then
task.spawn(UIState.ShutterClose, 1, TELEPORT_FADE_COLOR)
end
end)

task.spawn(function()
local State = RoundNetwork.queries.RequestRoundState.invoke(nil)
if not State then
return
end

CurrentPhase = State.Phase
_PhaseEndTime = State.PhaseEndTime
RoundEndTime = State.RoundEndTime or 0
MyRole = State.Role
ParticipantIds = State.ParticipantIds or {}
EliminatedPlayers = State.Eliminated or {}
LastResultData = State.ResultData

ScrollSpeedState.Active = ShouldBeActive(State.Phase)
ScrollSpeedState.EffectsActive = ShouldEffectsBeActive(State.Phase)
	Atmosphere.Offset = if State.Phase == "Intermission" or State.Phase == "PostRound" then 0.04 else 0.4
print("[RoundController] Initial state sync | Phase:", State.Phase, "| IsParticipant:", IsLocalParticipant(), "| Active:", ScrollSpeedState.Active)

if State.Phase == "InProgress" and IsLocalParticipant() then
ShowTimer()
elseif State.Phase == "PostRound" and LastResultData then
task.spawn(ShowScoreboard, LastResultData)
end
end)

function RoundController.GetPhase(): string
return CurrentPhase
end

function RoundController.GetRole(): string?
return MyRole
end

return RoundController