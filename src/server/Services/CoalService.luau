local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoalNetwork = require(ReplicatedStorage.Shared.Network.CoalNetwork)
local AnnouncementService = require(script.Parent.AnnouncementService)

local CoalConst = Constants.Coal
local CoalService = {}

local Active = false
local CurrentCoal = 0
local RequiredCoal = CoalConst.REQUIRED_COAL
local GrabbedCoals: { [BasePart]: Player } = {}
local PlayerGrabbedCoal: { [Player]: BasePart } = {}
local CollectedCoals: { [BasePart]: boolean } = {}
local TouchConnections: { [BasePart]: RBXScriptConnection } = {}
local ClickConnections: { RBXScriptConnection } = {}
local SpawnedParts: { Instance } = {}
local FilledCallback: (() -> ())? = nil

local function BroadcastCoalState()
	CoalNetwork.packets.CoalState.sendToAll({
		Current = CurrentCoal,
		Required = RequiredCoal,
	})
end

local function CollectAnimation(Coal: BasePart, CollectionPart: BasePart)
	Coal.Anchored = true
	Coal.CanCollide = false

	local CollectionCenter = CollectionPart.Position
	local CoalPos = Coal.Position

	-- Slide to the collection part's X,Z while keeping current Y
	local SlideCF = CFrame.new(CollectionCenter.X, CoalPos.Y, CollectionCenter.Z)
	local SlideTween = TweenService:Create(Coal, TweenInfo.new(CoalConst.SLIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = SlideCF,
	})
	SlideTween:Play()
	SlideTween.Completed:Wait()

	-- Fall down to the collection part's Y center
	local FallCF = CFrame.new(CollectionCenter.X, CollectionCenter.Y, CollectionCenter.Z)
	local FallTween = TweenService:Create(Coal, TweenInfo.new(CoalConst.FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = FallCF,
	})
	FallTween:Play()
	FallTween.Completed:Wait()

	-- Shrink into nothing
	local ShrinkTween = TweenService:Create(Coal, TweenInfo.new(CoalConst.SHRINK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.zero,
		CFrame = FallCF,
	})
	ShrinkTween:Play()
	ShrinkTween.Completed:Wait()
	Coal:Destroy()
end

local function ReleaseCoal(PlayerRef: Player)
	local Coal = PlayerGrabbedCoal[PlayerRef]
	if not Coal then
		return
	end

	PlayerGrabbedCoal[PlayerRef] = nil
	GrabbedCoals[Coal] = nil

	if Coal.Parent then
		pcall(function()
			Coal:SetNetworkOwnershipAuto()
		end)
	end

	CoalNetwork.packets.CoalReleased.sendTo({
		CoalName = Coal.Name,
	}, PlayerRef)
end

local function OnCoalTouchCollection(Coal: BasePart, OtherPart: BasePart)
	if not Active then
		return
	end
	if CollectedCoals[Coal] then
		return
	end
	if not CollectionService:HasTag(OtherPart, CoalConst.COLLECTION_TAG) then
		return
	end

	CollectedCoals[Coal] = true
	CurrentCoal += 1

	local GrabbingPlayer = GrabbedCoals[Coal]
	local CollectorUserId = if GrabbingPlayer then GrabbingPlayer.UserId else 0

	if GrabbingPlayer then
		PlayerGrabbedCoal[GrabbingPlayer] = nil
		CoalNetwork.packets.CoalReleased.sendTo({
			CoalName = Coal.Name,
		}, GrabbingPlayer)
	end
	GrabbedCoals[Coal] = nil

	if TouchConnections[Coal] then
		TouchConnections[Coal]:Disconnect()
		TouchConnections[Coal] = nil
	end

	local ClickDetector = Coal:FindFirstChildOfClass("ClickDetector")
	if ClickDetector then
		ClickDetector:Destroy()
	end

	CoalNetwork.packets.CoalCollected.sendToAll({
		CoalName = Coal.Name,
		CollectorUserId = CollectorUserId,
		Current = CurrentCoal,
		Required = RequiredCoal,
	})

	task.spawn(CollectAnimation, Coal, OtherPart)

	if CurrentCoal >= RequiredCoal then
		CoalNetwork.packets.CoalFilled.sendToAll({
			BoardingTime = CoalConst.BOARDING_WARNING_DURATION,
		})
		AnnouncementService.AnnounceAll(
			"Coal Loaded!",
			"Board the train! Departing in " .. CoalConst.BOARDING_WARNING_DURATION .. " seconds!",
			CoalConst.BOARDING_WARNING_DURATION - 2,
			true
		)
		if FilledCallback then
			task.spawn(FilledCallback)
		end
	end
end

local function SetupCoalPart(Coal: BasePart)
	local ClickDetector = Instance.new("ClickDetector")
	ClickDetector.MaxActivationDistance = CoalConst.PICKUP_MAX_DISTANCE
	ClickDetector.Parent = Coal

	local ClickConn = ClickDetector.MouseClick:Connect(function(PlayerWhoClicked: Player)
		if not Active then
			return
		end
		if CollectedCoals[Coal] then
			return
		end

		if GrabbedCoals[Coal] then
			return
		end
		if PlayerGrabbedCoal[PlayerWhoClicked] then
			return
		end

		GrabbedCoals[Coal] = PlayerWhoClicked
		PlayerGrabbedCoal[PlayerWhoClicked] = Coal

		pcall(function()
			Coal:SetNetworkOwner(PlayerWhoClicked)
		end)

		CoalNetwork.packets.CoalGrabbed.sendTo({
			CoalName = Coal.Name,
		}, PlayerWhoClicked)
	end)

	table.insert(ClickConnections, ClickConn)

	TouchConnections[Coal] = Coal.Touched:Connect(function(OtherPart: BasePart)
		OnCoalTouchCollection(Coal, OtherPart)
	end)
end

--[[
	Clones tagged coal + collection parts from the LeftStop template to the server
]]
local function SpawnCoalPartsAtScene(SceneCFrame: CFrame)
	local ZoneModels = ReplicatedStorage:WaitForChild("ZoneModels") :: Folder
	local Template = ZoneModels:FindFirstChild("LeftStop")
	if not Template then
		warn("[CoalService] LeftStop template not found in ZoneModels")
		return
	end

	local TemplatePivot = Template:GetPivot()

	local CoalFolder = Instance.new("Folder")
	CoalFolder.Name = "ServerCoal"
	CoalFolder.Parent = workspace

	-- Ground plane so coal doesn't fall through the void (baseplates are client-only)
	local Ground = Instance.new("Part")
	Ground.Name = "CoalGround"
	Ground.Size = CoalConst.GROUND_SIZE
	Ground.CFrame = SceneCFrame * CFrame.new(0, CoalConst.GROUND_Y_OFFSET, 0)
	Ground.Anchored = true
	Ground.CanCollide = true
	Ground.Transparency = 1
	Ground.Parent = CoalFolder
	table.insert(SpawnedParts, Ground)

	-- Clone CoalCollection tagged parts (deposit zones)
	for _, Descendant in Template:GetDescendants() do
		if Descendant:IsA("BasePart") and CollectionService:HasTag(Descendant, CoalConst.COLLECTION_TAG) then
			local RelativeCF = TemplatePivot:Inverse() * Descendant.CFrame
			local Clone = Descendant:Clone()
			Clone.CFrame = SceneCFrame * RelativeCF
			Clone.Anchored = true
			Clone.Parent = CoalFolder
			table.insert(SpawnedParts, Clone)
		end
	end

	-- Clone MoveableCoal tagged parts
	for _, Descendant in Template:GetDescendants() do
		if Descendant:IsA("BasePart") and CollectionService:HasTag(Descendant, CoalConst.COAL_NAME) then
			local RelativeCF = TemplatePivot:Inverse() * Descendant.CFrame
			local Coal = Descendant:Clone()
			Coal.Name = HttpService:GenerateGUID(false)
			Coal.CFrame = SceneCFrame * RelativeCF
			Coal.Anchored = false
			Coal.CanCollide = true
			Coal.Parent = CoalFolder
			table.insert(SpawnedParts, Coal)
		end
	end
end

--[[
	Cleans up all spawned server coal parts, ground, and collection zones
]]
local function CleanupSpawnedParts()
	for _, Part in SpawnedParts do
		if Part.Parent then
			Part:Destroy()
		end
	end
	table.clear(SpawnedParts)

	local CoalFolder = workspace:FindFirstChild("ServerCoal")
	if CoalFolder then
		CoalFolder:Destroy()
	end
end

--[[
	Activates the coal collection system, spawning coal at the given scene CFrame
]]
function CoalService.Activate(Required: number?, SceneCFrame: CFrame?)
	RequiredCoal = Required or CoalConst.REQUIRED_COAL
	CurrentCoal = 0
	table.clear(GrabbedCoals)
	table.clear(PlayerGrabbedCoal)
	table.clear(CollectedCoals)

	for _, Connection in TouchConnections do
		Connection:Disconnect()
	end
	table.clear(TouchConnections)

	for _, Connection in ClickConnections do
		Connection:Disconnect()
	end
	table.clear(ClickConnections)

	CleanupSpawnedParts()

	Active = true

	if SceneCFrame then
		SpawnCoalPartsAtScene(SceneCFrame)
	end

	-- Set up click + touch on coal parts (those not anchored = actual coal pieces)
	local CoalFolder = workspace:FindFirstChild("ServerCoal")
	if CoalFolder then
		for _, Child in CoalFolder:GetChildren() do
			if Child:IsA("BasePart") and not Child.Anchored then
				SetupCoalPart(Child)
			end
		end
	end

	CoalNetwork.packets.CoalActive.sendToAll({
		Active = true,
		Required = RequiredCoal,
	})

	BroadcastCoalState()
end

--[[
	Deactivates the coal collection system and cleans up
]]
function CoalService.Deactivate()
	Active = false
	FilledCallback = nil

	for _, Connection in TouchConnections do
		Connection:Disconnect()
	end
	table.clear(TouchConnections)

	for _, Connection in ClickConnections do
		Connection:Disconnect()
	end
	table.clear(ClickConnections)

	-- Release any players still carrying coal
	for PlayerRef, _ in PlayerGrabbedCoal do
		CoalNetwork.packets.CoalReleased.sendTo({
			CoalName = "",
		}, PlayerRef)
	end

	table.clear(GrabbedCoals)
	table.clear(PlayerGrabbedCoal)
	table.clear(CollectedCoals)

	CleanupSpawnedParts()

	CoalNetwork.packets.CoalActive.sendToAll({
		Active = false,
		Required = RequiredCoal,
	})
end

--[[
	Returns true when enough coal has been collected
]]
function CoalService.IsFilled(): boolean
	return CurrentCoal >= RequiredCoal
end

--[[
	Returns the current and required coal counts
]]
function CoalService.GetState(): (number, number, boolean)
	return CurrentCoal, RequiredCoal, Active
end

--[[
	Yields until enough coal has been collected
	(@yields)
]]
function CoalService.WaitForFilled()
	if CurrentCoal >= RequiredCoal then
		return
	end

	local Thread = coroutine.running()
	FilledCallback = function()
		FilledCallback = nil
		task.spawn(Thread)
	end
	coroutine.yield()
end

-- Handle release requests from clients
CoalNetwork.packets.RequestRelease.listen(function(Data, Player: Player)
	if not Active then
		return
	end
	ReleaseCoal(Player)
end)

-- Handle player disconnects while carrying
game:GetService("Players").PlayerRemoving:Connect(function(Player: Player)
	if PlayerGrabbedCoal[Player] then
		ReleaseCoal(Player)
	end
end)

CoalNetwork.queries.RequestCoalState.listen(function()
	return {
		Active = Active,
		Current = CurrentCoal,
		Required = RequiredCoal,
	}
end)

return CoalService
