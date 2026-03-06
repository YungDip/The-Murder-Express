local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)
local AnnouncementService = require(ServerScriptService.Server.Services.AnnouncementService)
local RoundService = require(ServerScriptService.Server.Services.RoundService)

local DefaultSpeed = Constants.WorldScroll.DEFAULT_SPEED

local function Log(Message: string)
	print("[WorldScrollTest]", os.clock(), Message)
end

local function RunCoalSequence()
	Log("=== Coal Sequence Start ===")

	Log("Running at default speed for 30s")
	task.wait(30)

	Log("Warning: train out of coal")
	AnnouncementService.AnnounceAll("The train has run out of coal!", nil, 5, true)

	Log("ChangeSpeed → 0 over 10s")
	WorldScrollService.ChangeSpeed(0, 10)
	task.wait(10)

	Log("Stopped for 30s")
	task.wait(30)

	Log("Announcement: coal found")
	AnnouncementService.AnnounceAll("Coal has been found!", nil, 5, false)
	Log("ChangeSpeed → " .. DefaultSpeed .. " over 5s")
	WorldScrollService.ChangeSpeed(DefaultSpeed, 5)
	task.wait(5)

	Log("Waiting 20s before tunnel")
	task.wait(20)

	Log("TunnelTransition → {LeftMountains, RightMountains}")
	WorldScrollService.TunnelTransition({ "LeftMountains", "RightMountains" })

	Log("=== Coal Sequence Complete ===")
end

task.wait(3)

while true do
	while RoundService.GetPhase() ~= "InProgress" do
		task.wait(0.5)
	end

	Log("Round started — launching coal sequence")
	task.spawn(RunCoalSequence)

	while RoundService.GetPhase() == "InProgress" do
		task.wait(0.5)
	end
end
