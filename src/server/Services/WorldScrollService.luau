local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)
local ScrollCompute = require(ReplicatedStorage.Shared.Util.ScrollCompute)
local WorldScrollNetwork = require(ReplicatedStorage.Shared.Network.WorldScrollNetwork)

local WorldScrollService = {}

local ScrollState: Types.ScrollState = {
	BaseDistance = 0,
	BaseTime = 0,
	Speed = 0,
	Transition = nil,
}

local ActiveScenery: {string} = {}
local CurrentPhase: Types.SceneryPhase = "Looping"
local CurrentSceneModels: {string} = {}
local CurrentStopDistance: number = 0

local function Now(): number
	return workspace:GetServerTimeNow()
end

local function EncodeFlatScrollState(State: Types.ScrollState): {[string]: any}
	local Transition = State.Transition
	return {
		ScrollBaseDistance = State.BaseDistance,
		ScrollBaseTime = State.BaseTime,
		ScrollSpeed = State.Speed,
		ScrollHasTransition = Transition ~= nil,
		ScrollTransitionStartSpeed = if Transition then Transition.StartSpeed else 0,
		ScrollTransitionEndSpeed = if Transition then Transition.EndSpeed else 0,
		ScrollTransitionStartTime = if Transition then Transition.StartTime else 0,
		ScrollTransitionDuration = if Transition then Transition.Duration else 0,
	}
end

local function BroadcastSpeedUpdate()
	local Encoded = EncodeFlatScrollState(ScrollState)
	WorldScrollNetwork.packets.SpeedUpdate.sendToAll({
		BaseDistance = Encoded.ScrollBaseDistance,
		BaseTime = Encoded.ScrollBaseTime,
		Speed = Encoded.ScrollSpeed,
		HasTransition = Encoded.ScrollHasTransition,
		TransitionStartSpeed = Encoded.ScrollTransitionStartSpeed,
		TransitionEndSpeed = Encoded.ScrollTransitionEndSpeed,
		TransitionStartTime = Encoded.ScrollTransitionStartTime,
		TransitionDuration = Encoded.ScrollTransitionDuration,
	})
end

--[[
    finalises a speed transition once its duration has elapsed
]]
local function FinaliseTransition()
	local Transition = ScrollState.Transition
	if not Transition then
		return
	end

	local EndTime = Transition.StartTime + Transition.Duration
	ScrollState = ScrollCompute.Snapshot(ScrollState, EndTime)
end

--[[
    changes the scroll speed with a smooth transition over TransitionTime seconds
]]
function WorldScrollService.ChangeSpeed(Speed: number, TransitionTime: number)
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	if TransitionTime <= 0 then
		ScrollState.Speed = Speed
	else
		ScrollState.Transition = {
			StartSpeed = ScrollState.Speed,
			EndSpeed = Speed,
			StartTime = CurrentTime,
			Duration = TransitionTime,
		}
	end

	BroadcastSpeedUpdate()

	if TransitionTime > 0 then
		task.delay(TransitionTime, function()
			FinaliseTransition()
		end)
	end
end

--[[
    drains old scenery through a tunnel, then starts new looping scenery
]]
function WorldScrollService.TunnelTransition(NewScenery: {string})
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local CurrentDistance = ScrollState.BaseDistance
	local Speed = ScrollState.Speed

	local EstimatedTransitionDistance = Constants.WorldScroll.TUNNEL_BUFFER + 1000

	CurrentPhase = "TunnelDraining"

	print("[WorldScrollService] TunnelTransition: Distance=" .. string.format("%.1f", CurrentDistance) .. " Speed=" .. string.format("%.1f", Speed))
	WorldScrollNetwork.packets.TunnelTransition.sendToAll({
		NewScenery = NewScenery,
		TunnelModel = Constants.WorldScroll.TUNNEL_MODEL,
		DrainAtDistance = CurrentDistance,
		TunnelAtDistance = CurrentDistance,
		NewSceneryAtDistance = CurrentDistance + EstimatedTransitionDistance,
	})

	if Speed > 0 then
		local TimeToNewScenery = EstimatedTransitionDistance / Speed
		print("[WorldScrollService] EstTimeToNewScenery=" .. string.format("%.1f", TimeToNewScenery) .. "s")		task.delay(TimeToNewScenery, function()
			ActiveScenery = NewScenery
			CurrentPhase = "Looping"
			print("[WorldScrollService] Tunnel transition complete, phase=Looping")
		end)
	else
		ActiveScenery = NewScenery
		CurrentPhase = "Looping"
	end
end

local SceneModelToLane: {[string]: string} = {
	LeftStop = "LeftMountains",
}

local function GetBoundsX(Object: Instance): number
	if Object:IsA("Model") then
		local _, Size = Object:GetBoundingBox()
		return Size.X
	end
	return (Object :: BasePart).Size.X
end

local function GetBoundsZ(Object: Instance): number
	if Object:IsA("Model") then
		local _, Size = Object:GetBoundingBox()
		return Size.Z
	end
	return (Object :: BasePart).Size.Z
end

--[[
    decelerates to a stop at a scene. The scene one-shot is placed at the
    forward edge of the lane it replaces. The train cruises at full speed
    until an 8-second brake brings it to rest at the scene centre.
]]
function WorldScrollService.StopAtNewScene(SceneComponents: {string}): number
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local CurrentSpeed = ScrollState.Speed
	local CurrentDistance = ScrollState.BaseDistance
	local ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder

	-- Compute where to place each scene one-shot and derive the stop distance
	local MaxSpawnDist = CurrentDistance
	for _, ModelName in SceneComponents do
		local ReplacesLane = SceneModelToLane[ModelName]
		if ReplacesLane then
			local LaneTemplate = ZoneModels:FindFirstChild(ReplacesLane)
			local SceneTemplate = ZoneModels:FindFirstChild(ModelName)
			if LaneTemplate and SceneTemplate then
				local LaneTileWidth = GetBoundsX(LaneTemplate)
				local PoolSize = Constants.WorldScroll.TILE_POOL_SIZE
				local CenterPool = math.floor(PoolSize / 2) + 1
				local SnapEdge = ScrollCompute.SnapToTileEdge(CurrentDistance, LaneTileWidth, CenterPool)

				local SceneWidth = GetBoundsX(SceneTemplate)
				local SceneSpawnDist = SnapEdge + SceneWidth / 2
				if SceneSpawnDist > MaxSpawnDist then
					MaxSpawnDist = SceneSpawnDist
				end
			end
		end
	end

	local StopDistance = MaxSpawnDist
	CurrentStopDistance = StopDistance

	-- Compute braking: cruise at full speed, then decelerate over SCENE_BRAKE_DURATION
	local BrakeDuration = Constants.WorldScroll.SCENE_BRAKE_DURATION
	local BrakeDist = CurrentSpeed * BrakeDuration / 2
	local BrakeStartDist = StopDistance - BrakeDist
	local CruiseDist = BrakeStartDist - CurrentDistance
	local CruiseTime: number

	if CruiseDist < 0 then
		-- Scene is too close for a full 8s brake — shorten the brake to fit
		local AvailDist = math.max(0, StopDistance - CurrentDistance)
		BrakeDuration = if CurrentSpeed > 0 then 2 * AvailDist / CurrentSpeed else 0
		CruiseTime = 0
	else
		CruiseTime = if CurrentSpeed > 0 then CruiseDist / CurrentSpeed else 0
	end

	local TotalTime = CruiseTime + BrakeDuration

	CurrentPhase = "SceneStopping"
	CurrentSceneModels = SceneComponents

	-- Send SceneStop at full speed (no transition yet)
	local Flat = EncodeFlatScrollState(ScrollState)
	WorldScrollNetwork.packets.SceneStop.sendToAll({
		SceneModels = CurrentSceneModels,
		StopDistance = StopDistance,
		ScrollBaseDistance = Flat.ScrollBaseDistance,
		ScrollBaseTime = Flat.ScrollBaseTime,
		ScrollSpeed = Flat.ScrollSpeed,
		ScrollHasTransition = Flat.ScrollHasTransition,
		ScrollTransitionStartSpeed = Flat.ScrollTransitionStartSpeed,
		ScrollTransitionEndSpeed = Flat.ScrollTransitionEndSpeed,
		ScrollTransitionStartTime = Flat.ScrollTransitionStartTime,
		ScrollTransitionDuration = Flat.ScrollTransitionDuration,
	})

	-- After cruising, begin the braking transition
	task.delay(CruiseTime, function()
		local BrakeTime = Now()
		ScrollState = ScrollCompute.Snapshot(ScrollState, BrakeTime)

		ScrollState.Transition = {
			StartSpeed = CurrentSpeed,
			EndSpeed = 0,
			StartTime = BrakeTime,
			Duration = BrakeDuration,
		}

		BroadcastSpeedUpdate()

		task.delay(BrakeDuration, function()
			FinaliseTransition()
			CurrentPhase = "SceneStopped"
		end)
	end)

	return TotalTime
end

--[[
    decelerates to a stop at a scene, using tunnels to hide the lane transitions.
    The approach tunnel covers LeftMountains disappearing before the scene.
    The departure tunnel covers LeftMountains reappearing after the scene.
]]
function WorldScrollService.StopAtNewSceneWithTunnels(SceneComponents: {string}, TunnelModelName: string, DrainLanes: {string}): number
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local CurrentSpeed = ScrollState.Speed
	local CurrentDistance = ScrollState.BaseDistance
	local ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder

	local TunnelTemplate = ZoneModels:FindFirstChild(TunnelModelName)
	local TunnelSegmentWidth = GetBoundsZ(TunnelTemplate)
	local SegmentCount = Constants.WorldScroll.SCENE_TUNNEL_SEGMENTS
	local TotalTunnelWidth = TunnelSegmentWidth * SegmentCount

	local MaxSpawnDist = CurrentDistance
	local MainSceneWidth = 0
	for _, ModelName in SceneComponents do
		local ReplacesLane = SceneModelToLane[ModelName]
		if ReplacesLane then
			local LaneTemplate = ZoneModels:FindFirstChild(ReplacesLane)
			local SceneTemplate = ZoneModels:FindFirstChild(ModelName)
			if LaneTemplate and SceneTemplate then
				local LaneTileWidth = GetBoundsX(LaneTemplate)
				local PoolSize = Constants.WorldScroll.TILE_POOL_SIZE
				local CenterPool = math.floor(PoolSize / 2) + 1
				local MinSnapBase = CurrentDistance + Constants.WorldScroll.TUNNEL_BUFFER + TotalTunnelWidth
				local SnapEdge = ScrollCompute.SnapToTileEdge(MinSnapBase, LaneTileWidth, CenterPool)

				local SceneWidth = GetBoundsX(SceneTemplate)
				local SceneSpawnDist = SnapEdge + SceneWidth / 2
				if SceneSpawnDist > MaxSpawnDist then
					MaxSpawnDist = SceneSpawnDist
					MainSceneWidth = SceneWidth
				end
			end
		end
	end

	local StopDistance = MaxSpawnDist
	CurrentStopDistance = StopDistance
	local SceneLeadingEdge = StopDistance - MainSceneWidth / 2
	local SceneTrailingEdge = StopDistance + MainSceneWidth / 2

	-- Build approach tunnel segment centers (right-to-left from scene leading edge)
	local ApproachTunnelCenters: {number} = {}
	for I = 1, SegmentCount do
		local Center = SceneLeadingEdge - (I - 0.5) * TunnelSegmentWidth
		table.insert(ApproachTunnelCenters, Center)
	end

	-- Build departure tunnel segment centers (left-to-right from scene trailing edge)
	local DepartureTunnelCenters: {number} = {}
	for I = 1, SegmentCount do
		local Center = SceneTrailingEdge + (I - 0.5) * TunnelSegmentWidth
		table.insert(DepartureTunnelCenters, Center)
	end

	local ApproachLeadingEdge = SceneLeadingEdge - TotalTunnelWidth
	local DrainAtDistance = ApproachLeadingEdge + TotalTunnelWidth / 2
	local RestoreAtDistance = SceneTrailingEdge + TotalTunnelWidth / 2

	-- Tiling range: halfway into approach tunnel → halfway into departure tunnel
	local TilingStart = SceneLeadingEdge - TotalTunnelWidth / 2
	local TilingEnd = SceneTrailingEdge + TotalTunnelWidth / 2

	local BrakeDuration = Constants.WorldScroll.SCENE_BRAKE_DURATION
	local BrakeDist = CurrentSpeed * BrakeDuration / 2
	local BrakeStartDist = StopDistance - BrakeDist
	local CruiseDist = BrakeStartDist - CurrentDistance
	local CruiseTime: number

	if CruiseDist < 0 then
		local AvailDist = math.max(0, StopDistance - CurrentDistance)
		BrakeDuration = if CurrentSpeed > 0 then 2 * AvailDist / CurrentSpeed else 0
		CruiseTime = 0
	else
		CruiseTime = if CurrentSpeed > 0 then CruiseDist / CurrentSpeed else 0
	end

	local TotalTime = CruiseTime + BrakeDuration

	CurrentPhase = "SceneStopping"
	CurrentSceneModels = SceneComponents

	local Flat = EncodeFlatScrollState(ScrollState)
	WorldScrollNetwork.packets.SceneTunnelStop.sendToAll({
		SceneModels = CurrentSceneModels,
		StopDistance = StopDistance,
		TunnelModel = TunnelModelName,
		ApproachTunnelCenters = ApproachTunnelCenters,
		DepartureTunnelCenters = DepartureTunnelCenters,
		DrainLanes = DrainLanes,
		DrainAtDistance = DrainAtDistance,
		RestoreLanes = DrainLanes,
		RestoreAtDistance = RestoreAtDistance,
		TilingStart = TilingStart,
		TilingEnd = TilingEnd,
		ScrollBaseDistance = Flat.ScrollBaseDistance,
		ScrollBaseTime = Flat.ScrollBaseTime,
		ScrollSpeed = Flat.ScrollSpeed,
		ScrollHasTransition = Flat.ScrollHasTransition,
		ScrollTransitionStartSpeed = Flat.ScrollTransitionStartSpeed,
		ScrollTransitionEndSpeed = Flat.ScrollTransitionEndSpeed,
		ScrollTransitionStartTime = Flat.ScrollTransitionStartTime,
		ScrollTransitionDuration = Flat.ScrollTransitionDuration,
	})

	task.delay(CruiseTime, function()
		local BrakeTime = Now()
		ScrollState = ScrollCompute.Snapshot(ScrollState, BrakeTime)

		ScrollState.Transition = {
			StartSpeed = CurrentSpeed,
			EndSpeed = 0,
			StartTime = BrakeTime,
			Duration = BrakeDuration,
		}

		BroadcastSpeedUpdate()

		task.delay(BrakeDuration, function()
			FinaliseTransition()
			CurrentPhase = "SceneStopped"
		end)
	end)

	return TotalTime
end

--[[
    accelerates from a stopped scene back into looping scrolling scenery
]]
function WorldScrollService.ResumeFromScene(TransitionScenery: {string}?, Speed: number?, TransitionTime: number?)
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local TargetSpeed = Speed or Constants.WorldScroll.DEFAULT_SPEED
	local AccelTime = TransitionTime or 5

	ScrollState.Transition = {
		StartSpeed = 0,
		EndSpeed = TargetSpeed,
		StartTime = CurrentTime,
		Duration = AccelTime,
	}

	local Scenery = TransitionScenery or ActiveScenery
	CurrentPhase = "SceneResuming"

	local Flat = EncodeFlatScrollState(ScrollState)
	WorldScrollNetwork.packets.SceneResume.sendToAll({
		ScrollBaseDistance = Flat.ScrollBaseDistance,
		ScrollBaseTime = Flat.ScrollBaseTime,
		ScrollSpeed = Flat.ScrollSpeed,
		ScrollHasTransition = Flat.ScrollHasTransition,
		ScrollTransitionStartSpeed = Flat.ScrollTransitionStartSpeed,
		ScrollTransitionEndSpeed = Flat.ScrollTransitionEndSpeed,
		ScrollTransitionStartTime = Flat.ScrollTransitionStartTime,
		ScrollTransitionDuration = Flat.ScrollTransitionDuration,
		TransitionScenery = Scenery,
	})

	task.delay(AccelTime, function()
		FinaliseTransition()
		ActiveScenery = Scenery
		CurrentPhase = "Looping"
	end)
end

WorldScrollNetwork.queries.RequestState.listen(function()
	local Flat = EncodeFlatScrollState(ScrollState)
	Flat.ActiveScenery = ActiveScenery
	Flat.Phase = CurrentPhase
	Flat.SceneModels = CurrentSceneModels
	return Flat
end)

--[[
    returns the world CFrame where a scene model template sits when the train is stopped
    at StopDistance. When stopped, CurrentDistance == StopDistance, so Offset == 0
    and the scene is placed at its template pivot.
]]
function WorldScrollService.GetSceneCFrame(ModelName: string): CFrame
	local ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder
	local Template = ZoneModels:FindFirstChild(ModelName)
	if not Template then
		return CFrame.new()
	end
	return Template:GetPivot()
end

function WorldScrollService.GetPhase(): Types.SceneryPhase
	return CurrentPhase
end

function WorldScrollService.GetStopDistance(): number
	return CurrentStopDistance
end

do
	local CurrentTime = Now()
	ScrollState = {
		BaseDistance = 0,
		BaseTime = CurrentTime,
		Speed = Constants.WorldScroll.DEFAULT_SPEED,
		Transition = nil,
	}

	ActiveScenery = { "LeftMountains", "RightMountains" }
	CurrentPhase = "Looping"
end

return WorldScrollService
