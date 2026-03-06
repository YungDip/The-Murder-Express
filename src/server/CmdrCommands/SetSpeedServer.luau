local ServerScriptService = game:GetService("ServerScriptService")
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)

return function(_Context, Speed: number, TransitionTime: number?)
	TransitionTime = TransitionTime or 0
	WorldScrollService.ChangeSpeed(Speed, TransitionTime)
	if TransitionTime > 0 then
		return "Speed changing to " .. tostring(Speed) .. " over " .. tostring(TransitionTime) .. "s"
	end
	return "Speed set to " .. tostring(Speed)
end
