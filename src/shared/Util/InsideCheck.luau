local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local InsideCheck = {}

local InsideCollisions: {BasePart} = {}
local Listeners: {(IsInside: boolean) -> ()} = {}
local CurrentState: boolean = true

local Params = OverlapParams.new()
Params.FilterType = Enum.RaycastFilterType.Include

-- Helpers

local function CollectInsideCollisions()
	for _, Car in workspace:GetChildren() do
		if not Car:IsA("Model") then continue end
		local Collision = (Car:FindFirstChild("Collisions") and Car.Collisions:FindFirstChild("SoundCollision"))
		if Collision and Collision:IsA("BasePart") then
			table.insert(InsideCollisions, Collision)
		end
	end
end

local function CheckIsInside(): boolean
	local Character = Player.Character
	if not Character then return true end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then return true end

	Params.FilterDescendantsInstances = { Character }

	for _, Zone in InsideCollisions do
		local Found = workspace:GetPartsInPart(Zone, Params)
		if #Found > 0 then
			return true
		end
	end

	return false
end

-- Public API

function InsideCheck.IsInside(): boolean
	return CurrentState
end

function InsideCheck.OnChanged(Callback: (IsInside: boolean) -> ())
	table.insert(Listeners, Callback)
	Callback(CurrentState)
end

-- Boot

CollectInsideCollisions()

task.spawn(function()
	while true do
		local NowInside = CheckIsInside()

		if NowInside ~= CurrentState then
			CurrentState = NowInside
			for _, Callback in Listeners do
				task.spawn(Callback, NowInside)
			end
		end

		task.wait(0.25)
	end
end)

return InsideCheck
