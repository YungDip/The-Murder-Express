local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

local PROFILE_TEMPLATE = {
	Coins = 0,
}

local PlayerStore = ProfileStore.New("PlayerData", PROFILE_TEMPLATE)

-- Mock store in Studio (does not persist between sessions)
-- To test real persistence, comment this out and enable Studio API access
--[[if RunService:IsStudio() then
	PlayerStore = PlayerStore.Mock
end]]

local Profiles: { [Player]: typeof(PlayerStore:StartSessionAsync("")) } = {}
local DataProxies: { [Player]: typeof(PROFILE_TEMPLATE) } = {}

local DataService = {}

--[[
	builds a proxy table that writes through to Profile.Data and auto-syncs leaderstats
]]
local function CreateDataProxy(PlayerInstance: Player, Profile: typeof(PlayerStore:StartSessionAsync("")))
	local Proxy = {}

	setmetatable(Proxy, {
		__newindex = function(_, Key, Value)
			rawset(Profile.Data, Key, Value)

			local Leaderstats = PlayerInstance:FindFirstChild("leaderstats")
			if Leaderstats then
				local Stat = Leaderstats:FindFirstChild(Key)
				if Stat then
					Stat.Value = Value
				end
			end
		end,
		__index = function(_, Key)
			return rawget(Profile.Data, Key)
		end,
	})

	return Proxy
end

local function SetupLeaderstats(PlayerInstance: Player, Profile: typeof(PlayerStore:StartSessionAsync("")))
	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"

	local CoinsValue = Instance.new("IntValue")
	CoinsValue.Name = "Coins"
	CoinsValue.Value = Profile.Data.Coins
	CoinsValue.Parent = Leaderstats

	Leaderstats.Parent = PlayerInstance
end

local function PlayerAdded(PlayerInstance: Player)
	local Profile = PlayerStore:StartSessionAsync(`{PlayerInstance.UserId}`, {
		Cancel = function()
			return PlayerInstance.Parent ~= Players
		end,
	})

	if Profile ~= nil then
		Profile:AddUserId(PlayerInstance.UserId)
		Profile:Reconcile()

		Profile.OnSessionEnd:Connect(function()
			Profiles[PlayerInstance] = nil
			DataProxies[PlayerInstance] = nil
			PlayerInstance:Kick("Profile session ended - please rejoin")
		end)

		if PlayerInstance.Parent == Players then
			Profiles[PlayerInstance] = Profile
			DataProxies[PlayerInstance] = CreateDataProxy(PlayerInstance, Profile)
			SetupLeaderstats(PlayerInstance, Profile)
		else
			Profile:EndSession()
		end
	else
		PlayerInstance:Kick("Profile failed to load - please rejoin")
	end
end

--[[
	returns the profile for a given player, or nil if not loaded
]]
function DataService.GetProfile(PlayerInstance: Player): typeof(PlayerStore:StartSessionAsync(""))
	return Profiles[PlayerInstance]
end

--[[
	returns the data proxy for a given player, or nil if not loaded.
	writing to the returned table auto-syncs leaderstats.
]]
function DataService.GetData(PlayerInstance: Player): typeof(PROFILE_TEMPLATE)?
	return DataProxies[PlayerInstance]
end

for _, PlayerInstance in Players:GetPlayers() do
	task.spawn(PlayerAdded, PlayerInstance)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(PlayerInstance: Player)
	local Profile = Profiles[PlayerInstance]
	if Profile ~= nil then
		Profile:EndSession()
	end
end)

return DataService
