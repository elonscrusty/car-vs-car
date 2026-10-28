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

-- data: { coins, rate, nextUp = { title, sub }, car = { name, stats = { power = { v, lv }, ... } },
--   dots = { Crates = 2, League = -1 (! ) }, signs: boolean (the viewer: sample world signs),
--   race: words (the RACE! button; nil = none), jobs: words (the JOBS pill; nil = none),
--   stagger: boolean (a new player: the pieces come in one at a time, not all at once),
--   banner = false / myCar = false: leave that piece off (the live game, over the 3D plot) }
-- actions: Garage(), Crates(), Shop(), League(), coins(), coach(), race(), jobs()
-- api: setCoins(n), setRate(words), setNextUp(title, sub, hurry), setCar(name, stats),
--   setCoach(f, words), setDot(name, n), float(x, y, words, color), setRace(words, tone, pulse),
--   setJobs(words)
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
		local sides: { [string]: Kit.Side } = {}
		local tiles: { GuiObject } = {}
		for i, sd in SIDES do
			local holder = spot(c, "plot", sd.name)
			local side: Kit.Side
			if sd.icon == "car" then
				side = Kit.side(holder, "Tile", 0, 0, sd.word, "bag", i)
				-- the garage tile shows a car poking out instead of an icon
				local tile = side.button:FindFirstChild("Tile") :: Frame
				local ic = tile:FindFirstChild("Icon")
				if ic then
					ic:Destroy()
				end
				local car = Icons.car(
					tile,
					-4,
					-16,
					70,
					46,
					{ kind = "racer", color = Base.color("danger"), z = 5 }
				)
				Anim.bob(car, UiTheme.MOTION.iconBob, 5, 0)
			else
				side = Kit.side(holder, "Tile", 0, 0, sd.word, sd.icon, i, sd.opts)
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
		local jobs: Kit.Pill? = nil
		local jobsHolder: Frame? = nil
		if data.jobs then
			local jp = piece("plot", "Jobs")
			local jh = spot(c, "plot", "Jobs")
			jobsHolder = jh
			jobs = Kit.pill(jh, "Jobs", 0, 0, jp.w, jp.h, "JOBS", "lime", data.jobs)
			local tap = Instance.new("TextButton")
			tap.Name = "Tap"
			tap.Text = ""
			tap.BackgroundTransparency = 1
			tap.Size = UDim2.fromScale(1, 1)
			tap.ZIndex = 9
			tap.Parent = jh
			tap.Activated:Connect(Screen.act(actions, "jobs"))
			Anim.press(tap)
		end
		-- a new player: one piece at a time (the race first, then the car, the tiles, the coins,
		-- COACH and the jobs), each popping in, so 6 things don't land at once
		if data.stagger then
			local steps: { { GuiObject? } } = {
				{ banner.frame, raceHolder },
				{ carHolder },
				tiles,
				{ coinsHolder },
				{ coachHolder, jobsHolder },
			}
			for i, step in steps do
				for _, obj in step do
					if obj then
						obj.Visible = false
					end
				end
				task.delay(0.3 + (i - 1) * UiTheme.MOTION.staggerStep, function()
					for _, obj in step do
						if obj and obj.Parent then
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
					jobs.set(words)
				end
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
		local pp = piece("race", "Place")
		local placeSpot = spot(c, "race", "Place")
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
		setTop(data.top or {})
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
		boost.setCharge(data.boost or 0)
		return {
			setLap = pill.set,
			setPlace = setPlace,
			setTop = setTop,
			setBoost = boost.setCharge,
		}
	end)
end

return Hud
