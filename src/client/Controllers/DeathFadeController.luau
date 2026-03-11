local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local UIState = require(script.Parent.Parent.UI.UIState)

local RoundConst = Constants.Round
local Player = Players.LocalPlayer

local DeathFadeController = {}

local CurrentPhase: string = "Intermission"
local IsActive = false

local function OnLocalPlayerDied()
	if IsActive then
		return
	end
	IsActive = true

	UIState.ShutterClose(RoundConst.DEATH_FADE_DURATION, Color3.new(0, 0, 0))

	local Character = Player.Character
	if not Character or not Character:FindFirstChildOfClass("Humanoid") or Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
		Player.CharacterAdded:Wait()
		task.wait(0.5)
	end

	task.wait(0.5)

	if UIState.IsShutterClosed then
		UIState.ShutterOpen(RoundConst.DEATH_FADE_DURATION, Color3.new(0, 0, 0))
	end

	IsActive = false
end

local function ConnectDeathHandler()
	local Character = Player.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end
	Humanoid.Died:Connect(function()
		task.spawn(OnLocalPlayerDied)
	end)
end

Player.CharacterAdded:Connect(function(Character)
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if Humanoid then
		Humanoid.Died:Connect(function()
			task.spawn(OnLocalPlayerDied)
		end)
	end
end)

if Player.Character then
	task.spawn(ConnectDeathHandler)
end

RoundNetwork.packets.PhaseChange.listen(function(Data)
	CurrentPhase = Data.Phase

	if Data.Phase == "Intermission" or Data.Phase == "PostRound" then
		if IsActive then
			IsActive = false
			UIState.ShutterReset()
		end
	end
end)

return DeathFadeController
