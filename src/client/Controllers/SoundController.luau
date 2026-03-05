local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local ZoneCheck = require(game:GetService("ReplicatedStorage").Shared.Util.ZoneCheck)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)

local Ambient = SoundService:WaitForChild("Ambient")
local InteriorSound = Ambient:WaitForChild("InteriorLoop")
local WheelsTemplate = Ambient:WaitForChild("WheelsLoop")
local WhistleTemplate = Ambient:WaitForChild("Whistle")
local RainSound = Ambient:WaitForChild("RainLoop")
local BlizzardSound = Ambient:WaitForChild("Blizzard")
local WindSound = Ambient:WaitForChild("WindLoop")
local ThunderSound = Ambient:WaitForChild("Thunder")

local SoundController = {}

-- Helpers

local function GetZoneVolume(Zone: ZoneCheck.Zone, Inside: number, Medium: number, Outside: number, Roof: number?): number
	if Zone == "Inside" then return Inside end
	if Zone == "Medium" then return Medium end
	if Zone == "Roof" then return Roof or Outside end
	return Outside
end

-- Interior Ambience (plays from SoundService, fades on inside/outside/medium)

local FadeTween: Tween = nil

local function FadeInterior(Zone: ZoneCheck.Zone)
	local SoundConst = Constants.Sound
	local TargetVolume = GetZoneVolume(Zone, SoundConst.INTERIOR_VOLUME, SoundConst.INTERIOR_VOLUME_MEDIUM, 0, 0)

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
	local SoundConst = Constants.Sound
	local Zone = ZoneCheck.GetState()
	InteriorSound.Volume = GetZoneVolume(Zone, SoundConst.INTERIOR_VOLUME, SoundConst.INTERIOR_VOLUME_MEDIUM, 0, 0)
	InteriorSound:Play()

	ZoneCheck.OnChanged(FadeInterior)
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

local function FadeWeather(Zone: ZoneCheck.Zone)
	local SoundConst = Constants.Sound

	FadeWeatherSound(RainSound, GetZoneVolume(Zone, SoundConst.RAIN_VOLUME_INSIDE, SoundConst.RAIN_VOLUME_MEDIUM, SoundConst.RAIN_VOLUME_OUTSIDE, SoundConst.RAIN_VOLUME_ROOF))
	FadeWeatherSound(BlizzardSound, GetZoneVolume(Zone, SoundConst.BLIZZARD_VOLUME_INSIDE, SoundConst.BLIZZARD_VOLUME_MEDIUM, SoundConst.BLIZZARD_VOLUME_OUTSIDE, SoundConst.BLIZZARD_VOLUME_ROOF))
	FadeWeatherSound(WindSound, GetZoneVolume(Zone, SoundConst.WIND_VOLUME_INSIDE, SoundConst.WIND_VOLUME_MEDIUM, SoundConst.WIND_VOLUME_OUTSIDE, SoundConst.WIND_VOLUME_ROOF))
end

function SoundController.InitWeather()
	local SoundConst = Constants.Sound
	local Zone = ZoneCheck.GetState()

	RainSound.Volume = GetZoneVolume(Zone, SoundConst.RAIN_VOLUME_INSIDE, SoundConst.RAIN_VOLUME_MEDIUM, SoundConst.RAIN_VOLUME_OUTSIDE, SoundConst.RAIN_VOLUME_ROOF)
	RainSound:Play()

	BlizzardSound.Volume = GetZoneVolume(Zone, SoundConst.BLIZZARD_VOLUME_INSIDE, SoundConst.BLIZZARD_VOLUME_MEDIUM, SoundConst.BLIZZARD_VOLUME_OUTSIDE, SoundConst.BLIZZARD_VOLUME_ROOF)
	BlizzardSound:Play()

	WindSound.Volume = GetZoneVolume(Zone, SoundConst.WIND_VOLUME_INSIDE, SoundConst.WIND_VOLUME_MEDIUM, SoundConst.WIND_VOLUME_OUTSIDE, SoundConst.WIND_VOLUME_ROOF)
	WindSound:Play()

	ThunderSound.Volume = GetZoneVolume(Zone, SoundConst.THUNDER_VOLUME_INSIDE, SoundConst.THUNDER_VOLUME_MEDIUM, SoundConst.THUNDER_VOLUME_OUTSIDE, SoundConst.THUNDER_VOLUME_ROOF)

	ZoneCheck.OnChanged(FadeWeather)
end

-- Thunder (random interval, like the horn)

function SoundController.InitThunder()
	local SoundConst = Constants.Sound

	while true do
		local Interval = math.random(SoundConst.THUNDER_MIN_INTERVAL, SoundConst.THUNDER_MAX_INTERVAL)
		task.wait(Interval)

		local Zone = ZoneCheck.GetState()
		ThunderSound.Volume = GetZoneVolume(Zone, SoundConst.THUNDER_VOLUME_INSIDE, SoundConst.THUNDER_VOLUME_MEDIUM, SoundConst.THUNDER_VOLUME_OUTSIDE, SoundConst.THUNDER_VOLUME_ROOF)
		ThunderSound:Play()
	end
end

-- Wheel Ambience (one per carriage, staggered playback, fades on inside/outside)

local WheelSounds: {Sound} = {}
local WheelZoneVolume: number = 0
local WheelsReady = false
local LastWheelDebugTime = 0

local WHEEL_VOLUME_LERP_SPEED = 3

local function FadeWheels(Zone: ZoneCheck.Zone)
	local SoundConst = Constants.Sound
	WheelZoneVolume = GetZoneVolume(Zone, SoundConst.WHEEL_VOLUME_INSIDE, SoundConst.WHEEL_VOLUME_MEDIUM, SoundConst.WHEEL_VOLUME_OUTSIDE, SoundConst.WHEEL_VOLUME_ROOF)
end

function SoundController.InitWheels()
	local SoundConst = Constants.Sound
	local Zone = ZoneCheck.GetState()
	WheelZoneVolume = GetZoneVolume(Zone, SoundConst.WHEEL_VOLUME_INSIDE, SoundConst.WHEEL_VOLUME_MEDIUM, SoundConst.WHEEL_VOLUME_OUTSIDE, SoundConst.WHEEL_VOLUME_ROOF)

	local Seen: {[Instance]: boolean} = {}
	local Pairs: {{Part: MeshPart, Sound: Sound}} = {}

	for _, Obj in workspace:QueryDescendants("MeshPart") do
		local IsWheel = string.find(Obj.Name, "Wheel") and not string.find(Obj.Name, "Part")
		if IsWheel and not Seen[Obj.Parent] then
			Seen[Obj.Parent] = true

			local Sound = WheelsTemplate:Clone()
			Sound.Volume = 0
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

	WheelsReady = true
	ZoneCheck.OnChanged(FadeWheels)
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

	-- Scale playback speed of ambient sounds based on world scroll speed
	RunService.PreRender:Connect(function(DeltaTime: number)
		local SpeedRatio = ScrollSpeedState.SpeedRatio

		BlizzardSound.PlaybackSpeed = math.clamp(SpeedRatio, 1, 1.5)
		WindSound.PlaybackSpeed = math.clamp(SpeedRatio, 1, 1.5)
		InteriorSound.PlaybackSpeed = math.max(0.01, SpeedRatio)

		-- Wheels: PlaybackSpeed 0.8–1.2 when moving, 0 at standstill; lerp volume
		if WheelsReady then
			local WheelTargetVolume = if SpeedRatio < 0.01 then 0 else WheelZoneVolume * math.clamp(SpeedRatio, 0, 1)
			local WheelPlayback = if SpeedRatio < 0.01 then 0 else math.clamp(0.8 + 0.4 * (SpeedRatio / 1), 0.8, 1.2)
			local LerpAlpha = math.clamp(DeltaTime * WHEEL_VOLUME_LERP_SPEED, 0, 1)

			for _, WheelSound in WheelSounds do
				if SpeedRatio < 0.01 then
					WheelSound.Volume = 0
				else
					WheelSound.Volume += (WheelTargetVolume - WheelSound.Volume) * LerpAlpha
				end
				WheelSound.PlaybackSpeed = WheelPlayback
			end

			-- Debug
			if os.clock() - LastWheelDebugTime > 1 then
				LastWheelDebugTime = os.clock()
				local First = WheelSounds[1]
				if First then
					print(string.format(
						"[Wheels] SpeedRatio=%.3f ZoneVol=%.3f TargetVol=%.3f ActualVol=%.3f Playback=%.3f Playing=%s Count=%d",
						SpeedRatio, WheelZoneVolume, WheelTargetVolume, First.Volume, First.PlaybackSpeed, tostring(First.Playing), #WheelSounds
					))
				end
			end
		end
	end)
end

return SoundController
