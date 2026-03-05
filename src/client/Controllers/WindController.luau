local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneCheck = require(ReplicatedStorage.Shared.Util.ZoneCheck)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)

local WindController = {}

-- State

local IsOutdoor = false

-- Zone transitions

local function OnZoneChanged(Zone: ZoneCheck.Zone)
	IsOutdoor = Zone == "Outside" or Zone == "Roof"
end

-- Boot

OnZoneChanged(ZoneCheck.GetState())
ZoneCheck.OnChanged(OnZoneChanged)

local LastWindDebugTime = 0

RunService.PreRender:Connect(function()
	local SpeedRatio = ScrollSpeedState.SpeedRatio

	if IsOutdoor then
		workspace.GlobalWind = Constants.Wind.GLOBAL_WIND * SpeedRatio
	else
		workspace.GlobalWind = Vector3.zero
	end

	if os.clock() - LastWindDebugTime > 1 then
		LastWindDebugTime = os.clock()
		print(string.format("[Wind] SpeedRatio=%.3f IsOutdoor=%s GlobalWind=%s",
			SpeedRatio, tostring(IsOutdoor), tostring(workspace.GlobalWind)))
	end
end)

return WindController
