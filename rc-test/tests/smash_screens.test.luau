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
