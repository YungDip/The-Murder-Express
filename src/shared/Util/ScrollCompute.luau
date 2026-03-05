--[[
	Deterministic scroll-distance calculator shared by server and all clients.
	Uses workspace:GetServerTimeNow() so every machine agrees on the result
	regardless of FPS or join time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local ScrollCompute = {}

-- Returns (CurrentDistance, CurrentSpeed) for a given ScrollState at time Now
function ScrollCompute.GetDistance(State: Types.ScrollState, Now: number): (number, number)
	local Transition = State.Transition

	if Transition then
		local Elapsed = math.min(Now - Transition.StartTime, Transition.Duration)
		local Duration = Transition.Duration

		if Duration <= 0 then
			-- Instant speed change
			local TimeAfter = Now - Transition.StartTime
			return State.BaseDistance + Transition.EndSpeed * TimeAfter, Transition.EndSpeed
		end

		local Alpha = Elapsed / Duration
		local StartSpd = Transition.StartSpeed
		local EndSpd = Transition.EndSpeed

		-- Integral of linear interpolation: ∫(StartSpd + (EndSpd - StartSpd) * t/Duration) dt from 0 to Elapsed
		-- = StartSpd * Elapsed + (EndSpd - StartSpd) * Elapsed² / (2 * Duration)
		local TransitionDistance = StartSpd * Elapsed + (EndSpd - StartSpd) * Elapsed * Alpha / 2

		if Elapsed >= Duration then
			-- Past the transition, moving at EndSpeed
			local TimeAfter = Now - Transition.StartTime - Duration
			local CurrentSpeed = EndSpd
			return State.BaseDistance + TransitionDistance + CurrentSpeed * TimeAfter, CurrentSpeed
		else
			local CurrentSpeed = StartSpd + (EndSpd - StartSpd) * Alpha
			return State.BaseDistance + TransitionDistance, CurrentSpeed
		end
	end

	-- Constant speed
	local TimeDelta = Now - State.BaseTime
	return State.BaseDistance + State.Speed * TimeDelta, State.Speed
end

-- Snapshot: collapse current state into a clean BaseDistance/BaseTime at the given time
function ScrollCompute.Snapshot(State: Types.ScrollState, Now: number): Types.ScrollState
	local Distance, Speed = ScrollCompute.GetDistance(State, Now)
	return {
		BaseDistance = Distance,
		BaseTime = Now,
		Speed = Speed,
		Transition = nil,
	}
end

-- Compute the distance required to decelerate from CurrentSpeed to TargetSpeed at a given deceleration rate
function ScrollCompute.DecelerationDistance(CurrentSpeed: number, TargetSpeed: number, Deceleration: number): number
	-- v² = v0² - 2*a*d  =>  d = (v0² - v²) / (2*a)
	return math.abs(CurrentSpeed * CurrentSpeed - TargetSpeed * TargetSpeed) / (2 * Deceleration)
end

-- Compute the time required to decelerate from CurrentSpeed to TargetSpeed at a given deceleration rate
function ScrollCompute.DecelerationTime(CurrentSpeed: number, TargetSpeed: number, Deceleration: number): number
	return math.abs(CurrentSpeed - TargetSpeed) / Deceleration
end

return ScrollCompute
