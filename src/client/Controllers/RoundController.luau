local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local Constants = require(ReplicatedStorage.Shared.Constants)
local LayeredSound = require(ReplicatedStorage.Shared.Util.LayeredSound)
local AnnouncementController = require(script.Parent.AnnouncementController)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)

local RoundConst = Constants.Round
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Atmosphere = Lighting:WaitForChild("Atmosphere")

local RoundController = {}

local CurrentPhase: string = "Intermission"
local _PhaseEndTime: number = 0
local RoundEndTime: number = 0
local MyRole: string? = nil
local ParticipantIds: { number } = {}
local EliminatedPlayers: { { Name: string, Role: string, UserId: number } } = {}
local LastResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } }? = nil

local TimerGui = Instance.new("ScreenGui")
TimerGui.Name = "TimerGui"
TimerGui.ResetOnSpawn = false
TimerGui.IgnoreGuiInset = true
TimerGui.DisplayOrder = 110
TimerGui.Parent = PlayerGui

local TimerContainer = Instance.new("Frame")
TimerContainer.Name = "TimerContainer"
TimerContainer.AnchorPoint = Vector2.new(0.5, 0)
TimerContainer.Position = UDim2.new(0.5, 0, -0.08, 0)
TimerContainer.Size = UDim2.new(RoundConst.TIMER_WIDTH, 0, 0, RoundConst.TIMER_HEIGHT)
TimerContainer.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
TimerContainer.BackgroundTransparency = 0.3
TimerContainer.BorderSizePixel = 0
TimerContainer.Parent = TimerGui

local TimerCorner = Instance.new("UICorner")
TimerCorner.CornerRadius = UDim.new(0, 6)
TimerCorner.Parent = TimerContainer

local TimerStroke = Instance.new("UIStroke")
TimerStroke.Color = RoundConst.TIMER_BORDER_COLOR
TimerStroke.Thickness = 2
TimerStroke.Parent = TimerContainer

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Name = "TimerLabel"
TimerLabel.Size = UDim2.fromScale(1, 1)
TimerLabel.BackgroundTransparency = 1
TimerLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
TimerLabel.TextColor3 = RoundConst.TIMER_TEXT_COLOR
TimerLabel.TextSize = RoundConst.TIMER_TEXT_SIZE
TimerLabel.Text = "3:00"
TimerLabel.Parent = TimerContainer

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
	TimerLabel.TextColor3 = RoundConst.TIMER_TEXT_COLOR
	TimerStroke.Color = RoundConst.TIMER_BORDER_COLOR
	TimerWarningPulsing = false
	TweenService:Create(TimerContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.02, 0),
	}):Play()
end

local function HideTimer()
	TimerSuppressedByAnnouncement = false
	if not TimerVisible then
		return
	end
	TimerVisible = false
	TimerWarningPulsing = false
	TweenService:Create(TimerContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, -0.08, 0),
	}):Play()
end

AnnouncementController.OnShow(function()
	if TimerVisible then
		TimerSuppressedByAnnouncement = true
		TimerVisible = false
		TimerWarningPulsing = false
		TweenService:Create(TimerContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.08, 0),
		}):Play()
	end
end)

AnnouncementController.OnHide(function()
	if TimerSuppressedByAnnouncement and CurrentPhase == "InProgress" and RoundEndTime > 0 then
		TimerSuppressedByAnnouncement = false
		TimerVisible = true
		TimerLabel.TextColor3 = RoundConst.TIMER_TEXT_COLOR
		TimerStroke.Color = RoundConst.TIMER_BORDER_COLOR
		TimerWarningPulsing = false
		TweenService:Create(TimerContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.02, 0),
		}):Play()
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
	TimerLabel.Text = FormatTime(Remaining)

	if Remaining <= RoundConst.TIMER_WARNING_THRESHOLD and Remaining > 0 then
		if not TimerWarningPulsing then
			TimerWarningPulsing = true
			TweenService:Create(TimerLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				TextColor3 = RoundConst.TIMER_WARNING_COLOR,
			}):Play()
			TweenService:Create(TimerStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Color = RoundConst.TIMER_WARNING_COLOR,
			}):Play()
		end
	end
end)

local RouletteGui = Instance.new("ScreenGui")
RouletteGui.Name = "RoleRevealGui"
RouletteGui.ResetOnSpawn = false
RouletteGui.IgnoreGuiInset = true
RouletteGui.DisplayOrder = 120
RouletteGui.Parent = PlayerGui

local RouletteContainer = Instance.new("Frame")
RouletteContainer.Name = "RouletteContainer"
RouletteContainer.AnchorPoint = Vector2.new(0.5, 0.5)
RouletteContainer.Position = UDim2.fromScale(0.5, 0.5)
RouletteContainer.Size = UDim2.new(0.25, 0, 0, RoundConst.ROULETTE_SLOT_HEIGHT)
RouletteContainer.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
RouletteContainer.BackgroundTransparency = 0.2
RouletteContainer.BorderSizePixel = 0
RouletteContainer.ClipsDescendants = true
RouletteContainer.Visible = false
RouletteContainer.Parent = RouletteGui

local RouletteCorner = Instance.new("UICorner")
RouletteCorner.CornerRadius = UDim.new(0, 8)
RouletteCorner.Parent = RouletteContainer

local RouletteStroke = Instance.new("UIStroke")
RouletteStroke.Color = RoundConst.TIMER_BORDER_COLOR
RouletteStroke.Thickness = 2
RouletteStroke.Parent = RouletteContainer

local RouletteScroll = Instance.new("Frame")
RouletteScroll.Name = "Scroll"
RouletteScroll.Size = UDim2.fromScale(1, 1)
RouletteScroll.Position = UDim2.fromScale(0, 0)
RouletteScroll.BackgroundTransparency = 1
RouletteScroll.Parent = RouletteContainer

local RoleHeaderLabel = Instance.new("TextLabel")
RoleHeaderLabel.Name = "RoleHeader"
RoleHeaderLabel.AnchorPoint = Vector2.new(0.5, 1)
RoleHeaderLabel.Position = UDim2.new(0.5, 0, 0.5, -(RoundConst.ROULETTE_SLOT_HEIGHT / 2) - 12)
RoleHeaderLabel.Size = UDim2.new(0.3, 0, 0, 30)
RoleHeaderLabel.BackgroundTransparency = 1
RoleHeaderLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
RoleHeaderLabel.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
RoleHeaderLabel.TextSize = 24
RoleHeaderLabel.Text = "Your Role"
RoleHeaderLabel.TextTransparency = 1
RoleHeaderLabel.Parent = RouletteGui

local ROLES_SEQUENCE = { "Innocent", "Detective", "Murderer" }

local RollClickSound: Sound = SoundService:WaitForChild("UI"):WaitForChild("RollClick")
local RoleSelectedSound: Sound = SoundService:WaitForChild("UI"):WaitForChild("RoleSelected")

--[[
    plays the role roulette animation and reveals the assigned role
    (@yields)
]]
local function PlayRoulette(TargetRole: string)
	RouletteContainer.Visible = true
	RoleHeaderLabel.TextTransparency = 1

	TweenService:Create(RoleHeaderLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	for _, Child in RouletteScroll:GetChildren() do
		Child:Destroy()
	end

	local SlotHeight = RoundConst.ROULETTE_SLOT_HEIGHT
	local TotalCycles = RoundConst.ROULETTE_TOTAL_CYCLES
	local TotalSlots = TotalCycles * #ROLES_SEQUENCE

	for I = 1, TotalSlots do
		local CycleIndex = ((I - 1) % #ROLES_SEQUENCE) + 1
		local RoleName: string
		if I == TotalSlots then
			RoleName = TargetRole
		else
			RoleName = ROLES_SEQUENCE[CycleIndex]
		end

		local Label = Instance.new("TextLabel")
		Label.Name = "Slot" .. I
		Label.Size = UDim2.new(1, 0, 0, SlotHeight)
		Label.Position = UDim2.new(0, 0, 0, (I - 1) * SlotHeight)
		Label.BackgroundTransparency = 1
		Label.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
		Label.TextColor3 = RoundConst.ROLE_COLORS[RoleName] or RoundConst.SCOREBOARD_TEXT_COLOR
		Label.TextSize = 30
		Label.Text = string.upper(RoleName)
		Label.Parent = RouletteScroll
	end

	RouletteScroll.Position = UDim2.fromOffset(0, 0)

	local MIN_DELAY = 0.04
	local MAX_DELAY = 0.25
	local MAX_PITCH = 3
	local MIN_PITCH = 1.5

	local PreviousClick: Sound? = nil

	for I = 1, TotalSlots - 1 do
		local Progress = I / TotalSlots
		local Alpha = Progress * Progress * Progress
		local StepDelay = MIN_DELAY + (MAX_DELAY - MIN_DELAY) * Alpha
		local Pitch = MAX_PITCH - (MAX_PITCH - MIN_PITCH) * Alpha

		local TargetY = -(I * SlotHeight)
		local StepTween = TweenService:Create(RouletteScroll, TweenInfo.new(
			StepDelay * 0.8,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		), {
			Position = UDim2.fromOffset(0, TargetY),
		})
		StepTween:Play()

		if PreviousClick then
			PreviousClick:Stop()
			PreviousClick:Destroy()
		end

		PreviousClick = LayeredSound.Play(RollClickSound, 0.05, Pitch)

		task.wait(StepDelay)
	end

	if PreviousClick then
		PreviousClick:Stop()
		PreviousClick:Destroy()
	end

	local FinalY = -((TotalSlots - 1) * SlotHeight)
	TweenService:Create(RouletteScroll, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, FinalY),
	}):Play()
	task.wait(0.15)

	LayeredSound.Play(RoleSelectedSound, 0.05, 1)

	local RoleColor = RoundConst.ROLE_COLORS[TargetRole] or RoundConst.SCOREBOARD_TEXT_COLOR

	TweenService:Create(RouletteStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = RoleColor,
		Thickness = 4,
	}):Play()

	TweenService:Create(RouletteContainer, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.28, 0, 0, SlotHeight + 10),
	}):Play()

	task.wait(0.3)

	TweenService:Create(RouletteContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.25, 0, 0, SlotHeight),
	}):Play()
	TweenService:Create(RouletteStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Thickness = 2,
	}):Play()

	task.wait(1.5)

	TweenService:Create(RouletteContainer, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(RouletteStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	TweenService:Create(RoleHeaderLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()

	for _, Child in RouletteScroll:GetChildren() do
		if Child:IsA("TextLabel") then
			TweenService:Create(Child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
			}):Play()
		end
	end

	task.wait(0.5)
	RouletteContainer.Visible = false

	RouletteContainer.BackgroundTransparency = 0.2
	RouletteStroke.Transparency = 0
	RouletteStroke.Color = RoundConst.TIMER_BORDER_COLOR
end

local function HideRoulette()
	RouletteContainer.Visible = false
	RoleHeaderLabel.TextTransparency = 1
end

local ScoreboardGui = Instance.new("ScreenGui")
ScoreboardGui.Name = "ScoreboardGui"
ScoreboardGui.ResetOnSpawn = false
ScoreboardGui.IgnoreGuiInset = true
ScoreboardGui.DisplayOrder = 130
ScoreboardGui.Parent = PlayerGui

local ScoreboardContainer = Instance.new("Frame")
ScoreboardContainer.Name = "ScoreboardContainer"
ScoreboardContainer.AnchorPoint = Vector2.new(0.5, 0.5)
ScoreboardContainer.Position = UDim2.fromScale(0.5, 0.5)
ScoreboardContainer.Size = UDim2.new(RoundConst.SCOREBOARD_WIDTH, 0, 0, 0)
ScoreboardContainer.AutomaticSize = Enum.AutomaticSize.Y
ScoreboardContainer.BackgroundColor3 = RoundConst.SCOREBOARD_BG_COLOR
ScoreboardContainer.BackgroundTransparency = 0.15
ScoreboardContainer.BorderSizePixel = 0
ScoreboardContainer.Visible = false
ScoreboardContainer.Parent = ScoreboardGui

local ScoreboardCorner = Instance.new("UICorner")
ScoreboardCorner.CornerRadius = UDim.new(0, 8)
ScoreboardCorner.Parent = ScoreboardContainer

local ScoreboardStroke = Instance.new("UIStroke")
ScoreboardStroke.Color = RoundConst.TIMER_BORDER_COLOR
ScoreboardStroke.Thickness = 2
ScoreboardStroke.Parent = ScoreboardContainer

local ScoreboardPadding = Instance.new("UIPadding")
ScoreboardPadding.PaddingTop = UDim.new(0, 16)
ScoreboardPadding.PaddingBottom = UDim.new(0, 16)
ScoreboardPadding.PaddingLeft = UDim.new(0, 16)
ScoreboardPadding.PaddingRight = UDim.new(0, 16)
ScoreboardPadding.Parent = ScoreboardContainer

local ScoreboardLayout = Instance.new("UIListLayout")
ScoreboardLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScoreboardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ScoreboardLayout.Padding = UDim.new(0, 8)
ScoreboardLayout.Parent = ScoreboardContainer

local function ShowScoreboard(ResultData: { Result: string, Players: { { Name: string, Role: string, Alive: boolean, UserId: number } } })
	for _, Child in ScoreboardContainer:GetChildren() do
		if Child:IsA("TextLabel") or Child:IsA("Frame") then
			if Child.Name ~= "ScoreboardContainer" then
				Child:Destroy()
			end
		end
	end

	local ResultText = RoundConst.RESULT_TEXT[ResultData.Result] or "Round Over!"
	local ResultColor = Color3.fromRGB(234, 224, 152)
	if ResultData.Result == "MurdererWin" then
		ResultColor = RoundConst.ROLE_COLORS.Murderer
	elseif ResultData.Result == "DetectiveWin" then
		ResultColor = RoundConst.ROLE_COLORS.Detective
	elseif ResultData.Result == "PassengersWin" then
		ResultColor = RoundConst.ROLE_COLORS.Innocent
	end

	local Header = Instance.new("TextLabel")
	Header.Name = "Header"
	Header.Size = UDim2.new(1, 0, 0, 0)
	Header.AutomaticSize = Enum.AutomaticSize.Y
	Header.BackgroundTransparency = 1
	Header.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
	Header.TextColor3 = ResultColor
	Header.TextSize = RoundConst.SCOREBOARD_HEADER_SIZE
	Header.Text = ResultText
	Header.TextWrapped = true
	Header.LayoutOrder = 1
	Header.Parent = ScoreboardContainer

	local Sep = Instance.new("Frame")
	Sep.Name = "Separator"
	Sep.Size = UDim2.new(0.8, 0, 0, 2)
	Sep.BackgroundColor3 = RoundConst.TIMER_BORDER_COLOR
	Sep.BackgroundTransparency = 0.5
	Sep.BorderSizePixel = 0
	Sep.LayoutOrder = 2
	Sep.Parent = ScoreboardContainer

	for Index, PlayerData in ResultData.Players do
		local Row = Instance.new("Frame")
		Row.Name = "Row_" .. PlayerData.Name
		Row.Size = UDim2.new(1, 0, 0, RoundConst.SCOREBOARD_ROW_HEIGHT)
		Row.BackgroundTransparency = if Index % 2 == 0 then 0.85 else 1
		Row.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
		Row.BorderSizePixel = 0
		Row.LayoutOrder = 10 + Index
		Row.Parent = ScoreboardContainer

		local RowCorner = Instance.new("UICorner")
		RowCorner.CornerRadius = UDim.new(0, 4)
		RowCorner.Parent = Row

		local StatusIcon = Instance.new("TextLabel")
		StatusIcon.Name = "Status"
		StatusIcon.Size = UDim2.new(0, 30, 1, 0)
		StatusIcon.Position = UDim2.fromOffset(8, 0)
		StatusIcon.BackgroundTransparency = 1
		StatusIcon.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
		StatusIcon.TextColor3 = if PlayerData.Alive then Color3.fromRGB(100, 200, 100) else Color3.fromRGB(200, 60, 60)
		StatusIcon.TextSize = 18
		StatusIcon.Text = if PlayerData.Alive then "●" else "✕"
		StatusIcon.Parent = Row

		local NameLabel = Instance.new("TextLabel")
		NameLabel.Name = "PlayerName"
		NameLabel.Size = UDim2.new(0.5, -50, 1, 0)
		NameLabel.Position = UDim2.fromOffset(42, 0)
		NameLabel.BackgroundTransparency = 1
		NameLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Regular)
		NameLabel.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
		NameLabel.TextSize = RoundConst.SCOREBOARD_ROW_TEXT_SIZE
		NameLabel.Text = PlayerData.Name
		NameLabel.TextXAlignment = Enum.TextXAlignment.Left
		NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		NameLabel.Parent = Row

		local RoleColor = RoundConst.ROLE_COLORS[PlayerData.Role] or RoundConst.SCOREBOARD_TEXT_COLOR
		local RoleLabel = Instance.new("TextLabel")
		RoleLabel.Name = "RoleLabel"
		RoleLabel.AnchorPoint = Vector2.new(1, 0)
		RoleLabel.Size = UDim2.new(0.35, -8, 1, 0)
		RoleLabel.Position = UDim2.new(1, -8, 0, 0)
		RoleLabel.BackgroundTransparency = 1
		RoleLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
		RoleLabel.TextColor3 = RoleColor
		RoleLabel.TextSize = RoundConst.SCOREBOARD_ROW_TEXT_SIZE
		RoleLabel.Text = PlayerData.Role
		RoleLabel.TextXAlignment = Enum.TextXAlignment.Right
		RoleLabel.Parent = Row
	end

	ScoreboardContainer.Visible = true
	ScoreboardContainer.Size = UDim2.new(RoundConst.SCOREBOARD_WIDTH * 0.8, 0, 0, 0)
	ScoreboardContainer.BackgroundTransparency = 1
	ScoreboardStroke.Transparency = 1

	TweenService:Create(ScoreboardContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(RoundConst.SCOREBOARD_WIDTH, 0, 0, 0),
		BackgroundTransparency = 0.15,
	}):Play()
	TweenService:Create(ScoreboardStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0,
	}):Play()

	for _, Child in ScoreboardContainer:GetChildren() do
		if Child:IsA("TextLabel") or (Child:IsA("Frame") and Child.Name ~= "ScoreboardContainer") then
			if Child:IsA("TextLabel") then
				Child.TextTransparency = 1
				TweenService:Create(Child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()
			end
		end
	end
end

local function HideScoreboard()
	if not ScoreboardContainer.Visible then
		return
	end

	TweenService:Create(ScoreboardContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(ScoreboardStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()

	task.wait(0.35)
	ScoreboardContainer.Visible = false

	for _, Child in ScoreboardContainer:GetChildren() do
		if Child:IsA("TextLabel") or (Child:IsA("Frame") and Child.Name ~= "ScoreboardContainer") then
			Child:Destroy()
		end
	end
end

local TeleportFadeGui = Instance.new("ScreenGui")
TeleportFadeGui.Name = "TeleportFadeGui"
TeleportFadeGui.ResetOnSpawn = false
TeleportFadeGui.IgnoreGuiInset = true
TeleportFadeGui.DisplayOrder = 200
TeleportFadeGui.ScreenInsets = Enum.ScreenInsets.None
TeleportFadeGui.Parent = PlayerGui

local TeleportFade = Instance.new("Frame")
TeleportFade.Name = "Fade"
TeleportFade.AnchorPoint = Vector2.new(0.5, 0.5)
TeleportFade.Position = UDim2.fromScale(0.5, 0.5)
TeleportFade.Size = UDim2.fromScale(1.5, 1.5)
TeleportFade.BackgroundColor3 = Color3.fromRGB(30, 20, 12)
TeleportFade.BackgroundTransparency = 0
TeleportFade.BorderSizePixel = 0
TeleportFade.Parent = TeleportFadeGui

local FadeGradient = Instance.new("UIGradient")
FadeGradient.Rotation = 90
FadeGradient.Transparency = NumberSequence.new(1)
FadeGradient.Parent = TeleportFade

local IsFadedToBlack = false
local SHUTTER_SECTIONS = 10

local function BuildFadeCloseKeypoints(Section: number, Alpha: number): NumberSequence
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

local function BuildFadeOpenKeypoints(Section: number, Alpha: number): NumberSequence
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

local function FadeToBlack(Duration: number)
	local SectionDuration = Duration / SHUTTER_SECTIONS

	for Section = 0, SHUTTER_SECTIONS - 1 do
		local Elapsed = 0
		while Elapsed < SectionDuration do
			local Delta = RunService.PreRender:Wait()
			Elapsed += Delta
			local T = math.clamp(Elapsed / SectionDuration, 0, 1)
			local Eased = T * T * (3 - 2 * T)
			local Alpha = 1 - Eased
			FadeGradient.Transparency = BuildFadeCloseKeypoints(Section, Alpha)
		end
	end

	FadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	IsFadedToBlack = true
end

local function FadeFromBlack(Duration: number)
	FadeGradient.Transparency = NumberSequence.new({
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
			FadeGradient.Transparency = BuildFadeOpenKeypoints(Section, Alpha)
		end
	end

	FadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	IsFadedToBlack = false
end

local function IsLocalParticipant(): boolean
	for _, Id in ParticipantIds do
		if Id == Player.UserId then
			return true
		end
	end
	return false
end

local ACTIVE_PHASES = {
	RoleReveal = true,
	InProgress = true,
	PostRound = true,
}

local function ShouldBeActive(Phase: string): boolean
	return ACTIVE_PHASES[Phase] == true and IsLocalParticipant()
end

local function HandlePhaseChange(Phase: string, NewPhaseEndTime: number, NewRoundEndTime: number?)
	CurrentPhase = Phase
	_PhaseEndTime = NewPhaseEndTime
	if NewRoundEndTime then
		RoundEndTime = NewRoundEndTime
	end

	ScrollSpeedState.Active = ShouldBeActive(Phase)
	Atmosphere.Density = if Phase == "Intermission" then 0.04 else 0.4
	print("[RoundController] HandlePhaseChange:", Phase, "| IsParticipant:", IsLocalParticipant(), "| Active:", ScrollSpeedState.Active)

	if Phase == "Intermission" then
		HideTimer()
		HideRoulette()
		HideScoreboard()
		if IsFadedToBlack then
			FadeFromBlack(3)
		end

	elseif Phase == "Teleporting" then
		HideTimer()
		HideRoulette()
		HideScoreboard()
		if IsLocalParticipant() then
			task.spawn(FadeToBlack, 1.5)
		end

	elseif Phase == "RoleReveal" then
		if IsLocalParticipant() then
			task.spawn(function()
				FadeFromBlack(3)
			end)
			if MyRole then
				task.spawn(PlayRoulette, MyRole)
			end
		end

	elseif Phase == "InProgress" then
		HideRoulette()
		HideScoreboard()
		if IsLocalParticipant() then
			ShowTimer()
		end

	elseif Phase == "PostRound" then
		HideTimer()
		HideRoulette()
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
	print("[RoundController] ParticipantList result | Phase:", CurrentPhase, "| IsParticipant:", IsLocalParticipant(), "| Active:", ScrollSpeedState.Active)

	if CurrentPhase == "Teleporting" and IsLocalParticipant() and not IsFadedToBlack then
		task.spawn(FadeToBlack, 1)
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
	Atmosphere.Offset = if State.Phase == "Intermission" then 0.04 else 0.4
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

function RoundController.IsLocalParticipant(): boolean
	return IsLocalParticipant()
end

function RoundController.GetParticipantIds(): { number }
	return ParticipantIds
end

function RoundController.GetEliminatedPlayers(): { { Name: string, Role: string, UserId: number } }
	return EliminatedPlayers
end

return RoundController
