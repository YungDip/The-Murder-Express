local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement
local Colors = Stylesheet.Colors
local Fonts = Stylesheet.FontFace
local Sizes = Stylesheet.TextSize
local Space = Stylesheet.Spacing

local MENU_WIDTH = 200
local VIEWPORT_HEIGHT = 180
local BUTTON_HEIGHT = 34
local ENTER_DURATION = 0.35
local EXIT_DURATION = 0.2

local LocalPlayer = Players.LocalPlayer

local function SubProgress(P: number, Start: number, Finish: number): number
	return math.clamp((P - Start) / (Finish - Start), 0, 1)
end

-- Renders a spinning 3D preview of the player's character
local function CharacterViewport(Props: {
	Player: Player,
	Opacity: any,
})
	local ViewportRef = React.useRef(nil :: ViewportFrame?)

	React.useEffect(function()
		local Viewport = ViewportRef.current
		if not Viewport then return end

		-- Clear any previous viewport contents
		for _, Child in Viewport:GetChildren() do
			if Child:IsA("WorldModel") or Child:IsA("Camera") then
				Child:Destroy()
			end
		end

		local Active = true

		task.spawn(function()
			local Success, Model = pcall(Players.CreateHumanoidModelFromUserId, Players, Props.Player.UserId)
			if not Success or not Active then
				if Model and typeof(Model) == "Instance" then
					Model:Destroy()
				end
				return
			end

			local Viewport = ViewportRef.current
			if not Viewport then
				Model:Destroy()
				return
			end

			for _, Descendant in Model:GetDescendants() do
				if Descendant:IsA("BaseScript") then
					Descendant:Destroy()
				end
			end

			local WorldModel = Instance.new("WorldModel")
			Model.Parent = WorldModel
			WorldModel.Parent = Viewport

			local Humanoid = Model:FindFirstChildWhichIsA("Humanoid")
			if Humanoid then
				local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
				if not Animator then
					Animator = Instance.new("Animator")
					Animator.Parent = Humanoid
				end
				local IdleAnim = Instance.new("Animation")
				IdleAnim.AnimationId = "rbxassetid://507766388"
				local Track = Animator:LoadAnimation(IdleAnim)
				Track.Looped = true
				Track:Play()
			end

			local Camera = Instance.new("Camera")
			Camera.FieldOfView = 50
			Camera.Parent = Viewport
			Viewport.CurrentCamera = Camera

			local Root = Model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local Head = Model:FindFirstChild("Head") :: BasePart?
			local FocusY = if Root then Root.Position.Y + 1.5
				elseif Head then Head.Position.Y
				else 3
			local Origin = if Root
				then Vector3.new(Root.Position.X, FocusY, Root.Position.Z)
				else Vector3.new(0, FocusY, 0)
			local Distance = 8
			local Angle = math.pi

			RunService.PreRender:Connect(function(DeltaTime: number)
				if not Active then return end
				Angle += DeltaTime * 0.4
				local CamPos = Origin + Vector3.new(
					math.sin(Angle) * Distance,
					0.5,
					math.cos(Angle) * Distance
				)
				Camera.CFrame = CFrame.lookAt(CamPos, Origin)
			end)
		end)

		return function()
			Active = false
			local Viewport = ViewportRef.current
			if Viewport then
				for _, Child in Viewport:GetChildren() do
					if Child:IsA("WorldModel") or Child:IsA("Camera") then
						Child:Destroy()
					end
				end
			end
		end
	end, { Props.Player })

	return E("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, VIEWPORT_HEIGHT),
		BackgroundColor3 = Colors.WarmBlack,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ImageTransparency = Props.Opacity:map(function(O: number) return 1 - O end),
		LightColor = Color3.fromRGB(200, 180, 160),
		LightDirection = Vector3.new(-1, -1, -1),
		Ambient = Color3.fromRGB(120, 110, 100),
		ref = ViewportRef,
		LayoutOrder = 1,
	}, {
		Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.MD }),
	})
end

-- Styled button for player actions
local function ActionButton(Props: {
	Text: string,
	Color: Color3?,
	TextColor: Color3?,
	LayoutOrder: number,
	Opacity: any,
	OnActivated: () -> (),
})
	return E("TextButton", {
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = Props.Color or Colors.MediumBrown,
		BackgroundTransparency = Props.Opacity:map(function(O: number) return 1 - O * 0.85 end),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = Props.LayoutOrder,
		[React.Event.Activated] = Props.OnActivated,
	}, {
		Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.MD }),

		Stroke = E("UIStroke", {
			Color = Colors.GoldDim,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = Props.Opacity:map(function(O: number) return 1 - O * 0.3 end),
		}),

		Label = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Fonts.Body,
			TextColor3 = Props.TextColor or Colors.Gold,
			TextSize = Sizes.Caption,
			Text = Props.Text,
			TextTransparency = Props.Opacity:map(function(O: number) return 1 - O end),
		}),
	})
end

-- Character viewport and action buttons for a selected player
local function PlayerActionMenu(Props: {
	Player: Player?,
	OffsetX: number,
	OnClose: () -> (),
})
	local Visible = Props.Player ~= nil
	local ShouldRender, Progress = Hooks.UseTransition(
		Visible,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutCubic,
		Easing.EaseInCubic
	)

	-- Keep reference to player during exit animation
	local DisplayPlayer, SetDisplayPlayer = React.useState(Props.Player)
	React.useEffect(function()
		if Props.Player then
			SetDisplayPlayer(Props.Player)
		end
	end, { Props.Player })

	-- Track friend status
	local FriendStatus, SetFriendStatus = React.useState(Enum.FriendStatus.Unknown :: Enum.FriendStatus)
	React.useEffect(function()
		if not DisplayPlayer or DisplayPlayer == LocalPlayer then return end

		local Success, Status = pcall(function()
			return LocalPlayer:GetFriendStatus(DisplayPlayer)
		end)
		if Success then
			SetFriendStatus(Status)
		end

		local Success2, Conn = pcall(function()
			return LocalPlayer.FriendStatusChanged:Connect(function(Player: Player, NewStatus: Enum.FriendStatus)
				if Player == DisplayPlayer then
					SetFriendStatus(NewStatus)
				end
			end)
		end)

		return function()
			if Success2 and Conn then
				Conn:Disconnect()
			end
		end
	end, { DisplayPlayer })

	if not ShouldRender or not DisplayPlayer then
		return nil
	end

	local IsLocalPlayer = DisplayPlayer == LocalPlayer

	local PanelOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0, 0.5))
	end)

	local ContentOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0.15, 0.7))
	end)

	local ButtonsOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0.3, 0.85))
	end)

	local SlideOffset = Progress:map(function(P: number)
		return math.floor(15 * (1 - P))
	end)

	-- Build action buttons
	local ActionChildren: { [string]: any } = {
		Layout = E("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Space.XS),
		}),
	}

	local ButtonIndex = 0

	ButtonIndex += 1
	ActionChildren["InspectAvatar"] = E(ActionButton, {
		Text = "Inspect Avatar",
		LayoutOrder = ButtonIndex,
		Opacity = ButtonsOpacity,
		OnActivated = function()
			pcall(GuiService.InspectPlayerFromUserId, GuiService, DisplayPlayer.UserId)
		end,
	})

	if not IsLocalPlayer then
		local IsFriend = FriendStatus == Enum.FriendStatus.Friend

		ButtonIndex += 1
		ActionChildren["Friend"] = E(ActionButton, {
			Text = if IsFriend then "Unfriend" else "Add Friend",
			LayoutOrder = ButtonIndex,
			Opacity = ButtonsOpacity,
			OnActivated = function()
				if IsFriend then
					pcall(StarterGui.SetCore, StarterGui, "PromptUnfriend", DisplayPlayer)
				else
					pcall(StarterGui.SetCore, StarterGui, "PromptSendFriendRequest", DisplayPlayer)
				end
			end,
		})

		ButtonIndex += 1
		ActionChildren["Block"] = E(ActionButton, {
			Text = "Block Player",
			Color = Colors.Danger,
			TextColor = Colors.WhiteMuted,
			LayoutOrder = ButtonIndex,
			Opacity = ButtonsOpacity,
			OnActivated = function()
				pcall(StarterGui.SetCore, StarterGui, "PromptBlockPlayer", DisplayPlayer)
			end,
		})
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = SlideOffset:map(function(Offset: number)
			return UDim2.new(1, -Props.OffsetX + Offset, 0, Space.SM + 36)
		end),
		Size = UDim2.new(0, MENU_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.DarkBrown,
		BackgroundTransparency = PanelOpacity:map(function(O: number) return 1 - O * 0.92 end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, {
		Corner = E("UICorner", { CornerRadius = Stylesheet.Corner.LG }),

		Stroke = E("UIStroke", {
			Color = Colors.GoldDim,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = PanelOpacity:map(function(O: number) return 1 - O * 0.5 end),
		}),

		Pad = E("UIPadding", {
			PaddingTop = UDim.new(0, Space.SM),
			PaddingBottom = UDim.new(0, Space.SM),
			PaddingLeft = UDim.new(0, Space.SM),
			PaddingRight = UDim.new(0, Space.SM),
		}),

		ContentLayout = E("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Space.SM),
		}),

		Header = E("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
		}, {
			DisplayName = E("TextLabel", {
				Size = UDim2.new(1, -28, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Fonts.Title,
				TextColor3 = Colors.Gold,
				TextSize = Sizes.Caption,
				Text = DisplayPlayer.DisplayName,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextTransparency = ContentOpacity:map(function(O: number) return 1 - O end),
			}),

			CloseBtn = E("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(24, 24),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				[React.Event.Activated] = Props.OnClose,
			}, {
				Icon = E("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Fonts.Title,
					TextColor3 = Colors.GoldMuted,
					TextSize = Sizes.Caption,
					Text = "\u{25B6}",
					TextTransparency = ContentOpacity:map(function(O: number) return 1 - O end),
				}),
			}),
		}),

		Viewport = E(CharacterViewport, {
			Player = DisplayPlayer,
			Opacity = ContentOpacity,
		}),

		Username = E("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			FontFace = Fonts.AccentLight,
			TextColor3 = Colors.GoldMuted,
			TextSize = Sizes.Small,
			Text = "@" .. DisplayPlayer.Name,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = ContentOpacity:map(function(O: number) return 1 - O end),
			LayoutOrder = 2,
		}),

		Sep = E("Frame", {
			Size = ContentOpacity:map(function(O: number)
				return UDim2.new(0.8 * O, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = ContentOpacity:map(function(O: number) return 1 - O * 0.35 end),
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}),

		Actions = E("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}, ActionChildren),
	})
end

return PlayerActionMenu
