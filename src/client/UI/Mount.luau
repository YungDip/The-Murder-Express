local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])

local App = require(script.Parent.App)
local Shutter = require(script.Parent.Components.Shutter)

local Mount = {}

local Root = nil
local ShutterRoot = nil

function Mount.Init()
	local Player = Players.LocalPlayer
	local PlayerGui = Player:WaitForChild("PlayerGui")

	-- Disable the default Roblox playerlist
	local Success = false
	while not Success do
		Success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if not Success then
			task.wait()
		end
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "ReactUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.DisplayOrder = 100
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	Root = ReactRoblox.createRoot(ScreenGui)
	Root:render(React.createElement(App))

	local ShutterGui = Instance.new("ScreenGui")
	ShutterGui.Name = "ShutterGui"
	ShutterGui.ResetOnSpawn = false
	ShutterGui.IgnoreGuiInset = true
	ShutterGui.DisplayOrder = 200
	ShutterGui.ScreenInsets = Enum.ScreenInsets.None
	ShutterGui.Parent = PlayerGui

	ShutterRoot = ReactRoblox.createRoot(ShutterGui)
	ShutterRoot:render(React.createElement(Shutter))
end

function Mount.Unmount()
	if Root then
		Root:unmount()
		Root = nil
	end
	if ShutterRoot then
		ShutterRoot:unmount()
		ShutterRoot = nil
	end
end

return Mount
