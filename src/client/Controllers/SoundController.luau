local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local ZoneCheck = require(game:GetService("ReplicatedStorage").Shared.Util.ZoneCheck)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)

local Ambient = SoundService:WaitForChild("Ambient")
local InteriorSound = Ambient:WaitForChild("InteriorLoop")
local WheelsTemplate = Ambient:WaitForChild("WheelsLoop")
local AccelTemplate = Ambient:WaitForChild("WheelsAccelerating")
local SlowingTemplate = Ambient:WaitForChild("WheelsSlowing")
local WhistleTemplate = Ambient:WaitForChild("Whistle")
local RainSound = Ambient:WaitForChild("RainLoop")
local BlizzardSound = Ambient:WaitForChild("Blizzard")
local WindSound = Ambient:WaitForChild("WindLoop")
local ThunderSound = Ambient:WaitForChild("Thunder")

local SoundController = {}

local function GetZoneVolume(Zone: ZoneCheck.Zone, Inside: number, Medium: number, Outside: number, Roof: number?): number
	if Zone == "Inside" then return Inside end
	if Zone == "Medium" then return Medium end
	if Zone == "Roof" then return Roof or Outside end
	return Outside
end

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
	InteriorSound.Looped = true
	InteriorSound.Volume = 0

	ZoneCheck.OnChanged(FadeInterior)
end

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
	RainSound.Looped = true
	BlizzardSound.Looped = true
	WindSound.Looped = true

	RainSound.Volume = 0
	BlizzardSound.Volume = 0
	WindSound.Volume = 0
	ThunderSound.Volume = 0

	ZoneCheck.OnChanged(FadeWeather)
end

function SoundController.InitThunder()
	local SoundConst = Constants.Sound

	while true do
		local Interval = math.random(SoundConst.THUNDER_MIN_INTERVAL, SoundConst.THUNDER_MAX_INTERVAL)
		task.wait(Interval)

		if not ScrollSpeedState.Active then
			continue
		end

		local Zone = ZoneCheck.GetState()
		ThunderSound.Volume = GetZoneVolume(Zone, SoundConst.THUNDER_VOLUME_INSIDE, SoundConst.THUNDER_VOLUME_MEDIUM, SoundConst.THUNDER_VOLUME_OUTSIDE, SoundConst.THUNDER_VOLUME_ROOF)
		ThunderSound:Play()
	end
end

local WheelSounds: {Sound} = {}
local AccelSounds: {Sound} = {}
local SlowingSounds: {Sound} = {}
local WheelZoneVolume: number = 0
local WheelsReady = false

local WHEEL_VOLUME_LERP_SPEED = 3

local LastTransitionStartTime: number = 0
local CrossfadeState: string = "idle"
local CrossfadeElapsed: number = 0
local ActiveTransitionSounds: {Sound} = {}
local CapturedBaseVolume: number = 0

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

			local Accel = AccelTemplate:Clone()
			Accel.Volume = 0
			Accel.Looped = false
			Accel.Parent = Obj

			local Slowing = SlowingTemplate:Clone()
			Slowing.Volume = 0
			Slowing.Looped = false
			Slowing.Parent = Obj

			table.insert(Pairs, { Part = Obj, Sound = Sound })
			table.insert(WheelSounds, Sound)
			table.insert(AccelSounds, Accel)
			table.insert(SlowingSounds, Slowing)
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

function SoundController.InitWhistle()
	local Horn = workspace:WaitForChild("HORN")
	local Whistle = WhistleTemplate:Clone()
	Whistle.Parent = Horn

	while true do
		if ScrollSpeedState.Active then
			Whistle:Play()
		end
		task.wait(Constants.Sound.WHISTLE_INTERVAL)
	end
end

do
	SoundController.InitInterior()
	SoundController.InitWeather()
	task.spawn(SoundController.InitWheels)
	task.spawn(SoundController.InitWhistle)
	task.spawn(SoundController.InitThunder)

	local WasActive = false

	RunService.PreRender:Connect(function(DeltaTime: number)
		local IsActive = ScrollSpeedState.Active

		if IsActive and not WasActive then
			print("[SoundController] Active transition: OFF -> ON")
			WasActive = true

			local SoundConst = Constants.Sound
			local Zone = ZoneCheck.GetState()
			local FadeInInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			InteriorSound.Volume = 0
			if not InteriorSound.IsPlaying then
				InteriorSound:Play()
			end
			TweenService:Create(InteriorSound, FadeInInfo, { Volume = GetZoneVolume(Zone, SoundConst.INTERIOR_VOLUME, SoundConst.INTERIOR_VOLUME_MEDIUM, 0, 0) }):Play()

			RainSound.Volume = 0
			if not RainSound.IsPlaying then
				RainSound:Play()
			end
			TweenService:Create(RainSound, FadeInInfo, { Volume = GetZoneVolume(Zone, SoundConst.RAIN_VOLUME_INSIDE, SoundConst.RAIN_VOLUME_MEDIUM, SoundConst.RAIN_VOLUME_OUTSIDE, SoundConst.RAIN_VOLUME_ROOF) }):Play()

			BlizzardSound.Volume = 0
			if not BlizzardSound.IsPlaying then
				BlizzardSound:Play()
			end
			TweenService:Create(BlizzardSound, FadeInInfo, { Volume = GetZoneVolume(Zone, SoundConst.BLIZZARD_VOLUME_INSIDE, SoundConst.BLIZZARD_VOLUME_MEDIUM, SoundConst.BLIZZARD_VOLUME_OUTSIDE, SoundConst.BLIZZARD_VOLUME_ROOF) }):Play()

			WindSound.Volume = 0
			if not WindSound.IsPlaying then
				WindSound:Play()
			end
			TweenService:Create(WindSound, FadeInInfo, { Volume = GetZoneVolume(Zone, SoundConst.WIND_VOLUME_INSIDE, SoundConst.WIND_VOLUME_MEDIUM, SoundConst.WIND_VOLUME_OUTSIDE, SoundConst.WIND_VOLUME_ROOF) }):Play()
		end

		if not IsActive then
			if WasActive then
				print("[SoundController] Active transition: ON -> OFF")
				WasActive = false
			end
			InteriorSound.Volume = 0
			RainSound.Volume = 0
			BlizzardSound.Volume = 0
			WindSound.Volume = 0
			if WheelsReady then
				for _, S in WheelSounds do
					S.Volume = 0
				end
				for _, S in AccelSounds do
					S.Volume = 0
				end
				for _, S in SlowingSounds do
					S.Volume = 0
				end
			end
			return
		end

		if not InteriorSound.IsPlaying then InteriorSound:Play() end
		if not RainSound.IsPlaying then RainSound:Play() end
		if not BlizzardSound.IsPlaying then BlizzardSound:Play() end
		if not WindSound.IsPlaying then WindSound:Play() end

		local SpeedRatio = ScrollSpeedState.SpeedRatio

		BlizzardSound.PlaybackSpeed = math.clamp(SpeedRatio, 1, 1.5)
		WindSound.PlaybackSpeed = math.clamp(SpeedRatio, 1, 1.5)
		InteriorSound.PlaybackSpeed = math.max(0.01, SpeedRatio)

		if not WheelsReady then
			return
		end

		local SoundConst = Constants.Sound
		local Transition = ScrollSpeedState.Transition
		local FadeDuration = SoundConst.WHEEL_TRANSITION_FADE_TIME

		if Transition then
			local IsNew = Transition.StartTime ~= LastTransitionStartTime
			if IsNew then
				LastTransitionStartTime = Transition.StartTime
				local IsDecelerating = Transition.EndSpeed == 0 and Transition.StartSpeed > 0
				local IsAccelerating = Transition.StartSpeed == 0 and Transition.EndSpeed > 0

				if IsDecelerating then
					for _, S in AccelSounds do
						S:Stop()
					end

					CapturedBaseVolume = if WheelSounds[1] then WheelSounds[1].Volume else WheelZoneVolume

					local SlowingSpeed = math.clamp(SlowingTemplate.TimeLength / Transition.Duration, 0.25, 4)
					for _, S in SlowingSounds do
						S.PlaybackSpeed = SlowingSpeed
						S.Volume = 0
						S.TimePosition = 0
						S:Play()
					end

					ActiveTransitionSounds = SlowingSounds
					CrossfadeState = "fade_to_transition"
					CrossfadeElapsed = 0

				elseif IsAccelerating then
					for _, S in SlowingSounds do
						S:Stop()
					end

					CapturedBaseVolume = WheelZoneVolume

					for _, S in AccelSounds do
						S.PlaybackSpeed = 1
						S.Volume = 0
						S.TimePosition = 0
						S:Play()
					end

					ActiveTransitionSounds = AccelSounds
					CrossfadeState = "fade_to_transition"
					CrossfadeElapsed = 0
				end
			end
		end

		if CrossfadeState == "fade_to_transition" then
			CrossfadeElapsed += DeltaTime
			local Raw = math.clamp(CrossfadeElapsed / FadeDuration, 0, 1)
			local TransAlpha = math.sqrt(Raw)
			local LoopAlpha = math.sqrt(1 - Raw)

			for _, S in WheelSounds do
				S.Volume = CapturedBaseVolume * LoopAlpha
			end
			for _, S in ActiveTransitionSounds do
				S.Volume = CapturedBaseVolume * TransAlpha
			end

			if Raw >= 1 then
				CrossfadeState = "transition"
			end

		elseif CrossfadeState == "transition" then
			for _, S in ActiveTransitionSounds do
				if S.IsPlaying then
					S.Volume = WheelZoneVolume
				end
			end
			for _, S in WheelSounds do
				S.Volume = 0
			end

			if ActiveTransitionSounds == AccelSounds and AccelSounds[1] then
				if AccelSounds[1].IsPlaying then
					local Remaining = AccelSounds[1].TimeLength - AccelSounds[1].TimePosition
					if Remaining <= FadeDuration then
						CapturedBaseVolume = WheelZoneVolume
						CrossfadeState = "fade_to_loop"
						CrossfadeElapsed = FadeDuration - Remaining
					end
				else
					CapturedBaseVolume = WheelZoneVolume
					CrossfadeState = "fade_to_loop"
					CrossfadeElapsed = 0
				end
			end

			if ActiveTransitionSounds == SlowingSounds then
				local AnyPlaying = false
				for _, S in SlowingSounds do
					if S.IsPlaying then
						AnyPlaying = true
						break
					end
				end
				if not AnyPlaying then
					CrossfadeState = "idle"
				end
			end

		elseif CrossfadeState == "fade_to_loop" then
			CrossfadeElapsed += DeltaTime
			local Raw = math.clamp(CrossfadeElapsed / FadeDuration, 0, 1)
			local LoopAlpha = math.sqrt(Raw)
			local TransAlpha = math.sqrt(1 - Raw)

			local LoopTargetVol = WheelZoneVolume * math.clamp(SpeedRatio, 0, 1)

			for _, S in WheelSounds do
				S.Volume = LoopTargetVol * LoopAlpha
			end
			for _, S in ActiveTransitionSounds do
				S.Volume = CapturedBaseVolume * TransAlpha
			end

			if Raw >= 1 then
				CrossfadeState = "idle"
				for _, S in ActiveTransitionSounds do
					S:Stop()
				end
			end

		else -- idle
			local TargetVol = if SpeedRatio < 0.01 then 0 else WheelZoneVolume * math.clamp(SpeedRatio, 0, 1)
			local LerpAlpha = math.clamp(DeltaTime * WHEEL_VOLUME_LERP_SPEED, 0, 1)
			for _, S in WheelSounds do
				S.Volume += (TargetVol - S.Volume) * LerpAlpha
			end
		end

		local WheelPlayback = if SpeedRatio < 0.01 then 0 else math.clamp(0.8 + 0.4 * (SpeedRatio / 1), 0.8, 1.2)
		for _, WheelSound in WheelSounds do
			WheelSound.PlaybackSpeed = WheelPlayback
		end
	end)
end

return SoundController
