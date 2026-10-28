--!strict
-- Car VS Car screens over the game (spec section 6): 2 Plot, 3 Race start, 4 Race. Phone rule:
-- coins top right, NEXT UP banner top middle, 4 side tiles on the left (a 2 x 2 block, so the
-- move stick's bottom-left corner stays free), ONE round thumb button bottom right (COACH on the
-- plot, BOOST in a race); the middle stays empty for the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Screen = require(Ui:WaitForChild("Screen"))

local Hud = {}

local function piece(id: string, name: string): UiScreens.Piece
	return UiScreens.piece(id, name)
end

local function spot(canvas: Instance, id: string, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Parent = canvas
	Base.place(f, piece(id, name))
	return f
end

-- ===== 2 Plot =====

local SIDES = {
	{ name = "Garage", word = "GARAGE", icon = "car" },
	{ name = "Crates", word = "CRATES", icon = "crate", opts = { rarity = "epic" } },
	{ name = "Shop", word = "SHOP", icon = "bag" },
	{ name = "League", word = "LEAGUE", icon = "trophy" },
}

-- One arrow at a piece (its spot frame h, design rect p), bobbing toward it: above the pieces at
-- the bottom middle (RACE!) and the top left tiles, beside the ones at the edges. loud (no tap for
-- a while): it bobs further and says what to tap.
local function pointAt(h: Frame, p: UiScreens.Piece, words: string?, loud: boolean): Frame
	-- a see-through frame over the piece holds the arrow and its words (gone with it)
	local over = Base.box(h, "Pointer", 0, 0, p.w, p.h, 8)
	local s = if loud then 54 else 44
	local tw, th = 170, 32
	-- where the arrow sits, which way it points (deg: 0 = right), how it bobs (dx, dy), the words
	local x, y, rot, dx, dy, wx, wy
	local align: string? = nil
	if p.x > Base.W * 0.7 then
		-- right edge: from the left, the words to its left
		x, y, rot, dx, dy = -s - 6, (p.h - s) / 2, 0, 1, 0
		wx, wy, align = x - tw - 4, (p.h - th) / 2, "r"
	elseif p.y > Base.H * 0.6 then
		-- bottom middle: from above, the words over it
		x, y, rot, dx, dy = (p.w - s) / 2, -s - 6, 90, 0, 1
		wx, wy, align = (p.w - tw) / 2, y - th, nil
	elseif p.y < 100 then
		-- the top tiles: from above, the words to its right
		x, y, rot, dx, dy = (p.w - s) / 2, -s - 4, 90, 0, 1
		wx, wy, align = x + s + 4, y + (s - th) / 2, "l"
	else
		-- the lower tiles: from the right, the words past it
		x, y, rot, dx, dy = p.w + 6, (p.h - s) / 2, 180, -1, 0
		wx, wy, align = x + s + 4, (p.h - th) / 2, "l"
	end
	local box = Base.box(over, "Arrow", x, y, s, s, 9)
	local arrow = Icons.make(box, "arrow", 0, 0, s, { z = 9 })
	arrow.Rotation = rot
	if words and loud then
		Base.text(over, "Words", wx, wy, tw, th, words, {
			color = Base.color("go"),
			stroke = 5,
			align = align,
			z = 9,
		})
		Anim.shout(h)
	end
	if not Base.reduced() then
		local home = box.Position
		local amp = (if loud then 12 else 7) * Base.k
		Anim.tick(box, function(t)
			local b = UiMotion.bob(t, 0.8, 1) -- (-1..0)
			box.Position = home + UDim2.fromOffset(-dx * b * amp, -dy * b * amp)
		end)
	end
	return over
end

-- data: { coins, rate, nextUp = { title, sub }, car = { name, stats = { power = { v, lv }, ... } },
--   dots = { Crates = 2, League = -1 (! ) }, signs: boolean (the viewer: sample world signs),
--   race: words (the RACE! button; nil = none), jobs: words (the JOBS pill; nil = none),
--   invite: words (the INVITE pill; nil = none),
--   stagger: boolean (a new player: the pieces come in one at a time, not all at once),
--   banner = false / myCar = false: leave that piece off (the live game, over the 3D plot),
--   words = { Garage = "TRAIN" }: other words on a tile }
-- actions: Garage(), Crates(), Shop(), League(), coins(), coach(), race(), jobs(), invite()
-- api: setCoins(n), setRate(words), setNextUp(title, sub, hurry), setCar(name, stats),
--   setCoach(f, words), setDot(name, n), float(x, y, words, color), setRace(words, tone, pulse),
--   setJobs(words), setShown(name, on) (a tile, Coach, Race or Jobs steps away / comes back),
--   point(name?, words?, loud?) (one bouncing arrow at that piece; loud: bigger, with its words)
function Hud.plot(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("plot", "hud", false, function(g)
		local c = g.canvas
		local banner = Kit.banner(c, piece("plot", "NextUp"))
		local nu = data.nextUp or {}
		banner.set(nu.title or "BIG RACE in 1:42", nu.sub or "Train up, then race 8 cars!")
		-- (the live game: no banner, the RACE! button has the clock; the plot's scoreboard is in the
		-- top middle, Studio plot-edges shot 12)
		if data.banner == false then
			banner.frame.Parent = nil
		end
		local cp = piece("plot", "Coins")
		local coinsHolder = spot(c, "plot", "Coins")
		local coins = Kit.currency(coinsHolder, "Coins", 0, 0, cp.w, cp.h, {
			value = data.coins or 0,
			rate = data.rate or "",
			plus = true,
			onClick = Screen.act(actions, "coins"),
		})
		local words: { [string]: string } = data.words or {}
		local sides: { [string]: Kit.Side } = {}
		local tiles: { GuiObject } = {}
		for i, sd in SIDES do
			local holder = spot(c, "plot", sd.name)
			local side: Kit.Side
			if sd.icon == "car" then
				side = Kit.side(holder, "Tile", 0, 0, words[sd.name] or sd.word, "bag", i)
				-- the garage tile shows a car poking out instead of an icon
				local tile = side.button:FindFirstChild("Tile") :: Frame
				local ic = tile:FindFirstChild("Icon")
				if ic then
					ic:Destroy()
				end
				-- (in the middle of the tile, over its word, like the other tiles' icons)
				local car = Icons.car(
					tile,
					6,
					10,
					50,
					32,
					{ kind = "racer", color = Base.color("danger"), z = 5 }
				)
				Anim.bob(car, UiTheme.MOTION.iconBob, 5, 0)
			else
				side =
					Kit.side(holder, "Tile", 0, 0, words[sd.name] or sd.word, sd.icon, i, sd.opts)
			end
			sides[sd.name] = side
			side.button.Activated:Connect(Screen.act(actions, sd.name))
			local n = (data.dots or {})[sd.name]
			side.setDot(n)
			table.insert(tiles, holder)
		end
		Anim.cascade(tiles)
		-- MY CAR: the car's 3 bars
		local mp = piece("plot", "MyCar")
		local carHolder, panel = Kit.placedPanel(c, mp)
		-- (the live game: the plot's pad signs and scoreboard show the bars; the panel sat on the
		-- speed tracks on a phone)
		if data.myCar == false then
			carHolder.Parent = nil
		end
		local car = data.car or {}
		local title = Base.text(
			panel,
			"Title",
			12,
			8,
			mp.w - 24,
			18,
			"MY CAR: " .. (car.name or ""),
			{ color = Base.color("blue"), align = "l", z = 4 }
		)
		local bars: { [string]: Kit.Bar } = {}
		for j, stat in UiTheme.STATS do
			local b = Kit.statBar(panel, 12, 32 + (j - 1) * 40, mp.w - 24, 36, stat.key)
			bars[stat.key] = b
			local s = (car.stats or {})[stat.key] or { 0, 1 }
			b.set(s[1], s[2], true)
		end
		-- COACH
		local kp = piece("plot", "Coach")
		local coachHolder = spot(c, "plot", "Coach")
		local coach = Kit.round(
			coachHolder,
			"Coach",
			0,
			0,
			kp.w,
			"pink",
			"COACH",
			{ cooldown = true, onClick = Screen.act(actions, "coach") }
		)
		if data.coach then
			coach.setCooldown(data.coach[1], data.coach[2])
		end
		-- RACE! (the live game)
		local race: TextButton? = nil
		local raceHolder: Frame? = nil
		local racePulse: Tween? = nil
		local raceTone = "lime"
		if data.race then
			local rp = piece("plot", "Race")
			local rh = spot(c, "plot", "Race")
			raceHolder = rh
			race = Kit.button(rh, "Race", 0, 0, rp.w, rp.h, "lime", data.race, {
				main = true,
				size = 24,
				onClick = Screen.act(actions, "race"),
			})
		end
		-- JOBS 1/3 (the live game)
		local jobs: TextButton? = nil
		local jobsHolder: Frame? = nil
		if data.jobs then
			local jp = piece("plot", "Jobs")
			local jh = spot(c, "plot", "Jobs")
			jobsHolder = jh
			-- (one line of big words: the pill's count was 6 px tall on a phone, Studio live1)
			jobs = Kit.button(jh, "Jobs", 0, 0, jp.w, jp.h, "blue", data.jobs, {
				size = 16,
				onClick = Screen.act(actions, "jobs"),
			})
		end
		-- INVITE (the live game: Roblox's invite screen; a friend here pays you both)
		local inviteHolder: Frame? = nil
		if data.invite then
			local ip = piece("plot", "Invite")
			local ih = spot(c, "plot", "Invite")
			inviteHolder = ih
			Kit.button(ih, "Invite", 0, 0, ip.w, ip.h, "pink", data.invite, {
				size = 16,
				onClick = Screen.act(actions, "invite"),
			})
		end
		-- every piece by name, for setShown and point
		local holders: { [string]: Frame } = {}
		for _, sd in SIDES do
			holders[sd.name] = sides[sd.name].button.Parent :: Frame
		end
		holders.Coach = coachHolder
		if raceHolder then
			holders.Race = raceHolder
		end
		if jobsHolder then
			holders.Jobs = jobsHolder
		end
		if inviteHolder then
			holders.Invite = inviteHolder
		end
		local hidden: { [Instance]: boolean } = {}
		local pointer: Frame? = nil
		local pointKey = ""
		-- a new player: one piece at a time (the race first, then the car, the tiles, the coins,
		-- COACH and the jobs), each popping in, so 6 things don't land at once
		if data.stagger then
			local steps: { { GuiObject? } } = {
				{ banner.frame, raceHolder },
				{ carHolder },
				tiles,
				{ coinsHolder },
				{ coachHolder, jobsHolder, inviteHolder },
			}
			for i, step in steps do
				for _, obj in step do
					if obj then
						obj.Visible = false
					end
				end
				task.delay(0.3 + (i - 1) * UiTheme.MOTION.staggerStep, function()
					for _, obj in step do
						if obj and obj.Parent and not hidden[obj] then
							obj.Visible = true
							Anim.pop(obj, nil, 0.4)
						end
					end
				end)
			end
		end
		-- (the viewer only: what the 3D signs over the machines look like)
		if data.signs then
			local signs = {
				{ "SignPower", "+3", "POWER/MIN", "boost" },
				{ "SignAir", "+2", "AIR/MIN", "pink" },
				{ "SignSpeed", "+4", "SPEED/MIN", "lime" },
			}
			for _, s in signs do
				local sp = piece("plot", s[1])
				Kit.sign(c, sp.x, sp.y, sp.w, sp.h, s[2], s[3], s[4])
			end
		end
		return {
			setCoins = coins.set,
			setRate = coins.setRate,
			setNextUp = function(t: string, sub: string?, hurry: boolean?)
				banner.set(t, sub)
				banner.hurry(hurry == true)
			end,
			setCar = function(name: string, stats: { [string]: { number } })
				title.Text = "MY CAR: " .. name
				for key, b in bars do
					local s = stats[key]
					if s then
						b.set(s[1], s[2])
					end
				end
			end,
			setCoach = coach.setCooldown,
			setDot = function(name: string, n: number?)
				local s = sides[name]
				if s then
					s.setDot(n)
				end
			end,
			float = function(x: number, y: number, words: string, color: string?)
				Kit.floatNum(c, x, y, words, color)
			end,
			setRace = function(words: string, toneName: string?, pulse: boolean?)
				if not race then
					return
				end
				Kit.setWords(race, words)
				local t = toneName or "lime"
				if t ~= raceTone then
					raceTone = t
					Kit.setTone(race, t)
				end
				if pulse and not racePulse then
					racePulse = Anim.pulse(race, 1.06, 0.9)
				elseif not pulse and racePulse then
					racePulse:Cancel()
					racePulse = nil
					Anim.scaler(race).Scale = 1
				end
			end,
			setJobs = function(words: string)
				if jobs then
					Kit.setWords(jobs, words)
				end
			end,
			setShown = function(name: string, on: boolean)
				local h = holders[name]
				if not h then
					return
				end
				-- (every call: the tiles' rise-in puts Visible back a beat after the screen opens,
				-- Studio live3 shot 01)
				local was = hidden[h] == true
				if on then
					hidden[h] = nil
					if was then
						h.Visible = true
						Anim.pop(h, nil, 0.4)
					end
				else
					hidden[h] = true
					h.Visible = false
				end
			end,
			point = function(name: string?, words: string?, loud: boolean?)
				local key = `{name}|{words}|{loud}`
				if key == pointKey then
					return
				end
				pointKey = key
				if pointer then
					pointer:Destroy()
					pointer = nil
				end
				local h = if name then holders[name] else nil
				if not (name and h) then
					return
				end
				pointer = pointAt(h, piece("plot", name), words, loud == true)
			end,
		}
	end)
end

-- ===== 3 Race start: 3 start lights, a giant GO! slam, the LAP pill =====

local function lapPill(c: Instance, id: string, lap: string): Kit.Pill
	local lp = piece(id, "Lap")
	return Kit.pill(spot(c, id, "Lap"), "Lap", 0, 0, lp.w, lp.h, "LAP", "blue", lap, { big = true })
end

-- data: { lap: "1/2", lit: number (0..3), go: boolean }
-- api: setLights(n, colorName), go(), setLap(words)
function Hud.start(data: { [string]: any }): Screen.Handle
	return Screen.open("start", "hud", false, function(g)
		local c = g.canvas
		local lp = piece("start", "Lights")
		local panel =
			Base.fill(spot(c, "start", "Lights"), "Panel", 0, 0, lp.w, lp.h, Base.color("navy"), 2)
		Base.corner(panel, 22)
		Base.outline(panel, UiTheme.OUTLINE.normal)
		local lights: { Frame } = {}
		for i = 1, 3 do
			local l = Base.fill(
				panel,
				"Light" .. i,
				12 + (i - 1) * 44,
				12,
				34,
				34,
				Base.color("inkMuted"),
				3
			)
			Base.corner(l)
			Base.outline(l, UiTheme.OUTLINE.normal)
			lights[i] = l
		end
		local pill = lapPill(c, "start", data.lap or "1/2")
		local gp = piece("start", "Go")
		local goSpot = spot(c, "start", "Go")
		local slam: Frame? = nil
		local function setLights(n: number, colorName: string?)
			for i, l in lights do
				local on = i <= n
				local col = Base.color(colorName or (if n >= 3 then "lime" else "danger"))
				l.BackgroundColor3 = if on then col else Base.color("inkMuted")
				if on then
					Kit.gloss(l, col, 0.35)
				else
					local gr = l:FindFirstChild("Gloss")
					if gr then
						gr:Destroy()
					end
				end
			end
		end
		local function go()
			if slam then
				slam:Destroy()
			end
			setLights(3, "lime")
			local holder = Base.box(goSpot, "Slam", 0, 0, gp.w, gp.h, 3)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.5)
			slam = holder
			Base.text(
				holder,
				"GO",
				0,
				0,
				gp.w,
				gp.h - 8,
				"GO!",
				{ color = Base.color("go"), stroke = 9, drop = 7, z = 3 }
			)
			Anim.slam(holder)
		end
		setLights(data.lit or 0)
		if data.go then
			go()
		end
		return { setLights = setLights, go = go, setLap = pill.set }
	end)
end

-- ===== 4 Race HUD (5 things at most): LAP, big place, top-3 list, BOOST, the free stick corner =====

-- data: { lap: "1/2", place: 3, total: 8, top = { { name, colorName, me } x3 }, boost: 0..1 }
-- actions: boost()
-- api: setLap(words), setPlace(p, total), setTop(list), setBoost(f)
function Hud.race(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("race", "hud", false, function(g)
		local c = g.canvas
		local pill = lapPill(c, "race", data.lap or "1/2")
		-- (the live game: lap = false / top = false / boost = false leave that piece off; the old
		-- drive HUD has the lap clock top left, and BOOST stays by DRIFT)
		if data.lap == false then
			pill.frame.Parent = nil
		end
		local pp = piece("race", "Place")
		-- (data.placeAt = { x, y, w, h }: somewhere else; the live game keeps the top middle for
		-- the FINISH IN strip, Studio live3 shot 06)
		local at = data.placeAt
		if at then
			pp = table.clone(pp)
			pp.x, pp.y, pp.w, pp.h, pp.anchor = at[1], at[2], at[3], at[4], "tl"
		end
		local placeSpot = Instance.new("Frame")
		placeSpot.Name = "Place"
		placeSpot.BackgroundTransparency = 1
		placeSpot.Parent = c
		Base.place(placeSpot, pp)
		local big = Base.text(
			placeSpot,
			"Place",
			0,
			0,
			pp.w * 0.62,
			pp.h - 6,
			"",
			{ color = Base.color("go"), stroke = 7, drop = 5, align = "r", z = 3 }
		)
		local of = Base.text(
			placeSpot,
			"Of",
			pp.w * 0.64,
			pp.h * 0.36,
			pp.w * 0.36,
			pp.h * 0.46,
			"",
			{ stroke = 5, drop = 3, align = "l", z = 3 }
		)
		local function setPlace(p: number, total: number)
			local was = big.Text
			Base.setText(big, UiMotion.place(p))
			Base.setText(of, "/ " .. tostring(total))
			if was ~= "" and was ~= big.Text then
				Anim.shout(placeSpot)
			end
		end
		setPlace(data.place or 1, data.total or 8)
		local tp = piece("race", "Top3")
		local topSpot = spot(c, "race", "Top3")
		local rows: { Frame } = {}
		local function setTop(list: { { [string]: any } })
			for _, r in rows do
				r:Destroy()
			end
			table.clear(rows)
			for i = 1, math.min(3, #list) do
				local e = list[i]
				local y = (i - 1) * 36
				local me = e.me == true
				local row = Base.fill(
					topSpot,
					"Row" .. i,
					0,
					y,
					tp.w,
					30,
					Base.color(if me then "lime" else "navy"),
					2
				)
				Base.corner(row)
				Base.outline(row, UiTheme.OUTLINE.normal)
				local disc =
					Base.fill(row, "Disc", 4, 4, 22, 22, Base.color(e.colorName or "blue"), 3)
				Base.corner(disc)
				Base.outline(disc, UiTheme.OUTLINE.small)
				Base.text(disc, "N", 3, 4, 16, 14, tostring(i), { stroke = 3.5, z = 4 })
				Base.text(
					row,
					"Name",
					32,
					7,
					tp.w - 42,
					17,
					e.name or "",
					{ stroke = if me then 3.5 else nil, align = "l", z = 3 }
				)
				table.insert(rows, row)
			end
		end
		if data.top == false then
			topSpot.Parent = nil
		else
			setTop(data.top or {})
		end
		local bp = piece("race", "Boost")
		local boost = Kit.round(
			spot(c, "race", "Boost"),
			"Boost",
			0,
			0,
			bp.w,
			"boost",
			"BOOST",
			{ charge = true, onClick = Screen.act(actions, "boost") }
		)
		if data.boost == false then
			boost.button.Parent = nil
		else
			boost.setCharge(data.boost or 0)
		end
		return {
			setLap = pill.set,
			setPlace = setPlace,
			setTop = setTop,
			setBoost = boost.setCharge,
		}
	end)
end

return Hud
