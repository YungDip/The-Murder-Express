local ScrollSpeedState = {
	SpeedRatio = 0,
	Transition = nil :: {StartSpeed: number, EndSpeed: number, StartTime: number, Duration: number}?,
	Active = false,
	EffectsActive = false,
}

return ScrollSpeedState
