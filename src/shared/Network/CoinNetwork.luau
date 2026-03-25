local ByteNet = require(game:GetService("ReplicatedStorage").Packages["bytenet-max"])

local CoinNetwork = ByteNet.defineNamespace("Coins", function()
	return {
		packets = {
			SpawnCoins = ByteNet.definePacket({
				value = ByteNet.struct({
					Coins = ByteNet.array(ByteNet.struct({
						Id = ByteNet.uint16,
						X = ByteNet.float32,
						Y = ByteNet.float32,
						Z = ByteNet.float32,
					})),
				}),
				reliabilityType = "reliable",
			}),

			CollectCoin = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),

			DespawnAll = ByteNet.definePacket({
				value = ByteNet.nothing,
				reliabilityType = "reliable",
			}),

			SpawnCoin = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.uint16,
					X = ByteNet.float32,
					Y = ByteNet.float32,
					Z = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),

			RequestCollect = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {
			RequestCoinState = ByteNet.defineQuery({
				request = ByteNet.nothing,
				response = ByteNet.struct({
					Active = ByteNet.bool,
					Coins = ByteNet.array(ByteNet.struct({
						Id = ByteNet.uint16,
						X = ByteNet.float32,
						Y = ByteNet.float32,
						Z = ByteNet.float32,
					})),
				}),
			}),
		},
	}
end)

return CoinNetwork
