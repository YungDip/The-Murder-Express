local Constants = {}

Constants.Sound = {
	WHEEL_STAGGER_DELAY = 2,
	WHEEL_VOLUME_OUTSIDE = 0.75,
	WHEEL_VOLUME_INSIDE = 0.1,
	WHISTLE_INTERVAL = 25,
	INTERIOR_VOLUME = 0.1,
	INTERIOR_FADE_TIME = 1,

	WIND_VOLUME_OUTSIDE = 0.2,
	WIND_VOLUME_INSIDE = 0.05,
	RAIN_VOLUME_OUTSIDE = 0.1,
	RAIN_VOLUME_INSIDE = 0.02,
	THUNDER_VOLUME_OUTSIDE = 0.3,
	THUNDER_VOLUME_INSIDE = 0.1,
	WEATHER_FADE_TIME = 1,
	THUNDER_MIN_INTERVAL = 15,
	THUNDER_MAX_INTERVAL = 45,
}

Constants.WorldScroll = {
	SCROLL_SPEED = 300,
	TILE_POOL_SIZE = 3,
}

Constants.Wind = {
	CHECK_INTERVAL = 0.25,
	GLOBAL_WIND = Vector3.new(-500, 0, 0),
}

Constants.CameraBob = {
	-- Inside (carriage sway — vertical bounce + roll)
	INSIDE_AMPLITUDE = Vector3.new(0.005, 0.06, 0.005),
	INSIDE_ROT_AMPLITUDE = Vector3.new(0.0, 0.0, 0.35),
	INSIDE_FREQUENCY = Vector3.new(0.9, 1.4, 0.9),
	INSIDE_ROT_FREQUENCY = Vector3.new(0.5, 0.4, 0.4),

	-- Outside (wind buffeting)
	OUTSIDE_AMPLITUDE = Vector3.new(0.06, 0.09, 0.04),
	OUTSIDE_ROT_AMPLITUDE = Vector3.new(0.35, 0.25, 0.4),
	OUTSIDE_FREQUENCY = Vector3.new(1.6, 1.1, 2.0),
	OUTSIDE_ROT_FREQUENCY = Vector3.new(1.0, 1.4, 0.8),

	-- Gust bursts (outside only, random intensity spikes)
	GUST_MIN_INTERVAL = 3,
	GUST_MAX_INTERVAL = 8,
	GUST_DURATION = 1.5,
	GUST_INTENSITY = 2.2,

	-- Transition
	LERP_SPEED = 3,
}

return Constants
