local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Shared.Constants)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local DebugUI = PlayerGui:WaitForChild("DebugUI")
local SeedVersion = DebugUI:WaitForChild("SeedVersion")

local function UpdateText()
	local Seed = workspace:GetAttribute("TrainSeed") or "?"
	SeedVersion.Text = `S: {Seed} V: {Constants.VERSION}`
end

UpdateText()
workspace:GetAttributeChangedSignal("TrainSeed"):Connect(UpdateText)

return {}
