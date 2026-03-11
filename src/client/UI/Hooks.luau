local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Easing = require(script.Parent.Easing)

local Hooks = {}

function Hooks.UseSignal(Signal: any, InitialState: any): any
	local State, SetState = React.useState(function()
		if type(InitialState) == "table" then
			return table.clone(InitialState)
		end
		return InitialState
	end)

	React.useEffect(function()
		local Connection = Signal:Connect(function(NewState: any)
			if type(NewState) == "table" then
				SetState(table.clone(NewState))
			else
				SetState(NewState)
			end
		end)
		return function()
			Connection:Disconnect()
		end
	end, {})

	return State
end

function Hooks.UseDelayedUnmount(Visible: boolean, ExitDuration: number): boolean
	local Mounted, SetMounted = React.useState(Visible)

	React.useEffect(function()
		if Visible then
			SetMounted(true)
			return nil
		end

		local Thread = task.delay(ExitDuration, function()
			SetMounted(false)
		end)

		return function()
			task.cancel(Thread)
		end
	end, { Visible, ExitDuration } :: { any })

	return Visible or Mounted
end

function Hooks.UseTransition(Visible: boolean, EnterDuration: number, ExitDuration: number, EnterEasing: ((number) -> number)?, ExitEasing: ((number) -> number)?): (boolean, any)
	local DefaultEnterEasing = EnterEasing or Easing.EaseOutCubic
	local DefaultExitEasing = ExitEasing or Easing.EaseInCubic

	local Progress, SetProgress = React.useBinding(if Visible then 1 else 0)
	local ShouldRender, SetShouldRender = React.useState(Visible)
	local AnimRef = React.useRef({
		StartValue = if Visible then 1 else 0,
		TargetValue = if Visible then 1 else 0,
		StartTime = 0,
		Animating = false,
	})

	React.useEffect(function()
		local Ref = AnimRef.current
		local Target = if Visible then 1 else 0

		if Visible then
			SetShouldRender(true)
		end

		Ref.StartValue = Progress:getValue()
		Ref.TargetValue = Target
		Ref.StartTime = os.clock()
		Ref.Animating = true

		local Duration = if Visible then EnterDuration else ExitDuration
		local EasingFn = if Visible then DefaultEnterEasing else DefaultExitEasing

		if Duration <= 0 then
			SetProgress(Target)
			Ref.Animating = false
			if not Visible then
				SetShouldRender(false)
			end
			return nil
		end

		local Connection = RunService.PreRender:Connect(function()
			if not Ref.Animating then
				return
			end

			local Elapsed = os.clock() - Ref.StartTime
			local T = math.clamp(Elapsed / Duration, 0, 1)
			local Eased = EasingFn(T)

			SetProgress(Ref.StartValue + (Ref.TargetValue - Ref.StartValue) * Eased)

			if T >= 1 then
				Ref.Animating = false
				SetProgress(Ref.TargetValue)
				if not Visible then
					SetShouldRender(false)
				end
			end
		end)

		return function()
			Connection:Disconnect()
		end
	end, { Visible } :: { any })

	return ShouldRender or Visible, Progress
end

return Hooks