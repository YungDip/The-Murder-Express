local SoundService = game:GetService("SoundService")

local LayeredSound = {}

--[[
    plays a cloned sound so multiple can overlap; returns the cloned Sound
]]
function LayeredSound.Play(Source: Sound, Volume: number?, PlaybackSpeed: number?): Sound
	local Clone = Source:Clone()
	Clone.Volume = Volume or Clone.Volume
	Clone.PlaybackSpeed = PlaybackSpeed or Clone.PlaybackSpeed
	Clone.Parent = SoundService
	Clone:Play()

	Clone.Ended:Once(function()
		Clone:Destroy()
	end)

	return Clone
end

return LayeredSound
