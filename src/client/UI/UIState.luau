local UIState = {}

local function CreateSignal()
	local Listeners = {}
	return {
		Connect = function(_, Callback: (...any) -> ())
			table.insert(Listeners, Callback)
			return {
				Disconnect = function()
					local Index = table.find(Listeners, Callback)
					if Index then
						table.remove(Listeners, Index)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, Listener in Listeners do
				task.spawn(Listener, ...)
			end
		end,
		Wait = function(Self)
			local Thread = coroutine.running()
			local Connection
			Connection = Self:Connect(function(...)
				Connection:Disconnect()
				task.spawn(Thread, ...)
			end)
			return coroutine.yield()
		end,
	}
end

-- Announcement
UIState.AnnouncementChanged = CreateSignal()
UIState.AnnouncementState = {
	Title = "",
	Subtitle = "",
	Visible = false,
	IsWarning = false,
}

function UIState.ShowAnnouncement(Title: string, Subtitle: string, IsWarning: boolean)
	UIState.AnnouncementState.Title = Title
	UIState.AnnouncementState.Subtitle = Subtitle
	UIState.AnnouncementState.IsWarning = IsWarning
	UIState.AnnouncementState.Visible = true
	UIState.AnnouncementChanged:Fire(UIState.AnnouncementState)
end

function UIState.HideAnnouncement()
	UIState.AnnouncementState.Visible = false
	UIState.AnnouncementChanged:Fire(UIState.AnnouncementState)
end

-- Timer
UIState.TimerChanged = CreateSignal()
UIState.TimerState = {
	Text = "3:00",
	Visible = false,
	Warning = false,
}

function UIState.SetTimerVisible(Visible: boolean)
	UIState.TimerState.Visible = Visible
	UIState.TimerChanged:Fire(UIState.TimerState)
end

function UIState.SetTimerText(Text: string)
	UIState.TimerState.Text = Text
	UIState.TimerChanged:Fire(UIState.TimerState)
end

function UIState.SetTimerWarning(Warning: boolean)
	UIState.TimerState.Warning = Warning
	UIState.TimerChanged:Fire(UIState.TimerState)
end

-- Roulette
UIState.RouletteChanged = CreateSignal()
UIState.RouletteState = {
	Visible = false,
	TargetRole = "",
	Playing = false,
}

function UIState.PlayRoulette(TargetRole: string)
	UIState.RouletteState.TargetRole = TargetRole
	UIState.RouletteState.Visible = true
	UIState.RouletteState.Playing = true
	UIState.RouletteChanged:Fire(UIState.RouletteState)
end

function UIState.HideRoulette()
	UIState.RouletteState.Visible = false
	UIState.RouletteState.Playing = false
	UIState.RouletteChanged:Fire(UIState.RouletteState)
end

-- Scoreboard
UIState.ScoreboardChanged = CreateSignal()
UIState.ScoreboardState = {
	Visible = false,
	Data = nil :: {
		Result: string,
		Players: { { Name: string, Role: string, Alive: boolean, UserId: number } },
	}?,
}

function UIState.ShowScoreboard(Data: {
	Result: string,
	Players: { { Name: string, Role: string, Alive: boolean, UserId: number } },
})
	UIState.ScoreboardState.Data = Data
	UIState.ScoreboardState.Visible = true
	UIState.ScoreboardChanged:Fire(UIState.ScoreboardState)
end

function UIState.HideScoreboard()
	UIState.ScoreboardState.Visible = false
	UIState.ScoreboardChanged:Fire(UIState.ScoreboardState)
end

-- Coal
UIState.CoalChanged = CreateSignal()
UIState.CoalState = {
	Active = false,
	Current = 0,
	Required = 0,
	Filled = false,
}

function UIState.SetCoalState(Active: boolean, Current: number, Required: number)
	UIState.CoalState.Active = Active
	UIState.CoalState.Current = Current
	UIState.CoalState.Required = Required
	if not Active then
		UIState.CoalState.Filled = false
	end
	UIState.CoalChanged:Fire(UIState.CoalState)
end

function UIState.SetCoalFilled(Filled: boolean)
	UIState.CoalState.Filled = Filled
	UIState.CoalChanged:Fire(UIState.CoalState)
end

-- Shutter
UIState.ShutterChanged = CreateSignal()
UIState.ShutterCompleted = CreateSignal()
UIState.ShutterState = nil :: {
	Action: string,
	Duration: number,
	Color: Color3,
	Id: number,
}?
UIState.IsShutterClosed = false

local ShutterRequestId = 0

function UIState.ShutterClose(Duration: number, Color: Color3?)
	ShutterRequestId += 1
	local MyId = ShutterRequestId
	UIState.IsShutterClosed = true
	UIState.ShutterState = {
		Action = "close",
		Duration = Duration,
		Color = Color or Color3.new(0, 0, 0),
		Id = MyId,
	}
	UIState.ShutterChanged:Fire(UIState.ShutterState)

	while true do
		local CompletedId = UIState.ShutterCompleted:Wait()
		if CompletedId == MyId then
			break
		end
	end
end

function UIState.ShutterOpen(Duration: number, Color: Color3?)
	ShutterRequestId += 1
	local MyId = ShutterRequestId
	UIState.ShutterState = {
		Action = "open",
		Duration = Duration,
		Color = Color or Color3.new(0, 0, 0),
		Id = MyId,
	}
	UIState.ShutterChanged:Fire(UIState.ShutterState)

	while true do
		local CompletedId = UIState.ShutterCompleted:Wait()
		if CompletedId == MyId then
			break
		end
	end
	UIState.IsShutterClosed = false
end

function UIState.ShutterReset()
	ShutterRequestId += 1
	UIState.IsShutterClosed = false
	UIState.ShutterState = {
		Action = "reset",
		Duration = 0,
		Color = Color3.new(0, 0, 0),
		Id = ShutterRequestId,
	}
	UIState.ShutterChanged:Fire(UIState.ShutterState)
end

return UIState