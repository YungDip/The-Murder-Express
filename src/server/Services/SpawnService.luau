local SpawnService = {}

--[[
    returns the designated train spawn CFrame
]]
function SpawnService.GetDesignatedSpawn(): CFrame
	local SpawnPoint = workspace:FindFirstChild("SpawnLocation")
	if SpawnPoint then
		return SpawnPoint.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 10, 0)
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
    batch teleports all players to the train spawn
]]
function SpawnService.TeleportAllToTrain(PlayerList: { Player })
	local SpawnCFrame = SpawnService.GetDesignatedSpawn()
	for _, PlayerInstance in PlayerList do
		SpawnService.TeleportCharacter(PlayerInstance, SpawnCFrame)
	end
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
