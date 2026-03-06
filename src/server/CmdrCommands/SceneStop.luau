return {
	Name = "scenestop",
	Aliases = { "stop" },
	Description = "Decelerate and stop at a scene.",
	Group = "Admin",
	Args = {
		{
			Type = "zone",
			Name = "scene",
			Description = "Scene model name to stop at.",
		},
	},
}
