local Stylesheet = {}

-- Core palette — warm old-money tones
Stylesheet.Colors = {
	-- Primary text / accents
	Gold = Color3.fromRGB(234, 224, 152),
	GoldMuted = Color3.fromRGB(190, 178, 120),
	GoldDim = Color3.fromRGB(140, 132, 90),

	-- Backgrounds
	DarkBrown = Color3.fromRGB(30, 24, 16),
	MediumBrown = Color3.fromRGB(40, 32, 24),
	LightBrown = Color3.fromRGB(55, 45, 33),
	WarmBlack = Color3.fromRGB(18, 14, 10),

	-- Semantic
	Danger = Color3.fromRGB(180, 45, 35),
	DangerBright = Color3.fromRGB(210, 55, 45),
	Detective = Color3.fromRGB(80, 140, 220),
	DetectiveMuted = Color3.fromRGB(60, 110, 180),
	Innocent = Color3.fromRGB(234, 224, 152),
	Murderer = Color3.fromRGB(180, 45, 35),

	-- Neutrals
	White = Color3.fromRGB(245, 240, 230),
	WhiteMuted = Color3.fromRGB(200, 192, 175),
	Separator = Color3.fromRGB(80, 68, 52),
	SeparatorDim = Color3.fromRGB(55, 46, 35),

	-- Status
	Alive = Color3.fromRGB(120, 180, 90),
	Dead = Color3.fromRGB(160, 55, 50),

	-- Coal
	CoalOrange = Color3.fromRGB(230, 140, 30),
	CoalYellow = Color3.fromRGB(245, 210, 60),
	CoalEmber = Color3.fromRGB(180, 60, 20),
}

Stylesheet.RoleColors = {
	Innocent = Stylesheet.Colors.Innocent,
	Detective = Stylesheet.Colors.Detective,
	Murderer = Stylesheet.Colors.Murderer,
}

-- Typography
Stylesheet.Font = {
	Primary = "rbxasset://fonts/families/HighwayGothic.json",
	Accent = "rbxasset://fonts/families/Merriweather.json",
}

Stylesheet.FontFace = {
	Title = Font.new(Stylesheet.Font.Primary, Enum.FontWeight.Bold),
	Subtitle = Font.new(Stylesheet.Font.Primary, Enum.FontWeight.Regular),
	Body = Font.new(Stylesheet.Font.Primary, Enum.FontWeight.Regular),
	Accent = Font.new(Stylesheet.Font.Accent, Enum.FontWeight.Bold),
	AccentLight = Font.new(Stylesheet.Font.Accent, Enum.FontWeight.Regular),
}

Stylesheet.TextSize = {
	Hero = 42,
	Title = 32,
	Subtitle = 24,
	Body = 20,
	Caption = 16,
	Small = 13,
}

-- Spacing + sizing
Stylesheet.Spacing = {
	XS = 4,
	SM = 8,
	MD = 14,
	LG = 20,
	XL = 32,
}

Stylesheet.Corner = {
	None = UDim.new(0, 0),
	SM = UDim.new(0, 4),
	MD = UDim.new(0, 6),
	LG = UDim.new(0, 10),
}

Stylesheet.Stroke = {
	Thin = 1,
	Normal = 2,
	Thick = 3,
}

-- Animation presets (duration in seconds)
Stylesheet.Animation = {
	Quick = 0.15,
	Normal = 0.3,
	Slow = 0.5,
	SlideIn = 0.6,
	BorderSnake = 0.9,

	-- Easing
	EaseOut = Enum.EasingStyle.Quad,
	EaseIn = Enum.EasingStyle.Quad,
	EaseBack = Enum.EasingStyle.Back,
	EaseSine = Enum.EasingStyle.Sine,
}

-- Transparency presets
Stylesheet.Transparency = {
	Solid = 0,
	Overlay = 0.15,
	Panel = 0.25,
	Subtle = 0.5,
	Ghost = 0.75,
	Invisible = 1,
}

-- Z-ordering (DisplayOrder for ScreenGuis)
Stylesheet.DisplayOrder = {
	Base = 100,
	Timer = 110,
	Roulette = 120,
	Scoreboard = 130,
	Announcement = 140,
	Fade = 200,
}

return Stylesheet
