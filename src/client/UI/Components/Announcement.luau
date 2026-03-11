local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement
local Colors = Stylesheet.Colors
local Fonts = Stylesheet.FontFace
local Sizes = Stylesheet.TextSize
local Space = Stylesheet.Spacing

local ENTER_DURATION = 0.8
local EXIT_DURATION = 0.5

local function SubProgress(P: number, Start: number, Finish: number): number
	return math.clamp((P - Start) / (Finish - Start), 0, 1)
end

local function Announcement()
	local State = Hooks.UseSignal(UIState.AnnouncementChanged, UIState.AnnouncementState)
	local ShouldRender, Progress = Hooks.UseTransition(
		State.Visible,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutQuart,
		Easing.EaseInCubic
	)

	local PulseAlpha, SetPulseAlpha = React.useBinding(0)
	local PulseConnection = React.useRef(nil :: RBXScriptConnection?)

	React.useEffect(function()
		if PulseConnection.current then
			PulseConnection.current:Disconnect()
			PulseConnection.current = nil
		end

		if not State.IsWarning or not State.Visible then
			SetPulseAlpha(0)
			return nil
		end

		PulseConnection.current = RunService.PreRender:Connect(function()
			SetPulseAlpha((math.sin(tick() * 4.8) + 1) / 2)
		end)

		return function()
			if PulseConnection.current then
				PulseConnection.current:Disconnect()
				PulseConnection.current = nil
			end
		end
	end, { State.IsWarning, State.Visible } :: { any })

	if not ShouldRender then
		return nil
	end

	-- Choreographed sub-animations mapped from the 0-1 progress
	local ContainerOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0, 0.5)) * 0.82
	end)

	local ContainerSlideY = Progress:map(function(P: number)
		local Sub = Easing.EaseOutCubic(SubProgress(P, 0, 0.55))
		return -0.08 + 0.12 * Sub
	end)

	local LineWidth = Progress:map(function(P: number)
		return Easing.EaseOutQuart(SubProgress(P, 0.05, 0.45))
	end)

	local TitleTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.15, 0.65))
	end)

	local TitleSlideY = Progress:map(function(P: number)
		local Sub = Easing.EaseOutCubic(SubProgress(P, 0.15, 0.65))
		return UDim2.fromOffset(0, math.floor(6 * (1 - Sub)))
	end)

	local SubtitleTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.35, 0.85)) * 0.6
	end)

	local StrokeTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.1, 0.5)) * 0.5
	end)

	local Position = ContainerSlideY:map(function(Y: number)
		return UDim2.new(0.5, 0, Y, 0)
	end)

	local TitleColor = if State.IsWarning then PulseAlpha:map(function(P: number)
		return Colors.Gold:Lerp(Colors.DangerBright, P)
	end) else Colors.Gold

	local StrokeColor = if State.IsWarning then PulseAlpha:map(function(P: number)
		return Colors.GoldDim:Lerp(Colors.Danger, P * 0.7)
	end) else Colors.GoldDim

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = Position,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Colors.DarkBrown,
		BackgroundTransparency = ContainerOpacity:map(function(A: number) return 1 - A end),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.MD,
		}),

		Stroke = E("UIStroke", {
			Color = StrokeColor,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = StrokeTransparency,
		}),

		Padding = E("UIPadding", {
			PaddingTop = UDim.new(0, Space.MD),
			PaddingBottom = UDim.new(0, Space.MD),
			PaddingLeft = UDim.new(0, Space.XL),
			PaddingRight = UDim.new(0, Space.XL),
		}),

		Layout = E("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Space.XS),
		}),

		TopRule = E("Frame", {
			Size = LineWidth:map(function(W: number)
				return UDim2.new(W * 0.4, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = StrokeTransparency,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}),

		TitleContainer = E("Frame", {
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ClipsDescendants = true,
		}, {
			TitleLabel = E("TextLabel", {
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Position = TitleSlideY,
				BackgroundTransparency = 1,
				FontFace = Fonts.Accent,
				TextColor3 = TitleColor,
				TextTransparency = TitleTransparency,
				TextSize = Sizes.Subtitle,
				RichText = true,
				Text = State.Title,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		}),

		SubtitleLabel = if State.Subtitle ~= "" then E("TextLabel", {
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Fonts.AccentLight,
			TextColor3 = Colors.WhiteMuted,
			TextTransparency = SubtitleTransparency,
			TextSize = Sizes.Caption,
			RichText = true,
			Text = State.Subtitle,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
		}) else nil,

		BottomRule = E("Frame", {
			Size = LineWidth:map(function(W: number)
				return UDim2.new(W * 0.4, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = StrokeTransparency,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}),
	})
end

return Announcement