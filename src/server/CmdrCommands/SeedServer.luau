local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local TrainGeneration = require(ServerScriptService.Server.Services.TrainGeneration)

return function(_Context, Seed: number, Length: number?)
	Length = Length or 15
	local PlayerCount = math.max(#Players:GetPlayers(), 1)
	workspace:SetAttribute("TrainSeed", Seed)
	local Sequence = TrainGeneration:Generate(Length, Seed, PlayerCount)

	return "Train regenerated with seed " .. tostring(Seed) .. " (" .. #Sequence .. " cars)"
end
