local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local DeathVelocityNetwork = ByteNet.defineNamespace("DeathVelocity", function()
	return {
		packets = {
			Apply = ByteNet.definePacket({
				value = ByteNet.struct({
					IsRoof = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
	}
end)

return DeathVelocityNetwork
