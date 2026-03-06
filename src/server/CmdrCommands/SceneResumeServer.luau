local ServerScriptService = game:GetService("ServerScriptService")
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)

return function(_Context, Speed: number?, TransitionTime: number?)
	TransitionTime = TransitionTime or 5
	WorldScrollService.ResumeFromScene(nil, Speed, TransitionTime)
	local SpeedStr = if Speed then tostring(Speed) else "default"
	return "Resuming from scene at speed " .. SpeedStr .. " over " .. tostring(TransitionTime) .. "s"
end
