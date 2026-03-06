local FootstepNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.FootstepNetwork)

local FootstepService = {}

do
	FootstepNetwork.packets.FootstepToServer.listen(function(MaterialIndex: number, SenderPlayer: Player)
		FootstepNetwork.packets.FootstepToClient.sendToAllExcept({
			Player = SenderPlayer,
			Material = MaterialIndex,
		}, SenderPlayer)
	end)
end

return FootstepService
