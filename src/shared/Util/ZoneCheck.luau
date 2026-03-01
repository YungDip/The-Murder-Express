local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

export type Zone = "Inside" | "Medium" | "Outside" | "Roof"

local ZoneCheck = {}

local Listeners: {(Zone: Zone) -> ()} = {}
local CurrentState: Zone = "Inside"

local MAX_CHECK_DISTANCE = 50
local Params = OverlapParams.new()
Params.FilterType = Enum.RaycastFilterType.Include

-- Helpers

local function GetPlayerRoot(): BasePart?
	local Character = Player.Character
	if not Character then return nil end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function IsPlayerInAnyTagged(Tag: string, Root: BasePart): boolean
	Params.FilterDescendantsInstances = { Player.Character }

	for _, Part in CollectionService:GetTagged(Tag) do
		if not Part:IsA("BasePart") then continue end
		if (Part.Position - Root.Position).Magnitude > MAX_CHECK_DISTANCE then continue end

		local Found = workspace:GetPartsInPart(Part, Params)
		if #Found > 0 then
			return true
		end
	end

	return false
end

local function CheckState(): Zone
	local Root = GetPlayerRoot()
	if not Root then return "Inside" end

	if IsPlayerInAnyTagged("InsideSoundCollisions", Root) then
		return "Inside"
	elseif IsPlayerInAnyTagged("MediumSoundCollisions", Root) then
		return "Medium"
	elseif IsPlayerInAnyTagged("RoofSoundCollisions", Root) then
		return "Roof"
	end

	return "Outside"
end

-- Public API

function ZoneCheck.GetState(): Zone
	return CurrentState
end

function ZoneCheck.IsInside(): boolean
	return CurrentState == "Inside"
end

function ZoneCheck.IsOnRoof(): boolean
	return CurrentState == "Roof"
end

function ZoneCheck.OnChanged(Callback: (Zone: Zone) -> ())
	table.insert(Listeners, Callback)
	Callback(CurrentState)
end

-- Boot

task.spawn(function()
	while true do
		local NewState = CheckState()

		if NewState ~= CurrentState then
			CurrentState = NewState
			for _, Callback in Listeners do
				task.spawn(Callback, NewState)
			end
		end

		task.wait(0.25)
	end
end)

return ZoneCheck
