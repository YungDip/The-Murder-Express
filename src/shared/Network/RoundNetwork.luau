local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local RoundNetwork = ByteNet.defineNamespace("Round", function()
	return {
		packets = {
			PhaseChange = ByteNet.definePacket({
				value = ByteNet.struct({
					Phase = ByteNet.string,
					PhaseEndTime = ByteNet.float64,
					RoundEndTime = ByteNet.optional(ByteNet.float64),
				}),
				reliabilityType = "reliable",
			}),

			RoleAssignment = ByteNet.definePacket({
				value = ByteNet.struct({
					Role = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),

			PlayerEliminated = ByteNet.definePacket({
				value = ByteNet.struct({
					Name = ByteNet.string,
					Role = ByteNet.string,
					UserId = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),

			RoundResult = ByteNet.definePacket({
				value = ByteNet.struct({
					Result = ByteNet.string,
					Players = ByteNet.array(ByteNet.struct({
						Name = ByteNet.string,
						Role = ByteNet.string,
						Alive = ByteNet.bool,
						UserId = ByteNet.float64,
					})),
				}),
				reliabilityType = "reliable",
			}),

			ParticipantList = ByteNet.definePacket({
				value = ByteNet.struct({
					PlayerIds = ByteNet.array(ByteNet.float64),
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {
			RequestRoundState = ByteNet.defineQuery({
				request = ByteNet.nothing,
				response = ByteNet.struct({
					Phase = ByteNet.string,
					PhaseEndTime = ByteNet.float64,
					RoundEndTime = ByteNet.float64,
					Role = ByteNet.optional(ByteNet.string),
					ParticipantIds = ByteNet.array(ByteNet.float64),
					Eliminated = ByteNet.array(ByteNet.struct({
						Name = ByteNet.string,
						Role = ByteNet.string,
						UserId = ByteNet.float64,
					})),
					ResultData = ByteNet.optional(ByteNet.struct({
						Result = ByteNet.string,
						Players = ByteNet.array(ByteNet.struct({
							Name = ByteNet.string,
							Role = ByteNet.string,
							Alive = ByteNet.bool,
							UserId = ByteNet.float64,
						})),
					})),
				}),
			}),
		},
	}
end)

return RoundNetwork
