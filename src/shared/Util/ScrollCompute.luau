local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local ScrollCompute = {}

--[[
    returns (CurrentDistance, CurrentSpeed) for a ScrollState at a given time
]]
function ScrollCompute.GetDistance(State: Types.ScrollState, Now: number): (number, number)
	local Transition = State.Transition

	if Transition then
		local Elapsed = math.min(Now - Transition.StartTime, Transition.Duration)
		local Duration = Transition.Duration

		if Duration <= 0 then
			local TimeAfter = Now - Transition.StartTime
			return State.BaseDistance + Transition.EndSpeed * TimeAfter, Transition.EndSpeed
		end

		local Alpha = Elapsed / Duration
		local StartSpd = Transition.StartSpeed
		local EndSpd = Transition.EndSpeed

		local TransitionDistance = StartSpd * Elapsed + (EndSpd - StartSpd) * Elapsed * Alpha / 2

		if Elapsed >= Duration then
			local TimeAfter = Now - Transition.StartTime - Duration
			local CurrentSpeed = EndSpd
			return State.BaseDistance + TransitionDistance + CurrentSpeed * TimeAfter, CurrentSpeed
		else
			local CurrentSpeed = StartSpd + (EndSpd - StartSpd) * Alpha
			return State.BaseDistance + TransitionDistance, CurrentSpeed
		end
	end

	local TimeDelta = Now - State.BaseTime
	return State.BaseDistance + State.Speed * TimeDelta, State.Speed
end

--[[
    collapses the current state into a clean snapshot at the given time
]]
function ScrollCompute.Snapshot(State: Types.ScrollState, Now: number): Types.ScrollState
	local Distance, Speed = ScrollCompute.GetDistance(State, Now)
	return {
		BaseDistance = Distance,
		BaseTime = Now,
		Speed = Speed,
		Transition = nil,
	}
end

--[[
    returns the distance required to decelerate from one speed to another
]]
function ScrollCompute.DecelerationDistance(CurrentSpeed: number, TargetSpeed: number, Deceleration: number): number
	return math.abs(CurrentSpeed * CurrentSpeed - TargetSpeed * TargetSpeed) / (2 * Deceleration)
end

--[[
    returns the time required to decelerate from one speed to another
]]
function ScrollCompute.DecelerationTime(CurrentSpeed: number, TargetSpeed: number, Deceleration: number): number
	return math.abs(CurrentSpeed - TargetSpeed) / Deceleration
end

return ScrollCompute
