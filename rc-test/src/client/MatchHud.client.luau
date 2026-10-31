--!strict
-- Car VS Car SMASH (10-28): the match HUD (Ui/Screens/Hud.match) while you are in a match. The
-- server sets the player attributes (Health, MaxHealth, Shield, Place, MatchEndsAt, Weapon,
-- Ammo, InMatch), keeps the scoreboard in ReplicatedStorage.MatchBoard and
-- fires SmashFeed (attacker, victim, weapon) on each smash; this only shows them. FIRE (the button, F, a gamepad's R2) asks the server through WeaponFire
-- with the camera's flat look; the server checks everything (aim, ammo, cooldown).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
-- (only with the SMASH game on: the racing game keeps working with it off)
if (Features :: any).SMASH ~= true then
	return
end

local Ui = script.Parent:WaitForChild("Ui")
local Base = require(Ui:WaitForChild("Base"))
local Screen = require(Ui:WaitForChild("Screen"))
local Hud = require(Ui:WaitForChild("Screens"):WaitForChild("Hud"))
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local Xp = require(Shared:WaitForChild("Xp"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local TestThumb = require(script.Parent:WaitForChild("TestThumb"))

local player = Players.LocalPlayer

local FIRE_REMOTE = "WeaponFire" -- (= Weapons.REMOTE, WEAPONS thread)
local FEED_REMOTE = "SmashFeed"
local FIRE_GAP = 0.12 -- the client's own spacing; the server drops asks faster than a cooldown
local DEFAULT_KARTS = 8
local BOARD = "MatchBoard" -- (MATCH: one Configuration per kart, attributes Name, Smashes, Level?, UserId)

local function attr(name: string): any
	return player:GetAttribute(name)
end
local function num(name: string, default: number): number
	local v = attr(name)
	return if type(v) == "number" then v else default
end

local function inMatch(): boolean
	local ends = attr("MatchEndsAt")
	return attr("InMatch") == true
		and type(ends) == "number"
		and ends > workspace:GetServerTimeNow() - 1
end

-- how many karts: the board's MatchKarts, else its count, else 8
local function karts(): number
	local folder = ReplicatedStorage:FindFirstChild(BOARD)
	local n = folder and folder:GetAttribute("MatchKarts")
	if type(n) == "number" and n > 0 then
		return n
	end
	local count = if folder then #folder:GetChildren() else 0
	return if count > 0 then count else DEFAULT_KARTS
end

-- aim: where the camera looks, flat (the server keeps it within 30 deg of the kart's nose).
-- On a PC with a mouse the gun points at the mouse instead (carter 10-31): the mouse ray is cut
-- with the flat ground at the kart's height. No auto-aim: it is only where the mouse is.
local function mouseAimOn(): boolean
	if not UserInputService.MouseEnabled then
		return false
	end
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.MouseMovement
		or last == Enum.UserInputType.MouseButton1
		or last == Enum.UserInputType.MouseButton2
		or last == Enum.UserInputType.MouseWheel
		or last == Enum.UserInputType.Keyboard
end

local function aim(): Vector3?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	if mouseAimOn() then
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local focus = cam.Focus.Position
		if math.abs(ray.Direction.Y) > 1e-3 then
			local t = (focus.Y - ray.Origin.Y) / ray.Direction.Y
			if t > 0 then
				local flat = (ray.Origin + ray.Direction * t - focus) * Vector3.new(1, 0, 1)
				if flat.Magnitude > 1 then
					return flat.Unit
				end
			end
		end
	end
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		return nil
	end
	return look.Unit
end

local lastFire = 0
local function fire()
	if not inMatch() then
		return
	end
	local now = os.clock()
	if now - lastFire < FIRE_GAP then
		return
	end
	lastFire = now
	local remote = ReplicatedStorage:FindFirstChild(FIRE_REMOTE)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(aim())
	end
end

-- the scoreboard from MatchBoard, most smashes first (the level badge hides without a Level)
local function boardList(): { { [string]: any } }
	local list = {}
	local folder = ReplicatedStorage:FindFirstChild(BOARD)
	if not folder then
		return list
	end
	for _, k in folder:GetChildren() do
		local name = k:GetAttribute("Name")
		local smashes = k:GetAttribute("Smashes")
		local level = k:GetAttribute("Level")
		table.insert(list, {
			name = if type(name) == "string" then name else k.Name,
			smashes = if type(smashes) == "number" then smashes else 0,
			level = if type(level) == "number" then level else nil,
			me = k:GetAttribute("UserId") == player.UserId,
		})
	end
	table.sort(list, function(a, b)
		if a.smashes ~= b.smashes then
			return a.smashes > b.smashes
		end
		return a.name < b.name
	end)
	SmashScreens.rank(list)
	return list
end

-- your place for the chip: the board's own rank, so the two always agree (audit R7-6); the
-- server's Place only while you're not on the board yet
local function myPlace(list: { { [string]: any } }): number
	for _, e in list do
		if e.me == true then
			return e.rank
		end
	end
	return num("Place", 1)
end

local hud: Screen.Handle? = nil
local lastSecs = -1 -- (the clock's last shown second)
-- PC key hints: small, bottom middle, shown 20 s from the start of each match, then fade out
local HINT_SECONDS = 20
local hintGui: ScreenGui? = nil
local hintToken = 0
local function hideHints()
	hintToken += 1
	if hintGui then
		hintGui:Destroy()
		hintGui = nil
	end
end
local function showHints()
	hideHints()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end
	local me = hintToken
	local gui = Instance.new("ScreenGui")
	gui.Name = "KeyHints"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -10)
	label.Size = UDim2.fromOffset(560, 24)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.BackgroundTransparency = 0.45
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextTransparency = 0.1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.Text = "W A S D drive    SPACE drift    CLICK fire (aim with mouse)    G special"
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	hintGui = gui
	task.delay(HINT_SECONDS, function()
		if hintToken ~= me or not label.Parent then
			return
		end
		local info = TweenInfo.new(1)
		TweenService:Create(label, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.delay(1.1, function()
			if hintToken == me then
				hideHints()
			end
		end)
	end)
end

local function close()
	hideHints()
	if hud then
		hud.close()
		hud = nil
	end
end

-- (something else closed it, the viewer's SCREENS bar: forget the handle so it opens again)
local function alive(): Screen.Handle?
	if hud and not Screen.isOpen("match") then
		hud = nil
	end
	return hud
end

local function refresh()
	local h = hud
	if not h then
		return
	end
	local api = h.api
	api.setPlace(myPlace(boardList()), karts(), num("Smashes", 0))
	api.setHealth(num("Health", 100), num("MaxHealth", 100), attr("Shield") == true)
	local w = attr("Weapon")
	api.setWeapon(if type(w) == "string" then w else "", num("Ammo", 0))
	-- (a how-to card up: SmashHowTo; the tip over FIRE would say the same)
	local card = attr("HowToCard")
	api.quiet(type(card) == "number" and card > 0)
end

local function open()
	local w = attr("Weapon")
	lastSecs = -1
	hud = Hud.match({
		place = num("Place", 1),
		total = karts(),
		smashes = num("Smashes", 0),
		secs = math.max(0, math.ceil(num("MatchEndsAt", 0) - workspace:GetServerTimeNow())),
		hp = num("Health", 100),
		maxHp = num("MaxHealth", 100),
		shield = attr("Shield") == true,
		weapon = if type(w) == "string" then w else "",
		ammo = num("Ammo", 0),
		board = boardList(),
		-- (the kit's health bar: your name and level star)
		name = player.DisplayName,
		level = (Xp.levelOf(num("Xp", 0))),
		-- (your first match: the GRAB A ? BOX tip over FIRE; after it, the button alone)
		tip = type(attr("Xp")) ~= "number" or (attr("Xp") :: number) <= 0,
	}, { fire = fire }, Base.phone())
	if not Base.phone() then
		showHints()
	end
end

local function check()
	alive()
	local want = inMatch()
	if want and not hud then
		open()
	elseif not want and hud then
		close()
	end
	refresh()
end

for _, name in
	{
		"Health",
		"MaxHealth",
		"Shield",
		"Place",
		"Smashes",
		"Weapon",
		"Ammo",
		"MatchEndsAt",
		"InMatch",
		"HowToCard",
	}
do
	player:GetAttributeChangedSignal(name):Connect(check)
end
check()

-- the scoreboard: redrawn when the board changes, 4 times a second at most
local boardDirty = true
local lastBoard = 0
local function watchKart(k: Instance)
	k.AttributeChanged:Connect(function()
		boardDirty = true
	end)
end
-- (MATCH clears the folder between rounds; if one is ever made anew, watch that one instead)
local folderConns: { RBXScriptConnection } = {}
local function watchBoard(folder: Instance)
	for _, cn in folderConns do
		cn:Disconnect()
	end
	table.clear(folderConns)
	boardDirty = true
	for _, k in folder:GetChildren() do
		watchKart(k)
	end
	table.insert(
		folderConns,
		folder.ChildAdded:Connect(function(k: Instance)
			watchKart(k)
			boardDirty = true
		end)
	)
	table.insert(
		folderConns,
		folder.ChildRemoved:Connect(function()
			boardDirty = true
		end)
	)
	table.insert(
		folderConns,
		folder.AttributeChanged:Connect(function()
			boardDirty = true
		end)
	)
end
ReplicatedStorage.ChildAdded:Connect(function(c: Instance)
	if c.Name == BOARD then
		watchBoard(c)
	end
end)
local firstBoard = ReplicatedStorage:FindFirstChild(BOARD)
if firstBoard then
	watchBoard(firstBoard)
end

-- the clock: words change once a second at most
RunService.Heartbeat:Connect(function()
	local h = alive()
	if not h then
		return
	end
	if boardDirty and os.clock() - lastBoard >= 0.25 then
		boardDirty = false
		lastBoard = os.clock()
		local list = boardList()
		h.api.setBoard(list)
		h.api.setPlace(myPlace(list), karts(), num("Smashes", 0))
	end
	local left = num("MatchEndsAt", 0) - workspace:GetServerTimeNow()
	local secs = math.max(0, math.ceil(left))
	if secs ~= lastSecs then
		-- the clock hits 0 once per match (SOUNDS 10-28; the 3-2-1-GO is MATCH's, not here)
		if secs == 0 and lastSecs > 0 then
			Sfx.matchEnd()
		end
		lastSecs = secs
		h.api.setClock(secs)
	end
	if left < -1 then
		check() -- (the match is over: the end screen takes it from here)
	end
end)

-- the Studio-only test thumb presses this same FIRE (client/TestThumb)
TestThumb.onFire(fire)

-- keyboard F, a gamepad's R2 and the left mouse button fire too (the button is the phone's).
-- Hold the left mouse button to keep shooting.
local mouseHeld = false
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fire()
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton1
		and UserInputService.MouseEnabled
	then
		mouseHeld = true
		fire()
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseHeld = false
	end
end)
RunService.Heartbeat:Connect(function()
	if mouseHeld then
		fire() -- (fire() keeps its own gap)
	end
end)

-- a kill list side's level, from its scoreboard entry (by player, else by name; nil = no badge)
local function levelOf(s: SmashJuice.Side?): number?
	local folder = ReplicatedStorage:FindFirstChild(BOARD)
	if not (s and folder) then
		return nil
	end
	for _, k in folder:GetChildren() do
		local id = k:GetAttribute("UserId")
		-- (a bot is on the board as UserId 0: a player with a bot's name keeps their own level)
		local hit = if s.userId ~= nil
			then id == s.userId
			else (id == nil or id == 0) and k:GetAttribute("Name") == s.name
		if hit then
			local level = k:GetAttribute("Level")
			return if type(level) == "number" then level else nil
		end
	end
	return nil
end

-- the kill list: SmashFeed's sides read by SmashJuice (a Player, a bot's name, or
-- { name, userId?, kart? }; nil attacker = the arena got them), your own rows lime
task.spawn(function()
	local feedRemote = ReplicatedStorage:WaitForChild(FEED_REMOTE, math.huge)
	if not (feedRemote and feedRemote:IsA("RemoteEvent")) then
		return
	end
	feedRemote.OnClientEvent:Connect(function(attacker: unknown, victim: unknown, weapon: unknown)
		local h = hud
		if not h then
			return
		end
		local f = SmashJuice.read(attacker, victim, weapon, player.UserId)
		if not f then
			return
		end
		local a = f.attacker
		h.api.feed(
			if a then SmashJuice.shortName(a.name) else "ARENA",
			SmashJuice.shortName(f.victim.name),
			f.weapon,
			(a ~= nil and a.me) or f.victim.me,
			levelOf(a),
			levelOf(f.victim)
		)
	end)
end)
