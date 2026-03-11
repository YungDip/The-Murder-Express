local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)
local Constants = require(ReplicatedStorage.Shared.Constants)

local E = React.createElement
local Colors = Stylesheet.Colors
local Fonts = Stylesheet.FontFace
local Sizes = Stylesheet.TextSize
local Space = Stylesheet.Spacing

local RoundConst = Constants.Round

local ENTER_DURATION = 0.8
local EXIT_DURATION = 0.5
local ROW_STAGGER = 0.06

local function SubProgress(P: number, Start: number, Finish: number): number
	return math.clamp((P - Start) / (Finish - Start), 0, 1)
end

local function ScoreboardRow(Props: {
	Index: number,
	Name: string,
	Role: string,
	Alive: boolean,
	LayoutOrder: number,
	Progress: any,
	RowCount: number,
})
	local RoleColor = Stylesheet.RoleColors[Props.Role] or Colors.Gold
	local IsEven = Props.Index % 2 == 0

	local RowDelay = 0.35 + (Props.Index - 1) * ROW_STAGGER
	local RowEnd = math.min(RowDelay + 0.35, 1)

	local RowOpacity = Props.Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, RowDelay, RowEnd))
	end)

	local RowSlideX = Props.Progress:map(function(P: number)
		local Sub = Easing.EaseOutCubic(SubProgress(P, RowDelay, RowEnd))
		return UDim2.new(0, math.floor(12 * (1 - Sub)), 0, 0)
	end)

	return E("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = RowSlideX,
		BackgroundColor3 = Colors.LightBrown,
		BackgroundTransparency = if IsEven then 0.7 else 1,
		BorderSizePixel = 0,
		LayoutOrder = Props.LayoutOrder,
	}, {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.SM,
		}),

		Padding = E("UIPadding", {
			PaddingLeft = UDim.new(0, Space.MD),
			PaddingRight = UDim.new(0, Space.MD),
		}),

		StatusDot = E("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = if Props.Alive then Colors.Alive else Colors.Dead,
			BackgroundTransparency = RowOpacity:map(function(O: number) return 1 - O end),
			BorderSizePixel = 0,
		}, {
			Corner = E("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		NameLabel = E("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			Size = UDim2.new(0.5, -18, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Fonts.Body,
			TextColor3 = Colors.WhiteMuted,
			TextSize = Sizes.Body,
			Text = Props.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = RowOpacity:map(function(O: number) return 1 - O end),
		}),

		RoleLabel = E("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.35, 0, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Fonts.Accent,
			TextColor3 = RoleColor,
			TextSize = Sizes.Caption,
			Text = string.upper(Props.Role),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = RowOpacity:map(function(O: number) return 1 - O end),
		}),
	})
end

local function Scoreboard()
	local State = Hooks.UseSignal(UIState.ScoreboardChanged, UIState.ScoreboardState)
	local ShouldRender, Progress = Hooks.UseTransition(
		State.Visible,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutQuart,
		Easing.EaseInCubic
	)

	if not ShouldRender then
		return nil
	end

	local Data = State.Data
	if not Data then
		return nil
	end

	local ResultText = RoundConst.RESULT_TEXT[Data.Result] or "Round Over"
	local ResultColor = Colors.Gold
	if Data.Result == "MurdererWin" then
		ResultColor = Colors.Murderer
	elseif Data.Result == "DetectiveWin" then
		ResultColor = Colors.Detective
	elseif Data.Result == "PassengersWin" then
		ResultColor = Colors.Innocent
	end

	-- Choreographed sub-animations
	local ContainerOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0, 0.45)) * 0.88
	end)

	local Scale = Progress:map(function(P: number)
		local Sub = Easing.EaseOutCubic(SubProgress(P, 0, 0.5))
		return 0.92 + 0.08 * Sub
	end)

	local HeaderTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.1, 0.5))
	end)

	local LineWidth = Progress:map(function(P: number)
		return Easing.EaseOutQuart(SubProgress(P, 0.15, 0.55))
	end)

	local SeparatorTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.2, 0.6)) * 0.5
	end)

	local StrokeTransparency = Progress:map(function(P: number)
		return 1 - Easing.EaseOutCubic(SubProgress(P, 0.05, 0.4))
	end)

	local Children = {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.LG,
		}),

		Stroke = E("UIStroke", {
			Color = Colors.GoldDim,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = StrokeTransparency,
		}),

		Padding = E("UIPadding", {
			PaddingTop = UDim.new(0, Space.LG),
			PaddingBottom = UDim.new(0, Space.LG),
			PaddingLeft = UDim.new(0, Space.LG),
			PaddingRight = UDim.new(0, Space.LG),
		}),

		Layout = E("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Space.SM),
		}),

		TopLine = E("Frame", {
			Size = LineWidth:map(function(W: number)
				return UDim2.new(0.25 * W, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = StrokeTransparency,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}),

		Header = E("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Fonts.Accent,
			TextColor3 = ResultColor,
			TextSize = Sizes.Title,
			Text = ResultText,
			TextTransparency = HeaderTransparency,
			TextWrapped = true,
			LayoutOrder = 1,
		}),

		Separator = E("Frame", {
			Size = LineWidth:map(function(W: number)
				return UDim2.new(0.6 * W, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.Separator,
			BackgroundTransparency = SeparatorTransparency,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}),

		BottomLine = E("Frame", {
			Size = LineWidth:map(function(W: number)
				return UDim2.new(0.25 * W, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = StrokeTransparency,
			BorderSizePixel = 0,
			LayoutOrder = 100,
		}),
	}

	local RowCount = #Data.Players
	for Index, PlayerData in Data.Players do
		Children["Row_" .. Index] = E(ScoreboardRow, {
			Index = Index,
			Name = PlayerData.Name,
			Role = PlayerData.Role,
			Alive = PlayerData.Alive,
			LayoutOrder = 10 + Index,
			Progress = Progress,
			RowCount = RowCount,
		})
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = Scale:map(function(S: number)
			return UDim2.new(0.36 * S, 0, 0, 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.DarkBrown,
		BackgroundTransparency = ContainerOpacity:map(function(A: number) return 1 - A end),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, Children)
end

return Scoreboard