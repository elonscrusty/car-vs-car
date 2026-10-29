--!strict
-- Smash between-rounds screen and how-to (WINDOWS): MatchResult is read safely, the words are
-- right, the count follows the server's next round, and the layout keeps the phone rules.
local H = require("./harness")
local MatchEnd = require("../src/shared/MatchEnd")
local SmashScreens = require("../src/shared/SmashScreens")
local UiScreens = require("../src/shared/UiScreens")
local UiTheme = require("../src/shared/UiTheme")

local test, eq, truthy = H.test, H.eq, H.truthy

print("SmashScreens")

local ME = 42

local function places()
	return {
		{ name = "Pepper", smashes = 10 },
		{ name = "carter", smashes = 9, userId = ME, carId = "zoomer" },
		{ name = "Sprout", smashes = 1 },
		{ name = "Blaze", smashes = 0 },
		{ name = "Skid", smashes = 0, userId = 7 },
	}
end

test("MatchResult: winner, top 3, my place, coins and xp", function()
	local pl, coins, nextAt, xp = MatchEnd.args(places(), 120, 1000, 60)
	local v = MatchEnd.read(pl, coins, nextAt, xp, ME)
	eq(v.total, 5)
	eq(#v.top, 3)
	eq(v.place, 2)
	eq(v.smashes, 9)
	eq(v.coins, 120)
	eq(v.xp, 60)
	eq(v.nextAt, 1000)
	eq(v.top[2].me, true)
	eq(v.top[1].me, false)
	eq(MatchEnd.winWords(v), "PEPPER WINS")
	eq(MatchEnd.placeWords(v.place, v.total), "2ND / 5")
end)

test("I won: YOU WIN!", function()
	local list = places()
	list[1].userId = ME
	list[2].userId = nil
	local v = MatchEnd.read(list, 50, nil, nil, ME)
	eq(MatchEnd.winWords(v), "YOU WIN!")
	eq(v.place, 1)
	eq(v.xp, 0)
end)

test("junk from the wire never errors and shows nothing odd", function()
	for _, junk in { nil :: any, 5, "x", { 1, 2 }, { { name = 3, smashes = "lots" } }, { {} } } do
		local v = MatchEnd.read(junk, "coins", 0 / 0, -5, ME)
		eq(v.coins, 0)
		eq(v.xp, 0)
		eq(v.nextAt, nil)
		eq(v.place, 0)
		for _, r in v.top do
			eq(type(r.name), "string")
			truthy(r.smashes >= 0)
		end
	end
	local long = { { name = string.rep("A", 80) .. "\n", smashes = 1e12 } }
	local v = MatchEnd.read(long, 1, nil, nil, ME)
	truthy(#v.top[1].name <= MatchEnd.MAX_NAME)
	eq(v.top[1].smashes, 9999)
	-- cut by letters: 25 two-byte letters -> 20 letters, still real text
	local accents = MatchEnd.read({ { name = string.rep("é", 25), smashes = 0 } }, 0, nil, nil, ME)
	eq(utf8.len(accents.top[1].name), MatchEnd.MAX_NAME)
	eq(MatchEnd.read({ { name = "\255\254", smashes = 0 } }, 0, nil, nil, ME).top[1].name, "?")
	eq(MatchEnd.winWords(MatchEnd.read({}, 0, nil, nil, ME)), "")
end)

test("at most 12 rows are read or sent", function()
	local big = {}
	for i = 1, 40 do
		big[i] = { name = "Bot" .. i, smashes = 0 }
	end
	eq(#(MatchEnd.args(big, 0)), MatchEnd.MAX_ROWS)
	eq(MatchEnd.read(big, 0, nil, nil, ME).total, MatchEnd.MAX_ROWS)
end)

test("the count: follows the server's next round, else 12 s; never below 0 or above 60", function()
	local v = MatchEnd.read(places(), 0, 112, nil, ME)
	eq(MatchEnd.left(v, 100, 100), 12)
	eq(MatchEnd.left(v, 100, 111.2), 1)
	eq(MatchEnd.left(v, 100, 130), 0)
	local far = MatchEnd.read(places(), 0, 1e9, nil, ME)
	eq(MatchEnd.left(far, 0, 0), 60)
	eq(MatchEnd.left(far, 0, 61), 0) -- a junk far-off round can't hold the screen up
	eq(MatchEnd.left(MatchEnd.read(places(), 0, math.huge, nil, ME), 0, 61), 0)
	local none = MatchEnd.read(places(), 0, nil, nil, ME)
	eq(MatchEnd.left(none, 50, 50), MatchEnd.AUTO)
	eq(MatchEnd.left(none, 50, 55.5), 7)
	eq(MatchEnd.countWords(12), "NEW ROUND STARTING IN 12")
	eq(MatchEnd.countWords(0), "GO!")
	eq(MatchEnd.smashWords(1), "1 SMASH")
	eq(MatchEnd.smashWords(3), "3 SMASHES")
	eq(MatchEnd.placeWords(11, 12), "11TH / 12")
	eq(MatchEnd.placeWords(3, 12), "3RD / 12")
end)

test(
	"layout: inside the safe area, stick corner free while driving, buttons to the rules",
	function()
		local stick = UiScreens.stickZone()
		for _, s in SmashScreens.LIST do
			local mains = 0
			for _, p in s.pieces do
				local where = `{s.id}.{p.name}`
				truthy(p.x >= 0 and p.y >= 0, where .. " starts outside")
				truthy(p.x + p.w <= UiScreens.W and p.y + p.h <= UiScreens.H, where .. " runs out")
				UiScreens.anchor(p)
				if s.gameplay then
					truthy(not UiScreens.overlap(p, stick), where .. " sits on the move stick")
				end
				if p.tone then
					truthy(UiTheme.TONES[p.tone], where .. " tone")
					eq(p.text, string.upper(p.text or ""), where .. " not ALL CAPS")
				end
				if p.tone or p.tap then
					truthy(p.w >= 44 and p.h >= 44, where .. " too small to tap")
				end
				if p.main then
					mains += 1
				end
			end
			truthy(mains <= 1, s.id .. " has more than one main action")
		end
		-- nothing on the between-rounds screen covers anything else
		local ps = SmashScreens.get("matchEnd").pieces
		for i = 1, #ps do
			for j = i + 1, #ps do
				truthy(not UiScreens.overlap(ps[i], ps[j]), `{ps[i].name} covers {ps[j].name}`)
			end
		end
	end
)

test("match HUD: nothing covers anything else, the flash words (STUCK...) included", function()
	local ps = UiScreens.get("match").pieces
	truthy(UiScreens.piece("match", "Words") ~= nil, "no spot for the flash words")
	for i = 1, #ps do
		for j = i + 1, #ps do
			truthy(
				not UiScreens.overlap(ps[i], ps[j]),
				`match.{ps[i].name} covers match.{ps[j].name}`
			)
		end
	end
	-- (client/Hud puts its flash words there in a match: they sat on the health bar, Studio round 5)
	local src = require("@lune/fs").readFile("src/client/Hud.luau")
	truthy(string.find(src, 'UiScreens.piece("match", "Words")', 1, true) ~= nil, "flash not moved")
end)

test("how-to tips never cover the match HUD (board, feed, clock, health, FIRE)", function()
	for _, tip in SmashScreens.get("howTo").pieces do
		for _, hud in UiScreens.get("match").pieces do
			truthy(not UiScreens.overlap(tip, hud), `howTo.{tip.name} covers match.{hud.name}`)
		end
	end
end)

test("how-to tips and arrows stay out of the middle third (the road ahead)", function()
	for _, tip in SmashScreens.get("howTo").pieces do
		truthy(tip.x + tip.w <= 252 or tip.x >= 504, `howTo.{tip.name} sits in the middle`)
	end
end)

test("Smash crate words: no training, racing or stats", function()
	for key, words in SmashScreens.WORDS do
		local low = string.lower(words)
		for _, bad in { "train", "race", "racing", "coach", "spd", "speed", "stat", "car " } do
			truthy(not low:find(bad, 1, true), `WORDS.{key} says "{bad}": {words}`)
		end
	end
end)

test("how-to tip ends well above the FIRE / gas circle", function()
	local tip = SmashScreens.piece("howTo", "Tip")
	local fire = UiScreens.piece("match", "Fire")
	truthy(tip.y + tip.h <= fire.y - 50, "the tip sits on the FIRE circle")
end)

test("a 3D kart fills ~70% of its view's width and never runs off the top", function()
	-- (what the camera sees across at that distance: 2 d tan(fov/2) high, times aspect wide)
	local function seen(w: number, h: number, l: number, aspect: number): (number, number)
		local d = SmashScreens.kartDistance(w, h, l, 30, aspect, SmashScreens.KART_FILL)
		local tanV = math.tan(math.rad(15))
		local r = math.sqrt(w * w + l * l) / 2
		return r / (d * tanV * aspect), (h / 2) / (d * tanV)
	end
	-- a kart (about 4 wide, 2.5 high, 6 long) on a wide card spot and on the round-over stage
	for _, aspect in { 1.37, 1.85 } do
		local across, up = seen(4, 2.5, 6, aspect)
		truthy(
			math.abs(across - SmashScreens.KART_FILL) < 0.001,
			`fills {across} across at {aspect}`
		)
		truthy(up <= 0.85 + 1e-6, `runs off the top at {aspect}`)
	end
	-- a tall thin view: the height wins, so it still fits (and is narrower than 70%)
	local across, up = seen(4, 2.5, 6, 0.4)
	truthy(up <= 0.85 + 1e-6 and across <= SmashScreens.KART_FILL + 1e-6)
	-- a bigger kart stands further back but looks the same size
	local a1 = seen(4, 2.5, 6, 1.5)
	local a2 = seen(8, 5, 12, 1.5)
	truthy(math.abs(a1 - a2) < 0.001)
	truthy(SmashScreens.KART_FILL >= 0.6 and SmashScreens.KART_FILL <= 0.8)
end)

test("how-to: TAP FIRE! shows only with a weapon", function()
	eq(SmashScreens.cardFor(3, ""), 0)
	eq(SmashScreens.cardFor(3, "Rockets"), 3)
	eq(SmashScreens.cardFor(2, ""), 2)
	eq(SmashScreens.cardFor(1, ""), 1)
end)

test("how-to: drive, grab, fire; doing a later thing first skips ahead", function()
	eq(#SmashScreens.STEPS, 3)
	local none = { moved = 0, weapon = "", fired = false }
	eq(SmashScreens.step(1, none), 1)
	eq(SmashScreens.step(1, { moved = 20, weapon = "", fired = false }), 2)
	eq(SmashScreens.step(2, { moved = 0, weapon = "", fired = false }), 2)
	eq(SmashScreens.step(1, { moved = 0, weapon = "Rockets", fired = false }), 3)
	eq(SmashScreens.step(3, { moved = 0, weapon = "Rockets", fired = false }), 3)
	eq(SmashScreens.step(1, { moved = 0, weapon = "", fired = true }), 4)
	eq(SmashScreens.step(4, none), 4)
	for _, st in SmashScreens.STEPS do
		eq(st.words, string.upper(st.words))
		if st.arrow then
			truthy(SmashScreens.piece("howTo", st.arrow))
		end
	end
end)

test("customize: EQUIP works only on an owned thing that isn't on yet", function()
	eq(select(1, SmashScreens.equipButton({ own = true, on = false })), "EQUIP")
	eq(select(2, SmashScreens.equipButton({ own = true, on = false })), true)
	eq(select(1, SmashScreens.equipButton({ own = true, on = true })), "ON")
	eq(select(2, SmashScreens.equipButton({ own = true, on = true })), false)
	eq(select(1, SmashScreens.equipButton({ own = false })), "LOCKED")
	eq(select(2, SmashScreens.equipButton({ own = false })), false)
	eq(select(2, SmashScreens.equipButton(nil)), false)
	eq(select(1, SmashScreens.equipButton({ own = true, on = true }, true)), "TAKE OFF")
	eq(select(2, SmashScreens.equipButton({ own = true, on = true }, true)), true)
	-- the window keeps the phone rules (title, X and slab room)
	local w = SmashScreens.piece("customize", "Window")
	truthy(w.y >= UiScreens.WINDOW_TOP and w.x >= UiScreens.WINDOW_LEFT)
	truthy(w.x + w.w + UiScreens.WINDOW_RIGHT <= UiScreens.W)
	for _, q in w.inner or {} do
		truthy(
			q.x >= 0 and q.y >= 0 and q.x + q.w <= w.w and q.y + q.h <= w.h,
			q.name .. " runs out of its window"
		)
	end
	truthy(not UiScreens.overlap(w, SmashScreens.piece("customize", "Card")))
end)

-- ===== audit round 6 =====

test("R6-4: GRAB A ? only in the first 15 s of the tips, then TAP FIRE! waits for a box", function()
	local none = { moved = 0, weapon = "", fired = false }
	eq(SmashScreens.step(2, { moved = 0, weapon = "", fired = false, secs = 5 }), 2)
	eq(SmashScreens.step(2, { moved = 0, weapon = "", fired = false, secs = 15 }), 3)
	eq(SmashScreens.step(2, { moved = 0, weapon = "", fired = false, secs = 60 }), 3)
	eq(
		SmashScreens.cardFor(
			SmashScreens.step(2, { moved = 0, weapon = "", fired = false, secs = 60 }),
			""
		),
		0
	)
	eq(SmashScreens.step(2, none), 2) -- (no clock: as before)
	truthy(
		string.find(
			require("@lune/fs").readFile("src/client/SmashHowTo.client.luau"),
			"secs = ",
			1,
			true
		) ~= nil,
		"the how-to never passes the time"
	)
end)

test(
	"R6-4: the how-to tip sits fully on screen with room to spare, small phone included",
	function()
		local tip = SmashScreens.piece("howTo", "Tip")
		truthy(tip.x + tip.w <= UiScreens.W - 16, "the tip touches the right edge")
		-- (Base.place: anchor point at its scale spot, the box fit to the piece's shape)
		for _, s in { { 667, 375 }, { 844, 390 }, { 1914, 753 } } do
			local sw, sh = s[1], s[2] - 58 -- (under the top bar)
			local bw, bh = tip.w / UiScreens.W * sw, tip.h / UiScreens.H * sh
			local ratio = tip.w / tip.h
			if bw / bh > ratio then
				bw = bh * ratio
			else
				bh = bw / ratio
			end
			local right = (tip.x + tip.w) / UiScreens.W * sw -- (anchor r: the right edge holds)
			truthy(right <= sw and right - bw >= 0, `tip off a {s[1]}x{s[2]} screen`)
			truthy(sw - right >= 8, `tip flush with the edge at {s[1]}x{s[2]}`)
		end
	end
)

test("R6-3: the place chip is never blank: GO SMASH! before your first smash", function()
	local src = require("@lune/fs").readFile("src/client/Ui/Screens/Hud.luau")
	truthy(string.find(src, '"GO SMASH!"', 1, true) ~= nil, "no GO SMASH! in the place chip")
	truthy(string.find(src, "placeSpot.Visible = smashes", 1, true) == nil, "the chip still hides")
end)

test("R6-2: stuck in Smash says OOPS! FLIPPING YOU BACK (no race words)", function()
	local src = require("@lune/fs").readFile("src/client/Main.client.luau")
	truthy(string.find(src, '"OOPS! FLIPPING YOU BACK"', 1, true) ~= nil, "still race words")
end)

test("Studio round 6: GO SMASH!'s drop hides with it; no car name bar in Smash", function()
	local fs = require("@lune/fs")
	local hud = fs.readFile("src/client/Ui/Screens/Hud.luau")
	truthy(string.find(hud, 'FindFirstChild(l.Name .. "Drop")', 1, true) ~= nil, "drop left behind")
	local screens = fs.readFile("src/client/CvcScreens.client.luau")
	truthy(string.find(screens, "if SMASH or not car then", 1, true) ~= nil, "BOLT bar in Smash")
end)

test("R7-6: the place chip and the board agree, ties share a place", function()
	-- (the kid on 1 smash tied with two others behind two leaders: 3RD on both, never 5)
	local list = {
		{ name = "A", smashes = 4 },
		{ name = "B", smashes = 2 },
		{ name = "C", smashes = 1 },
		{ name = "D", smashes = 1 },
		{ name = "ME", smashes = 1, me = true },
		{ name = "E", smashes = 0 },
	}
	local mine = SmashScreens.rank(list)
	eq(mine, 3)
	eq(list[5].rank, 3, "the board row says the same as the chip")
	eq(list[3].rank, 3)
	eq(list[1].rank, 1)
	eq(list[6].rank, 6)
	eq(SmashScreens.rank({ { name = "X", smashes = 2 } }), nil, "not on the board")
	local fs = require("@lune/fs")
	local mh = fs.readFile("src/client/MatchHud.client.luau")
	truthy(
		string.find(mh, 'num("Place", 1), karts()', 1, true) == nil,
		"the chip reads Place again"
	)
	truthy(string.find(mh, "SmashScreens.rank(list)", 1, true) ~= nil, "the board has no ranks")
	local hud = fs.readFile("src/client/Ui/Screens/Hud.luau")
	truthy(string.find(hud, "row.rank = e.rank or i", 1, true) ~= nil, "board rows ignore the rank")
end)

test(
	"MatchResult: the server's shared place wins over the row number (ties, no smashes)",
	function()
		local tied = {
			{ name = "Pepper", smashes = 3, place = 1 },
			{ name = "Me", smashes = 3, place = 1, userId = ME },
			{ name = "Skid", smashes = 0, place = 0 },
		}
		local v = MatchEnd.read(tied, 0, nil, nil, ME)
		eq(v.place, 1, "tied for 1st, not 2nd")
		eq(MatchEnd.placeWords(v.place, v.total), "1ST / 3")
		local noneRows = {
			{ name = "A", smashes = 2, place = 1 },
			{ name = "Me", smashes = 0, place = 0, userId = ME },
		}
		local none = MatchEnd.read(noneRows, 0, nil, nil, ME)
		eq(MatchEnd.placeWords(none.place, none.total), "- / 2", "no smashes: no place")
		local junkRows = { { name = "Me", smashes = 1, place = 1e9, userId = ME } }
		local junk = MatchEnd.read(junkRows, 0, nil, nil, ME)
		eq(junk.place, 1, "a junk place falls back to the row")
	end
)

test("R8-4: the DRIVE! card sits by the stick, out of the road ahead, for 3 s at most", function()
	eq(SmashScreens.STEPS[1].id, "drive")
	local tip = SmashScreens.piece("howTo", SmashScreens.STEPS[1].tip or "Tip")
	truthy(tip.name == "TipDrive", "DRIVE! still uses the right-hand tip")
	truthy(tip.x + tip.w <= 252, "the DRIVE! card is in the middle third")
	truthy(tip.x < 100, "the DRIVE! card isn't on the left by the stick")
	truthy(not UiScreens.overlap(tip, UiScreens.stickZone()), "the DRIVE! card sits on the stick")
	for _, hud in UiScreens.get("match").pieces do
		truthy(not UiScreens.overlap(tip, hud), `DRIVE! covers match.{hud.name}`)
	end
	local src = require("@lune/fs").readFile("src/client/SmashHowTo.client.luau")
	local secs = tonumber(string.match(src, "local DRIVE_SECS = (%d+)"))
	truthy(secs ~= nil and secs <= 3, "DRIVE! stays more than 3 s")
end)
