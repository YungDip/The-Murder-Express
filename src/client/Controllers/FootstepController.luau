local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local FootstepNetwork = require(game:GetService("ReplicatedStorage").Shared.Network.FootstepNetwork)

local Player = Players.LocalPlayer
local StepFolder = SoundService:WaitForChild("Step")
local FootConst = Constants.Footstep

local FootstepController = {}

local SoundTemplates: {[string]: Sound} = {}
for _, MaterialName in FootConst.MATERIALS do
	local Sound = StepFolder:FindFirstChild(MaterialName)
	if Sound then
		SoundTemplates[MaterialName] = Sound
	end
end

local MaterialToIndex: {[string]: number} = {}
local IndexToMaterial: {[number]: string} = {}
for Index, MaterialName in FootConst.MATERIALS do
	MaterialToIndex[MaterialName] = Index
	IndexToMaterial[Index] = MaterialName
end

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetMaterialFromRaycast(Character: Model): string
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then return FootConst.DEFAULT_MATERIAL end

	RayParams.FilterDescendantsInstances = { Character }
	local Result = workspace:Raycast(Root.Position, Vector3.new(0, -FootConst.RAYCAST_DISTANCE, 0), RayParams)

	if Result and Result.Instance then
		local FloorMaterial = Result.Instance:GetAttribute("FloorMaterial")
		if FloorMaterial and typeof(FloorMaterial) == "string" and SoundTemplates[FloorMaterial] then
			return FloorMaterial
		end
	end

	return FootConst.DEFAULT_MATERIAL
end

local function PlayStepSound(Character: Model, MaterialName: string)
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then return end

	local Template = SoundTemplates[MaterialName]
	if not Template then return end

	local Sound = Template:Clone()
	Sound.Volume = FootConst.VOLUME
	Sound.PlaybackSpeed = math.random() * (FootConst.PITCH_MAX - FootConst.PITCH_MIN) + FootConst.PITCH_MIN
	Sound.Parent = Root
	Sound:Play()
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
end

local function GetHorizontalSpeed(Character: Model): number
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then return 0 end

	local Velocity = Root.AssemblyLinearVelocity
	return Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude
end

local function DisableDefaultFootsteps(Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local Root = Character:WaitForChild("HumanoidRootPart", 5)
	if not Root then return end

	local Running = Root:FindFirstChild("Running")
	if Running and Running:IsA("Sound") then
		Running.Volume = 0
		Running.PlayOnRemove = false
	end

	Root.ChildAdded:Connect(function(Child)
		if Child.Name == "Running" and Child:IsA("Sound") then
			Child.Volume = 0
			Child.PlayOnRemove = false
		end
	end)
end

local StepAccumulator = 0

local function UpdateLocalStepping(DeltaTime: number)
	local Character = Player.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local Speed = GetHorizontalSpeed(Character)
	if Speed < FootConst.MIN_SPEED_THRESHOLD then
		StepAccumulator = 0
		return
	end

	if Humanoid.FloorMaterial == Enum.Material.Air then
		StepAccumulator = 0
		return
	end

	local StepInterval = FootConst.BASE_STEP_INTERVAL * (FootConst.DEFAULT_WALK_SPEED / math.max(Speed, 1))
	StepAccumulator += DeltaTime

	if StepAccumulator >= StepInterval then
		StepAccumulator -= StepInterval

		local MaterialName = GetMaterialFromRaycast(Character)
		local MaterialIndex = MaterialToIndex[MaterialName] or 1

		FootstepNetwork.packets.FootstepToServer.send(MaterialIndex)

		PlayStepSound(Character, MaterialName)
	end
end

local function OnFootstepReceived(Data: {Player: Instance, Material: number})
	local SteppingPlayer = Data.Player
	if not SteppingPlayer or not SteppingPlayer:IsA("Player") then return end

	if SteppingPlayer == Player then return end

	local Character = SteppingPlayer.Character
	if not Character then return end

	local MaterialName = IndexToMaterial[Data.Material] or FootConst.DEFAULT_MATERIAL
	PlayStepSound(Character, MaterialName)
end

local function OnCharacterAdded(Character: Model)
	task.spawn(function()
		Character:WaitForChild("Humanoid", 5)
		DisableDefaultFootsteps(Character)
	end)
end

local function SetupPlayer(TargetPlayer: Player)
	if TargetPlayer.Character then
		OnCharacterAdded(TargetPlayer.Character)
	end
	TargetPlayer.CharacterAdded:Connect(OnCharacterAdded)
end

do
	for _, TargetPlayer in Players:GetPlayers() do
		SetupPlayer(TargetPlayer)
	end
	Players.PlayerAdded:Connect(SetupPlayer)

	FootstepNetwork.packets.FootstepToClient.listen(OnFootstepReceived)

	RunService.PreSimulation:Connect(UpdateLocalStepping)
end

return FootstepController
