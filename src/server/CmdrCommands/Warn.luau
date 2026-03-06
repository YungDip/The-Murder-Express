return {
	Name = "warn",
	Aliases = {},
	Description = "Show a warning announcement with pulsing red border to all players.",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "title",
			Description = "The warning title (supports rich text).",
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
