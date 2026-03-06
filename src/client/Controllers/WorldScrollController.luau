local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)
local ScrollCompute = require(ReplicatedStorage.Shared.Util.ScrollCompute)
local WorldScrollNetwork = require(ReplicatedStorage.Shared.Network.WorldScrollNetwork)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)

local WorldScrollController = {}

type Lane = {
	Pool: {Model | BasePart},
	AnchorCFrame: CFrame,
	TileWidth: number,
	Direction: number,
	PoolSize: number,
	CenterPool: number,
	CycleLength: number,
	Active: boolean,
	DrainStartDistance: number?,
}

type OneShotTile = {
	Instance: Model | BasePart,
	AnchorCFrame: CFrame,
	Direction: number,
	SpawnDistance: number,
	TileWidth: number,
}

local ZoneModels: Folder = nil :: any

local ConstantLanes: {Lane} = {}
local SceneryLanes: {Lane} = {}
local OneShotTiles: {OneShotTile} = {}

local ServerScrollState: Types.ScrollState = {
	BaseDistance = 0,
	BaseTime = 0,
	Speed = 0,
	Transition = nil,
}

local _ActiveSceneryNames: {string} = {}
local CurrentPhase: Types.SceneryPhase = "Looping"

local TunnelData: {
	NewScenery: {string},
	TunnelLeadingEdge: number,
	TunnelTrailingEdge: number,
	OldSceneryHidden: boolean,
}? = nil

local SceneInstance: (Model | BasePart)? = nil
local SceneStopDistance: number = 0
local SceneTailInstances: {Model | BasePart} = {}

local Wheels: {{Mesh: MeshPart, Origin: CFrame, Radius: number}} = {}

local Initialized = false

local function GetBoundsX(Object: Instance): number
	if Object:IsA("Model") then
		local _, Size = Object:GetBoundingBox()
		return Size.X
	end
	return (Object :: BasePart).Size.X
end

--[[
    returns the scroll-direction width (Z axis) of a one-shot tile
]]
local function GetOneShotScrollWidth(Object: Instance): number
	if Object:IsA("Model") then
		local _, Size = Object:GetBoundingBox()
		return Size.Z
	end
	return (Object :: BasePart).Size.Z
end

local function GetTemplate(ModelName: string): Instance
	return ZoneModels:WaitForChild(ModelName)
end

local function CreateLaneFromTemplate(Config: Types.LaneConfig): Lane
	local Template = GetTemplate(Config.ModelName)
	local PoolSize = Config.PoolSize or Constants.WorldScroll.TILE_POOL_SIZE
	local TileWidth = GetBoundsX(Template)

	local AnchorCFrame = Template:GetPivot()

	local Pool: {Model | BasePart} = {}
	for Index = 1, PoolSize do
		local Clone = Template:Clone()
		Clone.Name = Config.ModelName
		Clone:PivotTo(CFrame.new(0, -1000, 0))
		Clone.Parent = workspace
		Pool[Index] = Clone
	end

	local CenterPool = Config.CenterPool or math.floor(PoolSize / 2) + 1

	return {
		Pool = Pool,
		AnchorCFrame = AnchorCFrame,
		TileWidth = TileWidth,
		Direction = Config.Direction,
		PoolSize = PoolSize,
		CenterPool = CenterPool,
		CycleLength = PoolSize * TileWidth,
		Active = true,
		DrainStartDistance = nil,
	}
end

local function DestroyLane(LaneData: Lane)
	for _, Tile in LaneData.Pool do
		if Tile and Tile.Parent then
			Tile:Destroy()
		end
	end
	LaneData.Active = false
	table.clear(LaneData.Pool)
end

local function UpdateLaneLooping(LaneData: Lane, ScrollOffset: number)
	if not LaneData.Active then
		return
	end

	local CycleLen = LaneData.CycleLength
	local TileWidth = LaneData.TileWidth
	local Direction = LaneData.Direction
	local Anchor = LaneData.AnchorCFrame
	local HalfSpan = (LaneData.CenterPool - 1) * TileWidth

	for Index, Tile in LaneData.Pool do
		local RawPos = (Index - 1) * TileWidth - (ScrollOffset % CycleLen)
		local WrappedPos = RawPos % CycleLen
		local FinalOffset = WrappedPos - HalfSpan

		Tile:PivotTo(Anchor * CFrame.new(Direction * FinalOffset, 0, 0))
	end
end

local function _UpdateLaneDraining(LaneData: Lane, CurrentDistance: number)
	if not LaneData.Active then
		return
	end

	local DrainStart = LaneData.DrainStartDistance or CurrentDistance
	local Delta = CurrentDistance - DrainStart

	local CycleLen = LaneData.CycleLength
	local TileWidth = LaneData.TileWidth
	local Direction = LaneData.Direction
	local Anchor = LaneData.AnchorCFrame
	local HalfSpan = (LaneData.CenterPool - 1) * TileWidth

	local AllOffscreen = true

	for Index, Tile in LaneData.Pool do
		local RawPos = (Index - 1) * TileWidth - (DrainStart % CycleLen)
		local WrappedPos = RawPos % CycleLen
		local OriginalOffset = WrappedPos - HalfSpan

		local FinalOffset = OriginalOffset - Delta

		if math.abs(FinalOffset) < HalfSpan + TileWidth * 3 then
			AllOffscreen = false
			Tile:PivotTo(Anchor * CFrame.new(Direction * FinalOffset, 0, 0))
		else
			Tile:PivotTo(CFrame.new(0, -1000, 0))
		end
	end

	if AllOffscreen then
		DestroyLane(LaneData)
	end
end

local function SpawnOneShotTile(ModelName: string, SpawnDistance: number, Direction: number, AnchorCFrame: CFrame): OneShotTile
	local Template = GetTemplate(ModelName)
	local Clone = Template:Clone()
	Clone.Name = ModelName .. "_OneShot"
	Clone.Parent = workspace

	local TileWidth = GetOneShotScrollWidth(Template)

	local Tile: OneShotTile = {
		Instance = Clone,
		AnchorCFrame = AnchorCFrame,
		Direction = Direction,
		SpawnDistance = SpawnDistance,
		TileWidth = TileWidth,
	}
	table.insert(OneShotTiles, Tile)
	return Tile
end

local function UpdateOneShotTile(Tile: OneShotTile, CurrentDistance: number)
	local Offset = Tile.SpawnDistance - CurrentDistance
	Tile.Instance:PivotTo(Tile.AnchorCFrame * CFrame.new(Tile.Direction * Offset, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
end

local function CleanupOneShotTile(Tile: OneShotTile)
	if Tile.Instance and Tile.Instance.Parent then
		Tile.Instance:Destroy()
	end
	local Found = table.find(OneShotTiles, Tile)
	if Found then
		table.remove(OneShotTiles, Found)
	end
end

local function SpawnSceneryLanes(SceneryNames: {string})
	for _, Lane in SceneryLanes do
		DestroyLane(Lane)
	end
	table.clear(SceneryLanes)

	for _, Name in SceneryNames do
		local Lane = CreateLaneFromTemplate({
			ModelName = Name,
			Direction = 1,
		})
		table.insert(SceneryLanes, Lane)
	end

	_ActiveSceneryNames = SceneryNames
end

local function CleanupScene()
	if SceneInstance and SceneInstance.Parent then
		SceneInstance:Destroy()
	end
	SceneInstance = nil

	for _, Inst in SceneTailInstances do
		if Inst and Inst.Parent then
			Inst:Destroy()
		end
	end
	table.clear(SceneTailInstances)
end

--[[
    decodes flat Scroll*-prefixed fields into a typed ScrollState
]]
local function DecodeFlatScrollState(Data: {[string]: any}): Types.ScrollState
	local State: Types.ScrollState = {
		BaseDistance = Data.ScrollBaseDistance,
		BaseTime = Data.ScrollBaseTime,
		Speed = Data.ScrollSpeed,
		Transition = nil,
	}

	if Data.ScrollHasTransition then
		State.Transition = {
			StartSpeed = Data.ScrollTransitionStartSpeed,
			EndSpeed = Data.ScrollTransitionEndSpeed,
			StartTime = Data.ScrollTransitionStartTime,
			Duration = Data.ScrollTransitionDuration,
		}
	end

	return State
end

--[[
    decodes non-prefixed fields into a typed ScrollState
]]
local function DecodeScrollState(Data: {[string]: any}): Types.ScrollState
	local State: Types.ScrollState = {
		BaseDistance = Data.BaseDistance,
		BaseTime = Data.BaseTime,
		Speed = Data.Speed,
		Transition = nil,
	}

	if Data.HasTransition then
		State.Transition = {
			StartSpeed = Data.TransitionStartSpeed,
			EndSpeed = Data.TransitionEndSpeed,
			StartTime = Data.TransitionStartTime,
			Duration = Data.TransitionDuration,
		}
	end

	return State
end

--[[
    initialises the constant looping lanes (tracks, baseplate)
]]
local function InitConstantLanes()
	for _, Lane in ConstantLanes do
		DestroyLane(Lane)
	end
	table.clear(ConstantLanes)

	for _, Config in Constants.WorldScroll.CONSTANT_LANES do
		local Lane = CreateLaneFromTemplate(Config)
		table.insert(ConstantLanes, Lane)
	end
end

function WorldScrollController.GetSpeedRatio(): number
	local ServerNow = workspace:GetServerTimeNow()
	local _, CurrentSpeed = ScrollCompute.GetDistance(ServerScrollState, ServerNow)
	return math.max(0, CurrentSpeed / Constants.WorldScroll.BASELINE_SPEED)
end

WorldScrollNetwork.packets.SyncState.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = Data.Phase :: Types.SceneryPhase

	if not Initialized then
		InitConstantLanes()
		Initialized = true
	end
	SpawnSceneryLanes(Data.ActiveScenery)
end)

WorldScrollNetwork.packets.SpeedUpdate.listen(function(Data)
	ServerScrollState = DecodeScrollState(Data)
end)

WorldScrollNetwork.packets.TunnelTransition.listen(function(Data)
	local ServerNow = workspace:GetServerTimeNow()
	local CurrentDistance = ScrollCompute.GetDistance(ServerScrollState, ServerNow)

	local TunnelTemplate = GetTemplate(Data.TunnelModel)
	local TunnelWidth = GetOneShotScrollWidth(TunnelTemplate)

	local Buffer = Constants.WorldScroll.TUNNEL_BUFFER
	local TunnelSpawnDistance = CurrentDistance + Buffer + TunnelWidth / 2
	local TunnelLeadingEdge = TunnelSpawnDistance - TunnelWidth / 2
	local TunnelTrailingEdge = TunnelSpawnDistance + TunnelWidth / 2

	TunnelData = {
		NewScenery = Data.NewScenery,
		TunnelLeadingEdge = TunnelLeadingEdge,
		TunnelTrailingEdge = TunnelTrailingEdge,
		OldSceneryHidden = false,
	}
	CurrentPhase = "TunnelIncoming"

	local RefAnchor = if #ConstantLanes > 0
		then ConstantLanes[1].AnchorCFrame
		else CFrame.new()
	local RefDirection = if #ConstantLanes > 0
		then ConstantLanes[1].Direction
		else 1

	SpawnOneShotTile(
		Data.TunnelModel,
		TunnelSpawnDistance,
		RefDirection,
		RefAnchor
	)
end)

WorldScrollNetwork.packets.SceneStop.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = "SceneStopping"
	SceneStopDistance = Data.StopDistance

	if Data.SceneModel ~= "" then
		local Template = GetTemplate(Data.SceneModel)
		local Clone = Template:Clone()
		Clone.Name = Data.SceneModel .. "_Scene"
		Clone.Parent = workspace
		SceneInstance = Clone
	end

	for _, Name in Data.TailScenery do
		local Template = GetTemplate(Name)
		local Clone = Template:Clone()
		Clone.Name = Name .. "_Tail"
		Clone.Parent = workspace
		table.insert(SceneTailInstances, Clone)
	end
end)

WorldScrollNetwork.packets.SceneResume.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = "SceneResuming"

	CleanupScene()

	SpawnSceneryLanes(Data.TransitionScenery)
end)

do
	ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder

	for _, Obj in workspace:QueryDescendants("MeshPart") do
		if string.find(Obj.Name, "Train_Wheel") and not string.find(Obj.Name, "Part") then
			table.insert(Wheels, {
				Mesh = Obj,
				Origin = Obj.CFrame,
				Radius = Obj.Size.Y / 2,
			})
		end
	end

	local StateData = WorldScrollNetwork.queries.RequestState.invoke(nil)
	ServerScrollState = DecodeFlatScrollState(StateData)
	CurrentPhase = StateData.Phase :: Types.SceneryPhase
	InitConstantLanes()
	SpawnSceneryLanes(StateData.ActiveScenery)
	Initialized = true

	local WasActive = false

	RunService.PreRender:Connect(function()
		if not Initialized then
			return
		end

		local IsActive = ScrollSpeedState.Active

		if IsActive and not WasActive then
			print("[WorldScrollController] Active transition: OFF -> ON")
			WasActive = true
		elseif not IsActive and WasActive then
			print("[WorldScrollController] Active transition: ON -> OFF")
			WasActive = false
		end

		if not IsActive then
			ScrollSpeedState.SpeedRatio = 0
			ScrollSpeedState.Transition = nil
			for _, LaneData in ConstantLanes do
				for _, Tile in LaneData.Pool do
					Tile:PivotTo(CFrame.new(0, -1000, 0))
				end
			end
			for _, LaneData in SceneryLanes do
				for _, Tile in LaneData.Pool do
					Tile:PivotTo(CFrame.new(0, -1000, 0))
				end
			end
			for _, Tile in OneShotTiles do
				Tile.Instance:PivotTo(CFrame.new(0, -1000, 0))
			end
			return
		end

		local ServerNow = workspace:GetServerTimeNow()
		local Distance, CurrentSpeed = ScrollCompute.GetDistance(ServerScrollState, ServerNow)

		ScrollSpeedState.SpeedRatio = math.max(0, CurrentSpeed / Constants.WorldScroll.BASELINE_SPEED)

		local Trans = ServerScrollState.Transition
		if Trans and (ServerNow - Trans.StartTime) < Trans.Duration then
			ScrollSpeedState.Transition = Trans
		else
			ScrollSpeedState.Transition = nil
		end

		for _, LaneData in ConstantLanes do
			UpdateLaneLooping(LaneData, Distance)
		end

		if CurrentPhase == "Looping" or CurrentPhase == "SceneResuming" then
			for _, LaneData in SceneryLanes do
				UpdateLaneLooping(LaneData, Distance)
			end

		elseif CurrentPhase == "TunnelIncoming" then
			if TunnelData then
				if not TunnelData.OldSceneryHidden then
					for _, LaneData in SceneryLanes do
						UpdateLaneLooping(LaneData, Distance)
					end

					if Distance >= TunnelData.TunnelLeadingEdge then
						for _, LaneData in SceneryLanes do
							DestroyLane(LaneData)
						end
						table.clear(SceneryLanes)
						TunnelData.OldSceneryHidden = true
					end
				end

			if Distance >= TunnelData.TunnelTrailingEdge then
					SpawnSceneryLanes(TunnelData.NewScenery)
					CurrentPhase = "Looping"
					TunnelData = nil
				end
			end

		elseif CurrentPhase == "SceneStopping" then
			for _, LaneData in SceneryLanes do
				UpdateLaneLooping(LaneData, Distance)
			end

			if SceneInstance and SceneInstance.Parent then
				local SceneOffset = SceneStopDistance - Distance
				local RefAnchor = if #ConstantLanes > 0
					then ConstantLanes[1].AnchorCFrame
					else CFrame.new()
				local RefDir = if #ConstantLanes > 0
					then ConstantLanes[1].Direction
					else 1
				SceneInstance:PivotTo(RefAnchor * CFrame.new(RefDir * SceneOffset, 0, 0))
			end

			local TailOffset = 0
			if SceneInstance then
				TailOffset = GetBoundsX(SceneInstance)
			end
			for Idx, Inst in SceneTailInstances do
				local Width = GetBoundsX(Inst)
				local InstOffset = SceneStopDistance + TailOffset + (Idx - 1) * Width - Distance
				local RefAnchor = if #ConstantLanes > 0
					then ConstantLanes[1].AnchorCFrame
					else CFrame.new()
				local RefDir = if #ConstantLanes > 0
					then ConstantLanes[1].Direction
					else 1
				Inst:PivotTo(RefAnchor * CFrame.new(RefDir * InstOffset, 0, 0))
			end

			if CurrentSpeed <= 0.01 then
				CurrentPhase = "SceneStopped"
			end

		elseif CurrentPhase == "SceneStopped" then
			if SceneInstance and SceneInstance.Parent then
				local SceneOffset = SceneStopDistance - Distance
				local RefAnchor = if #ConstantLanes > 0
					then ConstantLanes[1].AnchorCFrame
					else CFrame.new()
				local RefDir = if #ConstantLanes > 0
					then ConstantLanes[1].Direction
					else 1
				SceneInstance:PivotTo(RefAnchor * CFrame.new(RefDir * SceneOffset, 0, 0))
			end
		end

		for TileIndex = #OneShotTiles, 1, -1 do
			local Tile = OneShotTiles[TileIndex]
			UpdateOneShotTile(Tile, Distance)

			local BehindBy = Distance - Tile.SpawnDistance
			if BehindBy > Tile.TileWidth * 2 then
				CleanupOneShotTile(Tile)
			end
		end

		for _, Wheel in Wheels do
			local Angle = Distance / Wheel.Radius
			Wheel.Mesh.CFrame = Wheel.Origin * CFrame.Angles(0, 0, Angle)
		end
	end)
end

return WorldScrollController
