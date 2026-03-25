-- Stop sequences are now handled by RoundService directly.
-- This test file is disabled to avoid conflicts.
-- To re-enable manual testing, uncomment the code below.

--[[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)
local RoundService = require(ServerScriptService.Server.Services.RoundService)
local CoalService = require(ServerScriptService.Server.Services.CoalService)

local DefaultSpeed = Constants.WorldScroll.DEFAULT_SPEED
local CoalConst = Constants.Coal

local function Log(Message: string)
	print("[WorldScrollTest]", os.clock(), Message)
end

local function RunStopSequence()
	Log("=== Stop Sequence Start ===")

	Log("Running at default speed for 5s")
	task.wait(5)

	if RoundService.GetPhase() ~= "InProgress" then
		Log("Round ended before stop — aborting")
		return false
	end

	Log("StopAtNewSceneWithTunnels → {LeftStop, RightMountains}, Tunnel, {LeftMountains}")
	local TotalTime = WorldScrollService.StopAtNewSceneWithTunnels({"LeftStop", "RightMountains", "PowerLines"}, "Tunnel", {"LeftMountains"})
	Log("Cruise + brake = ~" .. string.format("%.1f", TotalTime) .. "s")
	task.wait(TotalTime + 1)

	if RoundService.GetPhase() ~= "InProgress" then
		Log("Round ended during approach — aborting")
		return false
	end

	Log("Stopped — activating coal collection (need " .. CoalConst.REQUIRED_COAL .. " coal)")
	local SceneCFrame = WorldScrollService.GetSceneCFrame("LeftStop")
	CoalService.Activate(CoalConst.REQUIRED_COAL, SceneCFrame)

	while not CoalService.IsFilled() and RoundService.GetPhase() == "InProgress" do
		task.wait(0.5)
	end

	if RoundService.GetPhase() ~= "InProgress" then
		Log("Round ended before coal filled — cleaning up")
		CoalService.Deactivate()
		return false
	end

	Log("Coal filled! Waiting " .. CoalConst.BOARDING_WARNING_DURATION .. "s for players to board")
	task.wait(CoalConst.BOARDING_WARNING_DURATION)

	CoalService.Deactivate()

	Log("ResumeFromScene → default speed over 5s")
	WorldScrollService.ResumeFromScene(nil, DefaultSpeed, 5)
	task.wait(5)

	Log("=== Stop Sequence Complete ===")
	return true
end

task.wait(3)

while true do
	while RoundService.GetPhase() ~= "InProgress" do
		task.wait(0.5)
	end

	Log("Round started — launching stop sequence")
	task.spawn(RunStopSequence)

	while RoundService.GetPhase() == "InProgress" do
		task.wait(0.5)
	end
end
--]]
