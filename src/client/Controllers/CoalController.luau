local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoalNetwork = require(ReplicatedStorage.Shared.Network.CoalNetwork)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local UIState = require(script.Parent.Parent.UI.UIState)

local CoalConst = Constants.Coal
local CoalController = {}

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Active = false
local CurrentCoal = 0
local RequiredCoal = 0

local CarriedCoal: BasePart? = nil
local CarryAttachment: Attachment? = nil
local CarryAlign: AlignPosition? = nil
local CarryConnection: RBXScriptConnection? = nil
local DropConnection: RBXScriptConnection? = nil
local DropTouchEndConnection: RBXScriptConnection? = nil
local CarryStartTime = 0
local TouchStartPositions: { [InputObject]: Vector2 } = {}

local PICKUP_COOLDOWN = 0.5
local TAP_MAX_DISTANCE = 20

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetCoalFolder(): Folder?
	return workspace:FindFirstChild("ServerCoal") :: Folder?
end

local function StopCarrying()
	if CarryConnection then
		CarryConnection:Disconnect()
		CarryConnection = nil
	end

	if DropConnection then
		DropConnection:Disconnect()
		DropConnection = nil
	end

	if DropTouchEndConnection then
		DropTouchEndConnection:Disconnect()
		DropTouchEndConnection = nil
	end

	if CarryAlign then
		CarryAlign:Destroy()
		CarryAlign = nil
	end

	if CarryAttachment then
		CarryAttachment:Destroy()
		CarryAttachment = nil
	end

	CarriedCoal = nil
	table.clear(TouchStartPositions)
end

local function GetMouseWorldPosition(): Vector3?
	local MousePos = UserInputService:GetMouseLocation()
	local Ray = Camera:ViewportPointToRay(MousePos.X, MousePos.Y)

	local FilterList = { Player.Character }
	if CarriedCoal then
		table.insert(FilterList, CarriedCoal)
	end
	RayParams.FilterDescendantsInstances = FilterList

	local Result = workspace:Raycast(Ray.Origin, Ray.Direction * CoalConst.CARRY_RAY_DISTANCE, RayParams)
	if Result then
		return Result.Position + Vector3.new(0, CoalConst.CARRY_HOVER_HEIGHT, 0)
	end

	return Ray.Origin + Ray.Direction * (CoalConst.CARRY_RAY_DISTANCE * 0.5)
end

local function StartCarrying(Coal: BasePart)
	StopCarrying()

	CarriedCoal = Coal

	local NewAttachment = Instance.new("Attachment")
	NewAttachment.Parent = Coal
	CarryAttachment = NewAttachment

	local NewAlign = Instance.new("AlignPosition")
	NewAlign.Mode = Enum.PositionAlignmentMode.OneAttachment
	NewAlign.Attachment0 = NewAttachment
	NewAlign.MaxForce = CoalConst.CARRY_MAX_FORCE
	NewAlign.Responsiveness = CoalConst.CARRY_RESPONSIVENESS
	NewAlign.Position = Coal.Position
	NewAlign.Parent = Coal
	CarryAlign = NewAlign

	CarryStartTime = tick()

	CarryConnection = RunService.PreRender:Connect(function()
		if not CarriedCoal or not CarriedCoal.Parent then
			StopCarrying()
			return
		end

		local TargetPos = GetMouseWorldPosition()
		if TargetPos and CarryAlign then
			CarryAlign.Position = TargetPos
		end
	end)

	DropConnection = UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if Processed then
			return
		end

		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			if tick() - CarryStartTime < PICKUP_COOLDOWN then
				return
			end
			CoalNetwork.packets.RequestRelease.send(nil)
			StopCarrying()
		elseif Input.UserInputType == Enum.UserInputType.Touch then
			TouchStartPositions[Input] = Vector2.new(Input.Position.X, Input.Position.Y)
		end
	end)

	DropTouchEndConnection = UserInputService.InputEnded:Connect(function(Input: InputObject, Processed: boolean)
		if Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local StartPos = TouchStartPositions[Input]
		TouchStartPositions[Input] = nil

		if Processed or not StartPos then
			return
		end
		if tick() - CarryStartTime < PICKUP_COOLDOWN then
			return
		end

		local Distance = (Vector2.new(Input.Position.X, Input.Position.Y) - StartPos).Magnitude
		if Distance < TAP_MAX_DISTANCE then
			CoalNetwork.packets.RequestRelease.send(nil)
			StopCarrying()
		end
	end)
end

CoalNetwork.packets.CoalGrabbed.listen(function(Data)
	local Folder = GetCoalFolder()
	if not Folder then
		return
	end

	for _, Child in Folder:GetChildren() do
		if Child:IsA("BasePart") and Child.Name == Data.CoalName then
			StartCarrying(Child)
			return
		end
	end
end)

CoalNetwork.packets.CoalReleased.listen(function(Data)
	if CarriedCoal and (Data.CoalName == "" or CarriedCoal.Name == Data.CoalName) then
		StopCarrying()
	end
end)

CoalNetwork.packets.CoalCollected.listen(function(Data)
	CurrentCoal = Data.Current
	RequiredCoal = Data.Required

	if CarriedCoal and CarriedCoal.Name == Data.CoalName then
		StopCarrying()
	end

	if Active then
		UIState.SetCoalState(true, CurrentCoal, RequiredCoal)
	end
end)

--[[
	Strips MoveableCoal and CoalCollection tagged parts from client-side scene clones
	so they don't duplicate the server-replicated parts
]]
local function StripClientSceneParts()
	for _, Part in CollectionService:GetTagged(CoalConst.COAL_NAME) do
		if Part:IsA("BasePart") and Part:IsDescendantOf(workspace) then
			local CoalFolder = workspace:FindFirstChild("ServerCoal")
			if not CoalFolder or not Part:IsDescendantOf(CoalFolder) then
				Part:Destroy()
			end
		end
	end

	for _, Part in CollectionService:GetTagged(CoalConst.COLLECTION_TAG) do
		if Part:IsA("BasePart") and Part:IsDescendantOf(workspace) then
			local CoalFolder = workspace:FindFirstChild("ServerCoal")
			if not CoalFolder or not Part:IsDescendantOf(CoalFolder) then
				Part:Destroy()
			end
		end
	end
end

CoalNetwork.packets.CoalActive.listen(function(Data)
	Active = Data.Active
	RequiredCoal = Data.Required
	if Active then
		CurrentCoal = 0
		StripClientSceneParts()
		UIState.SetCoalState(true, CurrentCoal, RequiredCoal)
	else
		StopCarrying()
		UIState.SetCoalState(false, 0, 0)
	end
end)

CoalNetwork.packets.CoalState.listen(function(Data)
	CurrentCoal = Data.Current
	RequiredCoal = Data.Required
	if Active then
		UIState.SetCoalState(true, CurrentCoal, RequiredCoal)
	end
end)

CoalNetwork.packets.CoalFilled.listen(function()
	UIState.SetCoalFilled(true)
end)

RoundNetwork.packets.PhaseChange.listen(function(Data)
	if Data.Phase == "PostRound" or Data.Phase == "Intermission" then
		if Active then
			Active = false
			StopCarrying()
			UIState.SetCoalState(false, 0, 0)
		end
	end
end)

task.spawn(function()
	local State = CoalNetwork.queries.RequestCoalState.invoke(nil)
	if not State then
		return
	end

	Active = State.Active
	CurrentCoal = State.Current
	RequiredCoal = State.Required
	UIState.SetCoalState(Active, CurrentCoal, RequiredCoal)
end)

function CoalController.IsActive(): boolean
	return Active
end

return CoalController
