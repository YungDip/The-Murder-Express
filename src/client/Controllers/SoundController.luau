local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local InsideCheck = require(game:GetService("ReplicatedStorage").Shared.Util.InsideCheck)

local Ambient = SoundService:WaitForChild("Ambient")
local InteriorSound = Ambient:WaitForChild("InteriorLoop")
local WheelsTemplate = Ambient:WaitForChild("WheelsLoop")
local WhistleTemplate = Ambient:WaitForChild("Whistle")
local RainSound = Ambient:WaitForChild("RainLoop")
local WindSound = Ambient:WaitForChild("WindLoop")
local ThunderSound = Ambient:WaitForChild("Thunder")

local SoundController = {}

-- Interior Ambience (plays from SoundService, fades on inside/outside)

local FadeTween: Tween = nil

local function FadeInterior(IsInside: boolean)
	local SoundConst = Constants.Sound
	local TargetVolume = if IsInside then SoundConst.INTERIOR_VOLUME else 0

	if FadeTween then
		FadeTween:Cancel()
	end

	FadeTween = TweenService:Create(
		InteriorSound,
		TweenInfo.new(SoundConst.INTERIOR_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Volume = TargetVolume }
	)
	FadeTween:Play()
end

function SoundController.InitInterior()
	InteriorSound.Volume = if InsideCheck.IsInside() then Constants.Sound.INTERIOR_VOLUME else 0
	InteriorSound:Play()

	InsideCheck.OnChanged(FadeInterior)
end

-- Weather Ambience (rain, wind, thunder — quieter inside)

local WeatherTweens: {[Sound]: Tween} = {}

local function FadeWeatherSound(TargetSound: Sound, TargetVolume: number)
	local SoundConst = Constants.Sound
	local Existing = WeatherTweens[TargetSound]

	if Existing then
		Existing:Cancel()
	end

	local NewTween = TweenService:Create(
		TargetSound,
		TweenInfo.new(SoundConst.WEATHER_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Volume = TargetVolume }
	)
	WeatherTweens[TargetSound] = NewTween
	NewTween:Play()
end

local function FadeWeather(IsInside: boolean)
	local SoundConst = Constants.Sound

	FadeWeatherSound(RainSound, if IsInside then SoundConst.RAIN_VOLUME_INSIDE else SoundConst.RAIN_VOLUME_OUTSIDE)
	FadeWeatherSound(WindSound, if IsInside then SoundConst.WIND_VOLUME_INSIDE else SoundConst.WIND_VOLUME_OUTSIDE)
end

function SoundController.InitWeather()
	local SoundConst = Constants.Sound
	local Inside = InsideCheck.IsInside()

	RainSound.Volume = if Inside then SoundConst.RAIN_VOLUME_INSIDE else SoundConst.RAIN_VOLUME_OUTSIDE
	RainSound:Play()

	WindSound.Volume = if Inside then SoundConst.WIND_VOLUME_INSIDE else SoundConst.WIND_VOLUME_OUTSIDE
	WindSound:Play()

	ThunderSound.Volume = if Inside then SoundConst.THUNDER_VOLUME_INSIDE else SoundConst.THUNDER_VOLUME_OUTSIDE

	InsideCheck.OnChanged(FadeWeather)
end

-- Thunder (random interval, like the horn)

function SoundController.InitThunder()
	local SoundConst = Constants.Sound

	while true do
		local Interval = math.random(SoundConst.THUNDER_MIN_INTERVAL, SoundConst.THUNDER_MAX_INTERVAL)
		task.wait(Interval)

		ThunderSound.Volume = if InsideCheck.IsInside() then SoundConst.THUNDER_VOLUME_INSIDE else SoundConst.THUNDER_VOLUME_OUTSIDE
		ThunderSound:Play()
	end
end

-- Wheel Ambience (one per carriage, staggered playback, fades on inside/outside)

local WheelSounds: {Sound} = {}

local function FadeWheels(IsInside: boolean)
	local SoundConst = Constants.Sound
	local TargetVolume = if IsInside then SoundConst.WHEEL_VOLUME_INSIDE else SoundConst.WHEEL_VOLUME_OUTSIDE

	for _, WheelSound in WheelSounds do
		FadeWeatherSound(WheelSound, TargetVolume)
	end
end

function SoundController.InitWheels()
	local SoundConst = Constants.Sound
	local Inside = InsideCheck.IsInside()
	local InitVolume = if Inside then SoundConst.WHEEL_VOLUME_INSIDE else SoundConst.WHEEL_VOLUME_OUTSIDE

	local Seen: {[Instance]: boolean} = {}
	local Pairs: {{Part: MeshPart, Sound: Sound}} = {}

	for _, Obj in workspace:QueryDescendants("MeshPart") do
		local IsWheel = string.find(Obj.Name, "Wheel") and not string.find(Obj.Name, "Part")
		if IsWheel and not Seen[Obj.Parent] then
			Seen[Obj.Parent] = true

			local Sound = WheelsTemplate:Clone()
			Sound.Volume = InitVolume
			Sound.Parent = Obj

			table.insert(Pairs, { Part = Obj, Sound = Sound })
			table.insert(WheelSounds, Sound)
		end
	end

	table.sort(Pairs, function(A, B)
		return A.Part.Position.X > B.Part.Position.X
	end)

	for _, Pair in Pairs do
		Pair.Sound:Play()
		task.wait(SoundConst.WHEEL_STAGGER_DELAY)
	end

	InsideCheck.OnChanged(FadeWheels)
end

-- Whistle / Horn Loop

function SoundController.InitWhistle()
	local Horn = workspace:WaitForChild("HORN")
	local Whistle = WhistleTemplate:Clone()
	Whistle.Parent = Horn

	while true do
		Whistle:Play()
		task.wait(Constants.Sound.WHISTLE_INTERVAL)
	end
end

-- Boot

do
	SoundController.InitInterior()
	SoundController.InitWeather()
	task.spawn(SoundController.InitWheels)
	task.spawn(SoundController.InitWhistle)
	task.spawn(SoundController.InitThunder)
end

return SoundController
