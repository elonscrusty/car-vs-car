--!strict
-- Smash SETTINGS glue (WINDOWS): ReplicatedStorage.OpenSettings (a BindableEvent this script
-- makes; the lobby MENU's SETTINGS tile fires it) opens KitWindows.settings. What it changes is
-- this player's own view only:
--   MUSIC / SOUNDS: two SoundGroups every sound is put in (sounds named "Music" in the music one)
--   SHADOWS: Lighting.GlobalShadows on this screen
--   NAME TAGS: other players' names and league badges over their heads
-- The server keeps them (SettingsServer: RemoteEvent SaveSettings, one save each SAVE_GAP s;
-- the saved ones come back on the attributes SetMusic, SetSfx, SetShadows, SetNames).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if (Features :: any).SMASH ~= true then
	return
end
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local Ui = script.Parent:WaitForChild("Ui")
local Screen = require(Ui:WaitForChild("Screen"))
local KitWindows = require(Ui:WaitForChild("Screens"):WaitForChild("KitWindows"))

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local state: GameSettings.Settings = GameSettings.clean(nil)

-- ===== sounds =====

local function group(name: string): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end
local musicGroup = group("CvcMusic")
local sfxGroup = group("CvcSfx")

local function sort(d: Instance)
	if d:IsA("Sound") and d.SoundGroup == nil then
		d.SoundGroup = if d.Name == "Music" then musicGroup else sfxGroup
	end
end
for _, root in { workspace, SoundService, pgui } :: { Instance } do
	for _, d in root:GetDescendants() do
		sort(d)
	end
	root.DescendantAdded:Connect(sort)
end

-- ===== name tags =====

local function tags(char: Model?)
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and not state.names then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name == "LeagueBadge" then
			d.Enabled = state.names
		end
	end
end

local function watch(p: Player)
	if p == player then
		return
	end
	local function onChar(char: Model)
		tags(char)
		-- (the server shows and hides names around a match: put ours back over it)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			hum:GetPropertyChangedSignal("DisplayDistanceType"):Connect(function()
				if
					not state.names
					and hum.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None
				then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end)
		end
		char.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("BillboardGui") and d.Name == "LeagueBadge" then
				d.Enabled = state.names
			end
		end)
	end
	if p.Character then
		task.spawn(onChar, p.Character)
	end
	p.CharacterAdded:Connect(onChar)
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)

-- ===== apply =====

local function apply()
	musicGroup.Volume = state.music
	sfxGroup.Volume = state.sfx
	Lighting.GlobalShadows = state.shadows
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if
				hum
				and state.names
				and hum.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None
			then
				-- (back on: the way Roblox shows names; the server hides them again in a match)
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
			tags(char)
		end
	end
end

-- the saved ones, from the server
local function fromServer()
	local m = player:GetAttribute("SetMusic")
	if m == nil then
		return
	end
	state = GameSettings.clean({
		music = m,
		sfx = player:GetAttribute("SetSfx"),
		shadows = player:GetAttribute("SetShadows"),
		names = player:GetAttribute("SetNames"),
	})
	apply()
end
player:GetAttributeChangedSignal("SetMusic"):Connect(fromServer)
fromServer()
apply()

-- ===== saving: the latest settings, at most one send each SAVE_GAP s =====

local sendAt = 0
local queued = false
local function send()
	if queued then
		return
	end
	queued = true
	local wait = math.max(0, sendAt - os.clock())
	task.delay(wait, function()
		queued = false
		sendAt = os.clock() + GameSettings.SAVE_GAP + 0.1
		local r = ReplicatedStorage:FindFirstChild("SaveSettings")
		if r and r:IsA("RemoteEvent") then
			r:FireServer({
				music = state.music,
				sfx = state.sfx,
				shadows = state.shadows,
				names = state.names,
			})
		end
	end)
end

-- ===== the window =====

local current: Screen.Handle? = nil
local function open()
	current = KitWindows.settings({
		music = state.music,
		sfx = state.sfx,
		shadows = state.shadows,
		names = state.names,
	}, {
		set = function(key: string, value: any)
			local t: { [string]: any } = {
				music = state.music,
				sfx = state.sfx,
				shadows = state.shadows,
				names = state.names,
			}
			t[key] = value
			state = GameSettings.clean(t)
			apply()
			send()
		end,
		close = function()
			if current then
				current.close()
				current = nil
			end
		end,
	})
end

local ev = ReplicatedStorage:FindFirstChild("OpenSettings")
if not (ev and ev:IsA("BindableEvent")) then
	local made = Instance.new("BindableEvent")
	made.Name = "OpenSettings"
	made.Parent = ReplicatedStorage
	ev = made
end
(ev :: BindableEvent).Event:Connect(open)
