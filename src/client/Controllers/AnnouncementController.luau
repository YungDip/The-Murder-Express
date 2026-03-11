local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnnouncementNetwork = require(ReplicatedStorage.Shared.Network.AnnouncementNetwork)
local Constants = require(ReplicatedStorage.Shared.Constants)
local LayeredSound = require(ReplicatedStorage.Shared.Util.LayeredSound)
local UIState = require(script.Parent.Parent.UI.UIState)

local AnnouncementConst = Constants.Announcement
local DISPLAY_DURATION = AnnouncementConst.DISPLAY_DURATION

local AnnouncementController = {}

local Queue: { { Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean? } } = {}
local IsShowing = false

local OnShowCallbacks: { () -> () } = {}
local OnHideCallbacks: { () -> () } = {}

--[[
shows a single announcement via React UIState bindings
(@yields)
]]
local function ShowAnnouncement(Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean?)
IsShowing = true

for _, Callback in OnShowCallbacks do
task.spawn(Callback)
end

local SoundObj = SoundService:FindFirstChild("UI") and SoundService.UI:FindFirstChild(if IsWarning then "Warning" else "Announcement")
if SoundObj and SoundObj:IsA("Sound") then
LayeredSound.Play(SoundObj, 0.5)
end

local HoldTime = Duration or DISPLAY_DURATION

UIState.ShowAnnouncement(Title, Subtitle or "", IsWarning or false)

task.wait(HoldTime)

UIState.HideAnnouncement()

-- Wait for exit animation
task.wait(0.8)

IsShowing = false

for _, Callback in OnHideCallbacks do
task.spawn(Callback)
end
end

--[[
drains the announcement queue one entry at a time
(@yields)
]]
local function ProcessQueue()
while #Queue > 0 do
local Entry = table.remove(Queue, 1)
ShowAnnouncement(Entry.Title, Entry.Subtitle, Entry.Duration, Entry.IsWarning)
task.wait(0.2)
end
end

--[[
adds an announcement to the queue
]]
function AnnouncementController.Announce(Title: string, Subtitle: string?, Duration: number?)
table.insert(Queue, { Title = Title, Subtitle = Subtitle, Duration = Duration })
if not IsShowing then
task.spawn(ProcessQueue)
end
end

--[[
adds a warning announcement to the queue with a pulsing border
]]
function AnnouncementController.Warn(Title: string, Subtitle: string?, Duration: number?)
table.insert(Queue, { Title = Title, Subtitle = Subtitle, Duration = Duration, IsWarning = true })
if not IsShowing then
task.spawn(ProcessQueue)
end
end

AnnouncementNetwork.packets.Show.listen(function(Data: { Title: string, Subtitle: string?, Duration: number?, IsWarning: boolean? })
if Data.IsWarning then
AnnouncementController.Warn(Data.Title, Data.Subtitle, Data.Duration)
else
AnnouncementController.Announce(Data.Title, Data.Subtitle, Data.Duration)
end
end)

--[[
returns whether an announcement is currently visible
]]
function AnnouncementController.IsShowing(): boolean
return IsShowing
end

--[[
registers a callback fired when an announcement begins showing
]]
function AnnouncementController.OnShow(Callback: () -> ())
table.insert(OnShowCallbacks, Callback)
end

--[[
registers a callback fired when an announcement finishes hiding
]]
function AnnouncementController.OnHide(Callback: () -> ())
table.insert(OnHideCallbacks, Callback)
end

return AnnouncementController