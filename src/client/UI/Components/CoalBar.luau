local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement
local Colors = Stylesheet.Colors

local ENTER_DURATION = 0.6
local EXIT_DURATION = 0.5

local COAL_WIDTH = 44
local COAL_HEIGHT = 36
local COAL_SPACING = 8

-- Per-slot rotations for a natural, hand-placed look
local SLOT_ROTATIONS = { -4, 2, -1, 3, -2, 1, -3, 4, 0, -2 }

-- Mineral/quartz spots on filled coal pieces
local COAL_SPOTS = {
	{ X = 0.25, Y = 0.30, Size = 5, Color = Color3.fromRGB(140, 140, 140) },
	{ X = 0.62, Y = 0.48, Size = 4, Color = Color3.fromRGB(175, 175, 175) },
	{ X = 0.40, Y = 0.68, Size = 3, Color = Color3.fromRGB(110, 110, 110) },
}

-- Geode/ore outline — angular, irregular rock chunk
-- Clockwise from top-left, last point closes back to start
local GEODE_SHAPE = {
	{ 0.15, 0.05 },
	{ 0.52, 0.00 },
	{ 0.82, 0.08 },
	{ 0.97, 0.40 },
	{ 0.88, 0.78 },
	{ 0.65, 0.97 },
	{ 0.30, 0.92 },
	{ 0.05, 0.65 },
	{ 0.02, 0.28 },
	{ 0.15, 0.05 },
}

local GeodeControlPoints: { Path2DControlPoint } = {}
for _, P in GEODE_SHAPE do
	table.insert(GeodeControlPoints, Path2DControlPoint.new(UDim2.fromScale(P[1], P[2])))
end

local function CoalSlot(Props: { Index: number, Filled: boolean, Opacity: any })
	local OutlineRef = React.useRef(nil :: Path2D?)

	React.useEffect(function()
		if OutlineRef.current then
			OutlineRef.current:SetControlPoints(GeodeControlPoints)
		end
	end, {})

	local Rotation = SLOT_ROTATIONS[((Props.Index - 1) % #SLOT_ROTATIONS) + 1]

	local FillChildren: { [string]: any } = {
		Corner = E("UICorner", {
			CornerRadius = UDim.new(0.3, 0),
		}),
	}

	if Props.Filled then
		for SpotIndex, Spot in COAL_SPOTS do
			FillChildren["Spot" .. SpotIndex] = E("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(Spot.X, Spot.Y),
				Size = UDim2.fromOffset(Spot.Size, Spot.Size),
				BackgroundColor3 = Spot.Color,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				SpotCorner = E("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			})
		end
	end

	return E("CanvasGroup", {
		Size = UDim2.fromOffset(COAL_WIDTH, COAL_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = Props.Opacity:map(function(A: number) return 1 - A end),
		Rotation = Rotation,
		LayoutOrder = Props.Index,
	}, {
		Fill = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -4),
			BackgroundColor3 = if Props.Filled then Color3.fromRGB(25, 20, 15) else Colors.MediumBrown,
			BackgroundTransparency = if Props.Filled then 0 else 0.4,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, FillChildren),

		Outline = E("Path2D", {
			ref = OutlineRef,
			Color3 = Colors.GoldMuted,
			Thickness = Stylesheet.Stroke.Normal,
			ZIndex = 3,
		}),
	})
end

local function CoalBar()
	local State = Hooks.UseSignal(UIState.CoalChanged, UIState.CoalState)
	local ShouldRender, Progress = Hooks.UseTransition(
		State.Active,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutCubic,
		Easing.EaseInCubic
	)

	if not ShouldRender then
		return nil
	end

	local Position = Progress:map(function(P: number)
		local Y = 1.02 - 0.06 * P
		return UDim2.new(0.5, 0, Y, 0)
	end)

	local SlotElements: { [string]: any } = {
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, COAL_SPACING),
		}),
	}

	for I = 1, State.Required do
		SlotElements["Coal" .. I] = E(CoalSlot, {
			Index = I,
			Filled = I <= State.Current,
			Opacity = Progress,
		})
	end

	local TotalWidth = State.Required * COAL_WIDTH + math.max(State.Required - 1, 0) * COAL_SPACING + 40

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = Position,
		Size = UDim2.fromOffset(math.max(TotalWidth, 200), 76),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),

		Hint = E("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			FontFace = Font.new(Stylesheet.Font.Accent, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
			TextColor3 = Colors.GoldDim,
			TextTransparency = Progress:map(function(A: number) return 1 - A * 0.7 end),
			TextSize = Stylesheet.TextSize.Small,
			Text = "Click on the coal to drag it back to the train!",
			TextXAlignment = Enum.TextXAlignment.Center,
		}, {
			HintStroke = E("UIStroke", {
				Color = Colors.WarmBlack,
				Thickness = 2,
				Transparency = Progress:map(function(A: number) return 1 - A * 0.6 end),
			}),
		}),

		Slots = E("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, COAL_HEIGHT + 10),
			BackgroundTransparency = 1,
		}, SlotElements),
	})
end

return CoalBar
