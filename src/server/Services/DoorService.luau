local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local DoorNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.DoorNetwork)

local DoorConst = Constants.Door
local DOOR_TAGS = { "CarDoor", "SideDoor", "CabinDoor" }

local DoorService = {}

local OpenDoors: { [Model]: boolean } = {}

local function GetAllDoors(): { Model }
	local Doors = {}
	for _, Tag in DOOR_TAGS do
		for _, Door in CollectionService:GetTagged(Tag) do
			if Door:IsA("Model") then
				table.insert(Doors, Door)
			end
		end
	end
	return Doors
end

local function IsAnyPlayerNear(Door: Model): boolean
	local Center = Door:GetBoundingBox().Position
	for _, TargetPlayer in Players:GetPlayers() do
		local Character = TargetPlayer.Character
		if not Character then continue end
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Root then continue end
		if (Root.Position - Center).Magnitude <= DoorConst.PROXIMITY_DISTANCE then
			return true
		end
	end
	return false
end

-- Send current door states to a newly joined player
local function SyncDoorsToPlayer(TargetPlayer: Player)
	for Door, IsOpen in OpenDoors do
		if IsOpen and Door.Parent then
			DoorNetwork.packets.DoorState.sendTo({
				Door = Door,
				IsOpen = true,
			}, TargetPlayer)
		end
	end
end

Players.PlayerAdded:Connect(function(TargetPlayer: Player)
	-- Small delay so the client has time to set up listeners
	task.delay(2, SyncDoorsToPlayer, TargetPlayer)
end)

-- Main proximity check loop
task.spawn(function()
	while true do
		task.wait(DoorConst.CHECK_INTERVAL)

		local Doors = GetAllDoors()
		for _, Door in Doors do
			local ShouldBeOpen = IsAnyPlayerNear(Door)
			local CurrentlyOpen = OpenDoors[Door] or false

			if ShouldBeOpen ~= CurrentlyOpen then
				OpenDoors[Door] = ShouldBeOpen
				DoorNetwork.packets.DoorState.sendToAll({
					Door = Door,
					IsOpen = ShouldBeOpen,
				})
			end
		end
	end
end)

return DoorService
