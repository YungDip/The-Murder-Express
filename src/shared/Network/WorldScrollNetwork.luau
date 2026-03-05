local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local WorldScrollNetwork = ByteNet.defineNamespace("WorldScroll", function()
	return {
		packets = {
			SyncState = ByteNet.definePacket({
				value = ByteNet.struct({
					ScrollBaseDistance = ByteNet.float64,
					ScrollBaseTime = ByteNet.float64,
					ScrollSpeed = ByteNet.float64,
					ScrollHasTransition = ByteNet.bool,
					ScrollTransitionStartSpeed = ByteNet.float64,
					ScrollTransitionEndSpeed = ByteNet.float64,
					ScrollTransitionStartTime = ByteNet.float64,
					ScrollTransitionDuration = ByteNet.float64,
					ActiveScenery = ByteNet.array(ByteNet.string),
					Phase = ByteNet.string,
					SceneModel = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),

			SpeedUpdate = ByteNet.definePacket({
				value = ByteNet.struct({
					BaseDistance = ByteNet.float64,
					BaseTime = ByteNet.float64,
					Speed = ByteNet.float64,
					HasTransition = ByteNet.bool,
					TransitionStartSpeed = ByteNet.float64,
					TransitionEndSpeed = ByteNet.float64,
					TransitionStartTime = ByteNet.float64,
					TransitionDuration = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),

			TunnelTransition = ByteNet.definePacket({
				value = ByteNet.struct({
					NewScenery = ByteNet.array(ByteNet.string),
					TunnelModel = ByteNet.string,
					DrainAtDistance = ByteNet.float64,
					TunnelAtDistance = ByteNet.float64,
					NewSceneryAtDistance = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),

			SceneStop = ByteNet.definePacket({
				value = ByteNet.struct({
					SceneModel = ByteNet.string,
					StopDistance = ByteNet.float64,
					ScrollBaseDistance = ByteNet.float64,
					ScrollBaseTime = ByteNet.float64,
					ScrollSpeed = ByteNet.float64,
					ScrollHasTransition = ByteNet.bool,
					ScrollTransitionStartSpeed = ByteNet.float64,
					ScrollTransitionEndSpeed = ByteNet.float64,
					ScrollTransitionStartTime = ByteNet.float64,
					ScrollTransitionDuration = ByteNet.float64,
					TailScenery = ByteNet.array(ByteNet.string),
				}),
				reliabilityType = "reliable",
			}),

			SceneResume = ByteNet.definePacket({
				value = ByteNet.struct({
					ScrollBaseDistance = ByteNet.float64,
					ScrollBaseTime = ByteNet.float64,
					ScrollSpeed = ByteNet.float64,
					ScrollHasTransition = ByteNet.bool,
					ScrollTransitionStartSpeed = ByteNet.float64,
					ScrollTransitionEndSpeed = ByteNet.float64,
					ScrollTransitionStartTime = ByteNet.float64,
					ScrollTransitionDuration = ByteNet.float64,
					TransitionScenery = ByteNet.array(ByteNet.string),
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {
			RequestState = ByteNet.defineQuery({
				request = ByteNet.nothing,
				response = ByteNet.struct({
					ScrollBaseDistance = ByteNet.float64,
					ScrollBaseTime = ByteNet.float64,
					ScrollSpeed = ByteNet.float64,
					ScrollHasTransition = ByteNet.bool,
					ScrollTransitionStartSpeed = ByteNet.float64,
					ScrollTransitionEndSpeed = ByteNet.float64,
					ScrollTransitionStartTime = ByteNet.float64,
					ScrollTransitionDuration = ByteNet.float64,
					ActiveScenery = ByteNet.array(ByteNet.string),
					Phase = ByteNet.string,
					SceneModel = ByteNet.string,
				}),
			}),
		},
	}
end)

return WorldScrollNetwork
