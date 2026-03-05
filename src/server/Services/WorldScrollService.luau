local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)
local ScrollCompute = require(ReplicatedStorage.Shared.Util.ScrollCompute)
local WorldScrollNetwork = require(ReplicatedStorage.Shared.Network.WorldScrollNetwork)

local WorldScrollService = {}

-- Internal state

local ScrollState: Types.ScrollState = {
	BaseDistance = 0,
	BaseTime = 0,
	Speed = 0,
	Transition = nil,
}

local ActiveScenery: {string} = {}
local CurrentPhase: Types.SceneryPhase = "Looping"
local CurrentSceneModel: string = ""

-- Helpers

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
	-- SpeedUpdate uses non-prefixed field names
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

-- Finalise a speed transition once its duration has elapsed
local function FinaliseTransition()
	local Transition = ScrollState.Transition
	if not Transition then
		return
	end

	local EndTime = Transition.StartTime + Transition.Duration
	ScrollState = ScrollCompute.Snapshot(ScrollState, EndTime)
end

-- Public API

-- Change the scroll speed with a smooth transition over TransitionTime seconds
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

-- Tunnel transition: drain old scenery, show tunnel, then start new scenery
function WorldScrollService.TunnelTransition(NewScenery: {string})
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local CurrentDistance = ScrollState.BaseDistance
	local Speed = ScrollState.Speed

	-- Server estimate: buffer + tunnel width + margin; client handles exact timing
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

	-- After the estimated transition time, update server state
	if Speed > 0 then
		local TimeToNewScenery = EstimatedTransitionDistance / Speed
		print("[WorldScrollService] EstTimeToNewScenery=" .. string.format("%.1f", TimeToNewScenery) .. "s")
		task.delay(TimeToNewScenery, function()
			ActiveScenery = NewScenery
			CurrentPhase = "Looping"
			print("[WorldScrollService] Tunnel transition complete, phase=Looping")
		end)
	else
		ActiveScenery = NewScenery
		CurrentPhase = "Looping"
	end
end

-- Stop at a scene: decelerate to 0, place a scene model, add tail scenery
function WorldScrollService.StopAtNewScene(SceneComponents: {string}, TailRepeats: number?)
	local CurrentTime = Now()
	ScrollState = ScrollCompute.Snapshot(ScrollState, CurrentTime)

	local CurrentSpeed = ScrollState.Speed
	local Deceleration = Constants.WorldScroll.STOP_DECELERATION

	local StopDistance = ScrollState.BaseDistance + ScrollCompute.DecelerationDistance(CurrentSpeed, 0, Deceleration)
	local TransitionTime = ScrollCompute.DecelerationTime(CurrentSpeed, 0, Deceleration)

	ScrollState.Transition = {
		StartSpeed = CurrentSpeed,
		EndSpeed = 0,
		StartTime = CurrentTime,
		Duration = TransitionTime,
	}

	CurrentPhase = "SceneStopping"
	CurrentSceneModel = if #SceneComponents > 0 then SceneComponents[1] else ""

	-- Build tail scenery: repeat the full scenery set N times beyond the scene for a visual buffer
	local Repeats = TailRepeats or Constants.WorldScroll.SCENE_TAIL_REPEATS
	local TailScenery: {string} = {}
	for _ = 1, Repeats do
		for _, Lane in Constants.WorldScroll.CONSTANT_LANES do
			table.insert(TailScenery, Lane.ModelName)
		end
		for _, Name in ActiveScenery do
			table.insert(TailScenery, Name)
		end
	end

	local Flat = EncodeFlatScrollState(ScrollState)
	WorldScrollNetwork.packets.SceneStop.sendToAll({
		SceneModel = CurrentSceneModel,
		StopDistance = StopDistance,
		ScrollBaseDistance = Flat.ScrollBaseDistance,
		ScrollBaseTime = Flat.ScrollBaseTime,
		ScrollSpeed = Flat.ScrollSpeed,
		ScrollHasTransition = Flat.ScrollHasTransition,
		ScrollTransitionStartSpeed = Flat.ScrollTransitionStartSpeed,
		ScrollTransitionEndSpeed = Flat.ScrollTransitionEndSpeed,
		ScrollTransitionStartTime = Flat.ScrollTransitionStartTime,
		ScrollTransitionDuration = Flat.ScrollTransitionDuration,
		TailScenery = TailScenery,
	})

	task.delay(TransitionTime, function()
		FinaliseTransition()
		CurrentPhase = "SceneStopped"
	end)
end

-- Resume from a stopped scene back into scrolling scenery
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

-- Player join sync: client requests state via query
WorldScrollNetwork.queries.RequestState.listen(function()
	local Flat = EncodeFlatScrollState(ScrollState)
	Flat.ActiveScenery = ActiveScenery
	Flat.Phase = CurrentPhase
	Flat.SceneModel = CurrentSceneModel
	return Flat
end)

-- Boot
do
	local CurrentTime = Now()
	ScrollState = {
		BaseDistance = 0,
		BaseTime = CurrentTime,
		Speed = Constants.WorldScroll.DEFAULT_SPEED,
		Transition = nil,
	}

	-- Start the initial scenery via tunnel transition (loads LeftMountains + RightMountains)
	ActiveScenery = { "LeftMountains", "RightMountains" }
	CurrentPhase = "Looping"
end

return WorldScrollService
