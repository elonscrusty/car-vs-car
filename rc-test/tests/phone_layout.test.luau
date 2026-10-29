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
	local row2 = board and board:FindFirstChild("Row2")
	truthy(row2 and row2:FindFirstChild("Level"), "no board badge for a level 12 kart")
	local row3 = board and board:FindFirstChild("Row3")
	truthy(row3 and row3:FindFirstChild("Level") == nil, "a badge with no level")
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
