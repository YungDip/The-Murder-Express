local ServerScriptService = game:GetService("ServerScriptService")
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)

return function(_Context, Zones: { string })
	WorldScrollService.TunnelTransition(Zones)
	return "Tunnel transition started to: " .. table.concat(Zones, ", ")
end
