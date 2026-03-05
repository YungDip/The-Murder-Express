-- WorldScroll integration test — runs through all service methods with debug prints

local ServerScriptService = game:GetService("ServerScriptService")

local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)

local function Log(Message: string)
	print("[WorldScrollTest]", os.clock(), Message)
end

-- Give everything a moment to boot
task.wait(3)

Log("=== Starting WorldScroll Test Sequence ===")

-- 1. Normal speed for a bit
Log("Running at default speed (125) for 5s")
task.wait(5)

-- 2. Speed up to 400
Log("ChangeSpeed → 400 over 2s")
WorldScrollService.ChangeSpeed(400, 2)
task.wait(5)

-- 3. Slow to 0
Log("ChangeSpeed → 0 over 5s")
WorldScrollService.ChangeSpeed(0, 5)
task.wait(6)

-- 4. Back to 150
Log("ChangeSpeed → 150 over 5s")
WorldScrollService.ChangeSpeed(150, 5)
task.wait(6)

-- 5. Stop again
Log("ChangeSpeed → 0 over 5s")
WorldScrollService.ChangeSpeed(0, 5)
task.wait(6)

-- 6. Back to 150
Log("ChangeSpeed → 150 over 5s")
WorldScrollService.ChangeSpeed(150, 5)
task.wait(6)

-- 7. Final stop
Log("ChangeSpeed → 0 over 5s")
WorldScrollService.ChangeSpeed(0, 5)
task.wait(6)

-- 8. Speed back up for tunnel
Log("ChangeSpeed → 150 over 3s")
WorldScrollService.ChangeSpeed(150, 3)
task.wait(5)

-- 9. Tunnel transition
Log("TunnelTransition → {LeftMountains, RightMountains}")
WorldScrollService.TunnelTransition({ "LeftMountains", "RightMountains" })
task.wait(15)

Log("=== WorldScroll Test Sequence Complete ===")
