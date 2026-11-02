--!strict
-- Hits you can feel (JUICE row, auditor "Road to 9/10" items 2 and 3). Numbers and rules live in
-- shared/SmashHits. Looks and sounds only: the server decides every hit.
--   * any kart that loses health (its MatchBoard row) flashes white-to-red and a "-34" floats up
--     beside it (UI kit v41: a red number on a yellow burst; a gun burst or a bump scrape adds up
--     into one number)
--   * other karts' hits are heard where they happen; a bump plays the bump sound
--   * your own hit on someone gives you a small shake; a boom near you shakes you by how near
--   * the blue spawn bubble over every kart that just came back (players: the server's Shield)
--   * Studio only, workspace TestSlowMo = true (or seconds): every shot, boom and hit is frozen on
--     screen for that long, and the Output says "[SmashHits] ..." and "[Sfx] <sound>" per cue;
--     TestSlowMo = "hold" keeps each kind's last frozen frame up until the attribute is cleared
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SmashHits = require(Shared:WaitForChild("SmashHits"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Match = require(Shared:WaitForChild("Match"))
local KitWorld = require(Shared:WaitForChild("KitWorld"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local SmashFx = require(script.Parent:WaitForChild("SmashFx"))
local ArenaLifeFx = require(script.Parent:WaitForChild("ArenaLifeFx"))
local Buzz = require(script.Parent:WaitForChild("Buzz"))

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
-- ("hold": each kind's last frozen frame and each weapon's last number, newest wins; and the
-- karts' flashes, held on)
local kept: { [string]: Instance } = {}
local keptFlash: { [Highlight]: boolean } = {}
local function held(): boolean
	return SmashHits.held(studio, workspace:GetAttribute(SmashHits.ATTR))
end
if studio then
	workspace:GetAttributeChangedSignal(SmashHits.ATTR):Connect(function()
		if not held() then
			for kind, snap in kept do
				snap:Destroy()
				kept[kind] = nil
			end
			for hl in keptFlash do
				hl.Enabled = false
				keptFlash[hl] = nil
			end
		end
	end)
end
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
		if not hold() then -- (TestSlowMo cleared in the last 0.06 s)
			return
		end
		for _, c in bits:GetChildren() do
			if c:IsA("BasePart") or c:IsA("Model") then
				local ok, copy = pcall(function()
					return c:Clone()
				end)
				if ok and copy then
					for _, d in (copy :: Instance):GetDescendants() do
						if d:IsA("ParticleEmitter") then
							d.Enabled = false
						elseif d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					if copy:IsA("BasePart") then
						copy.Anchored = true -- (a held copy must not drift or block a kart)
						copy.CanCollide = false
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
		if held() then
			local old = kept[kind]
			if old then
				old:Destroy()
			end
			kept[kind] = snap
			print(string.format("[SmashHits] slow-mo: %s frozen until TestSlowMo is cleared", kind))
			return
		end
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
	return m:GetPivot().Position
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

-- the fx's hurt = { { id, damage } } (WEAPONS #972, GUNMINE #973) as a set of kart ids
local function hurtOf(list: any): { [number]: boolean }?
	if type(list) ~= "table" then
		return nil
	end
	local out: { [number]: boolean } = {}
	for i, h in list do
		if type(i) ~= "number" or i > 16 then
			break
		end
		local id = type(h) == "table" and num(h.id)
		if id then
			out[id] = true
		end
	end
	return out
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
	FlameBurst = "fire flame",
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
			hurt = hurtOf(d.hurt),
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
-- What the flash goes on: the kart you SEE. Other karts are drawn by OtherCars as a FOLDER of
-- mesh parts (workspace.OtherCars.Car_<id>: Body, Wheel, Seat, ...), and a Highlight under a
-- Folder never draws, so it goes on that kart's Body part (the shell, most of what you see). The
-- Car_<id> model itself is the small hidden physics body (Studio 10-29: a flash on it never
-- showed); it is used only when nothing is drawn for it (your own kart is the real model).
local function flashOn(id: number, body: Model): Instance?
	if id == myId then
		return body
	end
	local others = workspace:FindFirstChild("OtherCars")
	local seen = others and others:FindFirstChild(body.Name)
	if not seen then
		-- (OtherCars hides far karts: nothing drawn, no flash; no OtherCars at all: the model)
		return if others then nil else body
	end
	if seen:IsA("Model") then
		return seen
	end
	local shell = seen:FindFirstChild("Body")
	if shell and shell:IsA("BasePart") then
		return shell
	end
	-- (no Body: the biggest part there)
	local best: BasePart? = nil
	for _, d in seen:GetDescendants() do
		if d:IsA("BasePart") and (best == nil or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	return best or body
end

local function flashKart(id: number)
	local body = kartOf(id)
	if not body then
		return
	end
	local m = flashOn(id, body)
	if not m then
		return
	end
	-- (one per drawn kart, kept on it: OtherCars hides a far kart by unparenting it and brings it
	-- back with its flash, so look for it instead of caching it)
	local h = m:FindFirstChild("HitFlash")
	if not (h and h:IsA("Highlight")) then
		local new = Instance.new("Highlight")
		new.Name = "HitFlash"
		new.DepthMode = Enum.HighlightDepthMode.Occluded
		new.OutlineColor = WHITE
		new.FillTransparency = 1
		new.OutlineTransparency = 1
		new.Parent = m
		h = new
	end
	local hl = h :: Highlight
	if held() then
		-- (Studio "hold": the flash stays on, mid white-to-red, until TestSlowMo is cleared)
		hl:SetAttribute("FlashId", ((hl:GetAttribute("FlashId") :: number?) or 0) + 1)
		hl.Enabled = true
		keptFlash[hl] = true
		-- (a short tween, not a zero one: it also takes over from a fade still running)
		TweenService:Create(hl, TweenInfo.new(0.05), {
			FillColor = WHITE:Lerp(CHERRY, 0.6),
			FillTransparency = 0.15,
			OutlineTransparency = 0,
		}):Play()
		return
	end
	local secs = math.max(SmashHits.FLASH_SECONDS, hold() or 0)
	-- (off between hits: an idle Highlight still costs a render pass on a phone)
	local flashId = ((hl:GetAttribute("FlashId") :: number?) or 0) + 1
	hl:SetAttribute("FlashId", flashId)
	task.delay(secs + 0.05, function()
		if hl:GetAttribute("FlashId") == flashId then
			hl.Enabled = false
		end
	end)
	hl.Enabled = true
	hl.FillColor = WHITE
	hl.FillTransparency = 0.15
	hl.OutlineTransparency = 0
	TweenService:Create(
		hl,
		TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ FillColor = CHERRY, FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
end

-- ===== the "-N" hit number (UI kit v41: a red stroked number on a yellow burst) =====
-- Grows 0.4 -> 1.2 -> 1, rises 44 px and fades (KitWorld.number). Pooled, 12 at most: the oldest
-- is reused. On the kart's body, not AlwaysOnTop (on carter's PC AlwaysOnTop billboards never
-- drew: KartWeaponIcon).
local numbersGui = Instance.new("Folder")
numbersGui.Name = "SmashNumbers"
local function kitColor(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
local INK = kitColor(KitWorld.INK)

type Num = {
	bb: BillboardGui,
	body: Frame,
	scale: UIScale,
	label: TextLabel,
	drop: TextLabel,
	burst: { Frame },
	strokes: { UIStroke },
}

local function makeNumber(): Num
	local bb = Instance.new("BillboardGui")
	bb.Name = "Hit"
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 60 -- (past that a kart is a few pixels: no big number over it)
	bb.ResetOnSpawn = false
	local w = KitWorld.BURST_PX + 48
	local h = KitWorld.BURST_PX + KitWorld.RISE_PX + 16
	bb.Size = UDim2.fromOffset(w, h)
	bb:SetAttribute("DW", w)
	bb:SetAttribute("DH", h)
	-- to the right of the kart's roof (Studio 10-29: "-34" sat on "CAPTAIN CRASH") and lifted clear
	-- above the weapon badge over the kart (auditor 10-29: it sat on the badge); its bottom starts
	-- there and it rises
	bb.StudsOffsetWorldSpace = Vector3.new(0, KitWorld.NUMBER_LIFT, 0)
	bb.SizeOffset = Vector2.new(KitWorld.NUMBER_SIDE, 0.5 + KitWorld.numberAbove() / h)
	bb.Enabled = false
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Size = UDim2.fromOffset(KitWorld.BURST_PX, KitWorld.BURST_PX)
	body.Position = UDim2.new(0.5, 0, 1, 0)
	body.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Parent = body
	-- the burst: squares turned a little each, ink ones a rim bigger under yellow ones (so no ink
	-- lines show inside)
	local burst: { Frame } = {}
	local side = KitWorld.BURST_PX / math.sqrt(2)
	for layer = 1, 2 do
		for i = 0, KitWorld.BURST_POINTS - 1 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Rotation = i * 90 / KitWorld.BURST_POINTS
			if layer == 1 then
				local r = KitWorld.STROKE_PX * 0.75
				f.Size = UDim2.fromOffset(side + 2 * r, side + 2 * r)
				f.BackgroundColor3 = INK
				f.ZIndex = 1
			else
				f.Size = UDim2.fromOffset(side, side)
				f.BackgroundColor3 = Color3.new(1, 1, 1)
				f.ZIndex = 2
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(kitColor(KitWorld.GO), kitColor(KitWorld.GO_DEEP))
				g.Rotation = 90 - f.Rotation -- (light at the top for every square)
				g.Parent = f
			end
			f.Parent = body
			table.insert(burst, f)
		end
	end
	local strokes: { UIStroke } = {}
	local function word(name: string, z: number, down: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 0.5, down)
		l.Size = UDim2.fromOffset(KitWorld.BURST_PX + 40, KitWorld.NUMBER_PX + 8)
		l.Font = Base.FONT
		l.TextSize = KitWorld.NUMBER_PX
		l.ZIndex = z
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = KitWorld.STROKE_PX
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
		table.insert(strokes, st)
		l.Parent = body
		return l
	end
	local drop = word("Drop", 3, KitWorld.DROP_PX)
	drop.TextColor3 = INK
	local label = word("Number", 4, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, kitColor(KitWorld.NUMBER_TOP)),
		ColorSequenceKeypoint.new(0.45, kitColor(KitWorld.NUMBER_MID)),
		ColorSequenceKeypoint.new(1, kitColor(KitWorld.NUMBER_LOW)),
	})
	fill.Rotation = 90
	fill.Parent = label
	bb.Parent = numbersGui
	return {
		bb = bb,
		body = body,
		scale = scale,
		label = label,
		drop = drop,
		burst = burst,
		strokes = strokes,
	}
end

-- the number's look `t` s in (stretched to `secs` for the Studio slow-mo)
local function pose(n: Num, t: number, secs: number, reduced: boolean)
	local u = t * KitWorld.SECONDS / secs
	local s, rise, see = KitWorld.number(u, reduced)
	if u <= KitWorld.POP_GROW + KitWorld.POP_SETTLE + 0.05 or reduced then
		n.scale.Scale = s
	end
	n.body.Position = UDim2.new(0.5, 0, 1, -rise)
	if see == 0 and u > 0 then
		return -- (solid until the fade: nothing to write)
	end
	for _, f in n.burst do
		f.BackgroundTransparency = see
	end
	n.label.TextTransparency = see
	n.drop.TextTransparency = see
	for _, st in n.strokes do
		st.Transparency = see
	end
end

local pool: { Num } = {}
local busy: { [number]: number? } = {} -- [slot] = when it showed
local busyFor: { [number]: number } = {} -- [slot] = how long it shows

local function freeNumber(slot: number)
	busy[slot] = nil
	local n = pool[slot]
	if n and n.bb.Parent ~= nil then -- (nil: it went with its kart)
		n.bb.Enabled = false
		n.bb.Adornee = nil
		n.bb.Parent = numbersGui
	end
end

local function showNumber(id: number, amount: number, weapon: string)
	local m = kartOf(id)
	local part = m and m.PrimaryPart
	if not part then
		return
	end
	numbersGui.Parent = player:FindFirstChildOfClass("PlayerGui")
	local text = SmashHits.text(amount)
	if held() then
		-- (Studio "hold": this weapon's newest number stays up until TestSlowMo is cleared; not
		-- from the pool, so the pool never reuses it)
		local n = makeNumber()
		n.label.Text, n.drop.Text = text, text
		pose(n, KitWorld.POP_GROW + KitWorld.POP_SETTLE, KitWorld.SECONDS, Base.reduced())
		local bb = n.bb
		bb.Adornee = part
		bb.Parent = part
		bb.Enabled = true
		local key = "number " .. weapon
		local old = kept[key]
		if old then
			old:Destroy()
		end
		kept[key] = bb
		return
	end
	local slot = KitWorld.pick(busy, #pool)
	local n = pool[slot]
	if n == nil or n.bb.Parent == nil then
		n = makeNumber()
		pool[slot] = n
	end
	assert(n)
	n.label.Text, n.drop.Text = text, text
	busy[slot] = os.clock()
	busyFor[slot] = math.max(KitWorld.SECONDS, hold() or 0)
	pose(n, 0, busyFor[slot], Base.reduced())
	n.bb.Adornee = part
	n.bb.Parent = part
	n.bb.Enabled = true
end

-- every frame: move the numbers showing on, free the ones that are done
local function stepNumbers(now: number)
	if next(busy) == nil then
		return
	end
	local reduced = Base.reduced()
	for slot, at in busy do
		if at == nil then
			continue
		end
		local n = pool[slot]
		local t = now - at
		if not n or t >= busyFor[slot] then
			freeNumber(slot)
		else
			pose(n, t, busyFor[slot], reduced)
		end
	end
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
	if logging() then
		say(string.format("shield bubble up on %s", nameOf(id)))
	end
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
local watchers: { [Player]: { RBXScriptConnection } } = {}
local function watchPlayer(p: Player)
	local function update()
		if p:GetAttribute("Shield") == true and p:GetAttribute("InMatch") == true then
			bubbleUp(p.UserId, nil)
		else
			bubbleDown(p.UserId)
		end
	end
	watchers[p] = {
		p:GetAttributeChangedSignal("Shield"):Connect(update),
		p:GetAttributeChangedSignal("InMatch"):Connect(update),
	}
	update()
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	for _, c in watchers[p] or {} do
		c:Disconnect()
	end
	watchers[p] = nil
	bubbleDown(p.UserId)
end)

-- where a bump happened: between the kart and the nearest other kart touching it (else on it)
local function bumpSpot(id: number, pos: Vector3): Vector3
	local best, bestD = pos, K * 2.5
	local name = "Car_" .. id
	for c in ArenaLifeFx.karts() do
		if c.Name ~= name and c.Parent then
			local p = c:GetPivot().Position
			local d = (p - pos).Magnitude
			if d < bestD then
				best, bestD = (p + pos) / 2, d
			end
		end
	end
	return best
end

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
		local pos = posOf(id)
		local p = SmashHits.add(pending[id], amount, now)
		if pos and p.first == now then
			p.x, p.z = pos.X, pos.Z -- (where it was hit: the kart moves on before the number)
		end
		pending[id] = p
		flashKart(id)
		-- the sound a moment later: the server sets Health just before it sends the shot or boom,
		-- so wait for that to land before telling a weapon hit from a bump
		-- (where a bump would be: now, while both karts are still there)
		local spot = if pos then bumpSpot(id, pos) else nil
		task.delay(SmashHits.SOUND_WAIT, function()
			if not pos then
				return
			end
			local w, by = SmashHits.guess(shots, id, pos.X, pos.Z, now, SIZES, SmashHits.SOUND_WAIT)
			-- the phone buzzes: a hit on you, and a bigger one when you smash a kart
			if id == myId then
				Buzz.hit()
			elseif hp <= 0 and by == myId then
				Buzz.smash()
			end
			if w == "bump" and spot then
				ArenaLifeFx.spark(spot)
			end
			if id == myId then
				if w == "bump" then
					Sfx.bump() -- (SmashFx plays your hit sound)
				end
			elseif w == "bump" then
				local mine = posOf(myId)
				local close = mine and (mine - pos).Magnitude < K * 1.6
				Sfx.bump(if close then nil else pos)
			else
				Sfx.hit(pos)
			end
		end)
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
	board.ChildAdded:Connect(function(row)
		watchRow(row)
		-- a bot joining a round starts behind the spawn shield too
		local id = tonumber(row.Name)
		if id and id < 0 then
			bubbleUp(id, os.clock() + Match.SHIELD)
		end
	end)
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
	stepNumbers(now)
	for id, p in pending do
		if SmashHits.due(p, now) then
			pending[id] = nil
			local pos = posOf(id)
			local weapon: string, owner: number? = "bump", nil
			local x, z = p.x or (pos and pos.X), p.z or (pos and pos.Z)
			if x and z then
				weapon, owner = SmashHits.guess(
					shots,
					id,
					x,
					z,
					p.first,
					SIZES,
					p.last - p.first + SmashHits.MERGE
				)
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
			if logging() then
				say(
					string.format(
						"hit %s on %s %s%s (number %.1f s, flash %.2f s)",
						weapon,
						nameOf(id),
						SmashHits.text(p.amount),
						if owner then " by " .. nameOf(owner) else "",
						math.max(KitWorld.SECONDS, hold() or 0),
						math.max(SmashHits.FLASH_SECONDS, hold() or 0)
					)
				)
			end
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
