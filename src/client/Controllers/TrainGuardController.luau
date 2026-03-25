local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local WorldScrollNetwork = require(ReplicatedStorage.Shared.Network.WorldScrollNetwork)

local TrainGuardController = {}

local Player = Players.LocalPlayer
local OFF_TRAIN_THRESHOLD = 1

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local IsInRound = false
local IsEliminated = false
local IsTrainStopped = false
local OffTrainStart: number? = nil

local function GetNearestSafeSpawn(Position: Vector3): CFrame?
	local TrainModel = workspace:FindFirstChild("Train")
	if not TrainModel then
		return nil
	end

	local ClosestCar: Model? = nil
	local ClosestDistance = math.huge

	for _, Car in TrainModel:GetChildren() do
		if not Car:IsA("Model") then
			continue
		end
		local CarCF = Car:GetBoundingBox()
		local Distance = (CarCF.Position - Position).Magnitude
		if Distance < ClosestDistance then
			ClosestDistance = Distance
			ClosestCar = Car
		end
	end

	if not ClosestCar then
		return nil
	end

	local PropSpawn = ClosestCar:FindFirstChild("PropSpawn")
	if PropSpawn then
		local SafeSpawn = PropSpawn:FindFirstChild("SafeSpawn")
		if SafeSpawn and SafeSpawn:IsA("BasePart") then
			return SafeSpawn:GetPivot()
		end
	end

	local CarCF, CarSize = ClosestCar:GetBoundingBox()
	return CFrame.new(CarCF.Position.X, CarCF.Position.Y - CarSize.Y / 2 + 12, CarCF.Position.Z)
end

local function IsOnTrain(Root: BasePart): boolean
	local Character = Player.Character
	if not Character then
		return true
	end

	RayParams.FilterDescendantsInstances = { Character }
	local Result = workspace:Raycast(Root.Position, Vector3.new(0, -15, 0), RayParams)
	if Result and Result.Instance then
		local TrainModel = workspace:FindFirstChild("Train")
		if TrainModel and Result.Instance:IsDescendantOf(TrainModel) then
			return true
		end
	end
	return false
end

RoundNetwork.packets.PhaseChange.listen(function(Data)
	IsInRound = Data.Phase == "InProgress"
	if not IsInRound then
		OffTrainStart = nil
		IsTrainStopped = false
		IsEliminated = false
	end
end)

WorldScrollNetwork.packets.SyncState.listen(function(Data)
	local Phase = Data.Phase
	IsTrainStopped = Phase == "SceneStopped" or Phase == "SceneStopping"
end)

WorldScrollNetwork.packets.SceneStop.listen(function()
	IsTrainStopped = true
end)

WorldScrollNetwork.packets.SceneTunnelStop.listen(function()
	IsTrainStopped = true
end)

WorldScrollNetwork.packets.SceneResume.listen(function()
	IsTrainStopped = false
end)

RoundNetwork.packets.PlayerEliminated.listen(function(Data)
	if Data.UserId == Player.UserId then
		IsEliminated = true
		OffTrainStart = nil
	end
end)

task.spawn(function()
	local State = RoundNetwork.queries.RequestRoundState.invoke(nil)
	if State then
		IsInRound = State.Phase == "InProgress"
	end
end)

RunService.PreSimulation:Connect(function()
	if not IsInRound or IsEliminated then
		OffTrainStart = nil
		return
	end

	if IsTrainStopped then
		OffTrainStart = nil
		return
	end

	local Character = Player.Character
	if not Character then
		OffTrainStart = nil
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		OffTrainStart = nil
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		OffTrainStart = nil
		return
	end

	if IsOnTrain(Root) then
		OffTrainStart = nil
		return
	end

	local CurrentTime = tick()
	if not OffTrainStart then
		OffTrainStart = CurrentTime
		return
	end

	if CurrentTime - OffTrainStart >= OFF_TRAIN_THRESHOLD then
		local TargetCF = GetNearestSafeSpawn(Root.Position)
		if TargetCF then
			Character:PivotTo(TargetCF)
		end
		OffTrainStart = nil
	end
end)

return TrainGuardController
