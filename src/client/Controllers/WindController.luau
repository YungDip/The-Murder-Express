local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneCheck = require(ReplicatedStorage.Shared.Util.ZoneCheck)

local WindController = {}

-- Helpers

local function ApplyWind(Zone: ZoneCheck.Zone)
	if Zone == "Outside" or Zone == "Roof" then
		workspace.GlobalWind = Constants.Wind.GLOBAL_WIND
	else
		workspace.GlobalWind = Vector3.zero
	end
end

-- Boot

ZoneCheck.OnChanged(ApplyWind)

return WindController
