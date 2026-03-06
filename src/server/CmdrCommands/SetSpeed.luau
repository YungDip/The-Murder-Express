return {
	Name = "setspeed",
	Aliases = { "speed" },
	Description = "Change the world scroll speed with an optional transition time.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "speed",
			Description = "Target scroll speed (studs/s).",
		},
		{
			Type = "number",
			Name = "transitionTime",
			Description = "Transition duration in seconds (default 0 = instant).",
			Optional = true,
			Default = 0,
		},
	},
}
