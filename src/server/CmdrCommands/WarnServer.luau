local ServerScriptService = game:GetService("ServerScriptService")
local AnnouncementService = require(ServerScriptService.Server.Services.AnnouncementService)

return function(_Context, Title: string, Subtitle: string?, Duration: number?)
	local Sub = if Subtitle == "" then nil else Subtitle
	AnnouncementService.AnnounceAll(Title, Sub, Duration, true)
	return "Warning announced: " .. Title
end
