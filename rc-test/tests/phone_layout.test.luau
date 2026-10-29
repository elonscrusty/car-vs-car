--!nocheck
-- The Smash screens on two real phone sizes (667x375, and 844x390 with its notch): the match HUD,
-- the end screen, the crate reveal and the garage. It builds them with the real client UI code
-- in the pretend game and measures where each piece lands (tests/ui_layout.luau). Nothing off
-- screen, buttons a thumb can hit (44 px, FIRE 88 px), words at least 14 px tall, the HUD pieces
-- apart, and nothing over the drive stick's corner (Lead road to 9/10, item 5).
local Fake = require("./fakeroblox")
local H = require("./harness")
local L = require("./ui_layout")
local roblox = require("@lune/roblox")

local test, truthy = H.test, H.truthy

print("Phone layout")

local S = Fake.server(Fake.store())
local req = S.client(1)
local Hud = req("Ui.Screens.Hud")
local Smash = req("Ui.Screens.Smash")
local Flow = req("Ui.Screens.Flow")

local TEXT_MIN, BUTTON_MIN, FIRE_MIN = 14, 44, 88

local function isText(b): boolean
	return (b.class == "TextLabel" or b.class == "TextButton" or b.class == "TextBox")
		and type(b.obj.Text) == "string"
		and b.obj.Text ~= ""
		and L.shows(b)
end

local function isButton(b): boolean
	return (b.class == "TextButton" or b.class == "ImageButton") and b.obj.Active ~= false
end

-- What shows of a box: cut to its clipping parent.
local function seen(b): (number, number, number, number)
	local x, y, w, h = b.x, b.y, b.w, b.h
	local c = b.clip
	if c then
		local x2, y2 = math.min(x + w, c[1] + c[3]), math.min(y + h, c[2] + c[4])
		x, y = math.max(x, c[1]), math.max(y, c[2])
		w, h = x2 - x, y2 - y
	end
	return x, y, w, h
end

local function name(b): string
	return string.format("%s (%d,%d %dx%d)", b.path, b.x, b.y, b.w, b.h)
end

-- Every problem on screen `h` at phone `ph`.
local function problems(h, ph): { string }
	local s = ph.safe
	local out = {}
	for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
		-- (texts, buttons and the screen's own pieces; a glow may spill past the edge)
		if isText(b) or isButton(b) or b.depth <= 1 then
			local x, y, w, hh = seen(b)
			if
				x < s[1] - 1
				or y < s[2] - 1
				or x + w > s[1] + s[3] + 1
				or y + hh > s[2] + s[4] + 1
			then
				table.insert(out, ph.name .. " off screen: " .. name(b))
			end
		end
		if isText(b) and L.letters(b) < TEXT_MIN then
			table.insert(
				out,
				string.format("%s text %.0f px: %q %s", ph.name, L.letters(b), b.obj.Text, name(b))
			)
		end
		if isButton(b) then
			local need = if string.find(b.path, "%.Fire") then FIRE_MIN else BUTTON_MIN
			if math.min(b.w, b.h) < need - 0.5 then
				table.insert(out, ph.name .. " small button: " .. name(b))
			end
		end
	end
	return out
end

local function none(list: { string })
	truthy(#list == 0, "\n  " .. table.concat(list, "\n  "))
end

local function matchHud()
	local h = Hud.match({
		place = 3,
		total = 8,
		secs = 120,
		hp = 100,
		maxHp = 100,
		smashes = 2,
		weapon = "Rockets",
		ammo = 3,
		board = {
			{ name = "BUBBLE BUGGY", smashes = 4, level = 3 },
			{ name = "CAPTAIN CRASHALOT", smashes = 3, level = 12 },
			{ name = "DIZZY DASH", smashes = 2 },
			{ name = "MRCARTER", smashes = 2, me = true, level = 1 },
		},
	})
	h.api.feed("ROCKET RACCOON", "LIL SMASHER", "rocket", false)
	h.api.feed("MRCARTER", "ZIPPY", "mine", true, 1, 7)
	h.api.feed("SUPERLONGNAME99", "ANOTHERLONGNAME", "gun", false, 12, 99)
	return h
end

-- The HUD's own pieces (the canvas children) on screen.
local function pieces(h, ph): { [string]: any }
	local s = ph.safe
	local got = {}
	for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
		if b.depth == 1 then
			got[b.obj.Name] = b
		end
	end
	return got
end

local function overlap(a, b): boolean
	return a.x < b.x + b.w - 1
		and b.x < a.x + a.w - 1
		and a.y < b.y + b.h - 1
		and b.y < a.y + a.h - 1
end

for _, ph in L.PHONES do
	test("match HUD fits a " .. ph.name .. " phone", function()
		local h = matchHud()
		none(problems(h, ph))
		h.close()
	end)

	test("match HUD pieces stay apart and off the stick at " .. ph.name, function()
		local h = matchHud()
		local got = pieces(h, ph)
		local names = {}
		for n in got do
			table.insert(names, n)
		end
		table.sort(names)
		local bad = {}
		for i, a in names do
			for j = i + 1, #names do
				local b = names[j]
				-- (the big words sit over the middle on purpose, for a moment)
				if a ~= "Words" and b ~= "Words" and overlap(got[a], got[b]) then
					table.insert(bad, a .. " on " .. b)
				end
			end
		end
		-- the drive stick's corner: bottom left, 140 design px square
		local s = ph.safe
		local k = math.min(s[3] / 756, s[4] / 390)
		local stick = { x = s[1], y = s[2] + s[4] - 140 * k, w = 140 * k, h = 140 * k }
		for n, b in got do
			if overlap(b, stick) then
				table.insert(bad, n .. " on the stick")
			end
		end
		truthy(got.Fire ~= nil, "no FIRE button")
		none(bad)
		h.close()
	end)

	test("end screen fits a " .. ph.name .. " phone", function()
		local h = Smash.matchEnd({
			place = 5,
			total = 8,
			top = {
				{ name = "ROCKET RACCOON", smashes = 8, me = false },
				{ name = "ZIPPY", smashes = 7, me = false },
				{ name = "BANANA BLITZ", smashes = 6, me = false },
			},
			winner = { name = "ROCKET RACCOON", smashes = 8, me = false },
			coins = 30,
			xp = 30,
			smashes = 2,
			nextAt = 10,
		})
		S.advance(3)
		none(problems(h, ph))
		h.close()
	end)

	test("crate reveal fits a " .. ph.name .. " phone", function()
		local h = Flow.reveal({
			rarity = "epic",
			name = "Cotton Candy",
			color = roblox.Color3.new(1, 0.5, 0.8),
			kind = "buggy",
			new = true,
			note = "New kart! Try it in CUSTOMIZE.",
			again = true,
		})
		S.advance(3)
		none(problems(h, ph))
		h.close()
	end)

	test("garage fits a " .. ph.name .. " phone", function()
		local h = Smash.customize({
			tab = 1,
			karts = {
				{ id = "a", name = "Bolt", rarity = "common", own = true, on = true },
				{ id = "b", name = "Cotton Candy", rarity = "rare", own = true },
			},
			hats = { { name = "Crown", rarity = "epic", own = false } },
			driving = { id = "a", name = "Bolt" },
		})
		S.advance(3)
		none(problems(h, ph))
		h.close()
	end)
end

test("a level badge sits before each name with a level, on the board and the kill list", function()
	local h = matchHud()
	local c = h.gui.canvas
	local board = c:FindFirstChild("Board")
	-- (the board is the leader and you: auditor round 12)
	local row1 = board and board:FindFirstChild("Row1")
	truthy(row1 and row1:FindFirstChild("Level"), "no board badge for the level 3 leader")
	local row2 = board and board:FindFirstChild("Row2")
	truthy(row2 and row2:FindFirstChild("Level"), "no board badge for your level 1 kart")
	truthy(board and board:FindFirstChild("Row3") == nil, "a third board row")
	local feed = c:FindFirstChild("Feed")
	local n = 0
	for _, r in feed:GetChildren() do
		if r:FindFirstChild("WhoLevel") and r:FindFirstChild("WhomLevel") then
			n += 1
			local who = r:FindFirstChild("Who")
			truthy(who.Text == "SUPERLO…" or who.Text == "MRCARTER", "name not cut: " .. who.Text)
		end
	end
	truthy(n == 2, "kill list badges: " .. n)
	h.close()
end)

test("the phone screens built with no script errors", function()
	none(S.errors)
end)

-- The lobby's GO SMASH! arrow and words sit at the screen's edge, past the middle third where the
-- kart is (from above the SMASH! button they sat on the kart, auditor's garage shot)
test("GO SMASH! points at the SMASH! button from the side, out of the middle third", function()
	local h = Hud.plot({ coins = 0, race = "SMASH!", banner = false, myCar = false })
	h.api.point("Race", "GO SMASH!", true, true)
	local s = L.PHONES[1].safe
	local k = math.min(s[3] / 756, s[4] / 390)
	local mid1, mid2 = s[1] + 252 * k, s[1] + 504 * k
	local seenArrow, seenWords = false, false
	for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
		if
			string.find(b.path, "Pointer.", 1, true)
			and (b.obj.Name == "Arrow" or b.obj.Name == "Words")
		then
			seenArrow = seenArrow or b.obj.Name == "Arrow"
			seenWords = seenWords or b.obj.Name == "Words"
			truthy(b.x + b.w <= mid1 + 1 or b.x >= mid2 - 1, "in the middle third: " .. name(b))
			truthy(b.x + b.w <= s[1] + s[3] + 1, "off screen: " .. name(b))
		end
	end
	truthy(seenArrow and seenWords, "no arrow or words")
	-- (with SMASH off the arrow still comes from above, as before)
	h.api.point("Race", "TAP RACE!", true, false)
	local above = false
	for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
		if string.find(b.path, "Pointer.Arrow", 1, true) and b.obj.Name == "Arrow" then
			above = b.x > mid1 and b.x + b.w < mid2
		end
	end
	truthy(above, "the race arrow moved with SMASH off")
	h.close()
end)

-- ===== a phone's match (carter 10-29: "can't see on mobile, too cluttered") =====
-- The small layout (UiScreens matchTouch): the middle half of the screen empty, our UI at most a
-- fifth of the screen, the board just you and the leader, at most 2 kill lines. Prints the
-- numbers for each phone (the auditor's bars).

local function phoneHud(desk: boolean?)
	local h = Hud.match({
		place = 3,
		total = 8,
		secs = 120,
		hp = 100,
		maxHp = 100,
		smashes = 2,
		weapon = "Rockets",
		ammo = 3,
		board = {
			{ name = "BUBBLE BUGGY", smashes = 4, level = 3 },
			{ name = "CAPTAIN CRASHALOT", smashes = 3, level = 12 },
			{ name = "DIZZY DASH", smashes = 2 },
			{ name = "MRCARTER", smashes = 2, me = true, level = 1 },
		},
	}, nil, not desk)
	h.api.feed("ROCKET RACCOON", "LIL SMASHER", "rocket", false)
	h.api.feed("MRCARTER", "ZIPPY", "mine", true, 1, 7)
	h.api.feed("SUPERLONGNAME99", "ANOTHERLONGNAME", "gun", false, 12, 99)
	return h
end

-- the middle half of the whole screen (a quarter in from each edge)
local function centre(ph): { x: number, y: number, w: number, h: number }
	return { x = ph.w / 4, y = ph.h / 4, w = ph.w / 2, h = ph.h / 2 }
end

local PHONE_SIZES = table.clone(L.PHONES)

-- the rows in a board or the kill list (not its constraint)
local function rowsIn(f): number
	local n = 0
	for _, r in f:GetChildren() do
		if r.ClassName == "Frame" then
			n += 1
		end
	end
	return n
end

for _, ph in PHONE_SIZES do
	test(
		"phone match HUD at " .. ph.name .. ": centre empty, UI 20% at most, all readable",
		function()
			local h = phoneHud()
			none(problems(h, ph))
			local s = ph.safe
			local mid = centre(ph)
			local inMid = {}
			local area = 0
			for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
				local x, y, w, hh = seen(b)
				if
					(isText(b) or isButton(b) or b.obj.BackgroundTransparency ~= 1)
					and overlap({ x = x, y = y, w = w, h = hh }, mid)
				then
					table.insert(inMid, name(b))
				end
				if b.depth == 1 then
					area += w * hh
				end
			end
			local pct = area / (ph.w * ph.h) * 100
			local board = h.gui.canvas:FindFirstChild("Board")
			local feed = h.gui.canvas:FindFirstChild("Feed")
			local boardRows, feedRows = rowsIn(board), rowsIn(feed)
			print(
				string.format(
					"       %s: UI %.1f%% of the screen, %d in the centre box, board %d rows, feed %d rows",
					ph.name,
					pct,
					#inMid,
					boardRows,
					feedRows
				)
			)
			none(inMid)
			truthy(pct <= 20, string.format("UI is %.1f%% of the screen", pct))
			truthy(boardRows == 2, "board rows: " .. boardRows)
			truthy(feedRows <= 2, "feed rows: " .. feedRows)
			-- the leader and you, nobody else
			local names = {}
			for _, r in board:GetChildren() do
				for _, l in r:GetChildren() do
					if l.ClassName == "TextLabel" and l.Name == "Name" then
						table.insert(names, l.Text)
					end
				end
			end
			table.sort(names)
			truthy(names[1] == "BUBBLE BU…" and names[2] == "MRCARTER", table.concat(names, ", "))
			h.close()
		end
	)
end

-- auditor round 12 (desktop Studio shots): the board is you and the leader, at most 2 kill lines,
-- on every screen, not just a phone's
test("desktop match HUD too: board you and the leader, kill feed 2 rows at most", function()
	local h = phoneHud(true)
	local board = h.gui.canvas:FindFirstChild("Board")
	local feed = h.gui.canvas:FindFirstChild("Feed")
	truthy(rowsIn(board) == 2, "board rows: " .. rowsIn(board))
	truthy(rowsIn(feed) <= 2, "feed rows: " .. rowsIn(feed))
	h.close()
end)

-- round 12 fix 5: no GO SMASH! arrow or words in the Smash lobby (the SMASH! button pulses);
-- far karts wear no names in a match on any screen, the near ones small
test("Smash lobby: no GO SMASH! pointer; match name tags small and near on any screen", function()
	local fs = require("@lune/fs")
	local cvc = fs.readFile("src/client/CvcScreens.client.luau")
	truthy(
		string.find(cvc, 'if goal == "Race" and (yard or SMASH) then nil else goal', 1, true) ~= nil,
		"the SMASH! button still gets an arrow"
	)
	local oc = fs.readFile("src/client/OtherCars.luau")
	truthy(
		string.find(oc, "elseif inMatch then MATCH_TAG_FAR", 1, true) ~= nil,
		"far tags in a match"
	)
	truthy(string.find(oc, "if inMatch then MATCH_TAG_SIZE", 1, true) ~= nil, "big tags in a match")
	truthy(string.find(oc, "PHONE and Players.LocalPlayer", 1, true) == nil, "still phone only")
end)

test("phone match HUD: kill lines go after 3 s, and FIRE carries the weapon", function()
	local h = phoneHud()
	local feed = h.gui.canvas:FindFirstChild("Feed")
	truthy(rowsIn(feed) == 2, "feed rows: " .. rowsIn(feed))
	S.advance(3.2)
	truthy(rowsIn(feed) == 0, "kill lines still up after 3 s: " .. rowsIn(feed))
	local fire = h.gui.canvas:FindFirstChild("Fire")
	truthy(
		fire:FindFirstChild("Ammo", true) ~= nil and fire:FindFirstChild("Icon", true) ~= nil,
		"no weapon on FIRE"
	)
	h.close()
end)

-- auditor round 12b / carter's kit v41: empty hands are a purple "?" orb with GRAB A ? BOX over
-- it (first match only); a weapon shows its icon and the ammo coin, the tip names it for 1.4 s
test("FIRE: the ? orb and GRAB A ? BOX when empty, the weapon and ammo when held", function()
	local h = Hud.match({
		place = 1,
		total = 8,
		secs = 120,
		hp = 100,
		maxHp = 100,
		smashes = 0,
		weapon = "",
		ammo = 0,
		board = {},
		tip = true,
	}, nil, true)
	local fire = h.gui.canvas:FindFirstChild("Fire", true)
	local orb = fire:FindFirstChild("Empty", true)
	local tip = h.gui.canvas:FindFirstChild("Tip", true)
	truthy(orb and orb.Visible, "no ? orb when empty")
	truthy(orb:FindFirstChild("Q") and orb:FindFirstChild("Q").Text == "?", "no ? on the orb")
	truthy(tip and tip.Visible, "no GRAB A ? BOX tip")
	truthy(tip:FindFirstChild("Words").Text == "GRAB A ? BOX", tip:FindFirstChild("Words").Text)
	-- (a how-to card up says the same: the tip steps aside, Studio r52)
	h.api.quiet(true)
	truthy(not tip.Visible, "the tip and the how-to card both say it")
	h.api.quiet(false)
	truthy(tip.Visible, "the tip stayed away after the card")
	-- (the chip shows your board place even on 0 smashes: GO! sat by a board with you 6th)
	h.api.setPlace(6, 8, 0)
	local chip
	for _, d in h.gui.canvas:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Name == "Place" then
			chip = d
		end
	end
	truthy(
		chip and chip.Visible and chip.Text == "6/8",
		"place chip: " .. tostring(chip and chip.Text)
	)
	h.api.setWeapon("Rockets", 3)
	truthy(not orb.Visible, "the orb stayed over the weapon")
	truthy(fire:FindFirstChild("Ammo", true).Visible, "no ammo coin")
	truthy(tip:FindFirstChild("Words").Text == "ROCKETS!", tip:FindFirstChild("Words").Text)
	S.advance(1.6)
	truthy(not tip.Visible, "the weapon's name stayed up")
	h.close()
	-- after the first match: no tip at all
	local h2 = Hud.match({ place = 1, total = 8, weapon = "", ammo = 0, board = {} }, nil, true)
	local tip2 = h2.gui.canvas:FindFirstChild("Tip", true)
	truthy(tip2 and not tip2.Visible, "the tip shows after the first match")
	h2.close()
end)

test("phone smash words: brief (1 s at most) and clear of the phone HUD", function()
	local SmashJuice = require("../src/shared/SmashJuice")
	local UiScreens = require("../src/shared/UiScreens")
	truthy(SmashJuice.TOUCH_SECONDS <= 1, "phone words stay " .. SmashJuice.TOUCH_SECONDS .. " s")
	for _, ph in PHONE_SIZES do
		local s = ph.safe
		local k = math.min(s[3] / 756, s[4] / 390)
		local ox = s[1] + (s[3] - 756 * k) / 2
		local w = SmashJuice.WORDS_W_TOUCH * ph.w
		for spot, at in SmashJuice.WORDS_TOUCH do
			local r = { x = (ph.w - w) / 2, y = (at.y - at.h / 2) * ph.h, w = w, h = at.h * ph.h }
			truthy(at.h * ph.h * 0.8 >= 14, `{spot} words under 14 px at {ph.name}`)
			for _, pc in UiScreens.get("matchTouch").pieces do
				if pc.name ~= "Words" then
					local b = { x = ox + pc.x * k, y = s[2] + pc.y * k, w = pc.w * k, h = pc.h * k }
					truthy(not overlap(r, b), `{spot} covers {pc.name} at {ph.name}`)
				end
			end
		end
	end
end)

-- WINDOWS' SETTINGS window: a computer's lobby has a SETTINGS gear (a phone's is in MENU)
test("a computer's lobby has a SETTINGS gear; none without it", function()
	local h =
		Hud.plot({ coins = 0, race = "SMASH!", banner = false, myCar = false, settings = true })
	local holder = h.gui.gui:FindFirstChild("Settings", true)
	truthy(holder ~= nil, "no Settings gear")
	truthy(holder and holder:FindFirstChild("Gear") ~= nil, "no button")
	local gear = holder and holder:FindFirstChild("Gear")
	truthy(gear and gear:FindFirstChild("Tooth1", true) ~= nil, "the gear icon isn't drawn")
	h.close()
	local h2 = Hud.plot({ coins = 0, race = "SMASH!", banner = false, myCar = false })
	truthy(h2.gui.gui:FindFirstChild("Settings", true) == nil, "a gear with settings off")
	h2.close()
end)

-- ===== a phone's lobby: MENU + SMASH! and the coins; the rest in the MENU window =====

local function phoneLobby()
	local h = Hud.plot({
		coins = 120,
		race = "SMASH!",
		banner = false,
		myCar = false,
		words = { Garage = "MENU" },
		icons = { Garage = "plus" },
		dots = { Garage = 2 },
		smallCoins = true,
	})
	-- as CvcScreens sets a phone's Smash lobby (PHONE_LOBBY), every tick (the tiles' rise-in puts
	-- Visible back a beat after the screen opens)
	S.advance(2)
	for _, n in { "Crates", "Shop", "League", "Jobs", "Invite", "Next", "Coach" } do
		h.api.setShown(n, false)
	end
	return h
end

local function buttonsShown(h, ph): { string }
	local s = ph.safe
	local out = {}
	for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
		if isButton(b) then
			table.insert(out, b.path)
		end
	end
	return out
end

for _, ph in PHONE_SIZES do
	test(
		"phone lobby at " .. ph.name .. ": at most 4 buttons and SMASH!, nothing in the centre",
		function()
			local h = phoneLobby()
			none(problems(h, ph))
			local shown = buttonsShown(h, ph)
			local s = ph.safe
			local mid = centre(ph)
			local inMid, area = {}, 0
			for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
				local x, y, w, hh = seen(b)
				if
					(isText(b) or isButton(b) or b.obj.BackgroundTransparency ~= 1)
					and overlap({ x = x, y = y, w = w, h = hh }, mid)
				then
					table.insert(inMid, name(b))
				end
				if b.depth == 1 then
					area += w * hh
				end
			end
			print(
				string.format(
					"       %s lobby: %d buttons (%s), UI %.1f%%, %d in the centre box",
					ph.name,
					#shown,
					table.concat(shown, " "):gsub("Ui_plot%.Canvas%.", ""),
					area / (ph.w * ph.h) * 100,
					#inMid
				)
			)
			truthy(#shown <= 5, "buttons: " .. table.concat(shown, ", "))
			truthy(string.find(table.concat(shown, " "), "Garage", 1, true) ~= nil, "no MENU tile")
			none(inMid)
			h.close()
		end
	)

	test("phone MENU window fits a " .. ph.name .. " phone", function()
		local h = Smash.menu({
			items = {
				{ id = "customize", word = "CUSTOMIZE", icon = "power" },
				{ id = "crates", word = "CRATES", icon = "crate", dot = 2 },
				{ id = "spin", word = "SPIN", icon = "gift", dot = -1 },
				{ id = "shop", word = "SHOP", icon = "bag" },
				{ id = "league", word = "LEAGUE", icon = "trophy" },
				{ id = "jobs", word = "JOBS", icon = "check" },
				{ id = "invite", word = "INVITE", icon = "heart" },
			},
		})
		S.advance(2)
		none(problems(h, ph))
		h.close()
	end)

	test("end screen at " .. ph.name .. ": prints its size", function()
		local h = Smash.matchEnd({
			place = 5,
			total = 8,
			top = { { name = "ROCKET RACCOON", smashes = 8, me = false } },
			winner = { name = "ROCKET RACCOON", smashes = 8, me = false },
			coins = 30,
			xp = 30,
			smashes = 2,
			nextAt = 10,
		})
		S.advance(3)
		local s = ph.safe
		local area = 0
		for _, b in L.boxes(h.gui.gui, s[1], s[2], s[3], s[4]) do
			if b.depth == 1 then
				local _, _, w, hh = seen(b)
				area += w * hh
			end
		end
		print(
			string.format(
				"       %s end screen: UI %.1f%% (a full screen between rounds)",
				ph.name,
				area / (ph.w * ph.h) * 100
			)
		)
		none(problems(h, ph))
		h.close()
	end)
end

test("a phone's Smash lobby hides the tiles MENU holds (CvcScreens)", function()
	local src = require("@lune/fs").readFile("src/client/CvcScreens.client.luau")
	for _, n in { "Crates", "Shop", "League", "Jobs", "Invite" } do
		local line = string.match(src, `api%.setShown%("{n}", ([^\n]*)`)
		truthy(
			line ~= nil and string.find(line, "not menu", 1, true) ~= nil,
			n .. " still shows on a phone"
		)
	end
	truthy(string.find(src, "PHONE_LOBBY then openMenu", 1, true) ~= nil, "MENU tile not wired")
	truthy(
		string.find(src, "and not PHONE", 1, true) ~= nil
			or string.find(
					require("@lune/fs").readFile("src/client/LuckySpin.client.luau"),
					"and not PHONE",
					1,
					true
				)
				~= nil,
		"SPIN tile still shows"
	)
end)
