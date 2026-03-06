local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)

local RoleService = {}

--[[
    assigns roles (1 Murderer, 1 Detective, rest Innocent) to a player list
]]
function RoleService.AssignRoles(PlayerList: { Player }): { [Player]: string }
	local RoleMap: { [Player]: string } = {}
	local Shuffled = table.clone(PlayerList)

	for I = #Shuffled, 2, -1 do
		local J = math.random(1, I)
		Shuffled[I], Shuffled[J] = Shuffled[J], Shuffled[I]
	end

	for Index, PlayerInstance in Shuffled do
		local Role: string
		if Index == 1 then
			Role = "Murderer"
		elseif Index == 2 then
			Role = "Detective"
		else
			Role = "Innocent"
		end

		RoleMap[PlayerInstance] = Role
		PlayerInstance:SetAttribute("Role", Role)
	end

	return RoleMap
end

--[[
    sends each player their own role, not other players' roles
]]
function RoleService.BroadcastRoles(RoleMap: { [Player]: string })
	for PlayerInstance, Role in RoleMap do
		RoundNetwork.packets.RoleAssignment.sendTo({
			Role = Role,
		}, PlayerInstance)
	end
end

--[[
    clears role attributes from all given players
]]
function RoleService.ClearRoles(PlayerList: { Player })
	for _, PlayerInstance in PlayerList do
		PlayerInstance:SetAttribute("Role", nil)
	end
end

--[[
    returns a player's current role from their attribute
]]
function RoleService.GetRole(PlayerInstance: Player): string?
	return PlayerInstance:GetAttribute("Role") :: string?
end

return RoleService
