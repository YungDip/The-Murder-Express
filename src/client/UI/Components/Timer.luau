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

local ENTER_DURATION = 0.5
local EXIT_DURATION = 0.4

local function Timer()
	local State = Hooks.UseSignal(UIState.TimerChanged, UIState.TimerState)
	local ShouldRender, Progress = Hooks.UseTransition(
		State.Visible,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutCubic,
		Easing.EaseInCubic
	)

	local PulseAlpha, SetPulseAlpha = React.useBinding(0)
	local PulseRef = React.useRef(nil :: RBXScriptConnection?)

	React.useEffect(function()
		if PulseRef.current then
			PulseRef.current:Disconnect()
			PulseRef.current = nil
		end

		if not State.Warning then
			SetPulseAlpha(0)
			return nil
		end

		PulseRef.current = RunService.PreRender:Connect(function()
			SetPulseAlpha((math.sin(tick() * 6) + 1) / 2)
		end)

		return function()
			if PulseRef.current then
				PulseRef.current:Disconnect()
				PulseRef.current = nil
			end
		end
	end, { State.Warning } :: { any })

	if not ShouldRender then
		return nil
	end

	local Position = Progress:map(function(P: number)
		local Y = -0.06 + 0.085 * P
		return UDim2.new(0.5, 0, Y, 0)
	end)

	local Opacity = Progress

	local TextColor = PulseAlpha:map(function(P: number)
		return Colors.Gold:Lerp(Colors.Danger, P)
	end)

	local StrokeColor = PulseAlpha:map(function(P: number)
		return Colors.GoldDim:Lerp(Colors.Danger, P * 0.6)
	end)

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = Position,
		Size = UDim2.new(0, 130, 0, 42),
		BackgroundColor3 = Colors.DarkBrown,
		BackgroundTransparency = Opacity:map(function(A: number) return 1 - A * 0.8 end),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.MD,
		}),

		Stroke = E("UIStroke", {
			Color = StrokeColor,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = Opacity:map(function(A: number) return 1 - A * 0.5 end),
		}),

		LeftDot = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = Opacity:map(function(A: number) return 1 - A * 0.5 end),
			BorderSizePixel = 0,
		}, {
			Corner = E("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		RightDot = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = Opacity:map(function(A: number) return 1 - A * 0.5 end),
			BorderSizePixel = 0,
		}, {
			Corner = E("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		TimerText = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Fonts.Title,
			TextColor3 = TextColor,
			TextTransparency = Opacity:map(function(A: number) return 1 - A end),
			TextSize = Sizes.Subtitle + 4,
			Text = State.Text,
		}),
	})
end

return Timer