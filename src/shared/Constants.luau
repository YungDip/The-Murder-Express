local Constants = {}

Constants.Sound = {
	WHEEL_STAGGER_DELAY = 2,
	WHEEL_VOLUME_ROOF = 1.0,
	WHEEL_VOLUME_OUTSIDE = 0.75,
	WHEEL_VOLUME_MEDIUM = 0.425,
	WHEEL_VOLUME_INSIDE = 0.1,
	WHISTLE_INTERVAL = 25,
	INTERIOR_VOLUME = 0.1,
	INTERIOR_VOLUME_MEDIUM = 0.05,
	INTERIOR_FADE_TIME = 1,

	WIND_VOLUME_ROOF = 0.5,
	WIND_VOLUME_OUTSIDE = 0.2,
	WIND_VOLUME_MEDIUM = 0.125,
	WIND_VOLUME_INSIDE = 0.05,
	RAIN_VOLUME_ROOF = 0.25,
	RAIN_VOLUME_OUTSIDE = 0.1,
	RAIN_VOLUME_MEDIUM = 0.06,
	RAIN_VOLUME_INSIDE = 0.02,
	THUNDER_VOLUME_ROOF = 0.5,
	THUNDER_VOLUME_OUTSIDE = 0.3,
	THUNDER_VOLUME_MEDIUM = 0.2,
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

Constants.Footstep = {
	RAYCAST_DISTANCE = 5,
	BASE_STEP_INTERVAL = 0.3,
	DEFAULT_WALK_SPEED = 16,
	MIN_SPEED_THRESHOLD = 0.5,
	VOLUME = 0.1,
	PITCH_MIN = 0.9,
	PITCH_MAX = 1.1,

	-- Material index mapping (must match FootstepNetwork uint8 values)
	MATERIALS = { "Metal", "Carpet", "Wood", "Sand", "Rock", "Concrete", "Grass" },
	DEFAULT_MATERIAL = "Metal",
}

Constants.CameraBob = {
	-- Inside (carriage sway — vertical bounce + roll)
	INSIDE_AMPLITUDE = Vector3.new(0.005, 0.06, 0.005),
	INSIDE_ROT_AMPLITUDE = Vector3.new(0.0, 0.0, 0.35),
	INSIDE_FREQUENCY = Vector3.new(0.9, 1.4, 0.9),
	INSIDE_ROT_FREQUENCY = Vector3.new(0.5, 0.4, 0.4),

	-- Outside (wind buffeting)
	OUTSIDE_AMPLITUDE = Vector3.new(0.03, 0.045, 0.02),
	OUTSIDE_ROT_AMPLITUDE = Vector3.new(0.18, 0.12, 0.2),
	OUTSIDE_FREQUENCY = Vector3.new(1.6, 1.1, 2.0),
	OUTSIDE_ROT_FREQUENCY = Vector3.new(1.0, 1.4, 0.8),

	-- Roof (violent wind exposure)
	ROOF_AMPLITUDE = Vector3.new(0.08, 0.1, 0.06),
	ROOF_ROT_AMPLITUDE = Vector3.new(0.5, 0.35, 0.6),
	ROOF_FREQUENCY = Vector3.new(2.2, 1.8, 2.5),
	ROOF_ROT_FREQUENCY = Vector3.new(1.6, 1.8, 1.2),

	-- Gust bursts (outside/roof only, random intensity spikes)
	GUST_MIN_INTERVAL = 3,
	GUST_MAX_INTERVAL = 8,
	GUST_DURATION = 1.5,
	GUST_INTENSITY = 1.6,
	GUST_ROOF_INTENSITY = 2.2,

	-- Transition
	LERP_SPEED = 3,
}

Constants.Door = {
	PROXIMITY_DISTANCE = 7,
	CHECK_INTERVAL = 0.2,
	SWING_ANGLE = 90,
	SWING_DURATION = 0.35,
}

return Constants
