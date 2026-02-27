local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local SoundZoneCheck = require(ReplicatedStorage.Shared.Util.SoundZoneCheck)

local WindController = {}

-- Helpers

local function ApplyWind(Zone: SoundZoneCheck.SoundZone)
	if Zone == "Outside" or Zone == "Roof" then
		workspace.GlobalWind = Constants.Wind.GLOBAL_WIND
	else
		workspace.GlobalWind = Vector3.zero
	end
end

-- Boot

SoundZoneCheck.OnChanged(ApplyWind)

return WindController
