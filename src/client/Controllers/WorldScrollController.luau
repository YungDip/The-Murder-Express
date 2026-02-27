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

type BulkScrollEntity = {
	PartStartIndex: number,
	PartCount: number,
	OriginalX: number,
}

type BulkScrollGroup = {
	AllParts: {BasePart},
	AllOriginalCFrames: {CFrame},
	AllNewCFrames: {CFrame},
	Entities: {BulkScrollEntity},
	Clones: {Instance},
	Direction: number,
	Speed: number,
	CycleLength: number,
	AnchorX: number,
	HalfSpan: number,
}

local Lanes: {Lane} = {}
local BulkScrollGroups: {BulkScrollGroup} = {}
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

type BulkScrollConfig = {
	FolderName: string,
	Lane: Lane,
}

function WorldScrollController.AttachBulkScroll(Config: BulkScrollConfig): BulkScrollGroup
	local Folder = workspace:WaitForChild(Config.FolderName)
	local ReferenceLane = Config.Lane

	local Direction = ReferenceLane.Direction
	local AnchorX = ReferenceLane.AnchorCFrame.Position.X
	local CycleLen = ReferenceLane.CycleLength
	local TileWidth = ReferenceLane.TileWidth
	local PoolSize = ReferenceLane.PoolSize
	local HalfSpan = math.floor(PoolSize / 2) * TileWidth

	local AllParts: {BasePart} = {}
	local AllOriginalCFrames: {CFrame} = {}
	local AllNewCFrames: {CFrame} = {}
	local Entities: {BulkScrollEntity} = {}
	local Clones: {Instance} = {}

	local OriginalChildren = Folder:GetChildren()

	for CopyIndex = 0, PoolSize - 1 do
		local ShiftVector = Vector3.new(Direction * CopyIndex * TileWidth, 0, 0)

		for _, Child in OriginalChildren do
			local Source: Instance
			if CopyIndex == 0 then
				Source = Child
			else
				Source = Child:Clone()
				Source.Parent = Folder
				table.insert(Clones, Source)
			end

			local Pivot = if Source:IsA("BasePart") then Source.CFrame else (Source :: Model):GetPivot()
			local ChildParts: {BasePart} = {}

			if Source:IsA("BasePart") then
				table.insert(ChildParts, Source)
			else
				for _, Desc in Source:GetDescendants() do
					if Desc:IsA("BasePart") then
						table.insert(ChildParts, Desc)
					end
				end
			end

			if #ChildParts == 0 then
				continue
			end

			if CopyIndex > 0 then
				for _, Part in ChildParts do
					Part.CFrame += ShiftVector
				end
			end

			local StartIndex = #AllParts + 1
			for _, Part in ChildParts do
				table.insert(AllParts, Part)
				table.insert(AllOriginalCFrames, Part.CFrame)
				table.insert(AllNewCFrames, Part.CFrame)
			end

			local EntityOriginalX = (Pivot.Position.X - AnchorX) * Direction + CopyIndex * TileWidth
			table.insert(Entities, {
				PartStartIndex = StartIndex,
				PartCount = #ChildParts,
				OriginalX = EntityOriginalX,
			})
		end
	end

	local Group: BulkScrollGroup = {
		AllParts = AllParts,
		AllOriginalCFrames = AllOriginalCFrames,
		AllNewCFrames = AllNewCFrames,
		Entities = Entities,
		Clones = Clones,
		Direction = Direction,
		Speed = ReferenceLane.Speed,
		CycleLength = CycleLen,
		AnchorX = AnchorX,
		HalfSpan = HalfSpan,
	}

	table.insert(BulkScrollGroups, Group)
	return Group
end

function WorldScrollController.DetachBulkScroll(TargetGroup: BulkScrollGroup)
	for _, Clone in TargetGroup.Clones do
		if Clone.Parent then
			Clone:Destroy()
		end
	end

	for Index, Part in TargetGroup.AllParts do
		if Part.Parent then
			Part.CFrame = TargetGroup.AllOriginalCFrames[Index]
		end
	end

	local Found = table.find(BulkScrollGroups, TargetGroup)
	if Found then
		table.remove(BulkScrollGroups, Found)
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
WorldScrollController.AddLane({ ModelName = "Baseplate", Direction = 1, PoolSize = 5 })
WorldScrollController.AddLane({ ModelName = "Tracks", Direction = 1, PoolSize = 3 })
--WorldScrollController.AttachBulkScroll({ FolderName = "Trees", Lane = BaseplateLane })

StartTime = os.clock()

RunService.PreRender:Connect(function()
	local Elapsed = os.clock() - StartTime
	local Distance = Constants.WorldScroll.SCROLL_SPEED * Elapsed

	for _, LaneData in Lanes do
		UpdateLane(LaneData, LaneData.Speed * Elapsed)
	end

	for _, Group in BulkScrollGroups do
		local ScrollOffset = Group.Speed * Elapsed
		local CycleLen = Group.CycleLength
		local HalfSpan = Group.HalfSpan
		local Dir = Group.Direction

		for _, Entity in Group.Entities do
			local RawPos = Entity.OriginalX - (ScrollOffset % CycleLen)
			local WrappedPos = RawPos % CycleLen
			local FinalLocalX = WrappedPos - HalfSpan
			local DeltaX = Dir * (FinalLocalX - Entity.OriginalX)
			local Offset = Vector3.new(DeltaX, 0, 0)

			for I = 0, Entity.PartCount - 1 do
				local Idx = Entity.PartStartIndex + I
				Group.AllNewCFrames[Idx] = Group.AllOriginalCFrames[Idx] + Offset
			end
		end

		workspace:BulkMoveTo(Group.AllParts, Group.AllNewCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for _, Wheel in Wheels do
		local Angle = Distance / Wheel.Radius
		Wheel.Mesh.CFrame = Wheel.Origin * CFrame.Angles(0, 0, Angle)
	end
end)

return WorldScrollController
