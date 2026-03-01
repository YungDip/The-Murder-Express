local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local DeathVelocityNetwork = require(ReplicatedStorage.Shared.Network.DeathVelocityNetwork)

local DeathConst = Constants.DeathVelocity
local ScrollSpeed = Constants.WorldScroll.SCROLL_SPEED

local DeathVelocityService = {}

DeathVelocityNetwork.packets.Apply.listen(function(Data, Sender)
	local Character = Sender.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
	if not Humanoid then return end

	local SpeedMultiplier = if Data.IsRoof then DeathConst.ROOF_MULTIPLIER else DeathConst.OUTSIDE_MULTIPLIER
	local Velocity = Vector3.new(-ScrollSpeed * SpeedMultiplier, DeathConst.UP_FORCE, 0)

	local Cleanup = {}

	for _, Part in Character:GetDescendants() do
		if not Part:IsA("BasePart") then continue end

		local Att = Instance.new("Attachment")
		Att.Name = "DeathFling"
		Att.Parent = Part

		local LV = Instance.new("LinearVelocity")
		LV.Name = "DeathFling"
		LV.Attachment0 = Att
		LV.VectorVelocity = Velocity
		LV.MaxForce = DeathConst.MAX_FORCE
		LV.RelativeTo = Enum.ActuatorRelativeTo.World
		LV.Parent = Part

		table.insert(Cleanup, Att)
		table.insert(Cleanup, LV)
	end

	task.delay(DeathConst.DURATION, function()
		for _, Inst in Cleanup do
			if Inst and Inst.Parent then Inst:Destroy() end
		end
	end)
end)

return DeathVelocityService
