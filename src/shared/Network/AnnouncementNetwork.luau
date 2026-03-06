local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local AnnouncementNetwork = ByteNet.defineNamespace("Announcements", function()
	return {
		packets = {
			Show = ByteNet.definePacket({
				value = ByteNet.struct({
					Title = ByteNet.string,
					Subtitle = ByteNet.optional(ByteNet.string),
					Duration = ByteNet.optional(ByteNet.float32),
					IsWarning = ByteNet.optional(ByteNet.bool),
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
	}
end)

return AnnouncementNetwork
