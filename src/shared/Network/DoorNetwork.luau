local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local DoorNetwork = ByteNet.defineNamespace("Doors", function()
	return {
		packets = {
			DoorState = ByteNet.definePacket({
				value = ByteNet.struct({
					Door = ByteNet.inst,
					IsOpen = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
	}
end)

return DoorNetwork
