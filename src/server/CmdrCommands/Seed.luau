return {
	Name = "seed",
	Aliases = {},
	Description = "Regenerate the train with a given seed.",
	Group = "Admin",
	Args = {
		{
			Type = "integer",
			Name = "seed",
			Description = "The seed number for train generation.",
		},
		{
			Type = "integer",
			Name = "length",
			Description = "Number of cars to generate (default 15).",
			Optional = true,
			Default = 15,
		},
	},
}
