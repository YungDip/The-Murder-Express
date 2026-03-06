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

RunService.PreRender:Connect(function()
	local SpeedRatio = ScrollSpeedState.SpeedRatio

	if IsOutdoor then
		workspace.GlobalWind = Constants.Wind.GLOBAL_WIND * SpeedRatio
	else
		workspace.GlobalWind = Vector3.zero
	end
end)

return WindController
