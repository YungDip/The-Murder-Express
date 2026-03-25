local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoalNetwork = require(ReplicatedStorage.Shared.Network.CoalNetwork)
local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local ScrollSpeedState = require(script.Parent.ScrollSpeedState)
local UIState = require(script.Parent.Parent.UI.UIState)

local CoalConst = Constants.Coal
local CoalController = {}

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Active = false
local CurrentCoal = 0
local RequiredCoal = 0
local IsEliminated = false

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

local Highlights: { [Instance]: Highlight } = {}
local HighlightConnection: RBXScriptConnection? = nil

local function GetCoalFolder(): Folder?
	return workspace:FindFirstChild("ServerCoal") :: Folder?
end

local function GetCoalRootPart(CoalInstance: Instance): BasePart?
	if CoalInstance:IsA("BasePart") then
		return CoalInstance
	elseif CoalInstance:IsA("Model") then
		return CoalInstance.PrimaryPart or CoalInstance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
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
		if Child.Name == Data.CoalName then
			local RootPart = GetCoalRootPart(Child)
			if RootPart then
				StartCarrying(RootPart)
				return
			end
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

local function CleanupHighlights()
	if HighlightConnection then
		HighlightConnection:Disconnect()
		HighlightConnection = nil
	end
	for _, HL in Highlights do
		HL:Destroy()
	end
	table.clear(Highlights)
end

local function StartHighlightLoop()
	CleanupHighlights()
	HighlightConnection = RunService.PreRender:Connect(function()
		local Character = Player.Character
		local Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
		if not Root then
			return
		end

		local Folder = GetCoalFolder()
		if not Folder then
			return
		end

		local RootPos = Root.Position
		local Range = CoalConst.HIGHLIGHT_RANGE

		for CoalInst, HL in Highlights do
			if not CoalInst.Parent then
				HL:Destroy()
				Highlights[CoalInst] = nil
			end
		end

		for _, Child in Folder:GetChildren() do
			local CoalRoot = GetCoalRootPart(Child)
			if not CoalRoot or CoalRoot.Anchored then
				continue
			end

			local HL = Highlights[Child]
			if not HL then
				HL = Instance.new("Highlight")
				HL.FillTransparency = 1
				HL.OutlineColor = Color3.new(1, 1, 1)
				HL.OutlineTransparency = 1
				HL.Parent = Child
				Highlights[Child] = HL
			end

			local Distance = (RootPos - CoalRoot.Position).Magnitude
			if Distance >= Range then
				HL.OutlineTransparency = 1
			else
				HL.OutlineTransparency = Distance / Range
			end
		end
	end)
end

CoalNetwork.packets.CoalActive.listen(function(Data)
	Active = Data.Active
	RequiredCoal = Data.Required
	if Active and ScrollSpeedState.Active and not IsEliminated then
		CurrentCoal = 0
		StripClientSceneParts()
		StartHighlightLoop()
		UIState.SetCoalState(true, CurrentCoal, RequiredCoal)
	else
		Active = false
		StopCarrying()
		CleanupHighlights()
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

RoundNetwork.packets.PlayerEliminated.listen(function(Data)
	if Data.UserId == Player.UserId then
		IsEliminated = true
		if Active then
			Active = false
			StopCarrying()
			CleanupHighlights()
			UIState.SetCoalState(false, 0, 0)
		end
	end
end)

RoundNetwork.packets.PhaseChange.listen(function(Data)
	if Data.Phase == "Intermission" or Data.Phase == "Teleporting" then
		IsEliminated = false
	end
	if Data.Phase == "PostRound" or Data.Phase == "Intermission" then
		if Active then
			Active = false
			StopCarrying()
			CleanupHighlights()
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
	if Active then
		StartHighlightLoop()
	end
end)

function CoalController.IsActive(): boolean
	return Active
end

return CoalController
