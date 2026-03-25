local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)

local GunPickupController = {}

local Player = Players.LocalPlayer
local PICKUP_RADIUS = 6
local CHECK_INTERVAL = 0.1
local LastCheckTime = 0

RunService.PreRender:Connect(function(DeltaTime: number)
	LastCheckTime += DeltaTime
	if LastCheckTime < CHECK_INTERVAL then
		return
	end
	LastCheckTime = 0

	local Character = Player.Character
	if not Character then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local Pickup = workspace:FindFirstChild("GunPickup")
	if not Pickup then
		return
	end

	local Handle = Pickup:FindFirstChild("Handle")
	if not Handle then
		return
	end

	local Distance = (Root.Position - Handle.Position).Magnitude
	if Distance <= PICKUP_RADIUS then
		RoundNetwork.packets.RequestGunPickup.send({})
	end
end)

return GunPickupController
