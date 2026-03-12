local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoinNetwork = require(ReplicatedStorage.Shared.Network.CoinNetwork)

local CoinConst = Constants.Coin
local Player = Players.LocalPlayer
local CoinTemplate = ReplicatedStorage:WaitForChild("DebrisModels"):WaitForChild("Coin")
local Interactables = SoundService:WaitForChild("Interactables")
local CoinAuraSound = Interactables:WaitForChild("CoinAura")
local CoinCollectSound = Interactables:WaitForChild("CoinCollect")

local CoinController = {}

local CoinParts: { [number]: MeshPart } = {}
local CoinPositions: { [number]: Vector3 } = {}
local CoinFolder: Folder = Instance.new("Folder")
CoinFolder.Name = "ClientCoins"
CoinFolder.Parent = workspace

local LastCheckTime: number = 0

--[[
	clones a coin meshpart at the given position
]]
local function CreateCoin(Id: number, Position: Vector3)
	local Coin = CoinTemplate:Clone()
	Coin.Name = "Coin_" .. Id
	Coin.CFrame = CFrame.new(Position)
	Coin.Parent = CoinFolder

	local Aura = CoinAuraSound:Clone()
	Aura.Looped = true
	Aura.Parent = Coin
	Aura:Play()

	CoinParts[Id] = Coin
	CoinPositions[Id] = Position
end

--[[
	plays collect sound, tweens size to zero, then destroys the coin
]]
local function CollectCoin(Id: number)
	local Part = CoinParts[Id]
	CoinParts[Id] = nil
	CoinPositions[Id] = nil

	if not Part then
		return
	end

	local Aura = Part:FindFirstChild("CoinAura")
	if Aura then
		Aura:Stop()
	end

	local Sound = CoinCollectSound:Clone()
	Sound.Parent = Part
	Sound:Play()

	local Duration = Sound.TimeLength
	if Duration <= 0 then
		Duration = 0.3
	end

	local BasePosition = Part.Position
	local SpinConnection: RBXScriptConnection
	SpinConnection = RunService.PreRender:Connect(function()
		local Elapsed = os.clock()
		local SpinAngle = (Elapsed * CoinConst.COLLECT_SPIN_SPEED) % 360
		Part.CFrame = CFrame.new(BasePosition) * CFrame.Angles(0, math.rad(SpinAngle), 0)
	end)

	local Tween = TweenService:Create(Part, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.zero,
	})
	Tween:Play()
	Tween.Completed:Once(function()
		SpinConnection:Disconnect()
		Part:Destroy()
	end)
end

--[[
	clears all coins
]]
local function ClearAllCoins()
	for Id, Part in CoinParts do
		Part:Destroy()
	end
	table.clear(CoinParts)
	table.clear(CoinPositions)
end

--[[
	checks nearby coins for pickup
]]
local function CheckPickup()
	local Character = Player.Character
	if not Character then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end

	local RootPosition = Root.Position

	for Id, Position in CoinPositions do
		local Distance = (RootPosition - Position).Magnitude
		if Distance <= CoinConst.PICKUP_RADIUS then
			CoinNetwork.packets.RequestCollect.send({
				Id = Id,
			})
			return
		end
	end
end

CoinNetwork.packets.SpawnCoins.listen(function(Data)
	ClearAllCoins()
	for _, CoinData in Data.Coins do
		CreateCoin(CoinData.Id, Vector3.new(CoinData.X, CoinData.Y, CoinData.Z))
	end
end)

CoinNetwork.packets.CollectCoin.listen(function(Data)
	CollectCoin(Data.Id)
end)

CoinNetwork.packets.DespawnAll.listen(function()
	ClearAllCoins()
end)

RunService.PreRender:Connect(function(DeltaTime: number)
	local Now = os.clock()

	local Character = Player.Character
	local Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
	local RootPosition = if Root then Root.Position else nil

	-- Animate nearby coins via BulkMoveTo
	local Parts: { BasePart } = {}
	local CFrames: { CFrame } = {}

	for Id, Part in CoinParts do
		local BasePosition = CoinPositions[Id]
		if not BasePosition or not Part then
			continue
		end

		if RootPosition and (RootPosition - BasePosition).Magnitude > CoinConst.RENDER_DISTANCE then
			continue
		end

		local BobOffset = (math.sin(Now * CoinConst.BOB_FREQUENCY * math.pi * 2) * 0.5 + 0.5) * CoinConst.BOB_AMPLITUDE
		local SpinAngle = (Now * CoinConst.SPIN_SPEED) % 360

		table.insert(Parts, Part)
		table.insert(CFrames, CFrame.new(BasePosition + Vector3.new(0, BobOffset, 0)) * CFrame.Angles(0, math.rad(SpinAngle), 0))
	end

	if #Parts > 0 then
		workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Periodic pickup check
	LastCheckTime += DeltaTime
	if LastCheckTime >= CoinConst.CLIENT_CHECK_INTERVAL then
		LastCheckTime = 0
		CheckPickup()
	end
end)

-- Sync state on join
task.spawn(function()
	local State = CoinNetwork.queries.RequestCoinState.invoke({})
	if State and State.Active then
		for _, CoinData in State.Coins do
			CreateCoin(CoinData.Id, Vector3.new(CoinData.X, CoinData.Y, CoinData.Z))
		end
	end
end)

return CoinController
