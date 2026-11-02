--!strict
-- The crate opening show (carter picked B "spinning reel", all out, 10-29; the page he tried is
-- crate-open/crate-all-out.html). Smash only. It plays between the OPEN tap and the reveal card:
-- the crate crashes in, its lid blasts off, a reel of cars blurs past with chasing lights, goes
-- dark and slow, freezes for a beat on your car, then BOOM (rings, lightning, a huge word, coins,
-- confetti) that grows with the rarity. The server already rolled the car; the plan (which cards,
-- where it stops, how long) is shared/CrateReel. SKIP is always there; with Reduced Motion on it
-- doesn't play at all. Words use Base.FONT, so a game-wide font change reaches it too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Crates = require(Shared:WaitForChild("Crates"))
local CrateReelPlan = require(Shared:WaitForChild("CrateReel"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Icons = require(Ui:WaitForChild("Icons"))
local Kit = require(Ui:WaitForChild("Kit"))
local Party = require(Ui.Parent:WaitForChild("Party"))
local Sfx = require(Ui.Parent:WaitForChild("Sfx"))

local CrateReel = {}

local W, H = Base.W, Base.H
local INK, WHITE = Base.color("ink"), Base.WHITE
local BLACK = Color3.new(0, 0, 0)
local BULB_ON, BULB_OFF = Color3.fromRGB(255, 229, 102), Color3.fromRGB(90, 74, 16)
-- the crate on the screen looks like the crate you picked (as in the crates window)
local CRATE_RARITY: { [string]: string } =
	{ free = "common", basic = "common", big = "rare", mega = "epic" }
local CARD_W, CARD_H, CARD_GAP = 170, 198, 12
local STEP = CARD_W + CARD_GAP
local REEL_Y, REEL_H = 42, 262
local CENTRE = W / 2 -- the pointer

local playing = false

local function tween(
	obj: Instance,
	secs: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		obj,
		TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function rarityColor(n: number): Color3
	local id = UiTheme.rarityId(CarCatalog.RARITY_ORDER[n])
	return Base.color(UiTheme.RARITY[id].color)
end

local function rarityWord(n: number): string
	local id = UiTheme.rarityId(CarCatalog.RARITY_ORDER[n])
	return UiTheme.RARITY[id].word
end

-- Kit.face takes hex words, so a colour goes back to its hex
local function hexOf(c: Color3): string
	return string.format(
		"%02x%02x%02x",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x / W, y / H)
end

-- A car on each card: a real car of that kind from the crate pool (the winner is yours).
local function carIds(): { [number]: { string } }
	local pool = Crates.pool()
	local out: { [number]: { string } } = {}
	for i, r in CarCatalog.RARITY_ORDER do
		out[i] = pool[r] or {}
	end
	return out
end

-- Plays the show for `o.kind` (the crate), `o.rarity` and `o.id` (the car that came out), then
-- calls done() (the reveal). Only one show at a time: while one plays, a second goes straight to
-- done().
function CrateReel.play(o: { id: string, rarity: string, kind: string? }, done: () -> ())
	if playing or Base.reduced() then
		done()
		return
	end
	playing = true
	local kind = o.kind or "basic"
	local plan = CrateReelPlan.plan(o.rarity, kind)
	local t = plan.rarity
	local rc = rarityColor(t)
	local g = Base.screen("CrateReel", Base.ORDER.celebrate, true)
	local back = g.back :: ScreenGui
	local alive = true
	local finished = false
	local conns: { RBXScriptConnection } = {}
	local stopRays: (() -> ())? = nil

	-- the ground: the reveal's warm purple, so the card after it feels like the same room
	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.BorderSizePixel = 0
	ground.Size = UDim2.fromScale(1, 1)
	ground.Active = true
	ground.Parent = back
	Kit.face(ground, { "2a1a5a", "5a2a8c", "9a3f8f" })
	local stage = Base.stage(g.canvas)
	stage.Name = "Stage"

	local function finish()
		if finished then
			return
		end
		finished = true
		alive = false
		for _, c in conns do
			c:Disconnect()
		end
		if stopRays then
			stopRays()
		end
		g.gui:Destroy()
		back:Destroy()
		playing = false
		done()
	end

	-- ===== small effects =====
	local function pause(secs: number)
		task.wait(secs)
		if not alive then
			error("skipped")
		end
	end

	local function flash(peak: number, secs: number)
		local f = Instance.new("Frame")
		f.Name = "Flash"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = WHITE
		f.BackgroundTransparency = 1 - peak
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 60
		f.Active = false
		f.Parent = g.gui
		tween(f, secs, { BackgroundTransparency = 1 }).Completed:Connect(function()
			f:Destroy()
		end)
	end

	local shaking = 0
	local function shake(strength: number, secs: number)
		shaking += 1
		local mine = shaking
		task.spawn(function()
			local t0 = os.clock()
			while alive and mine == shaking and os.clock() - t0 < secs do
				local left = 1 - (os.clock() - t0) / secs
				local a = strength * left
				stage.Position = UDim2.new(
					0.5,
					math.random(-100, 100) / 100 * a,
					0.5,
					math.random(-100, 100) / 100 * a
				)
				task.wait(0.03)
			end
			if alive then
				stage.Position = UDim2.fromScale(0.5, 0.5)
			end
		end)
	end

	local function ring(x: number, y: number, delay: number)
		task.delay(delay, function()
			if not alive then
				return
			end
			local r = Instance.new("Frame")
			r.Name = "Ring"
			r.BackgroundTransparency = 1
			r.AnchorPoint = Vector2.new(0.5, 0.5)
			r.Position = at(x, y)
			r.Size = UDim2.fromScale(40 / W, 40 / H)
			r.ZIndex = 30
			r.Parent = stage
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = r
			local s = Base.outline(r, 7, rc)
			tween(r, 0.75, { Size = UDim2.fromScale(560 / W, 560 / H) })
			tween(s, 0.75, { Transparency = 1 }).Completed:Connect(function()
				r:Destroy()
			end)
		end)
	end

	-- a jagged bolt of light from (x1, y1) to (x2, y2): a wide glow under a white core
	local function bolt(x1: number, y1: number, x2: number, y2: number)
		local pts = { { x1, y1 } }
		local n = 7
		for i = 1, n - 1 do
			local u = i / n
			local wob = math.sin(u * math.pi) * 60
			table.insert(pts, {
				x1 + (x2 - x1) * u + (math.random() - 0.5) * wob,
				y1 + (y2 - y1) * u + (math.random() - 0.5) * wob,
			})
		end
		table.insert(pts, { x2, y2 })
		for layer = 1, 2 do
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dy * dy) + 3
				local seg = Instance.new("Frame")
				seg.Name = "Bolt"
				seg.BorderSizePixel = 0
				seg.AnchorPoint = Vector2.new(0.5, 0.5)
				seg.BackgroundColor3 = if layer == 1 then rc else WHITE
				seg.BackgroundTransparency = if layer == 1 then 0.45 else 0
				seg.Position = at((a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
				seg.Size = UDim2.fromScale(len / W, (if layer == 1 then 13 else 4) / H)
				seg.Rotation = math.deg(math.atan2(dy, dx))
				seg.ZIndex = if layer == 1 then 31 else 32
				seg.Parent = stage
				tween(seg, 0.36, { BackgroundTransparency = 1 }).Completed:Connect(function()
					seg:Destroy()
				end)
			end
		end
	end

	local function coins(n: number)
		for _ = 1, n do
			local c = Instance.new("Frame")
			c.Name = "Coin"
			c.BorderSizePixel = 0
			c.BackgroundColor3 = Color3.fromRGB(255, 199, 44)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			local x = 40 + math.random() * (W - 80)
			c.Position = at(x, -30)
			c.Size = UDim2.fromScale(22 / W, 22 / H)
			c.ZIndex = 33
			c.Parent = stage
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = c
			Base.outline(c, 3)
			local secs = 1.1 + math.random() * 0.7
			task.delay(math.random() * 0.7, function()
				if not alive then
					return
				end
				tween(c, secs, {
					Position = at(x + (math.random() - 0.5) * 80, H + 30),
					Rotation = math.random(-360, 360),
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
					c:Destroy()
				end)
			end)
		end
	end

	-- the big word, letter by letter
	local function banner(text: string, big: boolean): () -> ()
		local h = if big then 112 else 92
		local cw = h * 0.62
		local x0 = (W - #text * cw) / 2
		local letters: { TextLabel } = {}
		for i = 1, #text do
			local ch = string.sub(text, i, i)
			local l = Base.text(
				stage,
				"Letter" .. i,
				x0 + (i - 1) * cw,
				128,
				cw,
				h,
				ch,
				{ color = rc, stroke = 12, z = 40 }
			)
			l.TextTransparency = 1
			l.Rotation = (if i % 2 == 0 then 1 else -1) * 25
			local home = l.Position
			l.Position = home - UDim2.fromScale(0, 120 / H)
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 1
			end
			table.insert(letters, l)
			task.delay((i - 1) * 0.055, function()
				if not alive then
					return
				end
				tween(
					l,
					0.42,
					{ TextTransparency = 0, Position = home, Rotation = 0 },
					Enum.EasingStyle.Back
				)
				if stroke then
					tween(stroke, 0.3, { Transparency = 0 })
				end
			end)
		end
		return function()
			for _, l in letters do
				local stroke = l:FindFirstChildOfClass("UIStroke")
				tween(
					l,
					0.36,
					{ TextTransparency = 1, Position = l.Position - UDim2.fromScale(0, 30 / H) }
				)
				if stroke then
					tween(stroke, 0.36, { Transparency = 1 })
				end
			end
		end
	end

	-- ===== SKIP =====
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AutoButtonColor = false
	skip.BackgroundColor3 = Base.color("navy")
	skip.BackgroundTransparency = 0.25
	skip.Font = Base.FONT
	skip.Text = "SKIP"
	skip.TextColor3 = WHITE
	skip.TextScaled = true
	skip.ZIndex = 70
	skip.Parent = stage
	Base.at(skip, W - 120, H - 48, 100, 34)
	Base.corner(skip, 10)
	Base.outline(skip, 3)
	conns[#conns + 1] = skip.Activated:Connect(finish)

	-- ===== the show =====
	task.spawn(function()
		local ok, err = pcall(function()
			Base.show(g, true)
			local rayAnchor = Base.box(stage, "RayAnchor", W / 2 - 330, H / 2 - 330, 660, 660, 2)
			rayAnchor.Visible = true
			stopRays = Party.rays(rayAnchor, rc:Lerp(WHITE, 0.3))

			-- the crate crashes in
			local crateSize = 170
			local cx, cy = W / 2 - crateSize / 2, 150
			local crate = Icons.make(
				stage,
				"crate",
				cx,
				-200,
				crateSize,
				{ rarity = CRATE_RARITY[kind] or "common", z = 8 }
			)
			-- (the cards are built while it falls, a few at a time, so nothing hitches)
			local reel = Base.box(stage, "Reel", 0, REEL_Y, W, REEL_H, 12)
			Base.atAnchored(reel, 0, REEL_Y, W, REEL_H, 0.5, 0.5)
			reel.ClipsDescendants = true
			reel.Visible = false
			local band = Instance.new("Frame")
			band.Name = "Band"
			band.BorderSizePixel = 0
			band.BackgroundColor3 = Color3.fromRGB(8, 20, 48)
			band.Size = UDim2.fromScale(1, 1)
			band.ZIndex = 1
			band.Parent = reel
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.1),
				NumberSequenceKeypoint.new(0.9, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = band
			local scaleUp = Instance.new("UIScale")
			scaleUp.Parent = reel
			local strip = Base.box(reel, "Strip", 0, 32, #plan.cards * STEP, CARD_H, 3)
			local function stripX(
				idx: number
			): number -- the strip's left, with card `idx` under the pointer
				return CENTRE - CARD_W / 2 - (idx - 1) * STEP
			end
			local function place(x: number)
				strip.Position = UDim2.fromScale(x / W, 32 / REEL_H)
			end
			place(stripX(1))
			local ids = carIds()
			local cards: { Frame } = {}
			local dims: { Frame } = {}
			local scales: { UIScale } = {}
			local built = false
			task.spawn(function()
				for i, rarityNo in plan.cards do
					if not alive then
						return
					end
					local col = rarityColor(rarityNo)
					local card =
						Base.fill(strip, "Card" .. i, (i - 1) * STEP, 0, CARD_W, CARD_H, WHITE, 3)
					Base.corner(card, 18)
					Base.outline(card, 4)
					Kit.face(card, { hexOf(col), "112b5c" })
					local sc = Instance.new("UIScale")
					sc.Parent = card
					local list = ids[rarityNo]
					local carId = if i == plan.win
						then o.id
						elseif #list > 0 then list[(i * 7) % #list + 1]
						else ""
					Icons.car(card, 10, 34, CARD_W - 20, 120, { id = carId, color = col, z = 5 })
					local bar = Base.fill(card, "Bar", 0, CARD_H - 30, CARD_W, 30, col, 4)
					Base.corner(bar, 14)
					Base.text(
						card,
						"Tag",
						0,
						CARD_H - 31,
						CARD_W,
						28,
						rarityWord(rarityNo),
						{ z = 6, stroke = 8 }
					)
					local dim = Base.fill(card, "Dim", 0, 0, CARD_W, CARD_H, BLACK, 9)
					Base.corner(dim, 18)
					dim.BackgroundTransparency = 0.6
					cards[i], dims[i], scales[i] = card, dim, sc
					if i % 5 == 0 then
						task.wait()
					end
				end
				built = true
			end)

			-- chasing lights round the reel
			local NB = 22
			local bulbs: { { Frame } } = {}
			for i = 1, NB do
				local pair: { Frame } = {}
				for row = 1, 2 do
					local b = Base.fill(
						reel,
						"Bulb",
						14 + (i - 1) * ((W - 28) / (NB - 1)) - 5,
						if row == 1 then 12 else REEL_H - 22,
						10,
						10,
						BULB_OFF,
						6
					)
					Base.corner(b)
					Base.outline(b, 2)
					pair[row] = b
				end
				bulbs[i] = pair
			end
			local bulbMode = "chase" -- "chase" | "slow" | "solid" | "off" | "alt"
			local phase, acc = 0, 0
			conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt: number)
				acc += dt
				if acc < 0.08 then
					return
				end
				acc = 0
				phase += 1
				for i, pair in bulbs do
					local a, b = false, false
					if bulbMode == "chase" or bulbMode == "slow" then
						local step = if bulbMode == "slow" then 3 else 4
						a = (i + phase) % step == 0
						b = (NB - i + phase) % step == 0
					elseif bulbMode == "solid" then
						a, b = true, true
					elseif bulbMode == "alt" then
						a = (i + phase) % 2 == 0
						b = not a
					end
					pair[1].BackgroundColor3 = if a then BULB_ON else BULB_OFF
					pair[2].BackgroundColor3 = if b then BULB_ON else BULB_OFF
				end
			end)

			-- speed streaks across the reel (stronger the faster it goes)
			local streaks = Base.fill(reel, "Streaks", 0, 20, W, REEL_H - 40, WHITE, 5)
			streaks.BackgroundTransparency = 1
			for i = 0, 7 do
				local s = Base.fill(streaks, "Streak", 0, i * 26 + 6, W, 3, WHITE, 5)
				s.BackgroundTransparency = 0.8
			end
			streaks.ClipsDescendants = true
			streaks.Visible = false

			-- the pointer
			local ptr = Base.box(stage, "Pointer", CENTRE - 15, REEL_Y - 16, 30, REEL_H + 30, 14)
			ptr.Visible = false
			local line = Base.fill(ptr, "Line", 11, 18, 8, REEL_H - 6, WHITE, 2)
			Base.corner(line, 4)
			local head = Base.text(
				ptr,
				"Head",
				0,
				0,
				30,
				26,
				"v",
				{ color = Base.color("gold"), stroke = 6, z = 3 }
			)
			head.Text = "\u{25BC}"

			-- the edges go dark for the last stretch
			local vig: { Frame } = {}
			for _, e in
				{
					{ 0, 0, W, 90, 90 },
					{ 0, H - 90, W, 90, 270 },
					{ 0, 0, 150, H, 0 },
					{ W - 150, 0, 150, H, 180 },
				}
			do
				local v = Base.fill(
					stage,
					"Vignette",
					e[1],
					e[2],
					e[3],
					e[4],
					Color3.fromRGB(4, 6, 20),
					20
				)
				local gr = Instance.new("UIGradient")
				gr.Rotation = e[5]
				gr.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				})
				gr.Parent = v
				v.BackgroundTransparency = 1
				table.insert(vig, v)
			end

			-- 1. crate drops, lands with a bang
			tween(
				crate,
				0.55,
				{ Position = at(cx, cy) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			pause(0.55)
			Sfx.shake(t)
			Party.burst(stage, at(cx + crateSize / 2, cy + crateSize), 22)
			ring(cx + crateSize / 2, cy + crateSize - 10, 0)
			shake(9, 0.32)
			pause(0.3)

			-- 2. lid blast on a pillar of light
			crate:Destroy()
			local open = Icons.make(
				stage,
				"crate",
				cx,
				cy,
				crateSize,
				{ rarity = CRATE_RARITY[kind] or "common", open = true, z = 8 }
			)
			local pillar = Base.fill(stage, "Pillar", W / 2 - 55, -20, 110, cy + 60, WHITE, 5)
			local pg = Instance.new("UIGradient")
			pg.Rotation = 90
			pg.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.1),
			})
			pg.Parent = pillar
			flash(0.7, 0.26)
			Party.burst(stage, at(W / 2, cy + 20), 30)
			Sfx.spark()
			pause(0.45)
			tween(pillar, 0.3, { BackgroundTransparency = 1 })

			-- 3. the reel opens
			while not built do
				pause(0.05)
			end
			reel.Visible = true
			ptr.Visible = true
			streaks.Visible = true
			open.Visible = false
			tween(scaleUp, 0.4, { Scale = 1 })
			reel.Size = UDim2.fromScale(0.6, 0.02)
			tween(reel, 0.35, { Size = UDim2.fromScale(1, REEL_H / H) }, Enum.EasingStyle.Back)
			pause(0.4)

			-- the spin: fast, then it slows right down onto the card
			local spinSecs = plan.spin
			local t0 = os.clock()
			local slowed = false
			local lastX = stripX(1)
			local lastIdx = -1
			local lastTick = 0
			tween(
				strip,
				spinSecs,
				{ Position = UDim2.fromScale(stripX(plan.stop) / W, 32 / REEL_H) },
				Enum.EasingStyle.Quint
			)
			local watching = true
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				if not watching or not alive then
					conn:Disconnect()
					return
				end
				local x = strip.Position.X.Scale * W
				local speed = math.abs(x - lastX)
				lastX = x
				streaks.Visible = speed > 6
				for _, s in streaks:GetChildren() do
					if s:IsA("Frame") then
						s.BackgroundTransparency = 1 - math.min(0.7, speed / 40)
					end
				end
				local idx = math.floor((CENTRE - CARD_W / 2 - x) / STEP + 1.5)
				for k = math.max(1, idx - 3), math.min(#cards, idx + 3) do
					local d = math.abs(x + (k - 1) * STEP + CARD_W / 2 - CENTRE)
					local u = math.max(0, 1 - d / 200)
					scales[k].Scale = 1 + 0.24 * u
					dims[k].BackgroundTransparency = 0.6 + 0.4 * u
					cards[k].ZIndex = if u > 0.5 then 5 else 3
				end
				if idx ~= lastIdx then
					lastIdx = idx
					ptr.Rotation = -14
					tween(ptr, 0.11, { Rotation = 0 })
					if os.clock() - lastTick > 0.07 then
						lastTick = os.clock()
						Sfx.count(1)
					end
				end
				if not slowed and os.clock() - t0 > spinSecs * 0.62 then
					slowed = true
					bulbMode = "slow"
					for _, v in vig do
						tween(v, 0.9, { BackgroundTransparency = 0 })
					end
					tween(
						scaleUp,
						1.4,
						{ Scale = 1.07 },
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)
				end
			end)
			pause(spinSecs)
			if plan.creep then
				pause(0.5)
				shake(4, 0.24)
				tween(
					strip,
					plan.creepSecs,
					{ Position = UDim2.fromScale(stripX(plan.win) / W, 32 / REEL_H) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.InOut
				)
				pause(plan.creepSecs)
			end
			watching = false
			streaks.Visible = false

			-- 4. HIT-STOP: everything freezes on your car for a beat
			bulbMode = "off"
			for k = math.max(1, plan.win - 3), math.min(#cards, plan.win + 3) do
				if k == plan.win then
					dims[k].BackgroundTransparency = 1
					cards[k].ZIndex = 8
					local glowRim = Base.outline(cards[k], 7, rc)
					glowRim.Transparency = 0
				else
					tween(dims[k], 0.25, { BackgroundTransparency = 0.25 })
					tween(scales[k], 0.25, { Scale = 0.9 })
				end
			end
			pause(plan.hold)

			-- 5. BOOM
			bulbMode = "solid"
			tween(scales[plan.win], 0.46, { Scale = 1.4 }, Enum.EasingStyle.Back)
			for i = 0, plan.rings - 1 do
				ring(W / 2, 170, i * 0.14)
			end
			Party.burst(stage, at(W / 2, 170), 40 + 16 * t)
			Party.burst(stage, at(W / 2, 170), 24 + 8 * t)
			for i = 1, plan.bolts do
				task.delay((i - 1) * 0.07, function()
					if alive then
						local a = math.random() * math.pi * 2
						bolt(
							W / 2,
							170,
							W / 2 + math.cos(a) * (260 + math.random() * 140),
							170 + math.sin(a) * (180 + math.random() * 60)
						)
					end
				end)
			end
			for _, v in vig do
				tween(v, 0.5, { BackgroundTransparency = 1 })
			end
			flash(0.7 + t * 0.07, 0.42)
			shake(plan.shake, 0.48 + t * 0.08)
			if t >= 3 then
				Sfx.fireworks()
			end
			bulbMode = "alt"
			local out = banner(plan.word, plan.big)
			if plan.coins > 0 then
				task.delay(0.3, function()
					if alive then
						coins(plan.coins)
					end
				end)
			end
			if plan.big then
				task.delay(0.52, function()
					if alive then
						flash(0.9, 0.5)
						shake(12, 0.5)
						ring(W / 2, 170, 0)
						ring(W / 2, 170, 0.15)
						Party.confetti(g.gui, 60)
					end
				end)
			end
			pause(#plan.word * 0.055 + 0.42 + 0.7)
			out()
			tween(reel, 0.3, { Size = UDim2.fromScale(1, 0.02) })
			ptr.Visible = false
			pause(0.35)
		end)
		-- (an error mid-show too: go on to the card, never leave the screen stuck)
		if not ok and not string.find(tostring(err), "skipped", 1, true) then
			warn("CrateReel: " .. tostring(err))
		end
		finish()
	end)
end

return CrateReel
