local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Announcement = require(script.Parent.Components.Announcement)
local Timer = require(script.Parent.Components.Timer)
local Roulette = require(script.Parent.Components.Roulette)
local Scoreboard = require(script.Parent.Components.Scoreboard)
local PlayerList = require(script.Parent.Components.PlayerList)
local CoalBar = require(script.Parent.Components.CoalBar)
local SpectateHUD = require(script.Parent.Components.SpectateHUD)

local E = React.createElement

local function App()
	return E(React.Fragment, nil, {
		Announcement = E(Announcement),
		Timer = E(Timer),
		Roulette = E(Roulette),
		Scoreboard = E(Scoreboard),
		PlayerList = E(PlayerList),
		CoalBar = E(CoalBar),
		SpectateHUD = E(SpectateHUD),
	})
end

return App
