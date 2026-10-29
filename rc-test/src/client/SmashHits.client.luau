--!strict
-- Hits you can feel (JUICE row, auditor "Road to 9/10" items 2 and 3). Numbers and rules live in
-- shared/SmashHits. Looks and sounds only: the server decides every hit.
--   * any kart that loses health (its MatchBoard row) flashes white-to-red and a "-34" floats up
--     over it in the weapon's colour (a gun burst or a bump scrape adds up into one number)
--   * other karts' hits are heard where they happen; a bump plays the bump sound
--   * your own hit on someone gives you a small shake; a boom near you shakes you by how near
--   * the blue spawn bubble over every kart that just came back (players: the server's Shield)
--   * Studio only, workspace TestSlowMo = true (or seconds): every shot, boom and hit is frozen on
--     screen for that long, and the Output says "[SmashHits] ..." and "[Sfx] <sound>" per cue
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SmashHits = require(Shared:WaitForChild("SmashHits"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Match = require(Shared:WaitForChild("Match"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local SmashFx = require(script.Parent:WaitForChild("SmashFx"))

local player = Players.LocalPlayer
local myId = player.UserId
local studio = RunService:IsStudio()

local K = Weapons.KART
local SIZES = {
	kart = K,
	rocket = Weapons.ROCKET.splash,
	nuke = Weapons.NUKE.splash,
	mine = 5 * Weapons.SCALE, -- server/weapons/Mine.RADIUS
}
local WHITE = Color3.new(1, 1, 1)
local CHERRY = Color3.fromRGB(230, 50, 60)
local SKY = Color3.fromRGB(90, 190, 255)
local NAVY = Color3.fromRGB(28, 32, 64)

-- ===== the Studio-only slow-mo hook and log =====
local function hold(): number?
	return SmashHits.hold(studio, workspace:GetAttribute(SmashHits.ATTR))
end
local function logging(): boolean
	return studio and (hold() ~= nil or workspace:GetAttribute("TestThumb") == true)
end
local function say(text: string)
	if logging() then
		print("[SmashHits] " .. text)
	end
end

-- Studio only: every Sfx cue says its name in the Output while the log is on (proof that each
-- weapon's fire, hit and boom sounds play). Wraps the shared table, so every caller is covered.
if studio then
	local t = Sfx :: any
	for name, fn in t do
		if type(fn) == "function" then
			t[name] = function(...)
				if logging() then
					print("[Sfx] " .. name)
				end
				return fn(...)
			end
		end
	end
end

local frozen = Instance.new("Folder")
frozen.Name = "SlowMoFreeze"
local lastFreeze: { [string]: number } = {}
-- Copy every weapon bit on screen right now (rockets, tracers, blasts, ice) as a still picture
-- for `secs` seconds; the real ones carry on and fade as usual. Once a second per kind at most.
local function freezeFrame(kind: string)
	local secs = hold()
	if not secs or os.clock() - (lastFreeze[kind] or -math.huge) < 1 then
		return
	end
	lastFreeze[kind] = os.clock()
	task.delay(0.06, function() -- (let the shot's parts be made and start to grow)
		local bits = workspace:FindFirstChild("WeaponBits")
		if not bits then
			return
		end
		frozen.Parent = workspace
		local snap = Instance.new("Folder")
		snap.Name = kind
		for _, c in bits:GetChildren() do
			if c:IsA("BasePart") or c:IsA("Model") then
				local ok, copy = pcall(function()
					return c:Clone()
				end)
				if ok and copy then
					for _, d in copy:GetDescendants() do
						if d:IsA("ParticleEmitter") then
							d.Enabled = false
						end
					end
					copy.Parent = snap
				end
			end
		end
		for _, d in bits:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.TimeScale = 0.15 -- (the live sparks crawl, so they're in the picture too)
			end
		end
		snap.Parent = frozen
		print(string.format("[SmashHits] slow-mo: %s frozen for %.1f s", kind, secs))
		task.delay(secs, function()
			snap:Destroy()
		end)
	end)
end

-- ===== karts =====
local function kartOf(id: number): Model?
	local m = workspace:FindFirstChild("Car_" .. id)
	return if m and m:IsA("Model") then m else nil
end
local function posOf(id: number): Vector3?
	local m = kartOf(id)
	if not m then
		return nil
	end
	local ok, cf = pcall(function()
		return m:GetPivot()
	end)
	return if ok then cf.Position else nil
end

-- ===== the shots the WeaponFx remote showed (to tell which weapon hit) =====
local shots: { SmashHits.Shot } = {}
local function vec(data: any, key: string): Vector3?
	local v = type(data) == "table" and data[key]
	return if typeof(v) == "Vector3" then v else nil
end
local function num(v: any): number?
	return if type(v) == "number" and v == v then v else nil
end

local FIRE_WORD: { [string]: string } = {
	RocketLaunch = "fire",
	GunShot = "fire gun",
	MineDrop = "fire mine (dropped)",
	FreezeShot = "fire freeze",
	RocketBoom = "boom",
	MineBoom = "boom mine",
	FreezeHit = "hit freeze (iced)",
	Shatter = "boom freeze (shatter)",
}

local function onFx(kind: unknown, data: unknown)
	if type(kind) ~= "string" or type(data) ~= "table" then
		return
	end
	local d = data :: any
	if kind == "RocketBoom" and d.quiet == true then
		return
	end
	local at = vec(d, "pos") or vec(d, "to") or vec(d, "position")
	if kind ~= "RocketLaunch" and kind ~= "RocketTurn" and kind ~= "MineDrop" and at then
		table.insert(shots, {
			t = os.clock(),
			kind = kind,
			x = at.X,
			z = at.Z,
			owner = num(d.owner),
			id = num(d.id),
			nuke = d.kind == "Nuke",
			hit = d.hit == true,
		})
	end
	-- a boom near you shakes you by how near (SmashFx)
	if (kind == "RocketBoom" or kind == "MineBoom" or kind == "Shatter") and at then
		SmashFx.boom(at)
	end
	if FIRE_WORD[kind] then
		local what = FIRE_WORD[kind]
		if kind == "RocketLaunch" or kind == "RocketBoom" then
			what ..= if d.kind == "Nuke" then " nuke" else " rocket"
		end
		-- (a gun burst is 6 shots: the log and the freeze take its first)
		if kind ~= "GunShot" or os.clock() - (lastFreeze.GunShot or -math.huge) >= 1 then
			say(what)
		end
		freezeFrame(kind)
	end
end
task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild(Weapons.FX_REMOTE)
	if remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(onFx)
	end
end)

-- ===== the victim flash and the floating number =====
local flashes: { [Model]: Highlight } = {}
local function flashKart(id: number)
	local m = kartOf(id)
	if not m then
		return
	end
	local h = flashes[m]
	if not h or h.Parent ~= m then
		local new = Instance.new("Highlight")
		new.Name = "HitFlash"
		new.DepthMode = Enum.HighlightDepthMode.Occluded
		new.OutlineColor = WHITE
		new.FillTransparency = 1
		new.OutlineTransparency = 1
		new.Parent = m
		h = new
		flashes[m] = new
		m.Destroying:Once(function()
			flashes[m] = nil
		end)
	end
	local hl = h :: Highlight
	local secs = math.max(SmashHits.FLASH_SECONDS, hold() or 0)
	hl.FillColor = WHITE
	hl.FillTransparency = 0.15
	hl.OutlineTransparency = 0
	TweenService:Create(
		hl,
		TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ FillColor = CHERRY, FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
end

local numbersGui = Instance.new("Folder")
numbersGui.Name = "SmashNumbers"
local function showNumber(id: number, amount: number, weapon: string)
	local m = kartOf(id)
	local part = m and m.PrimaryPart
	if not part then
		return
	end
	numbersGui.Parent = player:FindFirstChildOfClass("PlayerGui")
	local rgb = SmashHits.COLORS[weapon] or SmashHits.COLORS.bump
	local bb = Instance.new("BillboardGui")
	bb.Name = "Hit"
	bb.Adornee = part
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Size = UDim2.fromOffset(96, 44)
	bb.StudsOffset = Vector3.new(0, 0.6 * K, 0)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Base.FONT
	l.TextScaled = true
	l.Text = SmashHits.text(amount)
	l.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	l.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Color = NAVY
	stroke.Thickness = 3
	stroke.Parent = l
	local pop = Instance.new("UIScale")
	pop.Scale = 1.5
	pop.Parent = l
	bb.Parent = numbersGui
	local secs = math.max(SmashHits.NUMBER_SECONDS, hold() or 0)
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(
		bb,
		TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 1.3 * K, 0) }
	):Play()
	-- (holds solid for the first half, then fades)
	local fade = TweenInfo.new(
		secs * 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		secs * 0.5
	)
	TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(secs + 0.05, function()
		bb:Destroy()
	end)
end

local function nameOf(id: number): string
	local board = ReplicatedStorage:FindFirstChild("MatchBoard")
	local row = board and board:FindFirstChild(tostring(id))
	local n = row and row:GetAttribute("Name")
	return if type(n) == "string" then n else tostring(id)
end

-- ===== the spawn bubble =====
type Bubble = { part: BasePart, from: number, till: number? }
local bubbles: { [number]: Bubble } = {}
local bubbleFolder = Instance.new("Folder")
bubbleFolder.Name = "SpawnBubbles"
bubbleFolder.Parent = workspace

local function bubbleUp(id: number, till: number?)
	local b = bubbles[id]
	if b then
		b.till = till
		return
	end
	local p = Instance.new("Part")
	p.Name = "Bubble_" .. id
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.ForceField
	p.Color = SKY
	p.Size = Vector3.one * K * SmashHits.BUBBLE_SIZE
	p.Transparency = 1
	p.Parent = bubbleFolder
	bubbles[id] = { part = p, from = os.clock(), till = till }
	say(string.format("shield bubble up on %s", nameOf(id)))
end

local function bubbleDown(id: number)
	local b = bubbles[id]
	if not b then
		return
	end
	bubbles[id] = nil
	local p = b.part
	TweenService:Create(p, TweenInfo.new(SmashHits.BUBBLE_POP), {
		Size = p.Size * 1.3,
		Transparency = 1,
	}):Play()
	task.delay(SmashHits.BUBBLE_POP + 0.05, function()
		p:Destroy()
	end)
end

-- players: the server's Shield attribute (on at a respawn and a round start, off after 2 s)
local function watchPlayer(p: Player)
	local function update()
		if p:GetAttribute("Shield") == true and p:GetAttribute("InMatch") == true then
			bubbleUp(p.UserId, nil)
		else
			bubbleDown(p.UserId)
		end
	end
	p:GetAttributeChangedSignal("Shield"):Connect(update)
	p:GetAttributeChangedSignal("InMatch"):Connect(update)
	update()
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	bubbleDown(p.UserId)
end)

-- ===== the board: every kart's Health =====
local pending: { [number]: SmashHits.Pending } = {}
local lastHp: { [number]: number } = {}

local function onHealth(id: number, hp: number)
	local was = lastHp[id]
	lastHp[id] = hp
	if not was then
		return
	end
	if hp < was and was > 0 then
		local now = os.clock()
		local amount = was - math.max(hp, 0)
		pending[id] = SmashHits.add(pending[id], amount, now)
		flashKart(id)
		-- the sound right away (the number waits for the burst to end)
		local pos = posOf(id)
		if id ~= myId and pos then
			local w = SmashHits.guess(shots, id, pos.X, pos.Z, now, SIZES)
			if w == "bump" then
				local mine = posOf(myId)
				local close = mine and (mine - pos).Magnitude < K * 1.6
				Sfx.bump(if close then nil else pos)
			else
				Sfx.hit(pos)
			end
		elseif id == myId and pos then
			if SmashHits.guess(shots, id, pos.X, pos.Z, now, SIZES) == "bump" then
				Sfx.bump()
			end
		end
	elseif hp > was and was <= 0 then
		-- back from a smash: the bots' bubble (players have the server's Shield)
		if id < 0 then
			bubbleUp(id, os.clock() + Match.SHIELD)
		end
		if id == myId then
			say("back in the arena")
		end
	end
end

local function watchRow(row: Instance)
	local id = tonumber(row.Name)
	if not id then
		return
	end
	local function read()
		local hp = row:GetAttribute("Health")
		if type(hp) == "number" then
			onHealth(id :: number, hp)
		end
	end
	read()
	row:GetAttributeChangedSignal("Health"):Connect(read)
	row.Destroying:Once(function()
		lastHp[id :: number] = nil
		pending[id :: number] = nil
		bubbleDown(id :: number)
	end)
end
local function watchBoard(board: Instance)
	for _, row in board:GetChildren() do
		watchRow(row)
	end
	board.ChildAdded:Connect(watchRow)
end
do
	local board = ReplicatedStorage:FindFirstChild("MatchBoard")
	if board then
		watchBoard(board)
	else
		local conn: RBXScriptConnection
		conn = ReplicatedStorage.ChildAdded:Connect(function(c)
			if c.Name == "MatchBoard" then
				conn:Disconnect()
				watchBoard(c)
			end
		end)
	end
end

-- ===== every frame: due numbers, the bubbles =====
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	SmashHits.prune(shots, now)
	for id, p in pending do
		if SmashHits.due(p, now) then
			pending[id] = nil
			local pos = posOf(id)
			local weapon: string, owner: number? = "bump", nil
			if pos then
				weapon, owner =
					SmashHits.guess(shots, id, pos.X, pos.Z, p.first, SIZES, SmashHits.MERGE)
			end
			showNumber(id, p.amount, weapon)
			-- your own hit: a small shake (a bump counts when you were right there)
			if id ~= myId then
				local mine = posOf(myId)
				local mineBump = weapon == "bump"
					and pos ~= nil
					and mine ~= nil
					and (mine - pos).Magnitude < K * 1.6
				if owner == myId or mineBump then
					SmashFx.myHit(p.amount)
				end
			end
			say(
				string.format(
					"hit %s on %s %s%s (number %.1f s, flash %.2f s)",
					weapon,
					nameOf(id),
					SmashHits.text(p.amount),
					if owner then " by " .. nameOf(owner) else "",
					math.max(SmashHits.NUMBER_SECONDS, hold() or 0),
					math.max(SmashHits.FLASH_SECONDS, hold() or 0)
				)
			)
			freezeFrame("hit")
		end
	end
	for id, b in bubbles do
		if b.till and now >= b.till then
			bubbleDown(id)
		else
			local pos = posOf(id)
			if pos then
				local scale, see = SmashHits.bubble(now - b.from)
				b.part.Size = Vector3.one * K * SmashHits.BUBBLE_SIZE * scale
				b.part.Position = pos
				b.part.Transparency = see
			else
				b.part.Transparency = 1
			end
		end
	end
end)
