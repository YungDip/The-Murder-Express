local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local FootstepNetwork = ByteNet.defineNamespace("Footsteps", function()
	return {
		packets = {
			-- Client -> Server: player reports a footstep with material index
			FootstepToServer = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "unreliable",
			}),

			-- Server -> Client: broadcast a footstep from a specific player
			FootstepToClient = ByteNet.definePacket({
				value = ByteNet.struct({
					Player = ByteNet.inst,
					Material = ByteNet.uint8,
				}),
				reliabilityType = "unreliable",
			}),
		},
		queries = {},
	}
end)

return FootstepNetwork
