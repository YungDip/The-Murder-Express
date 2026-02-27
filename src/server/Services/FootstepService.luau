local FootstepNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.FootstepNetwork)

local FootstepService = {}

-- Listen for footstep packets from clients and broadcast to all other clients

do
	FootstepNetwork.packets.FootstepToServer.listen(function(MaterialIndex: number, SenderPlayer: Player)
		FootstepNetwork.packets.FootstepToClient.sendToAllExcept({
			Player = SenderPlayer,
			Material = MaterialIndex,
		}, SenderPlayer)
	end)
end

return FootstepService
