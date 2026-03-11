local Easing = {}

function Easing.Linear(T: number): number
	return T
end

function Easing.EaseInQuad(T: number): number
	return T * T
end

function Easing.EaseOutQuad(T: number): number
	return T * (2 - T)
end

function Easing.EaseInCubic(T: number): number
	return T * T * T
end

function Easing.EaseOutCubic(T: number): number
	return 1 - (1 - T) ^ 3
end

function Easing.EaseInOutCubic(T: number): number
	if T < 0.5 then
		return 4 * T * T * T
	end
	return 1 - (-2 * T + 2) ^ 3 / 2
end

function Easing.EaseOutQuart(T: number): number
	return 1 - (1 - T) ^ 4
end

function Easing.EaseOutBack(T: number): number
	local C1 = 1.70158
	local C3 = C1 + 1
	return 1 + C3 * (T - 1) ^ 3 + C1 * (T - 1) ^ 2
end

function Easing.EaseOutExpo(T: number): number
	if T >= 1 then
		return 1
	end
	return 1 - 2 ^ (-10 * T)
end

function Easing.Smoothstep(T: number): number
	return T * T * (3 - 2 * T)
end

return Easing
