local TrainGeneration = {}
local ServerStorage = game:GetService("ServerStorage")

TrainGeneration.ModelPool = ServerStorage.CarModels:GetChildren()

local LocomotiveEnd = workspace.Train.Locomotive.End

local CAR_TYPES = {"Connector", "CabinCar", "FlatCar", "RegularCar"}
local CONNECTOR_NEIGHBORS = { Connector = true, CabinCar = true }
local FLATCAR_FOLLOWERS = { CabinCar = true, RegularCar = true }
local MAX_SUCCESSION = 2
local FLATCAR_MAX_SUCCESSION = 4

-- Rules are validator functions: (Sequence, Position, CarType, Length) -> boolean
-- Add new entries to this table to extend generation constraints
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

local function GetModelByType(ModelPool: {Instance}, CarType: string): Model?
	for _, Model in ModelPool do
		if Model.Name == CarType then
			return Model
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

function TrainGeneration:Generate(Length: number, Seed: number)
	ClearGeneratedCars()

	local Rng = Random.new(Seed)
	local Sequence: {string} = {}
	local TypeCounts: {[string]: number} = {}

	for Position = 1, Length do
		local ValidTypes = GetValidTypes(self.Rules, Sequence, Position, Length)

		-- Prefer car types we haven't placed yet so every type appears at least once
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

	-- Clone and position each car
	local PreviousEnd = LocomotiveEnd

	for Index, CarType in Sequence do
		local Template = GetModelByType(self.ModelPool, CarType)
		if not Template then
			continue
		end

		local Car = Template:Clone()
		AlignCarToEnd(Car, PreviousEnd)

		Car.Name = CarType .. "_" .. Index
		Car.Parent = workspace.Train

		local EndPart = Car:FindFirstChild("End")
		if EndPart then
			PreviousEnd = EndPart
		end
	end

	return Sequence
end

do
	TrainGeneration:Generate(10, os.time())
end

return TrainGeneration