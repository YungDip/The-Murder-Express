local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoinNetwork = require(ReplicatedStorage.Shared.Network.CoinNetwork)
local DataService = require(script.Parent.DataService)

local CoinConst = Constants.Coin

local CoinService = {}

local ActiveCoins: { [number]: Vector3 } = {}
local CollectedCoins: { [number]: boolean } = {}
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
	local Id = 0

	for _, Spot in Spots do
		if math.random() < CoinConst.SPAWN_CHANCE then
			Id += 1
			table.insert(Selected, { Id = Id, Position = Spot })
		end
	end

	return Selected
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

	local Spots = GetCoinSpots()
	local Selected = SelectSpots(Spots)

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
	CoinNetwork.packets.DespawnAll.sendToAll({})
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

	Data.Coins += CoinConst.PICKUP_REWARD

	CoinNetwork.packets.CollectCoin.sendToAll({
		Id = Id,
	})
end)

CoinNetwork.queries.RequestCoinState.listen(function()
	return {
		Active = IsActive,
		Coins = BuildCoinPayload(),
	}
end)

return CoinService
