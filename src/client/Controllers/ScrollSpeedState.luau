-- Lightweight shared state for scroll speed ratio.
-- WorldScrollController writes this each frame; other controllers read it.
-- No yields, so require() completes instantly.

local ScrollSpeedState = {
	SpeedRatio = 1,
}

return ScrollSpeedState
