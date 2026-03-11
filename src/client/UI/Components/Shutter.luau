local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local UIState = require(script.Parent.Parent.UIState)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement

local BLADE_COUNT = 12
local STAGGER_OVERLAP = 0.45

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

	local Step = (1 - STAGGER_OVERLAP) / BLADE_COUNT
	local BladeDuration = STAGGER_OVERLAP + Step

	local Blades = {}
	for I = 0, BLADE_COUNT - 1 do
		local FromRight = I % 2 == 0
		local BladeStart = I * Step
		local OffscreenX = if FromRight then 1.5 else -1.5

		Blades["Blade" .. I] = E("Frame", {
			Position = Progress:map(function(P: number)
				local BladeT = math.clamp((P - BladeStart) / BladeDuration, 0, 1)
				local Eased = Easing.Smoothstep(BladeT)
				local Action = ActionRef.current

				local XOffset
				if Action == "close" then
					XOffset = OffscreenX * (1 - Eased)
				else
					XOffset = OffscreenX * Eased
				end

				return UDim2.fromScale(XOffset, I / BLADE_COUNT)
			end),
			Size = UDim2.fromScale(1, 1 / BLADE_COUNT + 0.003),
			BackgroundColor3 = BgColor,
			BorderSizePixel = 0,
			ZIndex = BLADE_COUNT - I,
		}, {
			TopEdge = E("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
			}),
			BottomEdge = E("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 1, -1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
			}),
		})
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.5, 1.5),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, Blades)
end

return Shutter
