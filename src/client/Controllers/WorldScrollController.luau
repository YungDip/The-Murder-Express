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
	ModelName: string,
}

type OneShotTile = {
	Instance: Model | BasePart,
	AnchorCFrame: CFrame,
	Direction: number,
	SpawnDistance: number,
	TileWidth: number,
	Rotation: CFrame,
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

local SceneTunnelData: {
	DrainLanes: {string},
	DrainAtDistance: number,
	DrainsApplied: boolean,
	RestoreLanes: {string},
	RestoreAtDistance: number,
	RestoresApplied: boolean,
}? = nil

local Wheels: {{Mesh: MeshPart, Origin: CFrame, Radius: number}} = {}

-- World-distance range [Left, Right] of the scene exclusion zone (nil when inactive)
local SceneZone: {Left: number, Right: number}? = nil
-- Lane model names that are replaced by a scene one-shot and should be hidden in the zone
local SceneReplacedLanes: {[string]: boolean} = {}
local HiddenDecorations: {[BasePart]: number} = {}

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
		ModelName = Config.ModelName,
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

--[[
	Computes the camera-relative offset of a tile at a given scroll distance.
]]
local function GetTileOffset(LaneData: Lane, Index: number, ScrollOffset: number): number
	local CycleLen = LaneData.CycleLength
	local TileWidth = LaneData.TileWidth
	local HalfSpan = (LaneData.CenterPool - 1) * TileWidth
	local RawPos = (Index - 1) * TileWidth - (ScrollOffset % CycleLen)
	local WrappedPos = RawPos % CycleLen
	return WrappedPos - HalfSpan
end

--[[
	Positions all tiles in a lane. If Zone is provided, tiles that would overlap
	the world-distance range [Zone.Left, Zone.Right] are pushed beyond the zone's
	right edge so that looping tiles seamlessly continue after a one-shot scene.
]]
local function UpdateLaneLooping(LaneData: Lane, ScrollOffset: number, Zone: {Left: number, Right: number}?)
	if not LaneData.Active then
		return
	end

	local CycleLen = LaneData.CycleLength
	local TileWidth = LaneData.TileWidth
	local TileHalf = TileWidth / 2
	local Direction = LaneData.Direction
	local Anchor = LaneData.AnchorCFrame
	local HalfSpan = (LaneData.CenterPool - 1) * TileWidth

	if not Zone then
		for Index, Tile in LaneData.Pool do
			local RawPos = (Index - 1) * TileWidth - (ScrollOffset % CycleLen)
			local WrappedPos = RawPos % CycleLen
			local FinalOffset = WrappedPos - HalfSpan
			Tile:PivotTo(CFrame.new(Direction * FinalOffset, 0, 0) * Anchor)
		end
		return
	end

	-- Zone-aware placement: compute normal offsets, then push any tile that
	-- overlaps the zone to stack beyond the zone's right edge.
	local ZoneRightLocal = Zone.Right - ScrollOffset
	local ZoneLeftLocal = Zone.Left - ScrollOffset

	-- First pass: compute normal offsets for all tiles
	local Offsets = table.create(LaneData.PoolSize)
	for Index = 1, LaneData.PoolSize do
		local RawPos = (Index - 1) * TileWidth - (ScrollOffset % CycleLen)
		local WrappedPos = RawPos % CycleLen
		Offsets[Index] = WrappedPos - HalfSpan
	end

	-- Second pass: push overlapping tiles beyond the zone right edge
	-- Sort pushed tiles so they stack neatly after the zone
	local NextPushOffset = ZoneRightLocal + TileHalf
	-- Collect indices of tiles that need pushing, sorted by their natural offset
	local PushIndices = {}
	for Index = 1, LaneData.PoolSize do
		local FinalOffset = Offsets[Index]
		local TileLeft = FinalOffset - TileHalf
		local TileRight = FinalOffset + TileHalf
		if TileRight > ZoneLeftLocal and TileLeft < ZoneRightLocal then
			table.insert(PushIndices, Index)
		end
	end
	-- Sort by natural offset so pushed tiles maintain order
	table.sort(PushIndices, function(A, B)
		return Offsets[A] < Offsets[B]
	end)
	for _, Index in PushIndices do
		Offsets[Index] = NextPushOffset
		NextPushOffset = NextPushOffset + TileWidth
	end

	for Index, Tile in LaneData.Pool do
		Tile:PivotTo(CFrame.new(Direction * Offsets[Index], 0, 0) * Anchor)
	end
end

--[[
	Finds the right (forward) edge of the most-forward tile in a lane at StopDistance.
	Returns the world distance of that edge.
]]
local function GetLaneForwardEdge(LaneData: Lane, AtDistance: number): number
	local TileHalf = LaneData.TileWidth / 2
	local BestOffset = -math.huge
	for Index = 1, LaneData.PoolSize do
		local Offset = GetTileOffset(LaneData, Index, AtDistance)
		if Offset > BestOffset then
			BestOffset = Offset
		end
	end
	return AtDistance + BestOffset + TileHalf
end

local function StripBaseplateDecorations(Tile: Model | BasePart)
	local RootY = Tile:GetPivot().Position.Y
	for _, Descendant in Tile:QueryDescendants("BasePart") do
		if Descendant.Position.Y > RootY + 1 and HiddenDecorations[Descendant] == nil then
			HiddenDecorations[Descendant] = Descendant.Transparency
			Descendant.Transparency = 1
		end
	end
end

local function RestoreAllDecorations()
	for Part, OriginalTransparency in HiddenDecorations do
		if Part and Part.Parent then
			Part.Transparency = OriginalTransparency
		end
	end
	table.clear(HiddenDecorations)
end

local function RestoreTileDecorations(Tile: Model | BasePart)
	for _, Descendant in Tile:QueryDescendants("BasePart") do
		local Cached = HiddenDecorations[Descendant]
		if Cached ~= nil then
			Descendant.Transparency = Cached
			HiddenDecorations[Descendant] = nil
		end
	end
end

--[[
	For each Baseplate tile, checks overlap with the scene zone.
	Tiles overlapping have their decorations hidden.
	Tiles that are well behind the player (scrolled past) get decorations restored.
	Tiles ahead that are outside the zone keep their current state.
]]
local function UpdateBaseplateExclusions(LaneData: Lane, ScrollOffset: number, Zone: {Left: number, Right: number})
	if not LaneData.Active then
		return
	end

	local TileHalf = LaneData.TileWidth / 2

	for Index, Tile in LaneData.Pool do
		local FinalOffset = GetTileOffset(LaneData, Index, ScrollOffset)
		local TileWorldLeft = ScrollOffset + FinalOffset - TileHalf
		local TileWorldRight = ScrollOffset + FinalOffset + TileHalf

		if TileWorldRight > Zone.Left and TileWorldLeft < Zone.Right then
			StripBaseplateDecorations(Tile)
		elseif TileWorldRight < ScrollOffset - LaneData.TileWidth then
			RestoreTileDecorations(Tile)
		end
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
			Tile:PivotTo(CFrame.new(Direction * FinalOffset, 0, 0) * Anchor)
		else
			Tile:PivotTo(CFrame.new(0, -1000, 0))
		end
	end

	if AllOffscreen then
		DestroyLane(LaneData)
	end
end

local function SpawnOneShotTile(ModelName: string, SpawnDistance: number, Direction: number, AnchorCFrame: CFrame, Rotation: CFrame?): OneShotTile
	local Template = GetTemplate(ModelName)
	local Clone = Template:Clone()
	Clone.Name = ModelName .. "_OneShot"
	Clone.Parent = workspace

	local Rot = Rotation or CFrame.identity
	local TileWidth = if Rotation then GetOneShotScrollWidth(Template) else GetBoundsX(Template)

	local Tile: OneShotTile = {
		Instance = Clone,
		AnchorCFrame = AnchorCFrame,
		Direction = Direction,
		SpawnDistance = SpawnDistance,
		TileWidth = TileWidth,
		Rotation = Rot,
	}
	table.insert(OneShotTiles, Tile)
	return Tile
end

local function UpdateOneShotTile(Tile: OneShotTile, CurrentDistance: number)
	local Offset = Tile.SpawnDistance - CurrentDistance
	Tile.Instance:PivotTo(CFrame.new(Tile.Direction * Offset, 0, 0) * Tile.AnchorCFrame * Tile.Rotation)
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
		RefAnchor,
		CFrame.Angles(0, math.rad(-90), 0)
	)
end)

--[[
	Maps a scene model name to the looping lane it replaces.
	e.g. "LeftStop" replaces "LeftMountains"
]]
local SceneModelToLane: {[string]: string} = {
	LeftStop = "LeftMountains",
}

WorldScrollNetwork.packets.SceneStop.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = "SceneStopping"

	local ActiveSet = {}
	for _, Name in _ActiveSceneryNames do
		ActiveSet[Name] = true
	end

	SceneZone = nil
	table.clear(SceneReplacedLanes)
	RestoreAllDecorations()

	-- Collect non-active scene models and find the lanes they replace
	local OneShotsToSpawn: {{ModelName: string, ReplacesLane: string?}} = {}
	for _, ModelName in Data.SceneModels do
		if not ActiveSet[ModelName] then
			local ReplacesLane = SceneModelToLane[ModelName]
			table.insert(OneShotsToSpawn, {ModelName = ModelName, ReplacesLane = ReplacesLane})
			if ReplacesLane then
				SceneReplacedLanes[ReplacesLane] = true
			end
		end
	end

	-- For each one-shot, snap its position to the forward edge of the lane it replaces
	-- using the current scroll distance so it appears right at the first available slot
	local ZoneLeft = math.huge
	local ZoneRight = -math.huge

	for _, Info in OneShotsToSpawn do
		local Template = GetTemplate(Info.ModelName)
		local OneShotWidth = GetBoundsX(Template)
		local OneShotHalf = OneShotWidth / 2

		local SpawnDist: number

		if Info.ReplacesLane then
			-- Find the lane this model replaces and snap to its forward tile edge
			local TargetLane: Lane? = nil
			for _, LaneData in SceneryLanes do
				if LaneData.ModelName == Info.ReplacesLane and LaneData.Active then
					TargetLane = LaneData
					break
				end
			end

			if TargetLane then
				local SnapEdge = ScrollCompute.SnapToTileEdge(Data.ScrollBaseDistance, TargetLane.TileWidth, TargetLane.CenterPool)
				SpawnDist = SnapEdge + OneShotHalf
			else
				SpawnDist = Data.StopDistance
			end
		else
			SpawnDist = Data.StopDistance
		end

		SpawnOneShotTile(Info.ModelName, SpawnDist, 1, Template:GetPivot())

		-- Expand the exclusion zone to cover this one-shot
		local Left = SpawnDist - OneShotHalf
		local Right = SpawnDist + OneShotHalf
		if Left < ZoneLeft then ZoneLeft = Left end
		if Right > ZoneRight then ZoneRight = Right end
	end

	if ZoneLeft < ZoneRight then
		SceneZone = {Left = ZoneLeft, Right = ZoneRight}
	end
end)

WorldScrollNetwork.packets.SceneTunnelStop.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = "SceneStopping"

	local ActiveSet = {}
	for _, Name in _ActiveSceneryNames do
		ActiveSet[Name] = true
	end

	SceneZone = nil
	table.clear(SceneReplacedLanes)
	RestoreAllDecorations()

	-- Lanes drained by tunnels should loop normally until the drain point
	local TunnelDrainSet: {[string]: boolean} = {}
	for _, LaneName in Data.DrainLanes do
		TunnelDrainSet[LaneName] = true
	end

	local OneShotsToSpawn: {{ModelName: string, ReplacesLane: string?}} = {}
	for _, ModelName in Data.SceneModels do
		if not ActiveSet[ModelName] then
			local ReplacesLane = SceneModelToLane[ModelName]
			table.insert(OneShotsToSpawn, {ModelName = ModelName, ReplacesLane = ReplacesLane})
			if ReplacesLane and not TunnelDrainSet[ReplacesLane] then
				SceneReplacedLanes[ReplacesLane] = true
			end
		end
	end

	local ZoneLeft = math.huge
	local ZoneRight = -math.huge

	for _, Info in OneShotsToSpawn do
		local Template = GetTemplate(Info.ModelName)
		local OneShotWidth = GetBoundsX(Template)
		local OneShotHalf = OneShotWidth / 2
		local SpawnDist = Data.StopDistance

		SpawnOneShotTile(Info.ModelName, SpawnDist, 1, Template:GetPivot())

		local Left = SpawnDist - OneShotHalf
		local Right = SpawnDist + OneShotHalf
		if Left < ZoneLeft then ZoneLeft = Left end
		if Right > ZoneRight then ZoneRight = Right end
	end

	if ZoneLeft < ZoneRight then
		SceneZone = {Left = ZoneLeft, Right = ZoneRight}
	end

	local RefAnchor = if #ConstantLanes > 0
		then ConstantLanes[1].AnchorCFrame
		else CFrame.new()
	local RefDirection = if #ConstantLanes > 0
		then ConstantLanes[1].Direction
		else 1
	local TunnelRotation = CFrame.Angles(0, math.rad(-90), 0)

	for _, Center in Data.ApproachTunnelCenters do
		SpawnOneShotTile(Data.TunnelModel, Center, RefDirection, RefAnchor, TunnelRotation)
	end
	for _, Center in Data.DepartureTunnelCenters do
		SpawnOneShotTile(Data.TunnelModel, Center, RefDirection, RefAnchor, TunnelRotation)
	end

	SceneTunnelData = {
		DrainLanes = Data.DrainLanes,
		DrainAtDistance = Data.DrainAtDistance,
		DrainsApplied = false,
		RestoreLanes = Data.RestoreLanes,
		RestoreAtDistance = Data.RestoreAtDistance,
		RestoresApplied = false,
	}
end)

WorldScrollNetwork.packets.SceneResume.listen(function(Data)
	ServerScrollState = DecodeFlatScrollState(Data)
	CurrentPhase = "SceneResuming"

	local NewScenery = Data.TransitionScenery

	if SceneTunnelData then
		_ActiveSceneryNames = NewScenery
		return
	end

	local Changed = #NewScenery ~= #_ActiveSceneryNames
	if not Changed then
		for Index, Name in NewScenery do
			if _ActiveSceneryNames[Index] ~= Name then
				Changed = true
				break
			end
		end
	end

	if Changed then
		SpawnSceneryLanes(NewScenery)
	else
		_ActiveSceneryNames = NewScenery
	end
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

		local ActiveZone = if SceneZone and (CurrentPhase == "SceneStopping" or CurrentPhase == "SceneStopped" or CurrentPhase == "SceneResuming") then SceneZone else nil

		for _, LaneData in ConstantLanes do
			UpdateLaneLooping(LaneData, Distance)
		end

		if ActiveZone then
			for _, LaneData in ConstantLanes do
				if LaneData.ModelName == "Baseplate" then
					UpdateBaseplateExclusions(LaneData, Distance, ActiveZone)
				end
			end
		end

		if CurrentPhase == "Looping" then
			for _, LaneData in SceneryLanes do
				UpdateLaneLooping(LaneData, Distance)
			end

		elseif CurrentPhase == "SceneResuming" then
			for _, LaneData in SceneryLanes do
				local Zone = if ActiveZone and SceneReplacedLanes[LaneData.ModelName] then ActiveZone else nil
				UpdateLaneLooping(LaneData, Distance, Zone)
			end

			if SceneTunnelData and not SceneTunnelData.RestoresApplied and Distance >= SceneTunnelData.RestoreAtDistance then
				for _, LaneName in SceneTunnelData.RestoreLanes do
					local Lane = CreateLaneFromTemplate({ ModelName = LaneName, Direction = 1 })
					table.insert(SceneryLanes, Lane)
				end
				SceneTunnelData.RestoresApplied = true
			end

			if SceneZone and Distance > SceneZone.Right + SceneZone.Right - SceneZone.Left then
				RestoreAllDecorations()
				SceneZone = nil
				table.clear(SceneReplacedLanes)
			end

			local TransitionActive = Trans and (ServerNow - Trans.StartTime) < Trans.Duration
			if not TransitionActive and SceneZone == nil and (SceneTunnelData == nil or SceneTunnelData.RestoresApplied) then
				SceneTunnelData = nil
				CurrentPhase = "Looping"
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
				local Zone = if ActiveZone and SceneReplacedLanes[LaneData.ModelName] then ActiveZone else nil
				UpdateLaneLooping(LaneData, Distance, Zone)
			end

			if SceneTunnelData and not SceneTunnelData.DrainsApplied and Distance >= SceneTunnelData.DrainAtDistance then
				for _, LaneName in SceneTunnelData.DrainLanes do
					for _, LaneData in SceneryLanes do
						if LaneData.ModelName == LaneName and LaneData.Active then
							DestroyLane(LaneData)
						end
					end
				end
				SceneTunnelData.DrainsApplied = true
			end

			if CurrentSpeed <= 0.01 then
				CurrentPhase = "SceneStopped"
			end

		elseif CurrentPhase == "SceneStopped" then
			for _, LaneData in SceneryLanes do
				local Zone = if ActiveZone and SceneReplacedLanes[LaneData.ModelName] then ActiveZone else nil
				UpdateLaneLooping(LaneData, Distance, Zone)
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
