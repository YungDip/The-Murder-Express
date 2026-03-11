local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)
local RoundService = require(ServerScriptService.Server.Services.RoundService)

local DefaultSpeed = Constants.WorldScroll.DEFAULT_SPEED

local function Log(Message: string)
	print("[WorldScrollTest]", os.clock(), Message)
end

local function RunStopSequence()
	Log("=== Stop Sequence Start ===")

	Log("Running at default speed for 20s")
	task.wait(20)

	Log("StopAtNewSceneWithTunnels → {LeftStop, RightMountains}, Tunnel, {LeftMountains}")
	local TotalTime = WorldScrollService.StopAtNewSceneWithTunnels({"LeftStop", "RightMountains"}, "Tunnel", {"LeftMountains"})
	Log("Cruise + brake = ~" .. string.format("%.1f", TotalTime) .. "s")
	task.wait(TotalTime + 1)

	Log("Stopped for 30s")
	task.wait(30)

	Log("ResumeFromScene → default speed over 5s")
	WorldScrollService.ResumeFromScene(nil, DefaultSpeed, 5)
	task.wait(5)

	Log("=== Stop Sequence Complete ===")
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
