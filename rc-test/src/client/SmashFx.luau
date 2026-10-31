--!strict
-- Smash juice (phase 4, JUICE row): listens to the SmashFeed remote and your Health, and plays
--   * "You SMASHED <name>!" big in the middle top, popping in, with a white edge flash, confetti,
--     a shake and a little slow-mo (the camera punches in, holds, and eases back)
--   * a streak word under it (DOUBLE SMASH!, TRIPLE SMASH!, SMASH STREAK x3!)
--   * when you get smashed: "You were smashed by X's rocket" in red, a hard shake, and the camera
--     swings over to X with a big 3-2-1, then hands back when you respawn (or after 3.5 s)
--   * a red edge flash, a shove, a quick shake and a zoom pop when you take a hit
-- Sounds come from client/Sfx (the SOUNDS row): smash (yours and others', placed), hit, the
-- 3-2-1 count, respawn and shield.
-- All numbers live in shared/SmashJuice. Everything is made once at start, so a smash only sets
-- properties: the words are on screen on the next frame (hard target ≤ 0.1 s, logged as
-- "[SmashFx] shown in N ms"). Looks only: the server decides every hit, and driving stays LOCKED
-- (the shake and zoom are laid over the chase camera after it runs, never fed back into it).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local Announcer = require(Shared:WaitForChild("Announcer"))
local Ui = script.Parent:WaitForChild("Ui")
local Base = require(Ui:WaitForChild("Base"))
local Icons = require(Ui:WaitForChild("Icons"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local SmashFx = {}

local CONFETTI = 48 -- pool size (the most one smash ever throws)
local NAVY = Color3.fromRGB(28, 32, 64)
local CHERRY = Color3.fromRGB(230, 50, 60)
local SUN = Color3.fromRGB(255, 210, 60)
local PINK = Color3.fromRGB(255, 90, 170)

local started = false
local addFeel: ((SmashJuice.Feel) -> ())? = nil -- set by start()
local timings: { number } = {} -- last few "event → on screen" times, seconds

local function tween(obj: Instance, secs: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(
		obj,
		TweenInfo.new(secs, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

-- a phone: the small, high, brief words (SmashJuice.WORDS_TOUCH)
local PHONE = Base.phone()
local SPOTS = if PHONE then SmashJuice.WORDS_TOUCH else SmashJuice.WORDS
local function secs(s: number): number
	return if PHONE then math.min(s, SmashJuice.TOUCH_SECONDS) else s
end

local function word(parent: Instance, name: string, color: Color3, spot: string): TextLabel
	local at = SPOTS[spot]
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, at.y)
	l.Size = UDim2.fromScale(if PHONE then SmashJuice.WORDS_W_TOUCH else SmashJuice.WORDS_W, at.h)
	l.BackgroundTransparency = 1
	l.Font = Base.FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = ""
	l.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = NAVY
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = l
	local max = Instance.new("UITextSizeConstraint")
	max.MaxTextSize = if PHONE then 56 else 64
	max.Parent = l
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = l
	l.Parent = parent
	return l
end

-- one word line: pop in now, fade out after `secs` (a newer show cancels the old fade)
local function showWord(l: TextLabel, text: string, secs: number, from: number)
	local id = (l:GetAttribute("ShowId") or 0) :: number + 1
	l:SetAttribute("ShowId", id)
	l.Text = text
	l.TextTransparency = 0
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	l.Visible = true
	local pop = l:FindFirstChild("Pop") :: UIScale
	if Base.reduced() then
		pop.Scale = 1
	else
		pop.Scale = from
		tween(pop, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(secs, function()
		if l:GetAttribute("ShowId") ~= id then
			return
		end
		tween(l, 0.25, { TextTransparency = 1 })
		if stroke then
			tween(stroke, 0.25, { Transparency = 1 })
		end
		task.delay(0.26, function()
			if l:GetAttribute("ShowId") == id then
				l.Visible = false
			end
		end)
	end)
end

function SmashFx.start()
	if started then
		return
	end
	started = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "SmashFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20 -- over the HUD, under windows
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the edge flash: a frame with a see-through middle (a UIGradient on 4 sides is costly, so
	-- one frame with a thick UIStroke-like border made of 4 bars)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.Parent = gui
	local bars: { Frame } = {}
	for i, spec in
		{
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.07) },
			{ UDim2.fromScale(0, 0.93), UDim2.fromScale(1, 0.07) },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.05, 1) },
			{ UDim2.fromScale(0.95, 0), UDim2.fromScale(0.05, 1) },
		}
	do
		local b = Instance.new("Frame")
		b.Name = "Edge" .. i
		b.Position = spec[1]
		b.Size = spec[2]
		b.BorderSizePixel = 0
		b.BackgroundTransparency = 1
		b.Parent = flash
		table.insert(bars, b)
	end

	-- the words (SmashJuice.WORDS: under the clock and health, between the scoreboard and FIRE)
	local you = word(gui, "YouSmashed", Color3.new(1, 1, 1), "you")
	-- (match 1A: SMASH! in gold, a thick ink line, the name white under it)
	local gold = Instance.new("UIGradient")
	gold.Rotation = 90
	gold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 251, 224)),
		ColorSequenceKeypoint.new(0.38, Color3.fromRGB(255, 233, 90)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 196, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 154, 0)),
	})
	gold.Parent = you
	local youLine = you:FindFirstChildOfClass("UIStroke")
	if youLine then
		youLine.Thickness = 6
	end
	local name = word(gui, "Name", Color3.new(1, 1, 1), "name")
	local streak = word(gui, "Streak", PINK, "streak")

	-- the wrecked card (carter's pick A, 10-29): a red verb, a name tag with the weapon on a pink
	-- badge, and a 3-2-1 ring. Made once; a death only sets text and icon.
	local RED = Color3.fromRGB(255, 67, 56)
	local PANEL = Color3.fromRGB(19, 48, 74)
	local spot = if PHONE then SmashJuice.WRECK_TOUCH else SmashJuice.WRECK
	local function popScale(parent: Instance): UIScale
		local sc = Instance.new("UIScale")
		sc.Name = "Pop"
		sc.Parent = parent
		return sc
	end
	local function popIn(sc: UIScale, from: number, delay: number)
		if Base.reduced() then
			sc.Scale = 1
			return
		end
		sc.Scale = from
		task.delay(delay, function()
			tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	local function ink(l: GuiObject, px: number)
		local st = Instance.new("UIStroke")
		st.Color = NAVY
		st.Thickness = px
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
	end
	local function text(parent: Instance, name: string, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Font = Base.FONT
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = ""
		l.Parent = parent
		return l
	end

	local card = Instance.new("Frame")
	card.Name = "Wreck"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundTransparency = 1
	card.Visible = false
	card.Parent = gui

	local verb = text(card, "Verb", RED)
	verb.AnchorPoint = Vector2.new(0.5, 0.5)
	verb.Position = UDim2.fromScale(0.5, spot.verb.y)
	verb.Size = UDim2.fromScale(spot.verb.w, spot.verb.h)
	ink(verb, if PHONE then 4 else 6)
	local verbMax = Instance.new("UITextSizeConstraint")
	verbMax.MaxTextSize = if PHONE then 44 else 84
	verbMax.Parent = verb
	local verbPop = popScale(verb)

	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.fromScale(0.5, spot.tag.y)
	tag.Size = UDim2.fromScale(spot.tag.w, spot.tag.h)
	tag.BackgroundColor3 = PANEL
	tag.Parent = card
	Base.corner(tag, 999)
	ink(tag, if PHONE then 3 else 4)
	local tagPop = popScale(tag)
	local tagText = text(tag, "Words", Color3.new(1, 1, 1))
	tagText.RichText = true
	tagText.Position = UDim2.fromScale(0.05, 0.12)
	tagText.Size = UDim2.fromScale(0.68, 0.76)
	tagText.TextXAlignment = Enum.TextXAlignment.Left
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.fromScale(0.985, 0.5)
	badge.Size = UDim2.fromScale(0.95, 0.95)
	badge.BackgroundColor3 = PINK
	badge.Parent = tag
	Base.corner(badge, 999)
	ink(badge, 3)
	local square = Instance.new("UIAspectRatioConstraint")
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = badge

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, spot.ring.y)
	ring.BackgroundColor3 = PANEL
	ring.BackgroundTransparency = 0.15
	ring.Parent = card
	Base.corner(ring, 999)
	local ringEdge = Instance.new("UIStroke")
	ringEdge.Color = SUN
	ringEdge.Parent = ring
	local ringPop = popScale(ring)
	local num = text(ring, "Number", Color3.new(1, 1, 1))
	num.AnchorPoint = Vector2.new(0.5, 0.5)
	num.Position = UDim2.fromScale(0.5, 0.5)
	num.Size = UDim2.fromScale(0.6, 0.6)
	ink(num, if PHONE then 3 else 5)
	local backIn = text(ring, "BackIn", Color3.new(1, 1, 1))
	backIn.AnchorPoint = Vector2.new(1, 0.5)
	backIn.Position = UDim2.new(0, -8, 0.5, 0)
	backIn.Size = UDim2.fromScale(0.9, 0.22)
	backIn.TextXAlignment = Enum.TextXAlignment.Right
	backIn.Text = "BACK IN"
	ink(backIn, 3)

	local function showWreck(w: SmashJuice.Wreck)
		local screen = gui.AbsoluteSize
		verb.Text = w.verb
		local who, thing = string.match(w.tag, "^by (.-)'s (.+)$")
		tagText.Text = if who
			then `by <font color="#ff4f9a">{who}'s {thing}</font>`
			else if string.sub(w.tag, 1, 3) == "by "
				then `by <font color="#ff4f9a">{string.sub(w.tag, 4)}</font>`
				else w.tag
		local tagH = screen.Y * spot.tag.h
		for _, c in badge:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local bs = tagH * 0.95
		local icon = bs * 0.66
		Icons.make(badge, w.icon, (bs - icon) / 2, (bs - icon) / 2, icon, { z = 3 })
		local d = math.floor(screen.Y * spot.ring.h)
		ring.Size = UDim2.fromOffset(d, d)
		ringEdge.Thickness = math.max(4, d * 0.06)
		num.Text = ""
		card.Visible = true
		popIn(verbPop, 0.2, 0)
		popIn(tagPop, 0.2, 0.12)
	end
	local function showCount(n: number)
		num.Text = tostring(n)
		popIn(ringPop, 1.35, 0)
	end

	-- the confetti pool
	type Bit = { frame: Frame, vx: number, vy: number, spin: number, life: number }
	local bits: { Bit } = {}
	local rng = Random.new()
	for i = 1, CONFETTI do
		local f = Instance.new("Frame")
		f.Name = "Confetti" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.Visible = false
		f.Parent = gui
		local c = SmashJuice.CONFETTI[(i - 1) % #SmashJuice.CONFETTI + 1]
		f.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
		table.insert(bits, { frame = f, vx = 0, vy = 0, spin = 0, life = 0 })
	end
	local live = 0

	local function confetti(n: number)
		local thrown = 0
		for _, b in bits do
			if thrown >= n then
				break
			end
			if b.life <= 0 then
				thrown += 1
				b.life = rng:NextNumber(1.1, 1.6)
				b.vx = rng:NextNumber(-0.55, 0.55)
				b.vy = rng:NextNumber(-0.75, -0.35)
				b.spin = rng:NextNumber(-540, 540)
				local s = rng:NextInteger(7, 13)
				b.frame.Size = UDim2.fromOffset(s, math.floor(s * 0.6))
				b.frame.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.12, 0.12), SPOTS.name.y)
				b.frame.Rotation = rng:NextNumber(0, 360)
				b.frame.BackgroundTransparency = 0
				b.frame.Visible = true
				live += 1
			end
		end
	end

	local function edge(color: Color3, strength: number)
		if strength <= 0 then
			return
		end
		for _, b in bars do
			b.BackgroundColor3 = color
			b.BackgroundTransparency = 1 - 0.6 * strength
			tween(b, 0.35, { BackgroundTransparency = 1 })
		end
	end

	-- camera: shake + zoom punch + killer camera, laid over whatever camera ran this frame. If
	-- nothing set the camera since our last frame, ours is taken back off first, so it never
	-- piles up (vault "Snippets - Camera Shake and FX").
	local trauma = 0
	local punch, slow, punchAt = 0, 0, -math.huge
	-- the shove: how far (degrees), which side, and when it began
	local kickYaw, kickPitch, kickRoll, kickSide, kickAt = 0, 0, 0, 1, -math.huge
	local fps = 60
	local noiseT = 0
	local seed = rng:NextNumber(0, 1000)
	local baseCf, outCf = CFrame.identity, CFrame.identity
	local baseFov, outFov = 70, -1
	local pending: number? = nil -- os.clock() of words waiting to be seen on screen
	local pendingWhat = "" -- (the log: which words)

	-- the killer camera
	local killcam = false
	local killAt = 0
	local killFrom = CFrame.identity
	local killer: SmashJuice.Side? = nil
	local wasSmashed = false -- a smash on you was seen, so the next Health rise is a respawn
	local killerModel: Instance? = nil -- the kart, once found (no tag scan every frame)
	local lastWant: CFrame? = nil
	local shownCount: number? = nil

	local function feel(f: SmashJuice.Feel)
		trauma = SmashJuice.addTrauma(trauma, f.trauma)
		if f.punch ~= 0 then
			punch, slow, punchAt = f.punch, f.slow, os.clock()
		end
		if f.kick ~= 0 or f.lift ~= 0 or f.twist ~= 0 then
			-- (the server doesn't say which side a hit came from: they alternate)
			kickSide = -kickSide
			kickYaw, kickPitch, kickRoll, kickAt = f.kick, f.lift, f.twist, os.clock()
		end
	end
	addFeel = feel

	-- where the killer's kart is: the kart the server named, a tagged "Kart" model with their
	-- OwnerId / KartName, or their character
	local function kartOf(s: SmashJuice.Side): Instance?
		local k = s.kart
		if k and k:IsDescendantOf(workspace) and (k:IsA("Model") or k:IsA("BasePart")) then
			return k
		end
		for _, m in CollectionService:GetTagged("Kart") do
			if
				m:IsA("Model")
				and m:IsDescendantOf(workspace)
				and (
					(s.userId and m:GetAttribute("OwnerId") == s.userId)
					or (not s.userId and m:GetAttribute("KartName") == s.name)
				)
			then
				return m
			end
		end
		local p = if s.userId then Players:GetPlayerByUserId(s.userId) else nil
		return p and p.Character
	end

	local function pivotOf(k: Instance?): CFrame?
		if k and k:IsDescendantOf(workspace) then
			if k:IsA("Model") then
				return k:GetPivot()
			elseif k:IsA("BasePart") then
				return k.CFrame
			end
		end
		return nil
	end

	-- the killer's kart, found once per killer camera (no tag scan every frame)
	local lookedAt = -math.huge
	local function killerAt(s: SmashJuice.Side): CFrame?
		local at = pivotOf(killerModel)
		if at then
			return at
		end
		-- not found yet: look again at most 4 times a second
		if os.clock() - lookedAt < 0.25 then
			return nil
		end
		lookedAt = os.clock()
		killerModel = kartOf(s)
		return pivotOf(killerModel)
	end

	local function endKillcam()
		killcam = false
		killer = nil
		killerModel = nil
		lastWant = nil
		shownCount = nil
		card.Visible = false
	end

	RunService:BindToRenderStep(
		"SmashFx",
		Enum.RenderPriority.Camera.Value + 3,
		function(dt: number)
			if pending then
				local ms = (os.clock() - pending) * 1000
				table.insert(timings, ms / 1000)
				if #timings > 20 then
					table.remove(timings, 1)
				end
				if RunService:IsStudio() then
					print(
						string.format(
							"[SmashFx] shown in %d ms: %s",
							math.floor(ms + 0.5),
							pendingWhat
						)
					)
				end
				pending = nil
			end
			fps += ((1 / math.max(dt, 1 / 240)) - fps) * math.min(dt * 2, 1)
			local cam = workspace.CurrentCamera
			if cam then
				-- the default camera (walking) builds on last frame's view, so only a Scriptable
				-- camera (the chase camera) gets the shake and the killer view; the zoom is fine on both
				local scriptable = cam.CameraType == Enum.CameraType.Scriptable
				if cam.CFrame == outCf then
					cam.CFrame = baseCf
				end
				if cam.FieldOfView == outFov then
					cam.FieldOfView = baseFov
				end
				baseCf, baseFov = cam.CFrame, cam.FieldOfView
				local cf = baseCf

				if killcam then
					local t = os.clock() - killAt
					local n = SmashJuice.countdown(t)
					if n ~= shownCount then
						shownCount = n
						if n then
							showCount(n)
							Sfx.count(n)
						end
					end
					if t >= SmashJuice.KILLCAM_MAX then
						endKillcam()
					else
						local at = killer and killerAt(killer)
						if at then
							local pos = at.Position
							local back = -at.LookVector * Vector3.new(1, 0, 1)
							back = if back.Magnitude > 1e-3 then back.Unit else Vector3.zAxis
							local want = CFrame.lookAt(
								pos
									+ back * SmashJuice.KILLCAM_BACK
									+ Vector3.yAxis * SmashJuice.KILLCAM_UP,
								pos
							)
							lastWant = want
							cf = killFrom:Lerp(want, SmashJuice.flyAlpha(t))
						else
							-- killer gone: keep looking where it was, and count
							cf = if lastWant
								then killFrom:Lerp(lastWant, SmashJuice.flyAlpha(t))
								else killFrom
						end
					end
				end

				local fov = baseFov - SmashJuice.punchAt(punch, slow, os.clock() - punchAt)
				if trauma > 0 then
					noiseT += dt * SmashJuice.noiseHz(fps)
					local p, y, r = SmashJuice.tilt(
						trauma,
						2 * math.noise(noiseT, seed),
						2 * math.noise(noiseT, seed + 31),
						2 * math.noise(noiseT, seed + 67)
					)
					cf *= CFrame.Angles(math.rad(p), math.rad(y), math.rad(r))
					trauma = SmashJuice.decay(trauma, dt)
				end
				local sp = SmashJuice.kickAt(os.clock() - kickAt)
				if sp ~= 0 then
					cf *= CFrame.Angles(
						math.rad(kickPitch * sp),
						math.rad(kickSide * kickYaw * sp),
						math.rad(kickSide * kickRoll * sp)
					)
				end
				if scriptable and cf ~= baseCf then
					cam.CFrame = cf
				end
				if fov ~= baseFov then
					cam.FieldOfView = fov
				end
				outCf, outFov = cam.CFrame, cam.FieldOfView
			end
			if live > 0 then
				for _, b in bits do
					if b.life > 0 then
						b.life -= dt
						b.vy += 1.4 * dt
						local pos = b.frame.Position
						b.frame.Position =
							UDim2.fromScale(pos.X.Scale + b.vx * dt * 0.6, pos.Y.Scale + b.vy * dt)
						b.frame.Rotation += b.spin * dt
						if b.life < 0.3 then
							b.frame.BackgroundTransparency = 1 - b.life / 0.3
						end
						if b.life <= 0 then
							b.frame.Visible = false
							live -= 1
						end
					end
				end
			end
		end
	)

	local myStreak = SmashJuice.streak()
	local announcer = Announcer.new()

	local function onFeed(attacker: unknown, victim: unknown, weapon: unknown)
		local at = os.clock()
		local f = SmashJuice.read(attacker, victim, weapon, player.UserId)
		if not f then
			return
		end
		local reduced = Base.reduced()
		if f.attacker and f.attacker.me and not f.victim.me then
			local shout = announcer:shout(at, true, myStreak:smash(at), myStreak.run)
			local word2 = if shout then shout.text else nil
			card.Visible = false
			showWord(you, SmashJuice.popWord(f.weapon), secs(SmashJuice.WORDS_SECONDS), 0.3)
			showWord(name, SmashJuice.shortName(f.victim.name), secs(SmashJuice.WORDS_SECONDS), 1.4)
			if word2 then
				showWord(streak, word2, secs(SmashJuice.STREAK_SECONDS), 1.5)
			end
			local juice = SmashJuice.feel("mySmash", myStreak.run, reduced)
			feel(juice)
			edge(Color3.new(1, 1, 1), juice.flash)
			confetti(juice.confetti)
			pending = at
			pendingWhat = SmashJuice.smashLine(f.weapon)
				.. " "
				.. SmashJuice.shortName(f.victim.name)
				.. "!"
				.. (if word2 then " + " .. word2 .. " + confetti" else "")
			Sfx.smash()
			if shout and shout.sound then
				Sfx.announce()
			end
		elseif f.victim.me then
			myStreak:reset()
			you.Visible = false
			name.Visible = false
			streak.Visible = false
			local other = if f.attacker and not f.attacker.me then f.attacker else nil
			showWreck(SmashJuice.wreck(f.weapon, other and other.name))
			local juice = SmashJuice.feel("smashed", nil, reduced)
			feel(juice)
			edge(CHERRY, juice.flash)
			pending = at
			pendingWhat = SmashJuice.deathLine(f.weapon, other and other.name) .. " + 3-2-1"
			-- the killer camera (it's info, so reduced motion keeps it)
			killcam = true
			killAt = at
			killFrom = baseCf
			killer = other
			killerModel = nil
			lookedAt = -math.huge
			lastWant = nil
			shownCount = nil
			wasSmashed = true
			Sfx.smash()
		else
			-- someone else's smash: heard from where it happened
			-- (no kart found → no sound, so far-off smashes never play at full volume)
			local shout = announcer:shout(at, false, nil, 0)
			if shout then
				showWord(streak, shout.text, secs(SmashJuice.STREAK_SECONDS), 1.5)
				if shout.sound then
					Sfx.announce()
				end
			end
			local where = pivotOf(kartOf(f.victim))
				or (f.attacker and pivotOf(kartOf(f.attacker :: SmashJuice.Side)))
			if where then
				Sfx.smash(where.Position)
			end
		end
	end

	local function hook(remote: Instance)
		if remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onFeed)
		end
	end
	local feed = ReplicatedStorage:FindFirstChild("SmashFeed")
	if feed then
		hook(feed)
	else
		-- the match server makes it; wait for it without blocking the caller
		local conn: RBXScriptConnection
		conn = ReplicatedStorage.ChildAdded:Connect(function(c: Instance)
			if c.Name == "SmashFeed" and c:IsA("RemoteEvent") then
				conn:Disconnect()
				hook(c)
			end
		end)
	end

	-- Health (the server sets it): going down is a hit; coming back up is the respawn, which hands
	-- the camera back
	local h0 = player:GetAttribute("Health")
	local lastHealth: number? = if type(h0) == "number" then h0 else nil
	-- the spawn shield goes up (the server sets Shield)
	player:GetAttributeChangedSignal("Shield"):Connect(function()
		if player:GetAttribute("Shield") == true then
			Sfx.shield()
		end
	end)
	player:GetAttributeChangedSignal("Health"):Connect(function()
		local h = player:GetAttribute("Health")
		if type(h) ~= "number" then
			return
		end
		local was = lastHealth
		lastHealth = h
		if was and h < was and h > 0 then
			local juice = SmashJuice.feel("hit", was - h, Base.reduced())
			feel(juice)
			edge(CHERRY, juice.flash)
			Sfx.hit()
		elseif was and h > was and was <= 0 and wasSmashed then
			wasSmashed = false
			-- back from a smash (the respawn)
			if RunService:IsStudio() then
				print(
					string.format("[SmashFx] back in %.1f s after the smash", os.clock() - killAt)
				)
			end
			Sfx.respawn()
			if killcam then
				endKillcam()
			end
		elseif was and h > was and killcam and os.clock() - killAt > 0.5 then
			endKillcam()
		end
	end)
end

-- a boom (rocket, mine) at `at`: shakes you by how near it was. WeaponFx can call this.
function SmashFx.boom(at: Vector3)
	local cam = workspace.CurrentCamera
	local add = addFeel
	if not cam or not add then
		return
	end
	add(SmashJuice.feel("boom", (cam.CFrame.Position - at).Magnitude, Base.reduced()))
end

-- a shake and a zoom punch for a moment that isn't a hit (the match start's 3-2-1-GO)
function SmashFx.kick(trauma: number, punch: number)
	local add = addFeel
	if add and not Base.reduced() then
		-- (every Feel field: a missing kick / lift / twist read as nil broke the camera every frame)
		add({
			trauma = trauma,
			punch = punch,
			kick = 0,
			lift = 0,
			twist = 0,
			slow = 0.12,
			confetti = 0,
			flash = 0,
		})
	end
end

-- your own hit on another kart (client/SmashHits): a small shake
function SmashFx.myHit(damage: number)
	local add = addFeel
	if add then
		add(SmashJuice.feel("myHit", damage, Base.reduced()))
	end
end

-- the last few "smash arrived → words on screen" times in seconds (for the Studio timing log)
function SmashFx.timings(): { number }
	return table.clone(timings)
end

return SmashFx
