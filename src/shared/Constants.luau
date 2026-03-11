local Constants = {}

--[[
	ROOF = On top of carriages
	OUTSIDE = On outdoor carriages (e.g. flat-bed at floor level)
	MEDIUM = In connectors or carriages with thin walls
	INSIDE = Inside normal carriages
]]
Constants.Sound = {
	WHEEL_STAGGER_DELAY = 0.2,
	WHEEL_VOLUME_ROOF = 1.0,
	WHEEL_VOLUME_OUTSIDE = 0.75,
	WHEEL_VOLUME_MEDIUM = 0.425,
	WHEEL_VOLUME_INSIDE = 0.25,
	WHEEL_TRANSITION_FADE_TIME = 0.5,
	WHISTLE_INTERVAL = 25,
	INTERIOR_VOLUME = 0.1,
	INTERIOR_VOLUME_MEDIUM = 0.05,
	INTERIOR_FADE_TIME = 0.5,

	WIND_VOLUME_ROOF = 0.5,
	WIND_VOLUME_OUTSIDE = 0.2,
	WIND_VOLUME_MEDIUM = 0.125,
	WIND_VOLUME_INSIDE = 0.05,
	RAIN_VOLUME_ROOF = 0.25,
	RAIN_VOLUME_OUTSIDE = 0.1,
	RAIN_VOLUME_MEDIUM = 0.06,
	RAIN_VOLUME_INSIDE = 0.02,
	BLIZZARD_VOLUME_ROOF = 0.3,
	BLIZZARD_VOLUME_OUTSIDE = 0.15,
	BLIZZARD_VOLUME_MEDIUM = 0.08,
	BLIZZARD_VOLUME_INSIDE = 0.03,
	THUNDER_VOLUME_ROOF = 0.5,
	THUNDER_VOLUME_OUTSIDE = 0.3,
	THUNDER_VOLUME_MEDIUM = 0.2,
	THUNDER_VOLUME_INSIDE = 0.1,
	WEATHER_FADE_TIME = 0.5,
	THUNDER_MIN_INTERVAL = 15,
	THUNDER_MAX_INTERVAL = 45,
}

Constants.WorldScroll = {
	DEFAULT_SPEED = 125,
	BASELINE_SPEED = 200,
	TILE_POOL_SIZE = 3,
	ZONE_MODELS_FOLDER = "ZoneModels",
	TUNNEL_MODEL = "TestTunnel",

	-- How far ahead (studs) to spawn the tunnel's leading edge
	TUNNEL_BUFFER = 600,

	-- Number of tunnel segments to stack for scene transitions
	SCENE_TUNNEL_SEGMENTS = 3,

	-- Lanes that always scroll regardless of scenery transitions
	CONSTANT_LANES = {
		{ ModelName = "Tracks", Direction = 1, PoolSize = 3 },
		{ ModelName = "Baseplate", Direction = 1, PoolSize = 6, CenterPool = 4 },
	},

	-- Default deceleration (studs/s²) used when stopping at a scene
	STOP_DECELERATION = 25,

	-- Extra distance (studs) beyond the physics braking distance to place the scene,
	-- ensuring it spawns well ahead of all visible looping tiles
	SCENE_APPROACH_BUFFER = 800,

	-- Duration (seconds) of the braking phase when stopping at a scene
	SCENE_BRAKE_DURATION = 8,
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
	VOLUME = 0.2,
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

Constants.DeathVelocity = {
	OUTSIDE_MULTIPLIER = 0.15,
	ROOF_MULTIPLIER = 0.675,
	UP_FORCE = -20,
	MAX_FORCE = 200,
	DURATION = 4,
}

Constants.Announcement = {
	TEXT_COLOR = Color3.fromRGB(234, 224, 152),
	BG_COLOR = Color3.fromRGB(40, 32, 24),
	BORDER_COLOR = Color3.fromRGB(234, 224, 152),
	FONT = "rbxasset://fonts/families/HighwayGothic.json",
	TITLE_SIZE = 35,
	SUBTITLE_SIZE = 26,
	DISPLAY_DURATION = 4,
	BORDER_THICKNESS = 2,
	SLIDE_DURATION = 0.5,
	BORDER_SNAKE_DURATION = 0.9,
	HOLD_AFTER_BORDER = 0.3,
	WARNING_COLOR = Color3.fromRGB(200, 50, 40),
	WARNING_PULSE_SPEED = 1.2,

	-- Small screen overrides (viewport height < 1080)
	SMALL_TITLE_SIZE = 20,
	SMALL_SUBTITLE_SIZE = 15,
	SMALL_PADDING_V = 8,
	SMALL_PADDING_H = 12,
	SMALL_WIDTH = 0.5,
	SMALL_THRESHOLD = 1080,
}

Constants.VERSION = "0.1.0"

Constants.SOLO_TEST_ENABLED = true

Constants.Round = {
	MIN_PLAYERS = 3,
	INTERMISSION_DURATION = 15,
	ROLE_REVEAL_DELAY = 5,
	ROUND_DURATION = 180,
	POST_ROUND_DURATION = 8,
	TELEPORT_FADE_DURATION = 1.5,
	DEATH_RAGDOLL_WAIT = 3,
	DEATH_FADE_DURATION = 3,

	-- Roulette
	ROULETTE_SPIN_DURATION = 3.5,
	ROULETTE_SLOT_HEIGHT = 50,
	ROULETTE_VISIBLE_SLOTS = 1,
	ROULETTE_TOTAL_CYCLES = 10,

	-- Timer UI
	TIMER_WIDTH = 0.12,
	TIMER_HEIGHT = 40,
	TIMER_FONT = "rbxasset://fonts/families/HighwayGothic.json",
	TIMER_TEXT_SIZE = 28,
	TIMER_TEXT_COLOR = Color3.fromRGB(234, 224, 152),
	TIMER_BG_COLOR = Color3.fromRGB(40, 32, 24),
	TIMER_BORDER_COLOR = Color3.fromRGB(234, 224, 152),
	TIMER_WARNING_THRESHOLD = 30,
	TIMER_WARNING_COLOR = Color3.fromRGB(200, 50, 40),

	-- Role Colors
	ROLE_COLORS = {
		Innocent = Color3.fromRGB(234, 224, 152),
		Detective = Color3.fromRGB(80, 140, 220),
		Murderer = Color3.fromRGB(200, 50, 40),
	},

	-- Scoreboard
	SCOREBOARD_WIDTH = 0.4,
	SCOREBOARD_ROW_HEIGHT = 36,
	SCOREBOARD_HEADER_SIZE = 32,
	SCOREBOARD_ROW_TEXT_SIZE = 22,
	SCOREBOARD_BG_COLOR = Color3.fromRGB(40, 32, 24),
	SCOREBOARD_TEXT_COLOR = Color3.fromRGB(234, 224, 152),

	-- Result display text
	RESULT_TEXT = {
		MurdererWin = "Murderer Wins!",
		DetectiveWin = "Detective Wins!",
		PassengersWin = "Passengers Survive!",
	},
}

return Constants
