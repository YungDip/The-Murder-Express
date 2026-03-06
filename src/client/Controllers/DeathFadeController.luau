local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)

local RoundConst = Constants.Round
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local DeathFadeController = {}

local CurrentPhase: string = "Intermission"
local IsActive = false

local DeathFadeGui = Instance.new("ScreenGui")
DeathFadeGui.Name = "DeathFadeGui"
DeathFadeGui.ResetOnSpawn = false
DeathFadeGui.IgnoreGuiInset = true
DeathFadeGui.DisplayOrder = 200
DeathFadeGui.ScreenInsets = Enum.ScreenInsets.None
DeathFadeGui.Parent = PlayerGui

local FadeFrame = Instance.new("Frame")
FadeFrame.Name = "DeathFade"
FadeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FadeFrame.Position = UDim2.fromScale(0.5, 0.5)
FadeFrame.Size = UDim2.fromScale(1.5, 1.5)
FadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
FadeFrame.BorderSizePixel = 0
FadeFrame.Visible = false
FadeFrame.Parent = DeathFadeGui

local ShutterGradient = Instance.new("UIGradient")
ShutterGradient.Rotation = 90
ShutterGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 1),
})
ShutterGradient.Parent = FadeFrame

local SHUTTER_SECTIONS = 10

local function BuildCloseKeypoints(Section: number, Alpha: number): NumberSequence
	local SectionStart = Section / SHUTTER_SECTIONS
	local SectionEnd = (Section + 1) / SHUTTER_SECTIONS
	local Keypoints = {}

	if Section == 0 then
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd - 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, 1))
	elseif Section == SHUTTER_SECTIONS - 1 then
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart + 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, Alpha))
	else
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart + 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd - 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, 1))
	end

	return NumberSequence.new(Keypoints)
end

local function BuildOpenKeypoints(Section: number, Alpha: number): NumberSequence
	local SectionStart = Section / SHUTTER_SECTIONS
	local SectionEnd = (Section + 1) / SHUTTER_SECTIONS
	local Keypoints = {}

	if Section == 0 then
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd - 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, 0))
	elseif Section == SHUTTER_SECTIONS - 1 then
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart + 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, Alpha))
	else
		table.insert(Keypoints, NumberSequenceKeypoint.new(0, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart, 1))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionStart + 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd - 0.001, Alpha))
		table.insert(Keypoints, NumberSequenceKeypoint.new(SectionEnd, 0))
		table.insert(Keypoints, NumberSequenceKeypoint.new(1, 0))
	end

	return NumberSequence.new(Keypoints)
end

local function ShutterClose(Duration: number)
	FadeFrame.Visible = true
	local SectionDuration = Duration / SHUTTER_SECTIONS

	for Section = 0, SHUTTER_SECTIONS - 1 do
		local Elapsed = 0
		while Elapsed < SectionDuration do
			local Delta = RunService.PreRender:Wait()
			Elapsed += Delta
			local T = math.clamp(Elapsed / SectionDuration, 0, 1)
			local Eased = T * T * (3 - 2 * T)
			local Alpha = 1 - Eased
			ShutterGradient.Transparency = BuildCloseKeypoints(Section, Alpha)
		end
	end

	ShutterGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function ShutterOpen(Duration: number)
	ShutterGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})

	local SectionDuration = Duration / SHUTTER_SECTIONS

	for Section = 0, SHUTTER_SECTIONS - 1 do
		local Elapsed = 0
		while Elapsed < SectionDuration do
			local Delta = RunService.PreRender:Wait()
			Elapsed += Delta
			local T = math.clamp(Elapsed / SectionDuration, 0, 1)
			local Eased = T * T * (3 - 2 * T)
			local Alpha = Eased
			ShutterGradient.Transparency = BuildOpenKeypoints(Section, Alpha)
		end
	end

	ShutterGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	FadeFrame.Visible = false
end

--[[
    plays the full shutter-close, hold, and shutter-open sequence on death
    (@yields)
]]
local function OnLocalPlayerDied()
	--[[if CurrentPhase ~= "InProgress" then
		return
	end
	if IsActive then
		return
	end
	IsActive = true

	task.wait(RoundConst.DEATH_RAGDOLL_WAIT)]]

	ShutterClose(RoundConst.DEATH_FADE_DURATION)

	local Character = Player.Character
	if not Character or not Character:FindFirstChildOfClass("Humanoid") or Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
		Player.CharacterAdded:Wait()
		task.wait(0.5)
	end

	task.wait(0.5)

	ShutterOpen(RoundConst.DEATH_FADE_DURATION)

	IsActive = false
end

local function ConnectDeathHandler()
	local Character = Player.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end
	Humanoid.Died:Connect(function()
		task.spawn(OnLocalPlayerDied)
	end)
end

Player.CharacterAdded:Connect(function(Character)
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if Humanoid then
		Humanoid.Died:Connect(function()
			task.spawn(OnLocalPlayerDied)
		end)
	end
end)

if Player.Character then
	task.spawn(ConnectDeathHandler)
end

RoundNetwork.packets.PhaseChange.listen(function(Data)
	CurrentPhase = Data.Phase

	if Data.Phase == "Intermission" or Data.Phase == "PostRound" then
		if IsActive then
			IsActive = false
			ShutterGradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			FadeFrame.Visible = false
		end
	end
end)

return DeathFadeController
