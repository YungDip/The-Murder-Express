local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoinNetwork = require(ReplicatedStorage.Shared.Network.CoinNetwork)
local DataService = require(script.Parent.DataService)

local CoinConst = Constants.Coin

local CoinService = {}

local ActiveCoins: { [number]: Vector3 } = {}
local CollectedCoins: { [number]: boolean } = {}
local AllSpots: { Vector3 } = {}
local StopSpots: { Vector3 } = {}
local NextId: number = 0
local IsActive: boolean = false

--[[
	finds all CoinPart instances in the train and returns their positions
]]
local function GetCoinSpots(): { Vector3 }
	local Train = workspace:FindFirstChild("Train")
	if not Train then
		return {}
	end

	local Spots = {}
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.FilterDescendantsInstances = {}

	for _, Descendant in Train:GetDescendants() do
		if Descendant:IsA("BasePart") and Descendant.Name == "CoinPart" then
			local Origin = Descendant.Position
			local Result = workspace:Raycast(Origin, Vector3.new(0, -CoinConst.RAYCAST_DOWN_DISTANCE, 0), RayParams)
			if Result then
				table.insert(Spots, Result.Position + Vector3.new(0, CoinConst.HEIGHT_OFFSET, 0))
			else
				table.insert(Spots, Origin)
			end
		end
	end

	return Spots
end

--[[
	selects a random subset of coin spots based on SPAWN_CHANCE
]]
local function SelectSpots(Spots: { Vector3 }): { { Id: number, Position: Vector3 } }
	local Selected = {}

	for _, Spot in Spots do
		if math.random() < CoinConst.SPAWN_CHANCE then
			NextId += 1
			table.insert(Selected, { Id = NextId, Position = Spot })
		end
	end

	return Selected
end

--[[
	picks a random spot that isn't currently occupied by an active coin
]]
local function GetRandomAvailableSpot(): Vector3?
	local OccupiedSet: { [Vector3]: boolean } = {}
	for _, Position in ActiveCoins do
		OccupiedSet[Position] = true
	end

	local Available = {}
	for _, Spot in AllSpots do
		if not OccupiedSet[Spot] then
			table.insert(Available, Spot)
		end
	end

	if #Available == 0 then
		return nil
	end

	return Available[math.random(#Available)]
end

--[[
	schedules a replacement coin to spawn after RESPAWN_DELAY seconds
]]
local function ScheduleRespawn()
	task.delay(CoinConst.RESPAWN_DELAY, function()
		if not IsActive then
			return
		end

		local Spot = GetRandomAvailableSpot()
		if not Spot then
			return
		end

		NextId += 1
		local Id = NextId
		ActiveCoins[Id] = Spot

		CoinNetwork.packets.SpawnCoin.sendToAll({
			Id = Id,
			X = Spot.X,
			Y = Spot.Y,
			Z = Spot.Z,
		})
	end)
end

--[[
	builds the network payload array from active coins
]]
local function BuildCoinPayload(): { { Id: number, X: number, Y: number, Z: number } }
	local Payload = {}
	for Id, Position in ActiveCoins do
		if not CollectedCoins[Id] then
			table.insert(Payload, {
				Id = Id,
				X = Position.X,
				Y = Position.Y,
				Z = Position.Z,
			})
		end
	end
	return Payload
end

--[[
	spawns coins for the current round and broadcasts to all clients
]]
function CoinService.SpawnCoins()
	table.clear(ActiveCoins)
	table.clear(CollectedCoins)
	NextId = 0

	AllSpots = GetCoinSpots()
	local Selected = SelectSpots(AllSpots)

	for _, CoinData in Selected do
		ActiveCoins[CoinData.Id] = CoinData.Position
	end

	IsActive = true

	CoinNetwork.packets.SpawnCoins.sendToAll({
		Coins = BuildCoinPayload(),
	})
end

--[[
	removes all coins and notifies clients
]]
function CoinService.DespawnAll()
	IsActive = false
	table.clear(ActiveCoins)
	table.clear(CollectedCoins)
	table.clear(AllSpots)
	table.clear(StopSpots)
	NextId = 0
	CoinNetwork.packets.DespawnAll.sendToAll({})
end

--[[
	finds CoinSpawns parts in LeftStop template and returns their world positions
]]
local function GetStopCoinSpots(SceneCFrame: CFrame): { Vector3 }
	local ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder
	local Template = ZoneModels:FindFirstChild("LeftStop")
	if not Template then
		return {}
	end

	local TemplatePivot = Template:GetPivot()
	local CoinSpawnsFolder = Template:FindFirstChild("CoinSpawns")
	if not CoinSpawnsFolder then
		return {}
	end

	local Spots = {}
	for _, Child in CoinSpawnsFolder:GetChildren() do
		if Child:IsA("BasePart") then
			local RelativeCF = TemplatePivot:Inverse() * Child.CFrame
			local WorldPos = (SceneCFrame * RelativeCF).Position + Vector3.new(0, CoinConst.HEIGHT_OFFSET, 0)
			table.insert(Spots, WorldPos)
		end
	end

	return Spots
end

--[[
	spawns coins at CoinSpawns positions for a stop scene
]]
function CoinService.SpawnStopCoins(SceneCFrame: CFrame)
	local Spots = GetStopCoinSpots(SceneCFrame)
	if #Spots == 0 then
		return
	end

	local Selected = SelectSpots(Spots)

	for _, Spot in Spots do
		table.insert(StopSpots, Spot)
		table.insert(AllSpots, Spot)
	end

	for _, CoinData in Selected do
		ActiveCoins[CoinData.Id] = CoinData.Position
	end

	CoinNetwork.packets.SpawnCoins.sendToAll({
		Coins = BuildCoinPayload(),
	})
end

--[[
	despawns only the stop coins and removes their spots
]]
function CoinService.DespawnStopCoins()
	local StopSet: { [Vector3]: boolean } = {}
	for _, Spot in StopSpots do
		StopSet[Spot] = true
	end

	local IdsToRemove = {}
	for Id, Position in ActiveCoins do
		if StopSet[Position] then
			table.insert(IdsToRemove, Id)
		end
	end

	for _, Id in IdsToRemove do
		ActiveCoins[Id] = nil
		CollectedCoins[Id] = nil
		CoinNetwork.packets.CollectCoin.sendToAll({ Id = Id })
	end

	local NewAllSpots = {}
	for _, Spot in AllSpots do
		if not StopSet[Spot] then
			table.insert(NewAllSpots, Spot)
		end
	end
	AllSpots = NewAllSpots
	table.clear(StopSpots)
end

CoinNetwork.packets.RequestCollect.listen(function(Data, Player: Player)
	if not IsActive then
		return
	end

	local Id = Data.Id
	local Position = ActiveCoins[Id]
	if not Position then
		return
	end

	if CollectedCoins[Id] then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end

	local Distance = (Root.Position - Position).Magnitude
	if Distance > CoinConst.SERVER_VERIFY_RADIUS then
		return
	end

	local Data = DataService.GetData(Player)
	if not Data then
		return
	end

	CollectedCoins[Id] = true
	ActiveCoins[Id] = nil

	Data.Coins += CoinConst.PICKUP_REWARD

	CoinNetwork.packets.CollectCoin.sendToAll({
		Id = Id,
	})

	ScheduleRespawn()
end)

CoinNetwork.queries.RequestCoinState.listen(function()
	return {
		Active = IsActive,
		Coins = BuildCoinPayload(),
	}
end)

return CoinService
