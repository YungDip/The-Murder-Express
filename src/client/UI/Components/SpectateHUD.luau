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

local ENTER_DURATION = 0.35
local EXIT_DURATION = 0.25
local ARROW_SIZE = 44
local BAR_HEIGHT = 52
local AVATAR_SIZE = 36

local function GetRoleColor(Role: string): Color3
	return Stylesheet.RoleColors[Role] or Colors.WhiteMuted
end

local function GetHeadshotUrl(UserId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", UserId)
end

-- "Spectate" entry button shown to lobby players
local function SpectateButton()
	local State = Hooks.UseSignal(UIState.SpectateChanged, UIState.SpectateState)
	local ShouldRender, Progress = Hooks.UseTransition(State.CanSpectate, ENTER_DURATION, EXIT_DURATION, Easing.EaseOutCubic, Easing.EaseInCubic)

	if not ShouldRender then
		return nil
	end

	local Opacity = Progress:map(function(P)
		return 1 - P
	end)

	local Position = Progress:map(function(P)
		return UDim2.new(0.5, 0, 0.92, (1 - P) * 30)
	end)

	return E("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = Position,
		Size = UDim2.fromOffset(180, 48),
		BackgroundColor3 = Colors.MediumBrown,
		BackgroundTransparency = Opacity:map(function(O)
			return 0.15 + O * 0.85
		end),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
		ZIndex = 5,
		[React.Event.Activated] = function()
			if UIState.OnSpectateStart then
				UIState.OnSpectateStart()
			end
		end,
	}, {
		Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.LG }),
		Stroke = E("UIStroke", {
			Color = Colors.Gold,
			Thickness = Stylesheet.Stroke.Normal,
			Transparency = Opacity,
		}),
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Space.SM),
		}),
		Icon = E("ImageLabel", {
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = "rbxassetid://1137376344",
			ImageColor3 = Colors.Gold,
			ImageTransparency = Opacity,
			LayoutOrder = 1,
		}),
		Label = E("TextLabel", {
			Size = UDim2.fromOffset(90, 24),
			BackgroundTransparency = 1,
			FontFace = Fonts.Title,
			TextColor3 = Colors.Gold,
			TextTransparency = Opacity,
			TextSize = Sizes.Body,
			Text = "Spectate",
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		}),
	})
end

-- Main spectate HUD with target info, arrows, exit
local function SpectateOverlay()
	local State = Hooks.UseSignal(UIState.SpectateChanged, UIState.SpectateState)
	local ShouldRender, Progress = Hooks.UseTransition(State.Visible, ENTER_DURATION, EXIT_DURATION, Easing.EaseOutCubic, Easing.EaseInCubic)

	local CycleTarget = React.useCallback(function(Direction: number)
		if UIState.OnSpectateCycle then
			UIState.OnSpectateCycle(Direction)
		end
	end, {})

	local StopSpectate = React.useCallback(function()
		if UIState.OnSpectateStop then
			UIState.OnSpectateStop()
		end
	end, {})

	if not ShouldRender then
		return nil
	end

	local RoleColor = GetRoleColor(State.TargetRole)
	local ShowArrows = State.AliveCount > 1

	-- Bottom bar slides up from below
	local BarPosition = Progress:map(function(P)
		return UDim2.new(0.5, 0, 1, 100 - (100 + Space.LG) * P)
	end)

	return E("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		-- Bottom container for everything
		BottomContainer = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = BarPosition,
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Layout = E("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, Space.SM),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			-- Player info bar with arrows
			InfoBar = E("Frame", {
				Size = UDim2.new(0, 0, 0, BAR_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Colors.DarkBrown,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				LayoutOrder = 1,
			}, {
				Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.LG }),
				Stroke = E("UIStroke", {
					Color = Colors.GoldDim,
					Thickness = Stylesheet.Stroke.Thin,
					Transparency = 0.4,
				}),
				Padding = E("UIPadding", {
					PaddingLeft = UDim.new(0, Space.SM),
					PaddingRight = UDim.new(0, Space.SM),
				}),
				RowLayout = E("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, Space.SM),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				-- Left arrow
				LeftArrow = if ShowArrows then E("TextButton", {
					Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = 1,
					[React.Event.Activated] = function()
						CycleTarget(-1)
					end,
				}, {
					Icon = E("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						FontFace = Fonts.Title,
						TextColor3 = Colors.GoldMuted,
						TextSize = Sizes.Subtitle,
						Text = "◀",
					}),
				}) else nil,

				-- Avatar
				Avatar = E("ImageLabel", {
					Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
					BackgroundColor3 = Colors.LightBrown,
					BackgroundTransparency = 0.5,
					Image = if State.TargetUserId > 0 then GetHeadshotUrl(State.TargetUserId) else "",
					LayoutOrder = 2,
				}, {
					Corner = E("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),

				-- Name
				NameLabel = E("TextLabel", {
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Fonts.Title,
					TextColor3 = Colors.White,
					TextSize = Sizes.Body,
					Text = State.TargetName,
					LayoutOrder = 3,
				}),

				-- Separator
				Separator = E("Frame", {
					Size = UDim2.new(0, 1, 0.5, 0),
					BackgroundColor3 = Colors.Separator,
					BorderSizePixel = 0,
					LayoutOrder = 4,
				}),

				-- Role
				RoleLabel = E("TextLabel", {
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Fonts.Accent,
					TextColor3 = RoleColor,
					TextSize = Sizes.Caption,
					Text = State.TargetRole,
					LayoutOrder = 5,
				}),

				-- Right arrow
				RightArrow = if ShowArrows then E("TextButton", {
					Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = 6,
					[React.Event.Activated] = function()
						CycleTarget(1)
					end,
				}, {
					Icon = E("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						FontFace = Fonts.Title,
						TextColor3 = Colors.GoldMuted,
						TextSize = Sizes.Subtitle,
						Text = "▶",
					}),
				}) else nil,
			}),

			-- Exit button
			ExitButton = E("TextButton", {
				Size = UDim2.fromOffset(100, 36),
				BackgroundColor3 = Colors.Danger,
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				FontFace = Fonts.Title,
				TextColor3 = Colors.White,
				TextSize = Sizes.Body,
				Text = "Exit",
				AutoButtonColor = true,
				LayoutOrder = 2,
				[React.Event.Activated] = StopSpectate,
			}, {
				Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.LG }),
			}),
		}),
	})
end

local function SpectateHUD()
	return E(React.Fragment, nil, {
		SpectateButton = E(SpectateButton),
		SpectateOverlay = E(SpectateOverlay),
	})
end

return SpectateHUD
