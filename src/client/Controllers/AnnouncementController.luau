local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local AnnouncementNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.AnnouncementNetwork)
local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local LayeredSound = require(game:GetService("ReplicatedStorage").Shared.Util.LayeredSound)

local AnnouncementConst = Constants.Announcement
local Player = game:GetService("Players").LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local AnnouncementController = {}

local Queue: { { Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean? } } = {}
local IsShowing = false

local OnShowCallbacks: { () -> () } = {}
local OnHideCallbacks: { () -> () } = {}

local BEIGE = AnnouncementConst.TEXT_COLOR
local BG_COLOR = AnnouncementConst.BG_COLOR
local BORDER_COLOR = AnnouncementConst.BORDER_COLOR
local WARNING_COLOR = AnnouncementConst.WARNING_COLOR
local WARNING_PULSE_SPEED = AnnouncementConst.WARNING_PULSE_SPEED
local FONT = AnnouncementConst.FONT
local TITLE_SIZE = AnnouncementConst.TITLE_SIZE
local SUBTITLE_SIZE = AnnouncementConst.SUBTITLE_SIZE
local DISPLAY_DURATION = AnnouncementConst.DISPLAY_DURATION
local BORDER_THICKNESS = AnnouncementConst.BORDER_THICKNESS
local SLIDE_DURATION = AnnouncementConst.SLIDE_DURATION
local BORDER_SNAKE_DURATION = AnnouncementConst.BORDER_SNAKE_DURATION
local HOLD_AFTER_BORDER = AnnouncementConst.HOLD_AFTER_BORDER

local function IsSmallScreen(): boolean
	return Camera.ViewportSize.Y < AnnouncementConst.SMALL_THRESHOLD
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnnouncementGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = PlayerGui

--[[
    creates a named border segment frame anchored and parented to Parent
]]
local function CreateBorderSegment(Parent: Frame, AnchorPoint: Vector2, Position: UDim2, InitialSize: UDim2, Name: string, Color: Color3): Frame
	local Segment = Instance.new("Frame")
	Segment.Name = Name
	Segment.AnchorPoint = AnchorPoint
	Segment.Position = Position
	Segment.Size = InitialSize
	Segment.BackgroundColor3 = Color
	Segment.BorderSizePixel = 0
	Segment.Parent = Parent
	return Segment
end

--[[
    animates 6 border segments snaking around a content box from top-center outward
    (@yields)
]]
local function AnimateBorderIn(BorderContainer: Frame, ContentBox: Frame, Gradients: { UIGradient }?, BorderColor: Color3): { Frame }
	local T = BORDER_THICKNESS

	task.wait()
	local BoxSize = ContentBox.AbsoluteSize
	local W = math.round(BoxSize.X)
	local H = math.round(BoxSize.Y)
	local HalfW = math.round(W / 2)

	BorderContainer.Size = UDim2.fromOffset(W, H)

	local TopRight = CreateBorderSegment(
		BorderContainer,
		Vector2.new(0, 0),
		UDim2.fromOffset(HalfW, 0),
		UDim2.fromOffset(0, T),
		"TopRight",
		BorderColor
	)

	local TopLeft = CreateBorderSegment(
		BorderContainer,
		Vector2.new(1, 0),
		UDim2.fromOffset(HalfW, 0),
		UDim2.fromOffset(0, T),
		"TopLeft",
		BorderColor
	)

	local RightSide = CreateBorderSegment(
		BorderContainer,
		Vector2.new(1, 0),
		UDim2.fromOffset(W, 0),
		UDim2.fromOffset(T, 0),
		"RightSide",
		BorderColor
	)

	local LeftSide = CreateBorderSegment(
		BorderContainer,
		Vector2.new(0, 0),
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(T, 0),
		"LeftSide",
		BorderColor
	)

	local BottomRight = CreateBorderSegment(
		BorderContainer,
		Vector2.new(1, 1),
		UDim2.fromOffset(W, H),
		UDim2.fromOffset(0, T),
		"BottomRight",
		BorderColor
	)

	local BottomLeft = CreateBorderSegment(
		BorderContainer,
		Vector2.new(0, 1),
		UDim2.fromOffset(0, H),
		UDim2.fromOffset(0, T),
		"BottomLeft",
		BorderColor
	)

	local SegDuration = BORDER_SNAKE_DURATION / 3
	local EaseStyle = Enum.EasingStyle.Quad
	local EaseOut = Enum.EasingDirection.Out
	local EaseIn = Enum.EasingDirection.In

	local TweenTopRight = TweenService:Create(TopRight, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(HalfW, T),
	})
	local TweenTopLeft = TweenService:Create(TopLeft, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(HalfW, T),
	})

	local TweenRight = TweenService:Create(RightSide, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(T, H),
	})
	local TweenLeft = TweenService:Create(LeftSide, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(T, H),
	})

	local TweenBottomRight = TweenService:Create(BottomRight, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(HalfW, T),
	})
	local TweenBottomLeft = TweenService:Create(BottomLeft, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(HalfW, T),
	})

	if Gradients then
		for _, G in Gradients do
			TweenService:Create(G, TweenInfo.new(BORDER_SNAKE_DURATION, EaseStyle, EaseOut), {
				Offset = Vector2.new(0, 1),
			}):Play()
		end
	end

	TweenTopRight:Play()
	TweenTopLeft:Play()
	TweenTopRight.Completed:Wait()

	TweenRight:Play()
	TweenLeft:Play()
	TweenRight.Completed:Wait()

	TweenBottomRight:Play()
	TweenBottomLeft:Play()
	TweenBottomLeft.Completed:Wait()

	return { TopRight, TopLeft, RightSide, LeftSide, BottomRight, BottomLeft }
end

--[[
    reverses the border animation, retracting all segments back to center
    (@yields)
]]
local function AnimateBorderOut(Segments: { Frame }, Gradients: { UIGradient }?)
	local T = BORDER_THICKNESS
	local TopRight, TopLeft, RightSide, LeftSide, BottomRight, BottomLeft =
		Segments[1], Segments[2], Segments[3], Segments[4], Segments[5], Segments[6]

	local SegDuration = BORDER_SNAKE_DURATION / 3
	local EaseStyle = Enum.EasingStyle.Quad
	local EaseOut = Enum.EasingDirection.Out
	local EaseIn = Enum.EasingDirection.In

	if Gradients then
		for _, G in Gradients do
			TweenService:Create(G, TweenInfo.new(BORDER_SNAKE_DURATION, EaseStyle, EaseIn), {
				Offset = Vector2.new(0, -1),
			}):Play()
		end
	end

	local TweenBR = TweenService:Create(BottomRight, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(0, T),
	})
	local TweenBL = TweenService:Create(BottomLeft, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(0, T),
	})
	TweenBR:Play()
	TweenBL:Play()
	TweenBR.Completed:Wait()

	local TweenR = TweenService:Create(RightSide, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(T, 0),
	})
	local TweenL = TweenService:Create(LeftSide, TweenInfo.new(SegDuration, EaseStyle, EaseOut), {
		Size = UDim2.fromOffset(T, 0),
	})
	TweenR:Play()
	TweenL:Play()
	TweenR.Completed:Wait()

	local TweenTR = TweenService:Create(TopRight, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(0, T),
	})
	local TweenTL = TweenService:Create(TopLeft, TweenInfo.new(SegDuration, EaseStyle, EaseIn), {
		Size = UDim2.fromOffset(0, T),
	})
	TweenTR:Play()
	TweenTL:Play()
	TweenTL.Completed:Wait()

	for _, Segment in Segments do
		Segment:Destroy()
	end
end

--[[
    shows a single announcement with animated border and slide-in/out
    (@yields)
]]
local function ShowAnnouncement(Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean?)
	IsShowing = true

	for _, Callback in OnShowCallbacks do
		task.spawn(Callback)
	end

	local SoundObj = SoundService.UI:FindFirstChild(if IsWarning then "Warning" else "Announcement")
	if SoundObj and SoundObj:IsA("Sound") then
		LayeredSound.Play(SoundObj, 0.5)
	end
	local HoldTime = Duration or DISPLAY_DURATION
	local BorderColor = if IsWarning then WARNING_COLOR else BORDER_COLOR
	local Small = IsSmallScreen()
	local ActiveTitleSize = if Small then AnnouncementConst.SMALL_TITLE_SIZE else TITLE_SIZE
	local ActiveSubtitleSize = if Small then AnnouncementConst.SMALL_SUBTITLE_SIZE else SUBTITLE_SIZE
	local ActivePadV = if Small then AnnouncementConst.SMALL_PADDING_V else 14
	local ActivePadH = if Small then AnnouncementConst.SMALL_PADDING_H else 20
	local ActiveWidth = if Small then AnnouncementConst.SMALL_WIDTH else 0.35

	local Anchor = Instance.new("Frame")
	Anchor.Name = "AnnouncementAnchor"
	Anchor.AnchorPoint = Vector2.new(0.5, 0)
	Anchor.Position = UDim2.new(0.5, 0, -0.15, 0)
	Anchor.Size = UDim2.new(ActiveWidth, 0, 0, 0) -- width; height is auto
	Anchor.AutomaticSize = Enum.AutomaticSize.Y
	Anchor.BackgroundTransparency = 1
	Anchor.Parent = ScreenGui

	local BorderContainer = Instance.new("Frame")
	BorderContainer.Name = "BorderContainer"
	BorderContainer.AnchorPoint = Vector2.new(0.5, 0)
	BorderContainer.Position = UDim2.new(0.5, 0, 0, 0)
	BorderContainer.Size = UDim2.new(1, 0, 0, 0) -- height set later from AbsoluteSize
	BorderContainer.BackgroundTransparency = 1
	BorderContainer.ZIndex = 2
	BorderContainer.Parent = Anchor

	local ContentBox = Instance.new("Frame")
	ContentBox.Name = "ContentBox"
	ContentBox.AnchorPoint = Vector2.new(0.5, 0)
	ContentBox.Position = UDim2.new(0.5, 0, 0, 0)
	ContentBox.Size = UDim2.new(1, 0, 0, 0)
	ContentBox.AutomaticSize = Enum.AutomaticSize.Y
	ContentBox.BackgroundColor3 = BG_COLOR
	ContentBox.BackgroundTransparency = 0.3
	ContentBox.BorderSizePixel = 0
	ContentBox.ZIndex = 1
	ContentBox.Parent = Anchor

	local ContentCorner = Instance.new("UICorner")
	ContentCorner.CornerRadius = UDim.new(0, 4)
	ContentCorner.Parent = ContentBox

	local Gradients: { UIGradient } = {}

	local Gradient = Instance.new("UIGradient")
	Gradient.Rotation = 90
	Gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	Gradient.Offset = Vector2.new(0, -1)
	Gradient.Parent = ContentBox
	table.insert(Gradients, Gradient)

	local Padding = Instance.new("UIPadding")
	Padding.PaddingTop = UDim.new(0, ActivePadV)
	Padding.PaddingBottom = UDim.new(0, ActivePadV)
	Padding.PaddingLeft = UDim.new(0, ActivePadH)
	Padding.PaddingRight = UDim.new(0, ActivePadH)
	Padding.Parent = ContentBox

	local ListLayout = Instance.new("UIListLayout")
	ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ListLayout.Padding = UDim.new(0, 6)
	ListLayout.Parent = ContentBox

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "Title"
	TitleLabel.Size = UDim2.new(1, 0, 0, 0)
	TitleLabel.AutomaticSize = Enum.AutomaticSize.Y
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.FontFace = Font.new(FONT, Enum.FontWeight.Bold)
	TitleLabel.TextColor3 = BEIGE
	TitleLabel.TextScaled = false
	TitleLabel.TextSize = ActiveTitleSize
	TitleLabel.RichText = true
	TitleLabel.Text = Title
	TitleLabel.TextWrapped = true
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	TitleLabel.LayoutOrder = 1
	TitleLabel.Parent = ContentBox

	local TitleGradient = Instance.new("UIGradient")
	TitleGradient.Rotation = 90
	TitleGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	TitleGradient.Offset = Vector2.new(0, -1)
	TitleGradient.Parent = TitleLabel
	table.insert(Gradients, TitleGradient)

	if Subtitle and Subtitle ~= "" then
		local SubtitleLabel = Instance.new("TextLabel")
		SubtitleLabel.Name = "Subtitle"
		SubtitleLabel.Size = UDim2.new(1, 0, 0, 0)
		SubtitleLabel.AutomaticSize = Enum.AutomaticSize.Y
		SubtitleLabel.BackgroundTransparency = 1
		SubtitleLabel.FontFace = Font.new(FONT, Enum.FontWeight.Regular)
		SubtitleLabel.TextColor3 = BEIGE
		SubtitleLabel.TextTransparency = 0.25
		SubtitleLabel.TextScaled = false
		SubtitleLabel.TextSize = ActiveSubtitleSize
		SubtitleLabel.RichText = true
		SubtitleLabel.Text = Subtitle
		SubtitleLabel.TextWrapped = true
		SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
		SubtitleLabel.LayoutOrder = 2
		SubtitleLabel.Parent = ContentBox

		local SubtitleGradient = Instance.new("UIGradient")
		SubtitleGradient.Rotation = 90
		SubtitleGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		SubtitleGradient.Offset = Vector2.new(0, -1)
		SubtitleGradient.Parent = SubtitleLabel
		table.insert(Gradients, SubtitleGradient)
	end

	local SlideIn = TweenService:Create(Anchor, TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.04, 0),
	})
	SlideIn:Play()
	SlideIn.Completed:Wait()

	local Segments = AnimateBorderIn(BorderContainer, ContentBox, Gradients, BorderColor)

	local PulseThread: thread? = nil
	if IsWarning then
		PulseThread = task.spawn(function()
			local PulseDuration = 1 / WARNING_PULSE_SPEED / 2
			local ToBeige = true
			while true do
				local TargetColor = if ToBeige then BEIGE else WARNING_COLOR
				for _, Segment in Segments do
					TweenService:Create(Segment, TweenInfo.new(PulseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						BackgroundColor3 = TargetColor,
					}):Play()
				end
				TweenService:Create(TitleLabel, TweenInfo.new(PulseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					TextColor3 = TargetColor,
				}):Play()
				ToBeige = not ToBeige
				task.wait(PulseDuration)
			end
		end)
	end

	task.wait(HoldTime)

	if PulseThread then
		task.cancel(PulseThread)
		for _, Segment in Segments do
			TweenService:Create(Segment, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = BorderColor,
			}):Play()
		end
		TweenService:Create(TitleLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = BEIGE,
		}):Play()
		task.wait(0.15)
	end

	AnimateBorderOut(Segments, Gradients)

	local SlideOut = TweenService:Create(Anchor, TweenInfo.new(SLIDE_DURATION * 0.8, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, -0.15, 0),
	})
	SlideOut:Play()
	SlideOut.Completed:Wait()

	Anchor:Destroy()

	IsShowing = false

	for _, Callback in OnHideCallbacks do
		task.spawn(Callback)
	end
end

--[[
    drains the announcement queue one entry at a time
    (@yields)
]]
local function ProcessQueue()
	while #Queue > 0 do
		local Entry = table.remove(Queue, 1)
		ShowAnnouncement(Entry.Title, Entry.Subtitle, Entry.Duration, Entry.IsWarning)
		task.wait(0.2)
	end
end

--[[
    adds an announcement to the queue
]]
function AnnouncementController.Announce(Title: string, Subtitle: string?, Duration: number?)
	table.insert(Queue, { Title = Title, Subtitle = Subtitle, Duration = Duration })
	if not IsShowing then
		task.spawn(ProcessQueue)
	end
end

--[[
    adds a warning announcement to the queue with a pulsing border
]]
function AnnouncementController.Warn(Title: string, Subtitle: string?, Duration: number?)
	table.insert(Queue, { Title = Title, Subtitle = Subtitle, Duration = Duration, IsWarning = true })
	if not IsShowing then
		task.spawn(ProcessQueue)
	end
end

AnnouncementNetwork.packets.Show.listen(function(Data: { Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean? })
	if Data.IsWarning then
		AnnouncementController.Warn(Data.Title, Data.Subtitle, Data.Duration)
	else
		AnnouncementController.Announce(Data.Title, Data.Subtitle, Data.Duration)
	end
end)

--[[
    returns whether an announcement is currently visible
]]
function AnnouncementController.IsShowing(): boolean
	return IsShowing
end

--[[
    registers a callback fired when an announcement begins showing
]]
function AnnouncementController.OnShow(Callback: () -> ())
	table.insert(OnShowCallbacks, Callback)
end

--[[
    registers a callback fired when an announcement finishes hiding
]]
function AnnouncementController.OnHide(Callback: () -> ())
	table.insert(OnHideCallbacks, Callback)
end

return AnnouncementController
