local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local CoalNetwork = ByteNet.defineNamespace("Coal", function()
	return {
		packets = {
			CoalState = ByteNet.definePacket({
				value = ByteNet.struct({
					Current = ByteNet.uint8,
					Required = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),

			CoalCollected = ByteNet.definePacket({
				value = ByteNet.struct({
					CoalName = ByteNet.string,
					CollectorUserId = ByteNet.float64,
					Current = ByteNet.uint8,
					Required = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),

			CoalActive = ByteNet.definePacket({
				value = ByteNet.struct({
					Active = ByteNet.bool,
					Required = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),

			CoalFilled = ByteNet.definePacket({
				value = ByteNet.struct({
					BoardingTime = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),

			CoalGrabbed = ByteNet.definePacket({
				value = ByteNet.struct({
					CoalName = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),

			CoalReleased = ByteNet.definePacket({
				value = ByteNet.struct({
					CoalName = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),

			RequestRelease = ByteNet.definePacket({
				value = ByteNet.nothing,
				reliabilityType = "reliable",
			}),
		},
		queries = {
			RequestCoalState = ByteNet.defineQuery({
				request = ByteNet.nothing,
				response = ByteNet.struct({
					Active = ByteNet.bool,
					Current = ByteNet.uint8,
					Required = ByteNet.uint8,
				}),
			}),
		},
	}
end)

return CoalNetwork
