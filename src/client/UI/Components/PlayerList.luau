local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.react)

local Stylesheet = require(script.Parent.Parent.Stylesheet)
local Hooks = require(script.Parent.Parent.Hooks)
local Easing = require(script.Parent.Parent.Easing)
local PlayerActionMenu = require(script.Parent.PlayerActionMenu)
local CarouselText = require(script.Parent.CarouselText)

local E = React.createElement
local Colors = Stylesheet.Colors
local Fonts = Stylesheet.FontFace
local Sizes = Stylesheet.TextSize
local Space = Stylesheet.Spacing

local ENTER_DURATION = 0.45
local EXIT_DURATION = 0.3
local ROW_HEIGHT = 42
local HEADER_HEIGHT = 28
local STAT_COL_WIDTH = 70
local AVATAR_SIZE = 28
local LIST_WIDTH = 280

local function SubProgress(P: number, Start: number, Finish: number): number
	return math.clamp((P - Start) / (Finish - Start), 0, 1)
end

local function GetHeadshotUrl(UserId: number): string
	return string.format(
		"rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48",
		UserId
	)
end

local function GetStatColumns(): { string }
	local Columns = {}
	local ColumnSet = {}
	for _, Player in Players:GetPlayers() do
		local Leaderstats = Player:FindFirstChild("leaderstats")
		if Leaderstats then
			for _, Stat in Leaderstats:GetChildren() do
				if Stat:IsA("ValueBase") and not ColumnSet[Stat.Name] then
					ColumnSet[Stat.Name] = true
					table.insert(Columns, Stat.Name)
				end
			end
		end
	end
	return Columns
end

local function GetStatValue(Player: Player, StatName: string): string
	local Leaderstats = Player:FindFirstChild("leaderstats")
	if not Leaderstats then
		return "-"
	end
	local Stat = Leaderstats:FindFirstChild(StatName)
	if Stat and Stat:IsA("ValueBase") then
		return tostring(Stat.Value)
	end
	return "-"
end

-- Toggle button (tab key visual)
local function ToggleButton(Props: {
	Expanded: boolean,
	OnToggle: () -> (),
})
	return E("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Space.SM, 0, Space.SM),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Colors.DarkBrown,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		[React.Event.Activated] = Props.OnToggle,
	}, {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.MD,
		}),

		Stroke = E("UIStroke", {
			Color = Colors.GoldDim,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = 0.5,
		}),

		Icon = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Fonts.Title,
			TextColor3 = Colors.GoldMuted,
			TextSize = Sizes.Caption,
			Text = if Props.Expanded then "▼" else "▶",
		}),
	})
end

-- Column header row
local function HeaderRow(Props: {
	StatColumns: { string },
	Opacity: any,
})
	local Children = {
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		Padding = E("UIPadding", {
			PaddingLeft = UDim.new(0, Space.SM + AVATAR_SIZE + Space.SM),
			PaddingRight = UDim.new(0, Space.SM),
		}),

		PlayerHeader = E("TextLabel", {
			Size = UDim2.new(1, -#Props.StatColumns * STAT_COL_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Fonts.Accent,
			TextColor3 = Colors.GoldDim,
			TextSize = Sizes.Small,
			Text = "PLAYER",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = Props.Opacity:map(function(O: number) return 1 - O end),
			LayoutOrder = 0,
		}),
	}

	for Index, Column in Props.StatColumns do
		Children["StatHeader_" .. Index] = E("TextLabel", {
			Size = UDim2.new(0, STAT_COL_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Fonts.Accent,
			TextColor3 = Colors.GoldDim,
			TextSize = Sizes.Small,
			Text = string.upper(Column),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = Props.Opacity:map(function(O: number) return 1 - O end),
			LayoutOrder = Index,
		})
	end

	return E("Frame", {
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, Children)
end

-- Single player row
local function PlayerRow(Props: {
	Player: Player,
	Index: number,
	StatColumns: { string },
	Progress: any,
	LayoutOrder: number,
	IsSelected: boolean,
	OnClick: () -> (),
})
	local IsEven = Props.Index % 2 == 0
	local RowDelay = 0.3 + (Props.Index - 1) * 0.04
	local RowEnd = math.min(RowDelay + 0.3, 1)

	local RowOpacity = Props.Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, RowDelay, RowEnd))
	end)

	local StatChildren = {
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		Padding = E("UIPadding", {
			PaddingLeft = UDim.new(0, Space.SM),
			PaddingRight = UDim.new(0, Space.SM),
		}),

		Avatar = E("ImageLabel", {
			Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
			BackgroundColor3 = Colors.MediumBrown,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Image = GetHeadshotUrl(Props.Player.UserId),
			ImageTransparency = RowOpacity:map(function(O: number) return 1 - O end),
			LayoutOrder = 0,
		}, {
			Corner = E("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = E("UIStroke", {
				Color = Colors.GoldDim,
				Thickness = Stylesheet.Stroke.Thin,
				Transparency = RowOpacity:map(function(O: number) return 1 - O * 0.6 end),
			}),
		}),

		NameLabel = E("TextLabel", {
			Size = UDim2.new(1, -AVATAR_SIZE - Space.SM - #Props.StatColumns * STAT_COL_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Fonts.Body,
			RichText = true,
			TextColor3 = Colors.Gold,
			TextSize = Sizes.Caption,
			Text = string.format(
				'%s <i><font color="#%s">@%s</font></i>',
				Props.Player.DisplayName,
				string.format(
					"%02x%02x%02x",
					math.floor(Colors.GoldMuted.R * 255),
					math.floor(Colors.GoldMuted.G * 255),
					math.floor(Colors.GoldMuted.B * 255)
				),
				Props.Player.Name
			),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = RowOpacity:map(function(O: number) return 1 - O end),
			LayoutOrder = 1,
		}, {
			NamePadding = E("UIPadding", {
				PaddingLeft = UDim.new(0, Space.SM),
			}),
		}),
	}

	for StatIndex, Column in Props.StatColumns do
		StatChildren["Stat_" .. StatIndex] = E(CarouselText, {
			Size = UDim2.new(0, STAT_COL_WIDTH, 1, 0),
			FontFace = Fonts.Body,
			TextColor3 = Colors.WhiteMuted,
			TextSize = Sizes.Caption,
			Text = GetStatValue(Props.Player, Column),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = RowOpacity:map(function(O: number) return 1 - O end),
			LayoutOrder = 10 + StatIndex,
		})
	end

	return E("TextButton", {
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = if Props.IsSelected then Colors.GoldDim else Colors.LightBrown,
		BackgroundTransparency = if Props.IsSelected then 0.6 else (if IsEven then 0.7 else 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = Props.LayoutOrder,
		[React.Event.Activated] = Props.OnClick,
	}, StatChildren)
end

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Main PlayerList component
local function PlayerList()
	local Expanded, SetExpanded = React.useState(not IsMobile)
	local PlayerListState, SetPlayerListState = React.useState(Players:GetPlayers())
	local SelectedPlayer, SetSelectedPlayer = React.useState(nil :: Player?)

	local ShouldRender, Progress = Hooks.UseTransition(
		Expanded,
		ENTER_DURATION,
		EXIT_DURATION,
		Easing.EaseOutCubic,
		Easing.EaseInCubic
	)

	React.useEffect(function()
		local function Refresh()
			SetPlayerListState(Players:GetPlayers())
		end

		local AddConn = Players.PlayerAdded:Connect(Refresh)
		local RemoveConn = Players.PlayerRemoving:Connect(Refresh)

		-- Refresh on leaderstats changes
		local StatConnections = {}

		local function WatchLeaderstats(Player: Player)
			local Leaderstats = Player:FindFirstChild("leaderstats")
			if Leaderstats then
				for _, Stat in Leaderstats:GetChildren() do
					if Stat:IsA("ValueBase") then
						local Conn = Stat.Changed:Connect(Refresh)
						table.insert(StatConnections, Conn)
					end
				end
				local ChildConn = Leaderstats.ChildAdded:Connect(function(Child)
					if Child:IsA("ValueBase") then
						local Conn = Child.Changed:Connect(Refresh)
						table.insert(StatConnections, Conn)
						Refresh()
					end
				end)
				table.insert(StatConnections, ChildConn)
			else
				local WaitConn
				WaitConn = Player.ChildAdded:Connect(function(Child)
					if Child.Name == "leaderstats" then
						WaitConn:Disconnect()
						WatchLeaderstats(Player)
						Refresh()
					end
				end)
				table.insert(StatConnections, WaitConn)
			end
		end

		for _, Player in Players:GetPlayers() do
			WatchLeaderstats(Player)
		end

		local WatchNewConn = Players.PlayerAdded:Connect(function(Player)
			WatchLeaderstats(Player)
		end)

		return function()
			AddConn:Disconnect()
			RemoveConn:Disconnect()
			WatchNewConn:Disconnect()
			for _, Conn in StatConnections do
				Conn:Disconnect()
			end
		end
	end, {})

	React.useEffect(function()
		local Conn = Players.PlayerRemoving:Connect(function(LeavingPlayer: Player)
			SetSelectedPlayer(function(Current: Player?)
				return if Current == LeavingPlayer then nil else Current
			end)
		end)
		return function()
			Conn:Disconnect()
		end
	end, {})

	local StatColumns = GetStatColumns()
	local DynamicWidth = LIST_WIDTH + #StatColumns * STAT_COL_WIDTH

	local ContainerOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0, 0.5))
	end)

	local HeaderOpacity = Progress:map(function(P: number)
		return Easing.EaseOutCubic(SubProgress(P, 0.1, 0.45))
	end)

	local SlideOffset = Progress:map(function(P: number)
		return math.floor(20 * (1 - P))
	end)

	local PanelChildren: { [string]: any } = {
		Corner = E("UICorner", {
			CornerRadius = Stylesheet.Corner.LG,
		}),

		Stroke = E("UIStroke", {
			Color = Colors.GoldDim,
			Thickness = Stylesheet.Stroke.Thin,
			Transparency = ContainerOpacity:map(function(O: number) return 1 - O * 0.5 end),
		}),

		InnerPadding = E("UIPadding", {
			PaddingTop = UDim.new(0, Space.SM),
			PaddingBottom = UDim.new(0, Space.SM),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
		}),

		ContentLayout = E("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
		}),

		HeaderSep = E("Frame", {
			Size = ContainerOpacity:map(function(O: number)
				return UDim2.new(0.85 * O, 0, 0, 1)
			end),
			BackgroundColor3 = Colors.GoldDim,
			BackgroundTransparency = ContainerOpacity:map(function(O: number) return 1 - O * 0.35 end),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}),

		ColumnHeaders = E(HeaderRow, {
			StatColumns = StatColumns,
			Opacity = HeaderOpacity,
		}),
	}

	for Index, Player in PlayerListState do
		PanelChildren["Player_" .. Player.UserId] = E(PlayerRow, {
			Player = Player,
			Index = Index,
			StatColumns = StatColumns,
			Progress = Progress,
			LayoutOrder = 10 + Index,
			IsSelected = SelectedPlayer == Player,
			OnClick = function()
				SetSelectedPlayer(if SelectedPlayer == Player then nil else Player)
			end,
		})
	end

	local ListPanel = nil
	if ShouldRender then
		ListPanel = E("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = SlideOffset:map(function(Offset: number)
				return UDim2.new(1, -Space.SM + Offset, 0, Space.SM + 36)
			end),
			Size = UDim2.new(0, DynamicWidth, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Colors.DarkBrown,
			BackgroundTransparency = ContainerOpacity:map(function(O: number) return 1 - O * 0.88 end),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, PanelChildren)
	end

	return E("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, {
		Toggle = E(ToggleButton, {
			Expanded = Expanded,
			OnToggle = function()
				if Expanded then
					SetSelectedPlayer(nil)
				end
				SetExpanded(not Expanded)
			end,
		}),

		Panel = ListPanel,

		ActionMenu = E(PlayerActionMenu, {
			Player = SelectedPlayer,
			OffsetX = Space.SM + DynamicWidth + Space.SM,
			OnClose = function()
				SetSelectedPlayer(nil)
			end,
		}),
	})
end

return PlayerList
