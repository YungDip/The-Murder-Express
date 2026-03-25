local SpawnService = {}

--[[
    returns the designated spawn CFrame (lobby)
]]
function SpawnService.GetDesignatedSpawn(): CFrame
	return SpawnService.GetLobbySpawn()
end

--[[
    returns the lobby spawn CFrame
]]
function SpawnService.GetLobbySpawn(): CFrame
	local Lobby = workspace:FindFirstChild("Lobby")
	if Lobby then
		local Spawn = Lobby:FindFirstChild("Spawn")
		if Spawn then
			return Spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 10, 0)
end

--[[
    teleports a player's character to the given CFrame
]]
function SpawnService.TeleportCharacter(PlayerInstance: Player, TargetCFrame: CFrame)
	local Character = PlayerInstance.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end
	Character:PivotTo(TargetCFrame)
end

--[[
    teleports a player to the train spawn
]]
function SpawnService.TeleportToTrain(PlayerInstance: Player)
	SpawnService.TeleportCharacter(PlayerInstance, SpawnService.GetDesignatedSpawn())
end

--[[
    teleports a player to the lobby spawn
]]
function SpawnService.TeleportToLobby(PlayerInstance: Player)
	SpawnService.TeleportCharacter(PlayerInstance, SpawnService.GetLobbySpawn())
end

--[[
    collects all SafeSpawn CFrames from train cars
]]
local function GetSafeSpawns(): { CFrame }
	local Spawns = {}
	local TrainModel = workspace:FindFirstChild("Train")
	if not TrainModel then
		return Spawns
	end
	for _, Car in TrainModel:GetChildren() do
		if not Car:IsA("Model") then
			continue
		end
		local PropSpawn = Car:FindFirstChild("PropSpawn")
		if PropSpawn then
			local SafeSpawn = PropSpawn:FindFirstChild("SafeSpawn")
			if SafeSpawn and SafeSpawn:IsA("BasePart") then
				table.insert(Spawns, SafeSpawn:GetPivot())
			end
		end
	end
	return Spawns
end

--[[
    returns the CFrame of the nearest SafeSpawn to the given world position
]]
function SpawnService.GetNearestSafeSpawn(Position: Vector3): CFrame
	local Spawns = GetSafeSpawns()
	local ClosestCFrame: CFrame? = nil
	local ClosestDistance = math.huge

	for _, SpawnCF in Spawns do
		local Distance = (SpawnCF.Position - Position).Magnitude
		if Distance < ClosestDistance then
			ClosestDistance = Distance
			ClosestCFrame = SpawnCF
		end
	end

	return ClosestCFrame or SpawnService.GetDesignatedSpawn()
end

--[[
    batch teleports all players to random SafeSpawn points across train cars
]]
function SpawnService.TeleportAllToTrain(PlayerList: { Player })
	local Spawns = GetSafeSpawns()
	if #Spawns == 0 then
		return
	end
	for _, PlayerInstance in PlayerList do
		local RandomSpawn = Spawns[math.random(1, #Spawns)]
		SpawnService.TeleportCharacter(PlayerInstance, RandomSpawn)
	end
end

--[[
    returns the CFrame at the center-floor of the nearest train car to Position
]]
function SpawnService.GetNearestCarCenter(Position: Vector3): CFrame
	local TrainModel = workspace:FindFirstChild("Train")
	if not TrainModel then
		return SpawnService.GetDesignatedSpawn()
	end

	local ClosestCar: Model? = nil
	local ClosestDistance = math.huge

	for _, Car in TrainModel:GetChildren() do
		if not Car:IsA("Model") then
			continue
		end
		if Car.Name == "Locomotive" then
			continue
		end
		local CarCF = Car:GetBoundingBox()
		local Distance = (CarCF.Position - Position).Magnitude
		if Distance < ClosestDistance then
			ClosestDistance = Distance
			ClosestCar = Car
		end
	end

	if ClosestCar then
		local CarCF, CarSize = ClosestCar:GetBoundingBox()
		return CFrame.new(CarCF.Position.X, CarCF.Position.Y - CarSize.Y / 2 + 3, CarCF.Position.Z)
	end

	return SpawnService.GetDesignatedSpawn()
end

--[[
    teleports a player to the nearest train car
]]
function SpawnService.TeleportToNearestCar(PlayerInstance: Player)
	local Character = PlayerInstance.Character
	if not Character then
		return
	end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end
	SpawnService.TeleportCharacter(PlayerInstance, SpawnService.GetNearestCarCenter(Root.Position))
end

--[[
    force respawns a player and teleports them to lobby once their character loads
    (@yields)
]]
function SpawnService.RespawnToLobby(PlayerInstance: Player)
	PlayerInstance:LoadCharacterAsync()
	local Character = PlayerInstance.Character or PlayerInstance.CharacterAdded:Wait()
	task.wait()
	Character:PivotTo(SpawnService.GetLobbySpawn())
end

return SpawnService
