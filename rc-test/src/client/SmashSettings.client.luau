--!strict
-- Smash SETTINGS glue (WINDOWS): ReplicatedStorage.OpenSettings (a BindableEvent this script
-- makes; the lobby MENU's SETTINGS tile fires it) opens KitWindows.settings. What it changes is
-- this player's own view only:
--   MUSIC / SOUNDS: two SoundGroups every sound is put in (sounds named "Music" in the music one)
--   SHADOWS: Lighting.GlobalShadows on this screen
--   NAME TAGS: other players' names and league badges over their heads
--   CAMERA: FOLLOW or FIXED (player attribute CamFixed, read by ChaseCamera)
-- The server keeps them (SettingsServer: RemoteEvent SaveSettings, one send each SAVE_GAP s;
-- the saved ones come once, on the attributes SetMusic, SetSfx, SetShadows, SetNames, SetCamera and
-- then SetLoaded: the window opens only after that, so nothing sent can put defaults over a save).
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
local roots: { Instance } = { workspace, SoundService, pgui }
local scripts = player:FindFirstChild("PlayerScripts")
if scripts then
	table.insert(roots, scripts) -- (the race beeps live with their scripts)
end
for _, root in roots do
	for _, d in root:GetDescendants() do
		sort(d)
	end
	root.DescendantAdded:Connect(sort)
end

-- ===== name tags =====

-- the humanoids whose names we hid, and what the server had them at (put back when NAME TAGS
-- goes on again; the server hides names in a match on purpose, and that stays)
local hidden: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = setmetatable({}, { __mode = "k" }) :: any
local NONE = Enum.HumanoidDisplayDistanceType.None

local function hideName(hum: Humanoid)
	if not state.names and hum.DisplayDistanceType ~= NONE then
		hidden[hum] = hum.DisplayDistanceType
		hum.DisplayDistanceType = NONE
	end
end

local function badges(char: Model?)
	if not char then
		return
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
		badges(char)
		char.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("BillboardGui") and d.Name == "LeagueBadge" then
				d.Enabled = state.names
			end
		end)
		local found = char:WaitForChild("Humanoid", 10)
		if not (found and found:IsA("Humanoid")) then
			return
		end
		local hum: Humanoid = found
		hideName(hum)
		-- (the server shows names again after a match: still hidden for us)
		hum:GetPropertyChangedSignal("DisplayDistanceType"):Connect(function()
			hideName(hum)
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
	player:SetAttribute("CamFixed", state.camera == "fixed")
	if state.names then
		for hum, was in hidden do
			hidden[hum] = nil
			if hum.Parent and hum.DisplayDistanceType == NONE then
				hum.DisplayDistanceType = was
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hideName(hum)
			end
			badges(p.Character)
		end
	end
end

-- the saved ones, once, from the server
local loaded = false
local function fromServer()
	if loaded or player:GetAttribute("SetLoaded") ~= true then
		return
	end
	loaded = true
	state = GameSettings.clean({
		music = player:GetAttribute("SetMusic"),
		sfx = player:GetAttribute("SetSfx"),
		shadows = player:GetAttribute("SetShadows"),
		names = player:GetAttribute("SetNames"),
		camera = player:GetAttribute("SetCamera"),
	})
	apply()
end
player:GetAttributeChangedSignal("SetLoaded"):Connect(fromServer)
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
	task.delay(math.max(0, sendAt - os.clock()), function()
		queued = false
		sendAt = os.clock() + GameSettings.SAVE_GAP
		local r = ReplicatedStorage:FindFirstChild("SaveSettings")
		if r and r:IsA("RemoteEvent") then
			r:FireServer({
				music = state.music,
				sfx = state.sfx,
				shadows = state.shadows,
				names = state.names,
				camera = state.camera,
			})
		end
	end)
end

-- ===== the window =====

local current: Screen.Handle? = nil
local function shut()
	if current then
		current.close()
		current = nil
	end
end

local function open()
	-- (not before the saved ones came: a change then would send defaults over them)
	if not loaded or player:GetAttribute("InMatch") == true then
		return
	end
	current = KitWindows.settings({
		music = state.music,
		sfx = state.sfx,
		shadows = state.shadows,
		names = state.names,
		camera = state.camera,
	}, {
		set = function(key: string, value: any)
			local t: { [string]: any } = {
				music = state.music,
				sfx = state.sfx,
				shadows = state.shadows,
				names = state.names,
				camera = state.camera,
			}
			t[key] = value
			state = GameSettings.clean(t)
			apply()
			send()
		end,
		close = shut,
	})
end

-- a match starting closes it (never a window over the arena)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") == true then
		shut()
	end
end)

local ev = ReplicatedStorage:FindFirstChild("OpenSettings")
if not (ev and ev:IsA("BindableEvent")) then
	local made = Instance.new("BindableEvent")
	made.Name = "OpenSettings"
	made.Parent = ReplicatedStorage
	ev = made
end
(ev :: BindableEvent).Event:Connect(open)
