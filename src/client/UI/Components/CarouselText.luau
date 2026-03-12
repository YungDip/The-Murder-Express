local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Easing = require(script.Parent.Parent.Easing)

local E = React.createElement

local DIGIT_DURATION = 0.3
local STAGGER_DELAY = 0.06
local WIDTH_DURATION = 0.25

-- Single digit slot with carousel slide and animated width
local function DigitSlot(Props: {
	Char: string,
	PrevChar: string?,
	Direction: number,
	Delay: number,
	LayoutOrder: number,
	CharWidth: number,
	FontFace: Font,
	TextColor3: Color3,
	TextSize: number,
	TextTransparency: any?,
})
	-- Slide progress for the text carousel
	local SlideProgress, SetSlideProgress = React.useBinding(1)
	local SlideRef = React.useRef(1)

	-- Width progress for expanding/collapsing slots
	local WidthProgress, SetWidthProgress = React.useBinding(1)
	local WidthRef = React.useRef(1)

	local IsAppearing = Props.Char ~= "" and (Props.PrevChar == "" or Props.PrevChar == nil)
	local IsDisappearing = Props.Char == "" and Props.PrevChar and Props.PrevChar ~= ""
	local HasSlide = Props.PrevChar and Props.PrevChar ~= Props.Char and Props.Char ~= "" and Props.PrevChar ~= ""

	-- Animate width when slot appears or disappears
	React.useEffect(function()
		if not IsAppearing and not IsDisappearing then
			WidthRef.current = 1
			SetWidthProgress(1)
			return
		end

		WidthRef.current = 0
		SetWidthProgress(0)

		local Active = true
		local Elapsed = 0
		local Started = false

		local ConnRef = nil :: RBXScriptConnection?
		ConnRef = RunService.PreRender:Connect(function(DeltaTime: number)
			if not Active then return end
			Elapsed += DeltaTime
			if not Started then
				if Elapsed < Props.Delay then return end
				Started = true
				Elapsed = 0
			end
			WidthRef.current = math.min(WidthRef.current + DeltaTime / WIDTH_DURATION, 1)
			SetWidthProgress(Easing.EaseOutCubic(WidthRef.current))
			if WidthRef.current >= 1 then
				Active = false
				if ConnRef then ConnRef:Disconnect() end
			end
		end)

		return function()
			Active = false
			if ConnRef then ConnRef:Disconnect() end
		end
	end, { Props.Char, Props.PrevChar })

	-- Animate slide when digit value changes
	React.useEffect(function()
		if not HasSlide then
			SlideRef.current = 1
			SetSlideProgress(1)
			return
		end

		SlideRef.current = 0
		SetSlideProgress(0)

		local Active = true
		local Elapsed = 0
		local Started = false

		local ConnRef = nil :: RBXScriptConnection?
		ConnRef = RunService.PreRender:Connect(function(DeltaTime: number)
			if not Active then return end
			Elapsed += DeltaTime
			if not Started then
				if Elapsed < Props.Delay then return end
				Started = true
				Elapsed = 0
			end
			SlideRef.current = math.min(SlideRef.current + DeltaTime / DIGIT_DURATION, 1)
			SetSlideProgress(Easing.EaseOutCubic(SlideRef.current))
			if SlideRef.current >= 1 then
				Active = false
				if ConnRef then ConnRef:Disconnect() end
			end
		end)

		return function()
			Active = false
			if ConnRef then ConnRef:Disconnect() end
		end
	end, { Props.Char, Props.PrevChar })

	local Transparency = Props.TextTransparency or 0
	local Dir = Props.Direction
	local CW = Props.CharWidth

	-- Compute width based on appear/disappear state
	local SlotWidth
	if IsAppearing then
		SlotWidth = WidthProgress:map(function(P: number) return UDim2.new(0, math.floor(CW * P), 1, 0) end)
	elseif IsDisappearing then
		SlotWidth = WidthProgress:map(function(P: number) return UDim2.new(0, math.floor(CW * (1 - P)), 1, 0) end)
	else
		SlotWidth = UDim2.new(0, CW, 1, 0)
	end

	local DisplayChar = if Props.Char ~= "" then Props.Char else (Props.PrevChar or "")
	local DisplayPrev = if HasSlide then Props.PrevChar else nil

	local Children: { [string]: any } = {}

	if HasSlide then
		-- Sliding carousel: old exits, new enters
		Children.Current = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Position = SlideProgress:map(function(P: number)
				return UDim2.fromScale(0, Dir * (1 - P))
			end),
			BackgroundTransparency = 1,
			FontFace = Props.FontFace,
			TextColor3 = Props.TextColor3,
			TextSize = Props.TextSize,
			Text = Props.Char,
			TextTransparency = Transparency,
		})
		Children.Previous = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Position = SlideProgress:map(function(P: number)
				return UDim2.fromScale(0, -Dir * P)
			end),
			BackgroundTransparency = 1,
			FontFace = Props.FontFace,
			TextColor3 = Props.TextColor3,
			TextSize = Props.TextSize,
			Text = DisplayPrev,
			TextTransparency = Transparency,
		})
	elseif IsDisappearing then
		-- Disappearing: show old char while width collapses
		Children.Current = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Props.FontFace,
			TextColor3 = Props.TextColor3,
			TextSize = Props.TextSize,
			Text = DisplayChar,
			TextTransparency = Transparency,
		})
	else
		-- Static or appearing
		Children.Current = E("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Props.FontFace,
			TextColor3 = Props.TextColor3,
			TextSize = Props.TextSize,
			Text = DisplayChar,
			TextTransparency = Transparency,
		})
	end

	return E("Frame", {
		Size = SlotWidth,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = Props.LayoutOrder,
	}, Children)
end

-- Right-pads a char array so both arrays are the same length
local function RightAlignChars(Chars: { string }, MaxLen: number): { string }
	local Pad = MaxLen - #Chars
	local Result = {}
	for I = 1, Pad do
		Result[I] = ""
	end
	for I = 1, #Chars do
		Result[Pad + I] = Chars[I]
	end
	return Result
end

-- Carousel that splits text into per-character staggered slots
local function CarouselText(Props: {
	Text: string,
	Size: UDim2,
	FontFace: Font,
	TextColor3: Color3,
	TextSize: number,
	TextXAlignment: Enum.TextXAlignment?,
	TextTransparency: any?,
	LayoutOrder: number?,
})
	local PrevTextRef = React.useRef(Props.Text)
	local PrevText, SetPrevText = React.useState(nil :: string?)
	local DirectionRef = React.useRef(1)

	React.useEffect(function()
		if Props.Text == PrevTextRef.current then return end

		local OldNum = tonumber(PrevTextRef.current)
		local NewNum = tonumber(Props.Text)
		DirectionRef.current = if OldNum and NewNum
			then (if NewNum >= OldNum then 1 else -1)
			else 1

		SetPrevText(PrevTextRef.current)
		PrevTextRef.current = Props.Text
	end, { Props.Text })

	local CurrentRaw = string.split(Props.Text, "")
	local PrevRaw = if PrevText then string.split(PrevText, "") else nil
	local MaxLen = math.max(#CurrentRaw, if PrevRaw then #PrevRaw else 0)
	local Dir = DirectionRef.current
	local CharWidth = math.floor(Props.TextSize * 0.6)

	-- Right-align both char arrays so digits line up from the right
	local CurrentChars = RightAlignChars(CurrentRaw, MaxLen)
	local PrevChars = if PrevRaw then RightAlignChars(PrevRaw, MaxLen) else nil

	local Children: { [string]: any } = {
		Layout = E("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = if Props.TextXAlignment == Enum.TextXAlignment.Left
				then Enum.HorizontalAlignment.Left
				elseif Props.TextXAlignment == Enum.TextXAlignment.Right
				then Enum.HorizontalAlignment.Right
				else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for Index = 1, MaxLen do
		local Char = CurrentChars[Index]
		local PrevChar = if PrevChars then PrevChars[Index] else nil
		-- Skip slots that are empty on both sides
		if Char == "" and (not PrevChar or PrevChar == "") then continue end
		-- Stagger from the right (last digit animates first)
		local StaggerIndex = MaxLen - Index
		Children["D" .. Index] = E(DigitSlot, {
			Char = Char,
			PrevChar = PrevChar,
			Direction = Dir,
			Delay = StaggerIndex * STAGGER_DELAY,
			LayoutOrder = Index,
			CharWidth = CharWidth,
			FontFace = Props.FontFace,
			TextColor3 = Props.TextColor3,
			TextSize = Props.TextSize,
			TextTransparency = Props.TextTransparency,
		})
	end

	return E("Frame", {
		Size = Props.Size,
		BackgroundTransparency = 1,
		LayoutOrder = Props.LayoutOrder,
	}, Children)
end

return CarouselText
