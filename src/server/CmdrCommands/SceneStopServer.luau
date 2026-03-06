local ServerScriptService = game:GetService("ServerScriptService")
local WorldScrollService = require(ServerScriptService.Server.Services.WorldScrollService)

return function(_Context, Scene: string)
	WorldScrollService.StopAtNewScene({ Scene })
	return "Stopping at scene: " .. Scene
end
