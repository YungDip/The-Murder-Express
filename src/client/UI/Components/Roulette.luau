local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)
local LayeredSound = require(ReplicatedStorage.Shared.Util.LayeredSound)

local E = React.createElement
local Colors = Stylesheet.Colors
local Fonts = Stylesheet.FontFace
local Sizes = Stylesheet.TextSize
local Space = Stylesheet.Spacing

local ROLES_SEQUENCE = { "Innocent", "Detective", "Murderer" }
local TOTAL_CYCLES = 10
local SLOT_HEIGHT = 50
local TOTAL_SLOTS = TOTAL_CYCLES * #ROLES_SEQUENCE

local function Roulette()
	local State = Hooks.UseSignal(UIState.RouletteChanged, UIState.RouletteState)

	local IsVisible, SetIsVisible = React.useState(false)
	local ScrollOffset, SetScrollOffset = React.useBinding(0)
	local HeaderOpacity, SetHeaderOpacity = React.useBinding(0)
	local ContainerOpacity, SetContainerOpacity = React.useBinding(0)
	local ContainerScale, SetContainerScale = React.useBinding(0.9)
	local StrokeOpacity, SetStrokeOpacity = React.useBinding(0)
	local StrokeColor, SetStrokeColor = React.useBinding(Colors.GoldDim)
	local ContentOpacity, SetContentOpacity = React.useBinding(0)
	local DimOpacity, SetDimOpacity = React.useBinding(0)
	local LineWidth, SetLineWidth = React.useBinding(0)

	local TargetRole = State.TargetRole
	local Slots = React.useMemo(function()
		local Result = {}
		for I = 1, TOTAL_SLOTS do
			local CycleIndex = ((I - 1) % #ROLES_SEQUENCE) + 1
			if I == TOTAL_SLOTS then
				table.insert(Result, if TargetRole ~= "" then TargetRole else ROLES_SEQUENCE[CycleIndex])
			else
				table.insert(Result, ROLES_SEQUENCE[CycleIndex])
			end
		end
		return Result
	end, { TargetRole } :: { any })

	React.useEffect(function()
		if not State.Playing then
			return nil
		end

		SetIsVisible(true)
		SetScrollOffset(0)
		SetHeaderOpacity(0)
		SetContainerOpacity(0)
		SetContainerScale(0.9)
		SetStrokeOpacity(0)
		SetStrokeColor(Colors.GoldDim)
		SetContentOpacity(0)
		SetDimOpacity(0)
		SetLineWidth(0)

		local Thread = task.spawn(function()
			-- Phase 1: Dim overlay + container scale entrance (0.4s)
			local EnterDuration = 0.4
			local EnterElapsed = 0
			while EnterElapsed < EnterDuration do
				local Delta = task.wait()
				EnterElapsed += Delta
				local T = math.clamp(EnterElapsed / EnterDuration, 0, 1)
				local Eased = Easing.EaseOutCubic(T)
				SetDimOpacity(Eased * 0.45)
				SetContainerOpacity(Eased * 0.85)
				SetContainerScale(0.9 + 0.1 * Eased)
				SetStrokeOpacity(Eased)
				SetContentOpacity(Eased)
			end

			-- Phase 2: Header lines extend + text fades in (0.35s)
			local HeaderDuration = 0.35
			local HeaderElapsed = 0
			while HeaderElapsed < HeaderDuration do
				local Delta = task.wait()
				HeaderElapsed += Delta
				local T = math.clamp(HeaderElapsed / HeaderDuration, 0, 1)
				local Eased = Easing.EaseOutCubic(T)
				SetHeaderOpacity(Eased)
				SetLineWidth(Eased)
			end

			-- Phase 3: Spin (existing roll mechanic)
			local MIN_DELAY = 0.04
			local MAX_DELAY = 0.25
			local MAX_PITCH = 3
			local MIN_PITCH = 1.5

			local RollClickSound = SoundService:FindFirstChild("UI") and SoundService.UI:FindFirstChild("RollClick")
			local RoleSelectedSound = SoundService:FindFirstChild("UI") and SoundService.UI:FindFirstChild("RoleSelected")
			local PreviousClick: Sound? = nil

			for I = 1, TOTAL_SLOTS - 1 do
				local SlotProgress = I / TOTAL_SLOTS
				local Alpha = SlotProgress * SlotProgress * SlotProgress
				local StepDelay = MIN_DELAY + (MAX_DELAY - MIN_DELAY) * Alpha
				local Pitch = MAX_PITCH - (MAX_PITCH - MIN_PITCH) * Alpha

				local TargetY = -(I * SLOT_HEIGHT)
				local StartY = -((I - 1) * SLOT_HEIGHT)
				local AnimDuration = StepDelay * 0.8
				local Elapsed = 0

				while Elapsed < AnimDuration do
					local Delta = task.wait()
					Elapsed += Delta
					local T = math.clamp(Elapsed / AnimDuration, 0, 1)
					local Eased = 1 - (1 - T) * (1 - T)
					SetScrollOffset(StartY + (TargetY - StartY) * Eased)
				end
				SetScrollOffset(TargetY)

				if PreviousClick then
					PreviousClick:Stop()
					PreviousClick:Destroy()
				end

				if RollClickSound then
					PreviousClick = LayeredSound.Play(RollClickSound, 0.05, Pitch)
				end

				task.wait(StepDelay * 0.2)
			end

			if PreviousClick then
				PreviousClick:Stop()
				PreviousClick:Destroy()
			end

			local FinalY = -((TOTAL_SLOTS - 1) * SLOT_HEIGHT)
			SetScrollOffset(FinalY)

			if RoleSelectedSound then
				LayeredSound.Play(RoleSelectedSound, 0.05, 1)
			end

			local RoleColor = Stylesheet.RoleColors[TargetRole] or Colors.Gold

			-- Landing celebration (0.5s): bounce, scale pop, stroke flash
			local LandDuration = 0.5
			local LandElapsed = 0
			while LandElapsed < LandDuration do
				local Delta = task.wait()
				LandElapsed += Delta
				local T = math.clamp(LandElapsed / LandDuration, 0, 1)

				local BounceDecay = math.exp(-6 * T)
				local BouncePhase = math.sin(T * math.pi * 2)
				SetScrollOffset(FinalY + BounceDecay * BouncePhase * SLOT_HEIGHT * 0.15)

				local ScalePop = math.sin(T * math.pi) * (1 - T) * 0.08
				SetContainerScale(1 + ScalePop)

				local FlashT = Easing.EaseOutCubic(T)
				SetStrokeColor(Colors.White:Lerp(RoleColor, FlashT))
			end
			SetScrollOffset(FinalY)
			SetContainerScale(1)
			SetStrokeColor(RoleColor)

			task.wait(1.5)

			-- Phase 4: Elegant exit (0.6s)
			local ExitDuration = 0.6
			local ExitElapsed = 0
			while ExitElapsed < ExitDuration do
				local Delta = task.wait()
				ExitElapsed += Delta
				local T = math.clamp(ExitElapsed / ExitDuration, 0, 1)
				local Eased = Easing.EaseInCubic(T)
				SetContainerOpacity(0.85 * (1 - Eased))
				SetContainerScale(1 - 0.05 * Eased)
				SetStrokeOpacity(1 - Eased)
				SetHeaderOpacity(1 - Eased)
				SetLineWidth(1 - Eased)
				SetContentOpacity(1 - Eased)
				SetDimOpacity(0.45 * (1 - Eased))
			end

			SetIsVisible(false)
			UIState.HideRoulette()
		end)

		return function()
			task.cancel(Thread)
			SetIsVisible(false)
		end
	end, { State.Playing } :: { any })

	if not IsVisible then
		return nil
	end

	local SlotChildren = {}
	for I, RoleName in Slots do
		local RoleColor = Stylesheet.RoleColors[RoleName] or Colors.Gold
		SlotChildren["Slot" .. I] = E("TextLabel", {
			Size = UDim2.new(1, 0, 0, SLOT_HEIGHT),
			Position = UDim2.fromOffset(0, (I - 1) * SLOT_HEIGHT),
			BackgroundTransparency = 1,
			FontFace = Fonts.Accent,
			TextColor3 = RoleColor,
			TextSize = Sizes.Title,
			Text = string.upper(RoleName),
			TextTransparency = ContentOpacity:map(function(O: number) return 1 - O end),
		})
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, {
		DimOverlay = E("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.WarmBlack,
			BackgroundTransparency = DimOpacity:map(function(O: number) return 1 - O end),
			BorderSizePixel = 0,
			ZIndex = 0,
		}),

		HeaderContainer = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, -(SLOT_HEIGHT / 2) - 20),
			Size = UDim2.new(0.3, 0, 0, 40),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Layout = E("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, Space.SM),
				FillDirection = Enum.FillDirection.Horizontal,
			}),

			LeftLine = E("Frame", {
				Size = LineWidth:map(function(W: number)
					return UDim2.fromOffset(math.floor(30 * W), 1)
				end),
				BackgroundColor3 = Colors.GoldDim,
				BackgroundTransparency = HeaderOpacity:map(function(O: number) return 1 - O * 0.5 end),
				BorderSizePixel = 0,
				LayoutOrder = 1,
			}),

			HeaderText = E("TextLabel", {
				Size = UDim2.new(0, 0, 0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Fonts.AccentLight,
				TextColor3 = Colors.WhiteMuted,
				TextSize = Sizes.Body,
				Text = "Your Role",
				TextTransparency = HeaderOpacity:map(function(O: number) return 1 - O end),
				LayoutOrder = 2,
			}),

			RightLine = E("Frame", {
				Size = LineWidth:map(function(W: number)
					return UDim2.fromOffset(math.floor(30 * W), 1)
				end),
				BackgroundColor3 = Colors.GoldDim,
				BackgroundTransparency = HeaderOpacity:map(function(O: number) return 1 - O * 0.5 end),
				BorderSizePixel = 0,
				LayoutOrder = 3,
			}),
		}),

		RouletteBox = E("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = ContainerScale:map(function(S: number)
				return UDim2.new(0.22 * S, 0, 0, math.floor(SLOT_HEIGHT * S))
			end),
			BackgroundColor3 = Colors.DarkBrown,
			BackgroundTransparency = ContainerOpacity:map(function(O: number) return 1 - O end),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			Corner = E("UICorner", {
				CornerRadius = Stylesheet.Corner.LG,
			}),

			Stroke = E("UIStroke", {
				Color = StrokeColor,
				Thickness = Stylesheet.Stroke.Normal,
				Transparency = StrokeOpacity:map(function(O: number) return 1 - O end),
			}),

			Scroll = E("Frame", {
				Size = UDim2.fromScale(1, 1),
				Position = ScrollOffset:map(function(Y: number)
					return UDim2.fromOffset(0, Y)
				end),
				BackgroundTransparency = 1,
			}, SlotChildren),
		}),
	})
end

return Roulette