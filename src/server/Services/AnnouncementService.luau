local AnnouncementNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.AnnouncementNetwork)

local AnnouncementService = {}

--[[
    broadcasts an announcement to all players
]]
function AnnouncementService.AnnounceAll(Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean?)
	AnnouncementNetwork.packets.Show.sendToAll({
		Title = Title,
		Subtitle = Subtitle,
		Duration = Duration,
		IsWarning = IsWarning,
	})
end

--[[
    sends an announcement to a specific player
]]
function AnnouncementService.AnnounceTo(TargetPlayer: Player, Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean?)
	AnnouncementNetwork.packets.Show.sendTo({
		Title = Title,
		Subtitle = Subtitle,
		Duration = Duration,
		IsWarning = IsWarning,
	}, TargetPlayer)
end

return AnnouncementService
