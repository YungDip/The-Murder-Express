local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local InsideCheck = require(game:GetService("ReplicatedStorage").Shared.Util.InsideCheck)

local Camera = workspace.CurrentCamera

local CameraController = {}

-- State

local BobConst = Constants.CameraBob

local CurrentAmplitude = BobConst.INSIDE_AMPLITUDE
local CurrentRotAmplitude = BobConst.INSIDE_ROT_AMPLITUDE
local CurrentFrequency = BobConst.INSIDE_FREQUENCY
local CurrentRotFrequency = BobConst.INSIDE_ROT_FREQUENCY

local TargetAmplitude = CurrentAmplitude
local TargetRotAmplitude = CurrentRotAmplitude
local TargetFrequency = CurrentFrequency
local TargetRotFrequency = CurrentRotFrequency

local GustMultiplier = 1
local GustTarget = 1
local GustDecaySpeed = 0

local Elapsed = 0

-- Random phase offsets so axes don't sync up

local PhaseOffset = Vector3.new(
	math.random() * math.pi * 2,
	math.random() * math.pi * 2,
	math.random() * math.pi * 2
)
local RotPhaseOffset = Vector3.new(
	math.random() * math.pi * 2,
	math.random() * math.pi * 2,
	math.random() * math.pi * 2
)

-- Inside/Outside transitions

local function OnInsideChanged(IsInside: boolean)
	if IsInside then
		TargetAmplitude = BobConst.INSIDE_AMPLITUDE
		TargetRotAmplitude = BobConst.INSIDE_ROT_AMPLITUDE
		TargetFrequency = BobConst.INSIDE_FREQUENCY
		TargetRotFrequency = BobConst.INSIDE_ROT_FREQUENCY
	else
		TargetAmplitude = BobConst.OUTSIDE_AMPLITUDE
		TargetRotAmplitude = BobConst.OUTSIDE_ROT_AMPLITUDE
		TargetFrequency = BobConst.OUTSIDE_FREQUENCY
		TargetRotFrequency = BobConst.OUTSIDE_ROT_FREQUENCY
	end
end

-- Helpers

local function LerpVector3(A: Vector3, B: Vector3, Alpha: number): Vector3
	return A + (B - A) * Alpha
end

local function SampleNoise(Time: number, Freq: Vector3, Phase: Vector3): Vector3
	local X = math.sin(Time * Freq.X * math.pi * 2 + Phase.X)
		+ 0.5 * math.sin(Time * Freq.X * 1.7 * math.pi * 2 + Phase.X + 1.3)
		+ 0.3 * math.sin(Time * Freq.X * 3.1 * math.pi * 2 + Phase.X + 2.7)
	local Y = math.sin(Time * Freq.Y * math.pi * 2 + Phase.Y)
		+ 0.5 * math.sin(Time * Freq.Y * 1.9 * math.pi * 2 + Phase.Y + 0.8)
		+ 0.3 * math.sin(Time * Freq.Y * 2.8 * math.pi * 2 + Phase.Y + 3.1)
	local Z = math.sin(Time * Freq.Z * math.pi * 2 + Phase.Z)
		+ 0.5 * math.sin(Time * Freq.Z * 2.1 * math.pi * 2 + Phase.Z + 1.9)
		+ 0.3 * math.sin(Time * Freq.Z * 3.4 * math.pi * 2 + Phase.Z + 0.4)

	local Norm = 1 / 1.8
	return Vector3.new(X * Norm, Y * Norm, Z * Norm)
end

-- Gust loop (random wind bursts when outside)

task.spawn(function()
	while true do
		local Interval = math.random(BobConst.GUST_MIN_INTERVAL, BobConst.GUST_MAX_INTERVAL)
		task.wait(Interval)

		if not InsideCheck.IsInside() then
			GustTarget = BobConst.GUST_INTENSITY
			GustDecaySpeed = (BobConst.GUST_INTENSITY - 1) / BobConst.GUST_DURATION
		end
	end
end)

-- Main update

RunService.PreRender:Connect(function(DeltaTime: number)
	Elapsed += DeltaTime

	local Alpha = math.clamp(DeltaTime * BobConst.LERP_SPEED, 0, 1)
	CurrentAmplitude = LerpVector3(CurrentAmplitude, TargetAmplitude, Alpha)
	CurrentRotAmplitude = LerpVector3(CurrentRotAmplitude, TargetRotAmplitude, Alpha)
	CurrentFrequency = LerpVector3(CurrentFrequency, TargetFrequency, Alpha)
	CurrentRotFrequency = LerpVector3(CurrentRotFrequency, TargetRotFrequency, Alpha)

	-- Decay gust back to 1
	if GustMultiplier > 1 then
		GustMultiplier = math.max(1, GustMultiplier - GustDecaySpeed * DeltaTime)
	elseif GustTarget > 1 then
		GustMultiplier = GustTarget
		GustTarget = 1
	end

	local PosNoise = SampleNoise(Elapsed, CurrentFrequency, PhaseOffset)
	local RotNoise = SampleNoise(Elapsed, CurrentRotFrequency, RotPhaseOffset)

	local OffsetX = PosNoise.X * CurrentAmplitude.X * GustMultiplier
	local OffsetY = PosNoise.Y * CurrentAmplitude.Y * GustMultiplier
	local OffsetZ = PosNoise.Z * CurrentAmplitude.Z * GustMultiplier

	local RotX = math.rad(RotNoise.X * CurrentRotAmplitude.X * GustMultiplier)
	local RotY = math.rad(RotNoise.Y * CurrentRotAmplitude.Y * GustMultiplier)
	local RotZ = math.rad(RotNoise.Z * CurrentRotAmplitude.Z * GustMultiplier)

	local BobCFrame = CFrame.new(OffsetX, OffsetY, OffsetZ)
		* CFrame.Angles(RotX, RotY, RotZ)

	Camera.CFrame = Camera.CFrame * BobCFrame
end)

-- Boot

InsideCheck.OnChanged(OnInsideChanged)

return CameraController
