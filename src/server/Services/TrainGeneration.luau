local TrainGeneration = {}
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

TrainGeneration.ModelPool = ServerStorage.CarModels:GetChildren()

local LocomotiveEnd = workspace.Train.Locomotive.End

local PropModels = ServerStorage:FindFirstChild("PropModels")

local CAR_TYPES = {"Connector", "CabinCar", "FlatCar", "RegularCar"}
local CONNECTOR_NEIGHBORS = { Connector = true, CabinCar = true }
local FLATCAR_FOLLOWERS = { CabinCar = true, RegularCar = true }
local MAX_SUCCESSION = 2
local FLATCAR_MAX_SUCCESSION = 4
local ROOMS_PER_CABIN = 5
local TABLE_SPAWN_CHANCE = 0.9
local DIVIDER_SPAWN_CHANCE = 0.5

TrainGeneration.Rules = {
	ConnectorAdjacency = function(Sequence: {string}, Position: number, CarType: string, _Length: number): boolean
		if CarType == "Connector" then
			local Previous = Sequence[Position - 1]
			if not CONNECTOR_NEIGHBORS[Previous] then
				return false
			end
		end

		local Previous = Sequence[Position - 1]
		if Previous == "Connector" and not CONNECTOR_NEIGHBORS[CarType] then
			return false
		end

		return true
	end,

	NoConnectorEnd = function(_Sequence: {string}, Position: number, CarType: string, Length: number): boolean
		return not (Position == Length and CarType == "Connector")
	end,

	NoFlatCarEnd = function(_Sequence: {string}, Position: number, CarType: string, Length: number): boolean
		return not (Position == Length and CarType == "FlatCar")
	end,

	FlatCarFollower = function(Sequence: {string}, Position: number, CarType: string, _Length: number): boolean
		local Previous = Sequence[Position - 1]
		if Previous == "FlatCar" and not FLATCAR_FOLLOWERS[CarType] then
			return false
		end
		return true
	end,

	MaxSuccession = function(Sequence: {string}, Position: number, CarType: string, _Length: number): boolean
		local Cap = if CarType == "FlatCar" then FLATCAR_MAX_SUCCESSION else MAX_SUCCESSION
		local RunLength = 0
		for I = Position - 1, 1, -1 do
			if Sequence[I] ~= CarType then
				break
			end
			RunLength += 1
		end
		return RunLength < Cap
	end,
}

local function ShuffleArray(Array: {any}, Rng: Random)
	for I = #Array, 2, -1 do
		local J = Rng:NextInteger(1, I)
		Array[I], Array[J] = Array[J], Array[I]
	end
end

local function GetModelByType(ModelPool: {Instance}, CarType: string, Rng: Random, VariantBags: {[string]: {Queue: {Instance}, Source: {Instance}}}): Model?
	for _, Item in ModelPool do
		if Item.Name == CarType then
			if Item:IsA("Folder") then
				local Children = Item:GetChildren()
				if #Children == 0 then
					return nil
				end

				local Bag = VariantBags[CarType]
				if not Bag then
					local Shuffled = table.clone(Children)
					ShuffleArray(Shuffled, Rng)
					Bag = { Queue = Shuffled, Source = Children }
					VariantBags[CarType] = Bag
				end

				if #Bag.Queue == 0 then
					Bag.Queue = table.clone(Bag.Source)
					ShuffleArray(Bag.Queue, Rng)
				end

				return table.remove(Bag.Queue)
			end
			return Item
		end
	end
	return nil
end

local function IsValidPlacement(Rules: {[string]: (...any) -> boolean}, Sequence: {string}, Position: number, CarType: string, Length: number): boolean
	for _, Rule in Rules do
		if not Rule(Sequence, Position, CarType, Length) then
			return false
		end
	end
	return true
end

local function GetValidTypes(Rules: {[string]: (...any) -> boolean}, Sequence: {string}, Position: number, Length: number): {string}
	local Valid = {}
	for _, CarType in CAR_TYPES do
		if IsValidPlacement(Rules, Sequence, Position, CarType, Length) then
			table.insert(Valid, CarType)
		end
	end
	return Valid
end

local function ClearGeneratedCars()
	for _, Child in workspace.Train:GetChildren() do
		if Child.Name ~= "Locomotive" then
			Child:Destroy()
		end
	end
end

local function AlignCarToEnd(Car: Model, PreviousEnd: BasePart)
	local StartPart = Car:FindFirstChild("Start")
	if not StartPart then
		return
	end

	local Offset = Car:GetPivot():ToObjectSpace(StartPart.CFrame)
	Car:PivotTo(PreviousEnd.CFrame * Offset:Inverse())
end

local function GetTableTemplates(): {Instance}
	local Tables = {}
	if not PropModels then
		return Tables
	end
	for _, Child in PropModels:GetChildren() do
		if string.find(Child.Name, "Table") then
			table.insert(Tables, Child)
		end
	end
	return Tables
end

local function SpawnProps(Car: Model, Rng: Random)
	local PropSpawnFolder = Car:FindFirstChild("PropSpawn")
	if not PropSpawnFolder then
		return
	end

	local TableTemplates = GetTableTemplates()
	local DividerTemplate = PropModels and PropModels:FindFirstChild("Divider")

	for _, SpawnPart in PropSpawnFolder:GetChildren() do
		if SpawnPart.Name == "TableSpawn" then
			if #TableTemplates > 0 and Rng:NextNumber() < TABLE_SPAWN_CHANCE then
				local Template = TableTemplates[Rng:NextInteger(1, #TableTemplates)]
				local Prop = Template:Clone()
				local SpawnCF = SpawnPart.CFrame
				if string.find(string.lower(Template.Name), "small") then
					SpawnCF = SpawnCF * CFrame.Angles(0, math.rad(90), 0)
				end
				Prop:PivotTo(SpawnCF)
				Prop.Parent = Car
			end
		elseif SpawnPart.Name == "DividerSpawn" then
			if DividerTemplate and Rng:NextNumber() < DIVIDER_SPAWN_CHANCE then
				local Prop = DividerTemplate:Clone()
				Prop:PivotTo(SpawnPart.CFrame)
				Prop.Parent = Car
			end
		end
	end
end

function TrainGeneration:Generate(Length: number, Seed: number, PlayerCount: number)
	ClearGeneratedCars()

	local RequiredCabinCars = math.ceil(PlayerCount / ROOMS_PER_CABIN)
	local Rng = Random.new(Seed)
	local Sequence: {string} = {}
	local TypeCounts: {[string]: number} = {}

	for Position = 1, Length do
		local ValidTypes = GetValidTypes(self.Rules, Sequence, Position, Length)

		local CabinCount = TypeCounts["CabinCar"] or 0
		local CabinDeficit = RequiredCabinCars - CabinCount
		local RemainingPositions = Length - Position + 1

		if CabinCount >= RequiredCabinCars then
			local Filtered = {}
			for _, Type in ValidTypes do
				if Type ~= "CabinCar" then
					table.insert(Filtered, Type)
				end
			end
			if #Filtered > 0 then
				ValidTypes = Filtered
			end
		elseif CabinDeficit >= RemainingPositions then
			local Filtered = {}
			for _, Type in ValidTypes do
				if Type == "CabinCar" then
					table.insert(Filtered, Type)
				end
			end
			if #Filtered > 0 then
				ValidTypes = Filtered
			end
		end

		local Needed = {}
		for _, Type in ValidTypes do
			if not TypeCounts[Type] then
				table.insert(Needed, Type)
			end
		end

		local Pool = if #Needed > 0 then Needed else ValidTypes
		local Choice = Pool[Rng:NextInteger(1, #Pool)]

		Sequence[Position] = Choice
		TypeCounts[Choice] = (TypeCounts[Choice] or 0) + 1
	end

	local PreviousEnd = LocomotiveEnd
	local VariantBags: {[string]: {Queue: {Instance}, Source: {Instance}}} = {}

	for Index, CarType in Sequence do
		local Template = GetModelByType(self.ModelPool, CarType, Rng, VariantBags)
		if not Template then
			continue
		end

		local Car = Template:Clone()
		AlignCarToEnd(Car, PreviousEnd)

		Car.Name = CarType .. "_" .. Index
		Car.Parent = workspace.Train

		if CarType == "RegularCar" then
			SpawnProps(Car, Rng)
		end

		local EndPart = Car:FindFirstChild("End")
		if EndPart then
			PreviousEnd = EndPart
		end
	end

	return Sequence
end

do
	local PlayerCount = math.max(#Players:GetPlayers(), 1)
	local Seed = os.time()
	workspace:SetAttribute("TrainSeed", Seed)
	TrainGeneration:Generate(15, Seed, PlayerCount)
end

return TrainGeneration