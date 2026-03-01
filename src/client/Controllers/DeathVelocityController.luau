local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneCheck = require(ReplicatedStorage.Shared.Util.ZoneCheck)
local DeathVelocityNetwork = require(ReplicatedStorage.Shared.Network.DeathVelocityNetwork)

local Player = Players.LocalPlayer

local DeathVelocityController = {}

local Applied = false

local function ApplyDeathVelocity()
	if Applied then return end
	Applied = true

	local Zone = ZoneCheck.GetState()
	if Zone == "Inside" or Zone == "Medium" then return end

	DeathVelocityNetwork.packets.Apply.send({
		IsRoof = Zone == "Roof",
	})
end

-- Boot

local function OnCharacterAdded(Character: Model)
	Applied = false
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	Humanoid.Died:Connect(ApplyDeathVelocity)
end

if Player.Character then
	task.spawn(OnCharacterAdded, Player.Character)
end

Player.CharacterAdded:Connect(OnCharacterAdded)

return DeathVelocityController
