local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldScrollController = {}

type LaneConfig = {
	ModelName: string,
	Direction: number,
	SpeedOverride: number?,
	PoolSize: number?,
}

type Lane = {
	Pool: {Model | BasePart},
	AnchorCFrame: CFrame,
	TileWidth: number,
	Direction: number,
	Speed: number,
	PoolSize: number,
	CycleLength: number,
}

local Lanes: {Lane} = {}
local StartTime: number = 0

-- Helpers

local function GetBoundsX(Object: Instance): number
	if Object:IsA("Model") then
		local _, Size = Object:GetBoundingBox()
		return Size.X
	end
	return (Object :: BasePart).Size.X
end

local function CreateLane(Config: LaneConfig): Lane
	local Original = workspace:WaitForChild(Config.ModelName)
	local PoolSize = Config.PoolSize or Constants.WorldScroll.TILE_POOL_SIZE
	local TileWidth = GetBoundsX(Original)
	local AnchorCFrame = Original:GetPivot()

	local Template = Original:Clone()
	local Pool: {Model | BasePart} = {}
	Pool[1] = Original

	for Index = 2, PoolSize do
		local Clone = Template:Clone()
		Clone.Name = Config.ModelName
		Clone.Parent = workspace
		Pool[Index] = Clone
	end

	Template:Destroy()

	return {
		Pool = Pool,
		AnchorCFrame = AnchorCFrame,
		TileWidth = TileWidth,
		Direction = Config.Direction,
		Speed = Config.SpeedOverride or Constants.WorldScroll.SCROLL_SPEED,
		PoolSize = PoolSize,
		CycleLength = PoolSize * TileWidth,
	}
end

local function UpdateLane(LaneData: Lane, ScrollOffset: number)
	local CycleLen = LaneData.CycleLength
	local TileWidth = LaneData.TileWidth
	local Direction = LaneData.Direction
	local Anchor = LaneData.AnchorCFrame
	local HalfSpan = math.floor(LaneData.PoolSize / 2) * TileWidth

	for Index, Tile in LaneData.Pool do
		local RawPos = (Index - 1) * TileWidth - (ScrollOffset % CycleLen)
		local WrappedPos = RawPos % CycleLen
		local FinalOffset = WrappedPos - HalfSpan

		Tile:PivotTo(Anchor * CFrame.new(Direction * FinalOffset, 0, 0))
	end
end

-- Public API

function WorldScrollController.AddLane(Config: LaneConfig): Lane
	local NewLane = CreateLane(Config)
	table.insert(Lanes, NewLane)
	return NewLane
end

function WorldScrollController.RemoveLane(TargetLane: Lane)
	for Index = 2, TargetLane.PoolSize do
		local Tile = TargetLane.Pool[Index]
		if Tile and Tile.Parent then
			Tile:Destroy()
		end
	end

	if TargetLane.Pool[1] and TargetLane.Pool[1].Parent then
		TargetLane.Pool[1]:PivotTo(TargetLane.AnchorCFrame)
	end

	local Found = table.find(Lanes, TargetLane)
	if Found then
		table.remove(Lanes, Found)
	end
end

-- Boot

local Wheels: {{Mesh: MeshPart, Origin: CFrame, Radius: number}} = {}

for _, Obj in workspace:QueryDescendants("MeshPart") do
	if string.find(Obj.Name, "Train_Wheel") and not string.find(Obj.Name, "Part") then
		table.insert(Wheels, {
			Mesh = Obj,
			Origin = Obj.CFrame,
			Radius = Obj.Size.Y / 2,
		})
	end
end

WorldScrollController.AddLane({ ModelName = "LeftSide", Direction = -1 })
WorldScrollController.AddLane({ ModelName = "RightSide", Direction = 1 })
WorldScrollController.AddLane({ ModelName = "Baseplate", Direction = 1, PoolSize = 11 })
WorldScrollController.AddLane({ ModelName = "Tracks", Direction = 1, PoolSize = 11 })

StartTime = os.clock()

RunService.PreRender:Connect(function()
	local Elapsed = os.clock() - StartTime
	local Distance = Constants.WorldScroll.SCROLL_SPEED * Elapsed

	for _, LaneData in Lanes do
		UpdateLane(LaneData, LaneData.Speed * Elapsed)
	end

	for _, Wheel in Wheels do
		local Angle = Distance / Wheel.Radius
		Wheel.Mesh.CFrame = Wheel.Origin * CFrame.Angles(0, 0, Angle)
	end
end)

return WorldScrollController
