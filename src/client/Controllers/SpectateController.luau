local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundNetwork = require(ReplicatedStorage.Shared.Network.RoundNetwork)
local Constants = require(ReplicatedStorage.Shared.Constants)

local RoundConst = Constants.Round
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera
local PlayerModule = require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))

local SpectateController = {}

local CurrentPhase: string = "Intermission"
local ParticipantIds: { number } = {}
local EliminatedUserIds: { [number]: boolean } = {}
local IsSpectating = false
local IsFreecam = false
local SpectateTargetIndex = 0
local FreecamCFrame = CFrame.new(0, 20, 0)

local FreecamMoveInput = Vector2.zero
local FreecamPitch = 0
local FreecamYaw = 0
local FreecamZoom = 0
local FREECAM_SPEED = 50
local FREECAM_SENSITIVITY = 0.003
local FREECAM_ZOOM_SPEED = 10
local FREECAM_MIN_ZOOM = -100
local FREECAM_MAX_ZOOM = 100
local FREECAM_BOUNDS_MARGIN = 50
local TouchDragging = false
local TouchStartPos = Vector2.zero
local LastTouchPos = Vector2.zero
local IsMouseLocked = false

local SpectateGui = Instance.new("ScreenGui")
SpectateGui.Name = "SpectateGui"
SpectateGui.ResetOnSpawn = false
SpectateGui.IgnoreGuiInset = true
SpectateGui.DisplayOrder = 50
SpectateGui.Parent = PlayerGui

local SpectateButton = Instance.new("TextButton")
SpectateButton.Name = "SpectateButton"
SpectateButton.AnchorPoint = Vector2.new(0.5, 1)
SpectateButton.Position = UDim2.new(0.5, 0, 0.92, 0)
SpectateButton.Size = UDim2.new(0, 180, 0, 48)
SpectateButton.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
SpectateButton.BackgroundTransparency = 0.2
SpectateButton.BorderSizePixel = 0
SpectateButton.Text = ""
SpectateButton.AutoButtonColor = true
SpectateButton.Visible = false
SpectateButton.Parent = SpectateGui

local SpectateButtonCorner = Instance.new("UICorner")
SpectateButtonCorner.CornerRadius = UDim.new(0, 8)
SpectateButtonCorner.Parent = SpectateButton

local SpectateButtonStroke = Instance.new("UIStroke")
SpectateButtonStroke.Color = RoundConst.TIMER_BORDER_COLOR
SpectateButtonStroke.Thickness = 2
SpectateButtonStroke.Parent = SpectateButton

local SpectateButtonLayout = Instance.new("UIListLayout")
SpectateButtonLayout.FillDirection = Enum.FillDirection.Horizontal
SpectateButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SpectateButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SpectateButtonLayout.Padding = UDim.new(0, 8)
SpectateButtonLayout.Parent = SpectateButton

local EyeIcon = Instance.new("ImageLabel")
EyeIcon.Name = "EyeIcon"
EyeIcon.Size = UDim2.fromOffset(24, 24)
EyeIcon.BackgroundTransparency = 1
EyeIcon.Image = "rbxassetid://1137376344"
EyeIcon.ImageColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
EyeIcon.LayoutOrder = 1
EyeIcon.Parent = SpectateButton

local SpectateButtonLabel = Instance.new("TextLabel")
SpectateButtonLabel.Name = "Label"
SpectateButtonLabel.Size = UDim2.fromOffset(90, 24)
SpectateButtonLabel.BackgroundTransparency = 1
SpectateButtonLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
SpectateButtonLabel.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
SpectateButtonLabel.TextSize = 20
SpectateButtonLabel.Text = "Spectate"
SpectateButtonLabel.TextXAlignment = Enum.TextXAlignment.Left
SpectateButtonLabel.LayoutOrder = 2
SpectateButtonLabel.Parent = SpectateButton

local SpectateHUD = Instance.new("Frame")
SpectateHUD.Name = "SpectateHUD"
SpectateHUD.Size = UDim2.fromScale(1, 1)
SpectateHUD.BackgroundTransparency = 1
SpectateHUD.Visible = false
SpectateHUD.Parent = SpectateGui

local SpectateNameLabel = Instance.new("TextLabel")
SpectateNameLabel.Name = "SpectateName"
SpectateNameLabel.AnchorPoint = Vector2.new(0.5, 0)
SpectateNameLabel.Position = UDim2.new(0.5, 0, 0.06, 0)
SpectateNameLabel.Size = UDim2.new(0.3, 0, 0, 30)
SpectateNameLabel.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
SpectateNameLabel.BackgroundTransparency = 0.4
SpectateNameLabel.BorderSizePixel = 0
SpectateNameLabel.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Regular)
SpectateNameLabel.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
SpectateNameLabel.TextSize = 18
SpectateNameLabel.Text = "Spectating: Player"
SpectateNameLabel.Parent = SpectateHUD

local SpectateNameCorner = Instance.new("UICorner")
SpectateNameCorner.CornerRadius = UDim.new(0, 6)
SpectateNameCorner.Parent = SpectateNameLabel

local LeftArrow = Instance.new("TextButton")
LeftArrow.Name = "LeftArrow"
LeftArrow.AnchorPoint = Vector2.new(0, 0.5)
LeftArrow.Position = UDim2.new(0.02, 0, 0.5, 0)
LeftArrow.Size = UDim2.fromOffset(48, 48)
LeftArrow.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
LeftArrow.BackgroundTransparency = 0.3
LeftArrow.BorderSizePixel = 0
LeftArrow.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
LeftArrow.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
LeftArrow.TextSize = 28
LeftArrow.Text = "◀"
LeftArrow.Parent = SpectateHUD

local LeftCorner = Instance.new("UICorner")
LeftCorner.CornerRadius = UDim.new(0, 8)
LeftCorner.Parent = LeftArrow

local RightArrow = Instance.new("TextButton")
RightArrow.Name = "RightArrow"
RightArrow.AnchorPoint = Vector2.new(1, 0.5)
RightArrow.Position = UDim2.new(0.98, 0, 0.5, 0)
RightArrow.Size = UDim2.fromOffset(48, 48)
RightArrow.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
RightArrow.BackgroundTransparency = 0.3
RightArrow.BorderSizePixel = 0
RightArrow.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
RightArrow.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
RightArrow.TextSize = 28
RightArrow.Text = "▶"
RightArrow.Parent = SpectateHUD

local RightCorner = Instance.new("UICorner")
RightCorner.CornerRadius = UDim.new(0, 8)
RightCorner.Parent = RightArrow

local FreecamButton = Instance.new("TextButton")
FreecamButton.Name = "FreecamToggle"
FreecamButton.AnchorPoint = Vector2.new(0.5, 1)
FreecamButton.Position = UDim2.new(0.5, 0, 0.92, 0)
FreecamButton.Size = UDim2.fromOffset(140, 40)
FreecamButton.BackgroundColor3 = RoundConst.TIMER_BG_COLOR
FreecamButton.BackgroundTransparency = 0.3
FreecamButton.BorderSizePixel = 0
FreecamButton.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
FreecamButton.TextColor3 = RoundConst.SCOREBOARD_TEXT_COLOR
FreecamButton.TextSize = 18
FreecamButton.Text = "Free Cam"
FreecamButton.Parent = SpectateHUD

local FreecamCorner = Instance.new("UICorner")
FreecamCorner.CornerRadius = UDim.new(0, 8)
FreecamCorner.Parent = FreecamButton

local ExitButton = Instance.new("TextButton")
ExitButton.Name = "ExitSpectate"
ExitButton.AnchorPoint = Vector2.new(0.5, 1)
ExitButton.Position = UDim2.new(0.5, 0, 0.97, 0)
ExitButton.Size = UDim2.fromOffset(100, 36)
ExitButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
ExitButton.BackgroundTransparency = 0.3
ExitButton.BorderSizePixel = 0
ExitButton.FontFace = Font.new(RoundConst.TIMER_FONT, Enum.FontWeight.Bold)
ExitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitButton.TextSize = 18
ExitButton.Text = "Exit"
ExitButton.Parent = SpectateHUD

local ExitCorner = Instance.new("UICorner")
ExitCorner.CornerRadius = UDim.new(0, 8)
ExitCorner.Parent = ExitButton

local function IsLocalParticipant(): boolean
	for _, Id in ParticipantIds do
		if Id == Player.UserId then
			return true
		end
	end
	return false
end

local function GetAliveParticipants(): { Player }
	local Alive = {}
	for _, Id in ParticipantIds do
		if not EliminatedUserIds[Id] and Id ~= Player.UserId then
			local P = Players:GetPlayerByUserId(Id)
			if P and P.Character and P.Character:FindFirstChildOfClass("Humanoid") then
				local Humanoid = P.Character:FindFirstChildOfClass("Humanoid")
				if Humanoid.Health > 0 then
					table.insert(Alive, P)
				end
			end
		end
	end
	return Alive
end

local function GetTrainBounds(): (Vector3, Vector3)
	local TrainFolder = workspace:FindFirstChild("Train")
	if not TrainFolder then
		return Vector3.new(-200, -50, -200), Vector3.new(200, 100, 200)
	end

	local MinBound = Vector3.new(math.huge, math.huge, math.huge)
	local MaxBound = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, Descendant in TrainFolder:GetDescendants() do
		if Descendant:IsA("BasePart") then
			local Pos = Descendant.Position
			local HalfSize = Descendant.Size / 2
			MinBound = MinBound:Min(Pos - HalfSize)
			MaxBound = MaxBound:Max(Pos + HalfSize)
		end
	end

	MinBound = MinBound - Vector3.new(FREECAM_BOUNDS_MARGIN, FREECAM_BOUNDS_MARGIN, FREECAM_BOUNDS_MARGIN)
	MaxBound = MaxBound + Vector3.new(FREECAM_BOUNDS_MARGIN, FREECAM_BOUNDS_MARGIN, FREECAM_BOUNDS_MARGIN)

	return MinBound, MaxBound
end

local function ClampToTrainBounds(Position: Vector3): Vector3
	local MinBound, MaxBound = GetTrainBounds()
	return Vector3.new(
		math.clamp(Position.X, MinBound.X, MaxBound.X),
		math.clamp(Position.Y, MinBound.Y, MaxBound.Y),
		math.clamp(Position.Z, MinBound.Z, MaxBound.Z)
	)
end

local function UpdateSpectateTarget()
	local Alive = GetAliveParticipants()

	if #Alive == 0 then
		if IsSpectating and not IsFreecam then
			IsFreecam = true
			FreecamButton.Text = "Follow Cam"
			Camera.CameraType = Enum.CameraType.Scriptable
			FreecamCFrame = Camera.CFrame
			FreecamPitch = 0
			FreecamYaw = 0
			SpectateNameLabel.Text = "Free Camera"
			LeftArrow.Visible = false
			RightArrow.Visible = false
		end
		return
	end

	if SpectateTargetIndex < 1 or SpectateTargetIndex > #Alive then
		SpectateTargetIndex = 1
	end

	local Target = Alive[SpectateTargetIndex]
	if Target and Target.Character then
		local Humanoid = Target.Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CameraSubject = Humanoid
			SpectateNameLabel.Text = "Spectating: " .. Target.DisplayName
		end
	end

	LeftArrow.Visible = #Alive > 1
	RightArrow.Visible = #Alive > 1
end

local function StartSpectate()
	if IsSpectating then
		return
	end
	IsSpectating = true
	IsFreecam = false
	SpectateTargetIndex = 1
	SpectateButton.Visible = false
	SpectateHUD.Visible = true
	FreecamButton.Text = "Free Cam"
	LeftArrow.Visible = true
	RightArrow.Visible = true

	PlayerModule:GetControls():Disable()

	UpdateSpectateTarget()
end

local function StopSpectate()
	if not IsSpectating then
		return
	end
	IsSpectating = false
	IsFreecam = false
	SpectateHUD.Visible = false
	FreecamMoveInput = Vector2.zero

	if IsMouseLocked then
		IsMouseLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	PlayerModule:GetControls():Enable()

	Camera.CameraType = Enum.CameraType.Custom
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Camera.CameraSubject = Humanoid
		end
	end

	if CurrentPhase == "InProgress" or CurrentPhase == "RoleReveal" then
		SpectateButton.Visible = true
	end
end

local function ToggleFreecam()
	if not IsSpectating then
		return
	end

	IsFreecam = not IsFreecam

	if IsFreecam then
		FreecamButton.Text = "Follow Cam"
		Camera.CameraType = Enum.CameraType.Scriptable
		FreecamCFrame = Camera.CFrame
		FreecamZoom = 0
		local LookVector = FreecamCFrame.LookVector
		FreecamPitch = math.asin(-LookVector.Y)
		FreecamYaw = math.atan2(LookVector.X, LookVector.Z)
		SpectateNameLabel.Text = "Free Camera"
		LeftArrow.Visible = false
		RightArrow.Visible = false
	else
		FreecamButton.Text = "Free Cam"
		FreecamMoveInput = Vector2.zero
		FreecamZoom = 0
		if IsMouseLocked then
			IsMouseLocked = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		LeftArrow.Visible = true
		RightArrow.Visible = true
		UpdateSpectateTarget()
	end
end

local function CycleTarget(Direction: number)
	if IsFreecam then
		return
	end

	local Alive = GetAliveParticipants()
	if #Alive <= 1 then
		return
	end

	SpectateTargetIndex = SpectateTargetIndex + Direction
	if SpectateTargetIndex < 1 then
		SpectateTargetIndex = #Alive
	elseif SpectateTargetIndex > #Alive then
		SpectateTargetIndex = 1
	end

	UpdateSpectateTarget()
end

SpectateButton.MouseButton1Click:Connect(StartSpectate)
ExitButton.MouseButton1Click:Connect(StopSpectate)
FreecamButton.MouseButton1Click:Connect(ToggleFreecam)
LeftArrow.MouseButton1Click:Connect(function()
	CycleTarget(-1)
end)
RightArrow.MouseButton1Click:Connect(function()
	CycleTarget(1)
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed or not IsSpectating or not IsFreecam then
		return
	end

	if Input.KeyCode == Enum.KeyCode.A then
		FreecamMoveInput = Vector2.new(-1, FreecamMoveInput.Y)
	elseif Input.KeyCode == Enum.KeyCode.D then
		FreecamMoveInput = Vector2.new(1, FreecamMoveInput.Y)
	elseif Input.KeyCode == Enum.KeyCode.E or Input.KeyCode == Enum.KeyCode.Space then
		FreecamMoveInput = Vector2.new(FreecamMoveInput.X, 1)
	elseif Input.KeyCode == Enum.KeyCode.Q or Input.KeyCode == Enum.KeyCode.LeftShift then
		FreecamMoveInput = Vector2.new(FreecamMoveInput.X, -1)
	end

	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsMouseLocked = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(Input, GameProcessed)
	if not IsSpectating or not IsFreecam then
		return
	end

	if Input.KeyCode == Enum.KeyCode.A or Input.KeyCode == Enum.KeyCode.D then
		FreecamMoveInput = Vector2.new(0, FreecamMoveInput.Y)
	elseif Input.KeyCode == Enum.KeyCode.E or Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.Q or Input.KeyCode == Enum.KeyCode.LeftShift then
		FreecamMoveInput = Vector2.new(FreecamMoveInput.X, 0)
	end

	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsMouseLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UserInputService.InputChanged:Connect(function(Input, GameProcessed)
	if not IsSpectating or not IsFreecam then
		return
	end

	if Input.UserInputType == Enum.UserInputType.MouseMovement then
		if IsMouseLocked then
			FreecamYaw = FreecamYaw - Input.Delta.X * FREECAM_SENSITIVITY
			FreecamPitch = math.clamp(FreecamPitch - Input.Delta.Y * FREECAM_SENSITIVITY, -math.rad(80), math.rad(80))
		end
	elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
		FreecamZoom = FreecamZoom + Input.Position.Z * FREECAM_ZOOM_SPEED
		FreecamZoom = math.clamp(FreecamZoom, FREECAM_MIN_ZOOM, FREECAM_MAX_ZOOM)
	end
end)

UserInputService.TouchStarted:Connect(function(Input, GameProcessed)
	if GameProcessed or not IsSpectating or not IsFreecam then
		return
	end
	if Input.Position.X > Camera.ViewportSize.X * 0.5 then
		TouchDragging = true
		TouchStartPos = Vector2.new(Input.Position.X, Input.Position.Y)
		LastTouchPos = TouchStartPos
	end
end)

UserInputService.TouchMoved:Connect(function(Input)
	if not TouchDragging or not IsSpectating or not IsFreecam then
		return
	end
	local CurrentPos = Vector2.new(Input.Position.X, Input.Position.Y)
	local Delta = CurrentPos - LastTouchPos
	LastTouchPos = CurrentPos
	FreecamYaw = FreecamYaw - Delta.X * FREECAM_SENSITIVITY * 2
	FreecamPitch = math.clamp(FreecamPitch - Delta.Y * FREECAM_SENSITIVITY * 2, -math.rad(80), math.rad(80))
end)

UserInputService.TouchEnded:Connect(function()
	TouchDragging = false
end)

RunService.PreRender:Connect(function(DeltaTime: number)
	if not IsSpectating then
		return
	end

	if not IsSpectating then
		local ShouldShow = (CurrentPhase == "InProgress" or CurrentPhase == "RoleReveal") and not IsLocalParticipant()
		SpectateButton.Visible = ShouldShow
	end

	if not IsFreecam then
		local Alive = GetAliveParticipants()
		if #Alive == 0 and not IsFreecam then
			IsFreecam = true
			FreecamButton.Text = "Follow Cam"
			Camera.CameraType = Enum.CameraType.Scriptable
			FreecamCFrame = Camera.CFrame
			FreecamPitch = 0
			FreecamYaw = 0
			SpectateNameLabel.Text = "Free Camera"
			LeftArrow.Visible = false
			RightArrow.Visible = false
		end
		return
	end

	local Rotation = CFrame.fromEulerAnglesYXZ(FreecamPitch, FreecamYaw, 0)
	local RightDir = Rotation.RightVector * FreecamMoveInput.X
	local UpDir = Vector3.new(0, FreecamMoveInput.Y, 0)
	local MoveDir = RightDir + UpDir

	if MoveDir.Magnitude > 0 then
		MoveDir = MoveDir.Unit
	end

	local ZoomDelta = Rotation.LookVector * FreecamZoom

	local NewPos = FreecamCFrame.Position + MoveDir * FREECAM_SPEED * DeltaTime + ZoomDelta
	NewPos = ClampToTrainBounds(NewPos)
	FreecamCFrame = CFrame.new(NewPos) * Rotation
	Camera.CFrame = FreecamCFrame
	FreecamZoom = 0
end)

RoundNetwork.packets.PhaseChange.listen(function(Data)
	CurrentPhase = Data.Phase

	if Data.Phase == "Intermission" or Data.Phase == "PostRound" then
		StopSpectate()
		SpectateButton.Visible = false
	elseif Data.Phase == "InProgress" then
		if not IsLocalParticipant() and not IsSpectating then
			SpectateButton.Visible = true
		end
	elseif Data.Phase == "Teleporting" or Data.Phase == "RoleReveal" then
		SpectateButton.Visible = false
	end
end)

RoundNetwork.packets.ParticipantList.listen(function(Data)
	ParticipantIds = Data.PlayerIds
	if (CurrentPhase == "InProgress" or CurrentPhase == "RoleReveal") and not IsLocalParticipant() then
		SpectateButton.Visible = true
	end
end)

RoundNetwork.packets.PlayerEliminated.listen(function(Data)
	EliminatedUserIds[Data.UserId] = true

	if IsSpectating and not IsFreecam then
		UpdateSpectateTarget()
	end
end)

task.spawn(function()
	local State = RoundNetwork.queries.RequestRoundState.invoke(nil)
	if not State then
		return
	end

	CurrentPhase = State.Phase
	ParticipantIds = State.ParticipantIds or {}

	if State.Eliminated then
		for _, Entry in State.Eliminated do
			EliminatedUserIds[Entry.UserId] = true
		end
	end

	if (State.Phase == "InProgress") and not IsLocalParticipant() then
		SpectateButton.Visible = true
	end
end)

function SpectateController.IsSpectating(): boolean
	return IsSpectating
end

function SpectateController.StartSpectate()
	StartSpectate()
end

function SpectateController.StopSpectate()
	StopSpectate()
end

return SpectateController
