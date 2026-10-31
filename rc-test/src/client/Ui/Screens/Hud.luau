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

local WHITE = Base.WHITE
local INK = Base.color("ink")
local PIP_ON = Color3.fromRGB(139, 232, 28) -- (the kit's lime)
local PIP_OFF = Color3.fromRGB(109, 122, 146) -- slate: a used shot

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
local function pointAt(
	h: Frame,
	p: UiScreens.Piece,
	words: string?,
	loud: boolean,
	aside: boolean?
): Frame
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
		if p.y > Base.H * 0.6 then
			-- (COACH, bottom right: the words go up a little, clear of the RACE! button's top;
			-- level with the arrow they ran under it, carter's phone 10-28)
			wy = -12
		end
	elseif aside and p.y > Base.H * 0.6 then
		-- bottom middle, aside (SMASH): from the right, past the middle third, the words at the
		-- edge; from above, the arrow and GO SMASH! sat on the kart (auditor's garage shot)
		-- (0.69 of the canvas, not 2/3: a wider phone's middle third reaches a little further)
		x, y, rot, dx, dy = math.max(p.w + 6, Base.W * 0.69 - p.x), (p.h - s) / 2, 180, -1, 0
		wx, wy, align = x + s + 4, (p.h - th) / 2, "l"
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
--   next = { words, f }: the small bar under the coins (coins toward the next buy; nil = none),
--   stagger: boolean (a new player: the pieces come in one at a time, not all at once),
--   banner = false / myCar = false: leave that piece off (the live game, over the 3D plot),
--   words = { Garage = "TRAIN" }: other words on a tile }
-- actions: Garage(), Crates(), Shop(), League(), coins(), coach(), race(), jobs(), invite(), next()
-- api: setCoins(n), setRate(words), setNextUp(title, sub, hurry), setCar(name, stats), setNext(words, f),
--   setCoach(f, words), setDot(name, n), float(x, y, words, color), setRace(words, tone, pulse),
--   setJobs(words), setShown(name, on) (a tile, Coach, Race or Jobs steps away / comes back),
--   point(name?, words?, loud?, aside?) (one bouncing arrow at that piece; loud: bigger, with its
--   words; aside: a bottom middle piece is pointed at from the side, clear of the middle third)
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
		-- (small: a phone's lobby, carter 10-29: a smaller chip to read, not to tap; the shop is in
		-- the MENU)
		local small = data.smallCoins == true
		local coins = Kit.currency(coinsHolder, "Coins", 0, 0, cp.w, cp.h, {
			value = data.coins or 0,
			rate = data.rate or "",
			plus = not small,
			plate = true,
			onClick = if small then nil else Screen.act(actions, "coins"),
			noPress = small,
		})
		if small then
			coins.button.Active = false
			local scale = Instance.new("UIScale")
			scale.Scale = 0.8
			scale.Parent = coinsHolder
		end
		-- NEXT CRATE 120/200 (the live game): a small bar under the coins, coins toward the next
		-- buy; no glow of its own (the one glow is the HUD goal's)
		local nextHolder: Frame? = nil
		local nextWords: TextLabel? = nil
		local nextBar: Frame? = nil
		if data.next then
			local np = piece("plot", "Next")
			local nh = spot(c, "plot", "Next")
			nextHolder = nh
			local nb = Instance.new("TextButton")
			nb.Name = "Next"
			nb.Text = ""
			nb.AutoButtonColor = false
			nb.BackgroundTransparency = 1
			nb.ZIndex = 3
			nb.Parent = nh
			Base.at(nb, 0, 0, np.w, np.h)
			local plate = Base.fill(nb, "Plate", 0, 0, np.w, np.h, Base.color("ink"), 1)
			plate.BackgroundTransparency = 0.3
			Base.corner(plate, 10)
			nextWords = Base.text(nb, "Words", 8, 5, np.w - 16, 16, data.next.words or "", {
				stroke = 3,
				z = 4,
			})
			nextBar = Kit.bar(nb, "Bar", 8, 25, np.w - 16, 12, "go", {
				still = true,
				value = math.clamp(data.next.f or 0, 0, 1),
				z = 3,
			})
			Anim.press(nb)
			nb.Activated:Connect(Screen.act(actions, "next"))
		end
		local words: { [string]: string } = data.words or {}
		local sides: { [string]: Kit.Side } = {}
		local tiles: { GuiObject } = {}
		for i, sd in SIDES do
			local holder = spot(c, "plot", sd.name)
			local side: Kit.Side
			local icon = (data.icons or {})[sd.name] -- (a phone's MENU tile: another icon)
			if sd.icon == "car" and not icon then
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
				side = Kit.side(
					holder,
					"Tile",
					0,
					0,
					words[sd.name] or sd.word,
					icon or sd.icon,
					i,
					if icon then nil else sd.opts
				)
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
		-- data.settings: a computer's SETTINGS gear (WINDOWS' window; a phone has it in MENU)
		local settingsHolder: Frame? = nil
		if data.settings then
			local sp = piece("plot", "Settings")
			local sh = spot(c, "plot", "Settings")
			settingsHolder = sh
			Kit.button(sh, "Gear", 0, 0, sp.w, sp.h, "steel", "", {
				size = 20,
				icon = "gear",
				onClick = Screen.act(actions, "Settings"),
			})
		end
		-- every piece by name, for setShown and point
		local holders: { [string]: Frame } = {}
		for name, side in sides do
			holders[name] = side.button.Parent :: Frame
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
		if settingsHolder then
			holders.Settings = settingsHolder
		end
		if nextHolder then
			holders.Next = nextHolder
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
				{ coinsHolder, nextHolder },
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
			setNext = function(w: string, f: number)
				if nextWords and nextBar then
					Base.setText(nextWords, w)
					Kit.setBar(nextBar, f)
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
			point = function(name: string?, words: string?, loud: boolean?, aside: boolean?)
				local key = `{name}|{words}|{loud}|{aside}`
				if key == pointKey then
					return
				end
				pointKey = key
				if pointer then
					pointer:Destroy()
					pointer = nil
				end
				-- one thing moves, the one pointed at: the other tiles stop their nudge (auditor L2)
				for sname, sd in sides do
					local tile = sd.button:FindFirstChild("Tile")
					if tile then
						tile:SetAttribute("Quiet", sname ~= name)
					end
				end
				local h = if name then holders[name] else nil
				if not (name and h) then
					return
				end
				pointer = pointAt(h, piece("plot", name), words, loud == true, aside)
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

-- ===== SMASH match HUD (10-28): place + kill list top left, clock + health top middle, FIRE
-- bottom right (with the weapon and its ammo); the stick corner stays free. Phone: the stick and
-- FIRE are all it needs =====

local FEED_ROWS = 4 -- (carter's pick B, 10-30: was 2; the old 3 s was 5 s in the preview)
local FEED_SECS = 5
local FEED_ROW = 22
local BOARD_TOP = 3 -- the top 3, then you (a phone's left side is the stick's: Audit F9)
-- the board's and the kill list's words are 18 tall: 14 px on a 667x375 phone (Lead item 5)
local WORDS = 18
local BOARD_ROW, BOARD_STEP = 24, 27
local BOARD_NAME, FEED_NAME = 12, 8 -- letters a name keeps (then …) so it never shrinks small

-- A name in capitals, cut to `max` letters (the last one a …) so its words stay big.
function Hud.cut(name: string?, max: number): string
	local s = string.upper(name or "")
	local n = utf8.len(s)
	if n == nil then
		return "?" -- (not UTF-8, as SmashJuice.shortName)
	end
	if n <= max then
		return s
	end
	return string.sub(s, 1, (utf8.offset(s, max) :: number) - 1) .. "…"
end

-- A yellow level badge, w x 22 (28 unless given), with the level in it.
local function levelBadge(
	parent: Instance,
	x: number,
	y: number,
	level: number,
	name: string?,
	w: number?
)
	local bw = w or 28
	local badge = Base.fill(parent, name or "Level", x, y, bw, 22, Base.color("go"), 3)
	Base.corner(badge)
	Base.outline(badge, UiTheme.OUTLINE.small)
	Base.text(badge, "N", 1, 2, bw - 2, WORDS, tostring(math.floor(level)), {
		color = INK,
		z = 4,
	})
	return badge
end

-- Gold words (match 1A): a light-to-orange gradient over the letters (the ink stroke stays)
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 251, 224)),
	ColorSequenceKeypoint.new(0.38, Color3.fromRGB(255, 233, 90)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 196, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 154, 0)),
})
function Hud.gold(l: TextLabel)
	l.TextColor3 = WHITE
	local g = Instance.new("UIGradient")
	g.Name = "Gold"
	g.Color = GOLD
	g.Rotation = 90
	g.Parent = l
end

-- the weapon's icon (Icons) for a weapon from the server: a Weapons name (Rockets, Nuke, Gun,
-- Mine, Freeze) or a kill-list word (rockets, machine gun, freeze ray, bump...). "" / nil /
-- unknown = the "?" box
local WEAPON_ICON: { [string]: string } = {
	rocket = "rocket",
	rockets = "rocket",
	nuke = "nuke",
	gun = "gun",
	["machine gun"] = "gun",
	mine = "mine",
	mines = "mine",
	freeze = "freeze",
	["freeze ray"] = "freeze",
	flame = "flame",
	bump = "power",
}
function Hud.weaponIcon(name: string?): string
	if name == nil or name == "" then
		return "mystery"
	end
	return WEAPON_ICON[string.lower(name)] or "mystery"
end

-- the board's rows: the top 3, then you with your place when you are lower down (short: the
-- leader and you, the match HUD on every screen since auditor round 12)
function Hud.boardRows(list: { { [string]: any } }, short: boolean?): { { [string]: any } }
	local out = {}
	local top = if short then 1 else BOARD_TOP
	for i, e in list do
		if i <= top or e.me == true then
			local row = table.clone(e)
			row.rank = e.rank or i -- (SmashScreens.rank: ties share a place, as the chip does)
			table.insert(out, row)
		end
		if i > top and e.me == true then
			break
		end
	end
	return out
end

-- data: { place, total, secs, hp, maxHp, shield: boolean, weapon: name or "", ammo,
--   board = { { name, smashes, level?, me } } (most smashes first) }
-- actions: fire()
-- api: setPlace(p, total, smashes?) (hidden while you have none: a place not earned, F11/R3-1),
--   setClock(secs), setHealth(hp, max, shield), setWeapon(name, ammo),
--   setBoard(list),
--   feed(attacker, victim, weapon, mine: boolean, attackerLevel?, victimLevel?) (a new kill on
--   top; mine = you are in it; a level puts its badge before that name)
-- touch: a phone's small layout (UiScreens matchTouch): a 2/8 chip, a slim health bar, small
--   rows, no level badges (every screen: the leader and you, 2 kill lines for 3 s)
function Hud.match(
	data: { [string]: any },
	actions: Screen.Actions?,
	touch: boolean?
): Screen.Handle
	-- a phone: the small layout (UiScreens matchTouch), the middle of the screen left empty
	local L = if touch then "matchTouch" else "match"
	return Screen.open("match", "hud", true, function(g)
		local c = g.canvas
		-- (match 1A) a soft dark shade down from the top edge, so the white words read on bright
		-- ground; on the back layer, edge to edge under the top bar
		if g.back then
			local shade = Instance.new("Frame")
			shade.Name = "Shade"
			shade.BorderSizePixel = 0
			shade.BackgroundColor3 = Color3.fromRGB(8, 24, 40)
			shade.Size = UDim2.new(1, 0, 0.3, 0)
			shade.Parent = g.back
			local sg = Instance.new("UIGradient")
			sg.Rotation = 90
			sg.Transparency = NumberSequence.new(0.32, 1)
			sg.Parent = shade
		end
		-- PLACE: a trophy, big yellow 1ST, small / 5 (carter's kit v41)
		local pp = piece(L, "Place")
		local placeSpot = spot(c, L, "Place")
		local cup = pp.h * (if touch then 0.86 else 0.78)
		Icons.make(placeSpot, "trophy", 0, (pp.h - cup) / 2, cup, { z = 3 })
		local px = cup + 2
		local big = Base.text(
			placeSpot,
			"Place",
			px,
			0,
			if touch then 76 else pp.w * 0.56 - px + 6,
			pp.h - 4,
			"",
			{
				color = Base.color("go"),
				stroke = 7,
				drop = 4,
				align = "l",
				z = 3,
			}
		)
		Hud.gold(big)
		local of = Base.text(
			placeSpot,
			"Of",
			if touch then px + 78 else pp.w * 0.62,
			pp.h * (if touch then 0.36 else 0.4),
			if touch then 40 else pp.w * 0.36,
			pp.h * 0.5,
			"",
			{ stroke = 5, drop = 3, align = "l", z = 3 }
		)
		-- (a phone, match 1A: the crash burst and your smashes right after the place)
		local smashIcon: GuiObject? = nil
		local smashWords: TextLabel? = nil
		if touch then
			local bs = pp.h * 0.8
			smashIcon = Icons.make(placeSpot, "burst", px + 116, (pp.h - bs) / 2, bs, { z = 3 })
			smashWords = Base.text(
				placeSpot,
				"Smashes",
				px + 118 + bs,
				pp.h * 0.18,
				pp.w - (px + 118 + bs),
				pp.h * 0.66,
				"x0",
				{ stroke = 6, drop = 3, align = "l", z = 3 }
			)
		end
		local shownSmashes: number? = nil
		-- +1 flies from the middle up to the smash count, which then bounces (match 1A)
		local function plusOne()
			local sw = smashWords
			if not sw or Base.reduced() then
				return
			end
			local w = Base.text(c, "PlusOne", 330, 150, 60, 36, "+1", { stroke = 6, z = 20 })
			Hud.gold(w)
			Anim.pop(w, 0.2, 0.4)
			local to = sw.AbsolutePosition - c.AbsolutePosition
			local cs = c.AbsoluteSize
			Anim.to(w, 0.55, {
				Position = UDim2.fromScale(
					if cs.X > 0 then to.X / cs.X else 0.1,
					if cs.Y > 0 then to.Y / cs.Y else 0.02
				),
				TextTransparency = 0.3,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.25)
			task.delay(0.8, function()
				w:Destroy()
				if sw.Parent then
					Anim.pop(sw, 0.3, 1.6)
				end
			end)
		end
		-- (before your first smash the chip says GO SMASH! instead: "- / 8" read as broken, audit
		-- R3-1, and an empty corner read as missing, audit R6-3)
		-- (a phone: one small "2/8", and GO! before your first smash)
		local go = Base.text(
			placeSpot,
			"Go",
			px,
			4,
			pp.w - px - 4,
			pp.h - 12,
			if touch then "GO!" else "GO SMASH!",
			{
				color = Base.color("go"),
				stroke = 6,
				drop = 3,
				align = "l",
				z = 3,
			}
		)
		local function setPlace(p: number, total: number, smashes: number?)
			local was = big.Text
			-- (your place as the board shows it, smashes or not: GO! read as broken next to a board
			-- with you 6th, Studio r52; GO! only before there is a place at all)
			local placed = p >= 1
			-- (each with its drop: GO SMASH!'s shadow stayed behind 3RD / 8, Studio round 6)
			for l, on in { [go] = not placed, [big] = placed, [of] = placed } do
				l.Visible = on
				local d = placeSpot:FindFirstChild(l.Name .. "Drop")
				if d and d:IsA("GuiObject") then
					d.Visible = on
				end
			end
			Base.setText(big, UiMotion.place(p))
			Base.setText(of, (if touch then "/" else "/ ") .. tostring(total))
			if smashWords and smashes then
				Base.setText(smashWords, "x" .. tostring(math.floor(smashes)))
				if shownSmashes and smashes > shownSmashes then
					plusOne()
				end
				shownSmashes = smashes
			end
			if was ~= "" and was ~= big.Text and placed then
				Anim.shout(placeSpot)
			end
		end
		setPlace(data.place or 1, data.total or 8, data.smashes)
		-- CLOCK: a clock and big white stroked words, no plate; red and breathing in the last
		-- 10 s (carter's kit v41)
		local cp = piece(L, "Clock")
		local clockSpot = spot(c, L, "Clock")
		local clockFrame = Base.box(clockSpot, "Clock", 0, 0, cp.w, cp.h, 2)
		local dial = cp.h * 0.9
		Icons.make(clockFrame, "clock", 0, (cp.h - dial) / 2, dial, { z = 3 })
		local clockWords = Base.text(
			clockFrame,
			"Value",
			dial + 2,
			0,
			cp.w - dial - 2,
			cp.h - 3,
			UiMotion.clock(data.secs or 180),
			{ stroke = 6, drop = 3, align = "l", z = 4 }
		)
		local hurry: Tween? = nil
		local function setClock(secs: number)
			Base.setText(clockWords, UiMotion.clock(secs))
			local late = secs <= 10 and secs > 0
			clockWords.TextColor3 = if late then Base.color("danger") else WHITE
			if late and not hurry then
				hurry = Anim.pulse(clockFrame, 1.16, 0.5)
			elseif not late and hurry then
				hurry:Cancel()
				hurry = nil
				Anim.scaler(clockFrame).Scale = 1
			end
		end
		-- HEALTH (carter's kit v41): the blue level star, your name and 72/100 over the bar, the
		-- heart on its left end; lime over 60%, orange to 31%, red at 30% and under; a blue fill
		-- and SHIELD! while the shield is up. A phone: the star, the heart on a short bar, the
		-- number beside it.
		local hp = piece(L, "Health")
		local hs = spot(c, L, "Health")
		-- (a phone: no star, its number would read under 14 px)
		local starS = if touch then 0 else 34
		if not touch then
			-- (a star badge: two blue squares, one turned 45, so it reads as a star, not a ball:
			-- Studio qa_r58)
			local star = Base.box(hs, "Level", 0, (hp.h - starS) / 2, starS, starS, 5)
			local ps = math.floor(starS * 0.74)
			-- (twice: the outlined pair under, a fill-only pair over, so no edge crosses the blue)
			for layer = 1, 2 do
				for k, turn in { 0, 45 } do
					local off = (starS - ps) / 2
					local pt =
						Base.fill(star, `Point{layer}{k}`, off, off, ps, ps, WHITE, 3 + layer)
					pt.Rotation = turn
					Base.corner(pt, 4)
					if layer == 1 then
						Base.outline(pt, UiTheme.OUTLINE.normal)
					end
					local f = UiTheme.FACE.blue
					Kit.face(pt, { f.hi, f.c, f.c2 }, 90 - turn)
				end
			end
			Base.text(
				star,
				"N",
				starS * 0.1,
				starS * 0.12,
				starS * 0.8,
				starS * 0.72,
				tostring(math.floor(tonumber(data.level) or 1)),
				{ stroke = 3.5, z = 6 }
			)
		end
		local bx = starS + 4
		local labelH = if touch then 16 else 19
		local barY = if touch then 17 else 21
		local barH = hp.h - barY
		-- (match 1A: moving stripes, a tick every fifth, and a white chunk that lingers on a hit)
		local bar = Kit.bar(hs, "Bar", bx + 8, barY, hp.w - bx - 8, barH, "lime", {
			value = 1,
			z = 3,
		})
		local chunk = Base.fill(bar, "Chunk", 0, 0, hp.w - bx - 8, barH, WHITE, 0)
		Base.corner(chunk)
		for i = 1, 4 do
			local t = Base.fill(bar, "Tick" .. i, (hp.w - bx - 8) * i / 5 - 1, 0, 2, barH, INK, 4)
			t.BackgroundTransparency = 0.55
		end
		local heart = barH + 10
		local heartIcon =
			Icons.make(hs, "heart", bx - 4, barY + (barH - heart) / 2, heart, { z = 5 })
		do
			Base.text(
				hs,
				"Name",
				bx + 8,
				0,
				(hp.w - bx - 8) * 0.5,
				labelH,
				Hud.cut(string.upper(tostring(data.name or "")), BOARD_NAME),
				{ stroke = 3.5, align = "l", z = 6 }
			)
		end
		local hpWords = Base.text(
			hs,
			"Words",
			bx + 8 + (hp.w - bx - 8) * 0.5,
			0,
			(hp.w - bx - 8) * 0.5,
			19,
			"",
			{
				stroke = 3.5,
				align = "r",
				z = 6,
			}
		)
		local lastHp = -1
		local function setHealth(n: number, max: number, shield: boolean?)
			local f = if max > 0 then math.clamp(n / max, 0, 1) else 0
			local fill = bar:FindFirstChild("Fill") :: Frame?
			if fill then
				fill.BackgroundColor3 = Base.color(
					if shield
						then "blue"
						elseif f > 0.6 then "lime"
						elseif f > 0.3 then "boost"
						else "danger"
				)
			end
			Kit.setBar(bar, f)
			-- (the chunk waits 0.35 s, then shrinks; healing jumps it up with the fill)
			if lastHp >= 0 and n < lastHp then
				Anim.to(chunk, 0.3, { Size = UDim2.fromScale(f, 1) }, nil, nil, 0.35)
			else
				chunk.Size = UDim2.fromScale(f, 1)
			end
			local now = math.max(0, math.floor(n))
			Base.setText(
				hpWords,
				if shield then "SHIELD!" else `{now}/{math.max(0, math.floor(max))}`
			)
			if lastHp >= 0 and n < lastHp then
				-- (a hit: the heart jumps; the bar keeps its size, it read as a third-size bar
				-- caught mid-jump, Studio qa_r61)
				Anim.pop(heartIcon, 0.3, 1.45)
			end
			lastHp = n
		end
		setHealth(data.hp or 100, data.maxHp or 100, data.shield)
		-- SCOREBOARD: the leader and you (any screen, auditor round 12), most smashes first: the
		-- place, a level badge (when the kart has a level), the name, the smashes; your row lime
		-- (a phone, match 1A: no board, the place chip says it)
		local bp = if touch then nil else piece(L, "Board")
		local boardSpot = if touch then nil else spot(c, L, "Board")
		local boardRows: { Frame } = {}
		local function setBoard(list: { { [string]: any } })
			if not (bp and boardSpot) then
				return
			end
			for _, r in boardRows do
				r:Destroy()
			end
			table.clear(boardRows)
			for i, e in Hud.boardRows(list, true) do
				local me = e.me == true
				local row = Base.fill(
					boardSpot,
					"Row" .. i,
					0,
					(i - 1) * (if touch then 25 else BOARD_STEP),
					bp.w,
					if touch then 22 else BOARD_ROW,
					Base.color(if me then "lime" else "navy"),
					2
				)
				row.BackgroundTransparency = if me then 0 else 0.2
				Base.corner(row)
				Base.outline(row, UiTheme.OUTLINE.small)
				Base.text(row, "Rank", 2, 2, 20, WORDS, tostring(e.rank or i), {
					stroke = 3,
					z = 3,
				})
				local left = 24
				if type(e.level) == "number" and not touch then
					levelBadge(row, 23, 1, e.level)
					left = 58
				end
				Base.text(
					row,
					"Name",
					left,
					2,
					bp.w - left - 36,
					WORDS,
					Hud.cut(e.name, if touch then 10 else BOARD_NAME),
					{
						stroke = 3,
						align = "l",
						z = 3,
					}
				)
				Base.text(row, "Smashes", bp.w - 34, 2, 30, 20, tostring(e.smashes or 0), {
					color = Base.color("go"),
					stroke = 3.5,
					align = "r",
					z = 3,
				})
				table.insert(boardRows, row)
			end
		end
		setBoard(data.board or {})
		-- KILL LIST: up to 4 rows, newest on top, each gone after 5 s (carter's pick B)
		local fp = piece(L, "Feed")
		local feedSpot = spot(c, L, "Feed")
		local rows: { Frame } = {}
		local feedRows = FEED_ROWS
		local feedSecs = FEED_SECS
		local feedStep = FEED_ROW
		local function layoutRows()
			for i, r in rows do
				Anim.to(r, 0.2, { Position = UDim2.fromScale(0, (i - 1) * feedStep / fp.h) })
			end
		end
		local function feed(
			attacker: string,
			victim: string,
			weapon: string?,
			mine: boolean?,
			attackerLevel: number?,
			victimLevel: number?
		)
			-- carter's pick B (10-30, match-screen/killlist): bare outlined words, no plate: WHO
			-- (gold when you are in it), the weapon, a red arrow, WHOM
			local rowH = FEED_ROW
			local row = Base.box(feedSpot, "Row", 0, 0, fp.w, rowH, 2)
			local nameW = math.floor((fp.w - rowH - 18) / 2)
			local function side(x: number, name: string, key: string, gold: boolean)
				Base.text(
					row,
					key,
					x,
					2,
					nameW,
					rowH - 4,
					Hud.cut(name, if touch then 6 else FEED_NAME),
					{
						stroke = 3.5,
						align = "l",
						z = 3,
						color = if gold then Base.color("go") else nil,
					}
				)
			end
			-- (levels stay off this line: the kit's board and health bar show them)
			side(0, attacker, "Who", mine == true)
			Icons.make(row, Hud.weaponIcon(weapon), nameW + 2, 0, rowH, { z = 4 })
			local arrow = Base.text(row, "Arrow", nameW + rowH + 2, 2, 14, rowH - 4, "›", {
				stroke = 3.5,
				align = "c",
				z = 3,
				color = Base.color("danger"),
			})
			arrow.Name = "Arrow"
			side(nameW + rowH + 16, victim, "Whom", false)
			table.insert(rows, 1, row)
			while #rows > feedRows do
				(table.remove(rows) :: Frame):Destroy()
			end
			layoutRows()
			Anim.pop(row, nil, 0.4)
			task.delay(feedSecs, function()
				local i = table.find(rows, row)
				if i then
					table.remove(rows, i)
					row:Destroy()
					layoutRows()
				end
			end)
		end
		-- FIRE (carter's kit v41): a glossy pink thumb button with the weapon's big icon, the ammo
		-- in a yellow coin on its bottom left; no weapon: a purple orb with a big "?"
		local fpc = piece(L, "Fire")
		local fireSpot = spot(c, L, "Fire")
		local fire = Kit.round(fireSpot, "Fire", 0, 0, fpc.w, "pink", "FIRE", {
			onClick = Screen.act(actions, "fire"),
		})
		-- (match 1A) empty hands: a soft white ring breathes around the orb
		local ring = Base.box(fireSpot, "Ring", -8, -8, fpc.w + 16, fpc.w + 16, 2)
		Base.corner(ring)
		local ringLine = Base.outline(ring, 4, WHITE)
		ringLine.Transparency = 0.45
		if not Base.reduced() then
			Anim.pulse(ring, 1.08, 0.7)
		end
		local body = fire.button:FindFirstChild("Body") :: Frame
		local label = body:FindFirstChild("Label") :: TextLabel
		local icon: GuiObject? = nil
		local ball = Base.fill(fire.button, "Ammo", -2, fpc.w * 0.64, 38, 38, WHITE, 7)
		Base.corner(ball)
		Base.outline(ball, UiTheme.OUTLINE.normal)
		Kit.face(ball, { UiTheme.FACE.go.hi, UiTheme.FACE.go.c, UiTheme.FACE.go.c2 })
		local ammoWords = Base.text(ball, "N", 4, 6, 30, 24, "", { color = INK, z = 8 })
		-- ammo pips on an arc at the top left (the kit): lime = a shot left, slate = used. Only for
		-- small stocks (5 or fewer); a big stock is just the coin's number
		local PIP_MAX = 5
		local pips: { Frame } = {}
		for i = 1, PIP_MAX do
			local a = math.rad(190 + (i - 1) * 28)
			local r = fpc.w / 2 + 10
			local pip = Base.fill(
				fire.button,
				"Pip" .. i,
				fpc.w / 2 + math.cos(a) * r - 6.5,
				fpc.w / 2 + math.sin(a) * r - 6.5,
				13,
				13,
				PIP_ON,
				7
			)
			Base.corner(pip)
			Base.outline(pip, 3)
			pip.Visible = false
			pips[i] = pip
		end
		local maxAmmo = 0 -- (the stock the weapon came with)
		local orbH = fpc.w - 9 * fpc.w / 100
		local dim = Base.fill(body, "Empty", 0, 0, fpc.w, orbH, WHITE, 7)
		Base.corner(dim)
		Base.outline(dim, UiTheme.OUTLINE.normal)
		Kit.face(dim, { "c9a8ff", "8a4dff", "5a22c8" })
		Base.text(dim, "Q", fpc.w * 0.25, orbH * 0.18, fpc.w * 0.5, orbH * 0.6, "?", {
			stroke = 7,
			drop = 3,
			z = 8,
		})
		-- the tip over it: GRAB A ? BOX while empty, the weapon's name for 1.4 s when one comes;
		-- your first match only (data.tip), then the button alone (carter: the minimum)
		local tipOn = data.tip == true
		local quiet = false -- (a how-to card is up: it says the same, Studio r52)
		local tip = Base.fill(fireSpot, "Tip", -14, -34, fpc.w + 28, 28, WHITE, 6)
		Base.corner(tip, 10)
		Base.outline(tip, UiTheme.OUTLINE.normal)
		Kit.face(tip, { UiTheme.FACE.go.hi, UiTheme.FACE.go.c, UiTheme.FACE.go.c2 })
		local tipWords =
			Base.text(tip, "Words", 6, 5, fpc.w + 16, 18, "GRAB A ? BOX", { color = INK, z = 7 })
		tip.Visible = false
		local tipSeq = 0 -- (each weapon name shown counts up; only the newest one hides it)
		local naming = false -- the weapon's name is up
		local shownWeapon: string? = nil
		local lastName: string?, lastAmmo: number? = nil, nil
		local function setWeapon(name: string?, ammo: number?)
			lastName, lastAmmo = name, ammo
			local has = name ~= nil and name ~= "" and (ammo or 0) > 0
			local key = if has then Hud.weaponIcon(name) else "mystery"
			-- (keyed on the name too: a weapon with no icon of its own also shows "mystery")
			local shown = if has then `{key}|{name}` else ""
			if shown ~= shownWeapon then
				shownWeapon = shown
				if icon then
					icon:Destroy()
				end
				icon = Icons.make(body, key, fpc.w * 0.22, fpc.w * 0.14, fpc.w * 0.56, { z = 6 })
				maxAmmo = if has then ammo or 0 else 0
				if has then
					Anim.pop(fire.button, nil, 0.6)
					if tipOn then
						tipWords.Text = string.upper(tostring(name)) .. "!"
						naming = true
						tipSeq += 1
						local mine = tipSeq
						task.delay(1.4, function()
							if mine == tipSeq then
								naming = false
								if shownWeapon ~= "" then
									tip.Visible = false
								end
							end
						end)
					end
				end
			end
			label.Visible = false -- (the kit: the big icon says it, no FIRE words)
			if tipOn then
				if not has then
					naming = false
					tipWords.Text = "GRAB A ? BOX"
					tip.Visible = not quiet
				else
					tip.Visible = naming and not quiet
				end
			end
			if icon then
				icon.Visible = has
			end
			ball.Visible = has
			ammoWords.Text = tostring(ammo or 0)
			maxAmmo = math.max(maxAmmo, ammo or 0)
			for i, pip in pips do
				pip.Visible = has and maxAmmo <= PIP_MAX and i <= maxAmmo
				pip.BackgroundColor3 = if i <= (ammo or 0) then PIP_ON else PIP_OFF
			end
			dim.Visible = not has
			ring.Visible = not has
		end
		setWeapon(data.weapon, data.ammo)
		-- BUTTONS (Settings): FIRE grows or shrinks around its own middle
		fireSpot.AnchorPoint = Vector2.new(0.5, 0.5)
		fireSpot.Position = UDim2.new(
			fireSpot.Position.X.Scale + fireSpot.Size.X.Scale / 2,
			0,
			fireSpot.Position.Y.Scale + fireSpot.Size.Y.Scale / 2,
			0
		)
		local fireScale = Instance.new("UIScale")
		fireScale.Parent = fireSpot
		return {
			setButtonScale = function(v: number)
				fireScale.Scale = math.clamp(v, 0.5, 1.5)
			end,
			setPlace = setPlace,
			setClock = setClock,
			setHealth = setHealth,
			setWeapon = setWeapon,
			-- quiet(on): a how-to card is up, so the tip over FIRE steps aside (same words twice)
			quiet = function(on: boolean)
				quiet = on
				setWeapon(lastName, lastAmmo)
			end,
			setBoard = setBoard,
			feed = feed,
		}
	end)
end

return Hud
