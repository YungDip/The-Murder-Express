return {
	Name = "announce",
	Aliases = { "ann" },
	Description = "Show an announcement to all players.",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "title",
			Description = "The announcement title (supports rich text).",
		},
		{
			Type = "string",
			Name = "subtitle",
			Description = "Optional subtitle text.",
			Optional = true,
			Default = "",
		},
		{
			Type = "number",
			Name = "duration",
			Description = "Display duration in seconds (default 4).",
			Optional = true,
			Default = 4,
		},
	},
}
