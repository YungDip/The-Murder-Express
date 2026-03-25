local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)

local ToolService = {}

local KnifeTemplate: Tool = nil :: any
local GunTemplate: Tool = nil :: any
local GunPickupModel: Model? = nil
local GunPickupValidate: ((Player) -> boolean)? = nil
local GunPickupCallback: ((Player) -> ())? = nil
local GunPickupActive = false

local PICKUP_RADIUS = 8
local RAYCAST_DOWN_DISTANCE = 50

local function RemoveToolsFromPlayer(PlayerInstance: Player)
	local Character = PlayerInstance.Character
	if Character then
		for _, Child in Character:GetChildren() do
			if Child:IsA("Tool") and (Child.Name == "Knife" or Child.Name == "Gun") then
				Child:Destroy()
			end
		end
	end

	local Backpack = PlayerInstance:FindFirstChild("Backpack")
	if Backpack then
		for _, Child in Backpack:GetChildren() do
			if Child:IsA("Tool") and (Child.Name == "Knife" or Child.Name == "Gun") then
				Child:Destroy()
			end
		end
	end
end

function ToolService.GiveTools(RoleMap: { [Player]: string })
	for PlayerInstance, Role in RoleMap do
		if Role == "Murderer" and KnifeTemplate then
			local Knife = KnifeTemplate:Clone()
			Knife.Parent = PlayerInstance:FindFirstChild("Backpack")
		elseif Role == "Detective" and GunTemplate then
			local Gun = GunTemplate:Clone()
			Gun.Parent = PlayerInstance:FindFirstChild("Backpack")
		end
	end
end

function ToolService.CleanupTools(Participants: { Player })
	for _, PlayerInstance in Participants do
		RemoveToolsFromPlayer(PlayerInstance)
	end
	ToolService.CleanupGunPickup()
end

function ToolService.CleanupGunPickup()
	GunPickupActive = false
	GunPickupValidate = nil
	GunPickupCallback = nil
	if GunPickupModel then
		GunPickupModel:Destroy()
		GunPickupModel = nil
	end
end

--[[
	spawns a gun mesh at the given CFrame for an innocent to pick up, raycasted to the floor
]]
function ToolService.SpawnGunPickup(SpawnCFrame: CFrame, ValidatePlayer: (Player) -> boolean, OnPickedUp: (Player) -> ())
	ToolService.CleanupGunPickup()

	if not GunTemplate then
		return
	end

	local Handle = GunTemplate:FindFirstChild("Handle")
	if not Handle then
		return
	end

	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Exclude all player characters and PropSpawn parts from the raycast
	local FilterList = {}
	for _, PlayerInstance in game:GetService("Players"):GetPlayers() do
		if PlayerInstance.Character then
			table.insert(FilterList, PlayerInstance.Character)
		end
	end
	local TrainModel = workspace:FindFirstChild("Train")
	if TrainModel then
		for _, Car in TrainModel:GetChildren() do
			local PropSpawn = Car:FindFirstChild("PropSpawn")
			if PropSpawn then
				table.insert(FilterList, PropSpawn)
			end
		end
	end
	RayParams.FilterDescendantsInstances = FilterList

	local RayResult = workspace:Raycast(SpawnCFrame.Position, Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0), RayParams)
	local FloorPosition: Vector3
	if RayResult then
		FloorPosition = RayResult.Position + Vector3.new(0, 1, 0)
	else
		FloorPosition = SpawnCFrame.Position + Vector3.new(0, 1, 0)
	end

	local Pickup = Instance.new("Model")
	Pickup.Name = "GunPickup"

	local MeshClone = Handle:Clone()
	MeshClone.Name = "Handle"
	MeshClone.Anchored = true
	MeshClone.CanCollide = false
	MeshClone.CFrame = CFrame.new(FloorPosition) * CFrame.Angles(math.rad(90), 0, 0)
	MeshClone.Parent = Pickup

	local Highlight = Instance.new("Highlight")
	Highlight.FillColor = Color3.fromRGB(80, 140, 220)
	Highlight.FillTransparency = 0.5
	Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	Highlight.OutlineTransparency = 0
	Highlight.Parent = Pickup

	Pickup.PrimaryPart = MeshClone
	Pickup.Parent = workspace
	GunPickupModel = Pickup
	GunPickupValidate = ValidatePlayer
	GunPickupCallback = OnPickedUp
	GunPickupActive = true
end

do
	local ToolsFolder = ServerStorage:FindFirstChild("Tools")
	if ToolsFolder then
		KnifeTemplate = ToolsFolder:FindFirstChild("Knife") :: Tool
		GunTemplate = ToolsFolder:FindFirstChild("Gun") :: Tool
	end

	if not KnifeTemplate then
		warn("[ToolService] Knife tool not found in ServerStorage.Tools")
	end
	if not GunTemplate then
		warn("[ToolService] Gun tool not found in ServerStorage.Tools")
	end
end

RoundNetwork.packets.RequestGunPickup.listen(function(_, PlayerInstance: Player)
	if not GunPickupActive or not GunPickupModel or not GunPickupValidate or not GunPickupCallback then
		return
	end

	local Character = PlayerInstance.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end

	local Handle = GunPickupModel:FindFirstChild("Handle")
	if not Handle then
		return
	end

	local Distance = (Root.Position - Handle.Position).Magnitude
	if Distance > PICKUP_RADIUS then
		return
	end

	if not GunPickupValidate(PlayerInstance) then
		return
	end

	local Callback = GunPickupCallback
	ToolService.CleanupGunPickup()

	local Gun = GunTemplate:Clone()
	Gun.Parent = PlayerInstance:FindFirstChild("Backpack")

	Callback(PlayerInstance)
end)

return ToolService
