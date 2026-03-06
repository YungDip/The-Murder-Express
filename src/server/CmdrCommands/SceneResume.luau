return {
	Name = "sceneresume",
	Aliases = { "resume" },
	Description = "Resume scrolling from a stopped scene.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "speed",
			Description = "Target speed to resume at (default uses Constants).",
			Optional = true,
		},
		{
			Type = "number",
			Name = "transitionTime",
			Description = "Acceleration time in seconds (default 5).",
			Optional = true,
			Default = 5,
		},
	},
}
