return {
	Name = "tunnel",
	Aliases = {},
	Description = "Trigger a tunnel transition to new scenery zones.",
	Group = "Admin",
	Args = {
		{
			Type = "zones",
			Name = "zones",
			Description = "Zone names to transition to (comma-separated).",
		},
	},
}
