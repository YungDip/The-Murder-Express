local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

export type SoundZone = "Inside" | "Medium" | "Outside" | "Roof"

local SoundZoneCheck = {}

local Listeners: {(Zone: SoundZone) -> ()} = {}
local CurrentState: SoundZone = "Inside"

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

local function CheckState(): SoundZone
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

function SoundZoneCheck.GetState(): SoundZone
	return CurrentState
end

function SoundZoneCheck.IsInside(): boolean
	return CurrentState == "Inside"
end

function SoundZoneCheck.IsOnRoof(): boolean
	return CurrentState == "Roof"
end

function SoundZoneCheck.OnChanged(Callback: (Zone: SoundZone) -> ())
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

return SoundZoneCheck
