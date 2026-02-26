local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local InsideCheck = require(ReplicatedStorage.Shared.Util.InsideCheck)

local WindController = {}

-- Helpers

local function ApplyWind(IsInside: boolean)
	workspace.GlobalWind = if IsInside then Vector3.zero else Constants.Wind.GLOBAL_WIND
end

-- Boot

InsideCheck.OnChanged(ApplyWind)

return WindController
