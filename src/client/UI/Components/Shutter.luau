local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement

local SLAT_COUNT = 14
local STAGGER_OVERLAP = 0.65

local function Shutter()
	local Request = Hooks.UseSignal(UIState.ShutterChanged, UIState.ShutterState)

	local Progress, SetProgress = React.useBinding(0)
	local BgColor, SetBgColor = React.useBinding(Color3.new(0, 0, 0))
	local FrameVisible, SetFrameVisible = React.useState(false)
	local ActionRef = React.useRef("close")
	local CompletedRef = React.useRef(0)
	local PrevRequestId = React.useRef(0)

	React.useEffect(function()
		if not Request or not Request.Id or Request.Id == PrevRequestId.current then
			return nil
		end
		PrevRequestId.current = Request.Id

		if Request.Action == "reset" then
			SetProgress(0)
			SetFrameVisible(false)
			ActionRef.current = "close"
			CompletedRef.current = Request.Id
			UIState.ShutterCompleted:Fire(Request.Id)
			return nil
		end

		SetBgColor(Request.Color or Color3.new(0, 0, 0))
		ActionRef.current = Request.Action
		SetFrameVisible(true)
		SetProgress(0)

		local CurrentId = Request.Id
		local Thread = task.spawn(function()
			RunService.PreRender:Wait()

			local Duration = Request.Duration
			local Elapsed = 0
			while Elapsed < Duration do
				local Delta = RunService.PreRender:Wait()
				Elapsed += Delta
				SetProgress(math.clamp(Elapsed / Duration, 0, 1))
			end
			SetProgress(1)

			if Request.Action == "open" then
				SetFrameVisible(false)
			end

			CompletedRef.current = CurrentId
			UIState.ShutterCompleted:Fire(CurrentId)
		end)

		return function()
			task.cancel(Thread)
			if CompletedRef.current ~= CurrentId then
				UIState.ShutterCompleted:Fire(CurrentId)
			end
		end
	end, { Request and Request.Id } :: { any })

	if not FrameVisible then
		return nil
	end

	local Step = (1 - STAGGER_OVERLAP) / SLAT_COUNT
	local SlatDuration = STAGGER_OVERLAP + Step
	local SlatHeight = 1 / SLAT_COUNT + 0.012

	local Elements = {}

	for I = 0, SLAT_COUNT - 1 do
		local CloseSlatStart = I * Step
		local OpenSlatStart = (SLAT_COUNT - 1 - I) * Step
		local FinalY = I / SLAT_COUNT
		local IsLastSlat = I == SLAT_COUNT - 1
		local IsEvenSlat = I % 2 == 0

		local Children = {}

		-- Curved metal highlight (subtle light on convex top surface)
		Children.MetalHighlight = E("Frame", {
			Size = UDim2.fromScale(1, 0.5),
			Position = UDim2.fromScale(0, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if IsEvenSlat then 0.92 else 0.94,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Gradient = E("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.4, 0.6),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}),
		})

		-- Bottom surface shadow (underside of curved slat)
		Children.MetalShadow = E("Frame", {
			Size = UDim2.fromScale(1, 0.55),
			Position = UDim2.fromScale(0, 0.45),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = if IsEvenSlat then 0.5 else 0.55,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Gradient = E("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.6),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Rotation = 90,
			}),
		})

		-- Top lip highlight
		Children.TopEdge = E("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			ZIndex = 3,
		})

		-- Bottom lip shadow
		Children.BottomEdge = E("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, -2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 3,
		})

		-- Embossed center ridge highlight
		Children.RidgeHighlight = E("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.46),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			ZIndex = 3,
		})

		-- Embossed center ridge shadow
		Children.RidgeShadow = E("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.54),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 3,
		})

		-- Edge definition stroke
		Children.Stroke = E("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Thickness = 1,
			Transparency = 0.5,
		})

		-- Heavy handle bar on the bottom slat
		if IsLastSlat then
			Children.HandleBar = E("Frame", {
				Size = UDim2.new(1, 0, 0, 8),
				Position = UDim2.new(0, 0, 1, -8),
				BackgroundColor3 = BgColor:map(function(C: Color3)
					return Color3.new(
						math.clamp(C.R + 0.04, 0, 1),
						math.clamp(C.G + 0.04, 0, 1),
						math.clamp(C.B + 0.04, 0, 1)
					)
				end),
				BorderSizePixel = 0,
				ZIndex = 4,
			}, {
				Highlight = E("Frame", {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.fromScale(0, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.75,
					BorderSizePixel = 0,
				}),
				Shadow = E("Frame", {
					Size = UDim2.new(1, 0, 0, 2),
					Position = UDim2.new(0, 0, 1, -2),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.1,
					BorderSizePixel = 0,
				}),
				Corner = E("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),
				Stroke = E("UIStroke", {
					Color = Color3.new(0, 0, 0),
					Thickness = 1,
					Transparency = 0.5,
				}),
			})
		end

		Elements["Slat" .. I] = E("Frame", {
			Position = Progress:map(function(P: number)
				local Action = ActionRef.current
				local SlatStart = if Action == "close" then CloseSlatStart else OpenSlatStart
				local SlatT = math.clamp((P - SlatStart) / SlatDuration, 0, 1)

				if Action == "close" then
					local Eased = Easing.EaseOutQuart(SlatT)
					return UDim2.fromScale(0, -SlatHeight + (FinalY + SlatHeight) * Eased)
				else
					local Eased = Easing.EaseInCubic(SlatT)
					return UDim2.fromScale(0, FinalY + (-FinalY - SlatHeight) * Eased)
				end
			end),
			Size = UDim2.fromScale(1, SlatHeight),
			BackgroundColor3 = BgColor:map(function(C: Color3)
				local Bump = if IsEvenSlat then 0.015 else 0
				return Color3.new(
					math.max(C.R, 0.03) + Bump,
					math.max(C.G, 0.03) + Bump,
					math.max(C.B, 0.03) + Bump
				)
			end),
			BorderSizePixel = 0,
			ZIndex = SLAT_COUNT + 1 - I,
			ClipsDescendants = true,
		}, Children)
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.5, 1.5),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, Elements)
end

return Shutter
