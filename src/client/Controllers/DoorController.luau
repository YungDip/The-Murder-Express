local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local DoorNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.DoorNetwork)

local DoorConst = Constants.Door
local DOOR_TAGS = { "CarDoor", "SideDoor", "CabinDoor" }

local DoorController = {}

-- Sound mapping: tag -> { Open = soundName, Close = soundName }
local SOUND_MAP = {
	CarDoor = { Open = "InnerCarDoorOpen", Close = "InnerCarDoorClose" },
	SideDoor = { Open = "SideCarDoorOpen", Close = "SideCarDoorClose" },
	CabinDoor = { Open = "WoodDoorOpen", Close = "WoodDoorClose" },
}

-- Track original pivots and active animations
local OriginalPivots: { [Model]: CFrame } = {}
local ActiveAnimations: { [Model]: thread } = {}

local function GetDoorTag(Door: Model): string?
	for _, Tag in DOOR_TAGS do
		if CollectionService:HasTag(Door, Tag) then
			return Tag
		end
	end
	return nil
end

local function GetOriginalPivot(Door: Model): CFrame
	if not OriginalPivots[Door] then
		OriginalPivots[Door] = Door:GetPivot()
	end
	return OriginalPivots[Door]
end

local function SetCanCollide(Door: Model, Value: boolean)
	for _, Part in Door:QueryDescendants("BasePart") do
		Part.CanCollide = Value
	end
end

local function PlayDoorSound(Door: Model, IsOpen: boolean)
	local Tag = GetDoorTag(Door)
	if not Tag then return end

	local SoundInfo = SOUND_MAP[Tag]
	if not SoundInfo then return end

	local SoundName = if IsOpen then SoundInfo.Open else SoundInfo.Close
	local Template = SoundService:FindFirstChild(SoundName, true)
	if not Template or not Template:IsA("Sound") then return end

	local TargetPart = Door:FindFirstChildWhichIsA("BasePart")
	if not TargetPart then return end

	local Sound = Template:Clone()
	Sound.Parent = TargetPart
	Sound:Play()
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
end

local function AnimateDoor(Door: Model, IsOpen: boolean)
	local Existing = ActiveAnimations[Door]
	if Existing then
		task.cancel(Existing)
		ActiveAnimations[Door] = nil
	end

	local ClosedPivot = GetOriginalPivot(Door)
	local SwingAngle = Door:GetAttribute("CustomSwingAngle") or DoorConst.SWING_ANGLE
	local OpenPivot = ClosedPivot * CFrame.Angles(0, math.rad(SwingAngle), 0)

	local TargetPivot = if IsOpen then OpenPivot else ClosedPivot
	local StartPivot = Door:GetPivot()

	if IsOpen then
		SetCanCollide(Door, false)
	end

	ActiveAnimations[Door] = task.spawn(function()
		local Elapsed = 0
		while Elapsed < DoorConst.SWING_DURATION do
			local DeltaTime = RunService.PreSimulation:Wait()
			Elapsed += DeltaTime
			local Alpha = math.clamp(Elapsed / DoorConst.SWING_DURATION, 0, 1)
			Alpha = 1 - (1 - Alpha) ^ 2 -- EaseOut Quad
			Door:PivotTo(StartPivot:Lerp(TargetPivot, Alpha))
		end
		Door:PivotTo(TargetPivot)

		if not IsOpen then
			SetCanCollide(Door, true)
		end

		ActiveAnimations[Door] = nil
	end)
end

-- Listen for door state changes from server
DoorNetwork.packets.DoorState.listen(function(Data: { Door: Instance, IsOpen: boolean })
	local Door = Data.Door
	local IsOpen = Data.IsOpen

	if not Door or not Door:IsA("Model") or not Door.Parent then return end

	PlayDoorSound(Door, IsOpen)
	AnimateDoor(Door, IsOpen)
end)

return DoorController
