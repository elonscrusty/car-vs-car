--!strict
-- Hits you can feel (JUICE row, auditor Road to 9/10 items 2 and 3): which weapon a Health drop
-- was, one number per gun burst, the spawn bubble, the Studio-only slow-mo hook, plus text checks
-- on client/SmashHits.
local fs = require("@lune/fs")
local H = require("./harness")
local SmashHits = require("../src/shared/SmashHits")
local SmashJuice = require("../src/shared/SmashJuice")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Smash hits")

local SIZES = { kart = 1.375, rocket = 2.75, nuke = 11, mine = 1.25 }

local function shot(t: number, kind: string, x: number, z: number, extra: { [string]: any }?): any
	local s: { [string]: any } = { t = t, kind = kind, x = x, z = z }
	for k, v in extra or {} do
		s[k] = v
	end
	return s
end

test("smash hits: the weapon behind a Health drop", function()
	local shots = {
		shot(9.0, "GunShot", 0, 0, { owner = 5, hit = true }),
		shot(9.9, "RocketBoom", 50, 50, { owner = 6 }),
		shot(9.9, "RocketBoom", 100, 100, { owner = 7, nuke = true }),
		shot(9.95, "MineBoom", -30, 0, { owner = 8 }),
		shot(9.95, "FreezeHit", 70, 0, { owner = 9, id = -3 }),
		shot(9.95, "GunShot", 200, 0, { owner = 4, hit = false }),
	}
	local w, by = SmashHits.guess(shots, -1, 50.5, 51, 10, SIZES)
	eq(w, "rocket", "a rocket boom next to it")
	eq(by, 6)
	w, by = SmashHits.guess(shots, -1, 105, 100, 10, SIZES)
	eq(w, "nuke", "the nuke's big splash reaches 5 studs")
	eq(by, 7)
	eq((SmashHits.guess(shots, -1, -30.5, 0.5, 10, SIZES)), "mine")
	eq((SmashHits.guess(shots, -3, 0, 900, 10, SIZES)), "freeze", "the ice names its kart")
	eq((SmashHits.guess(shots, -1, 200, 0, 10, SIZES)), "bump", "a missed bullet is no hit")
	eq((SmashHits.guess(shots, -1, 0.2, 0, 10, SIZES)), "bump", "a bullet 1 s old is too old")
	eq((SmashHits.guess(shots, -1, 0.2, 0, 9.3, SIZES)), "gun")
	eq((SmashHits.guess(shots, 6, 50, 50, 10, SIZES)), "bump", "your own rocket never hits you")
	local by2
	w, by2 = SmashHits.guess(shots, -1, 400, 400, 10, SIZES)
	eq(w, "bump")
	eq(by2, nil)
	-- the remote and the Health can land a frame apart: a boom just after still counts
	local late = { shot(10.05, "RocketBoom", 0, 0, { owner = 2 }) }
	eq((SmashHits.guess(late, -1, 0, 0, 10, SIZES)), "bump")
	eq((SmashHits.guess(late, -1, 0, 0, 10, SIZES, SmashHits.MERGE)), "rocket")
	-- the newest wins
	local two = {
		shot(9.5, "MineBoom", 0, 0, { owner = 2 }),
		shot(9.8, "GunShot", 0, 0, { owner = 3, hit = true }),
	}
	eq((SmashHits.guess(two, -1, 0, 0, 10, SIZES)), "gun")
	SmashHits.prune(shots, 20)
	eq(#shots, 0, "old shots are dropped")
end)

test("smash hits: a gun burst adds up to one number", function()
	local p = SmashHits.add(nil, 34 / 6, 1)
	for i = 1, 5 do
		p = SmashHits.add(p, 34 / 6, 1 + 0.07 * i)
	end
	eq(SmashHits.text(p.amount), "-34")
	truthy(not SmashHits.due(p, 1.4), "still coming")
	truthy(SmashHits.due(p, 1.36 + SmashHits.MERGE), "shows once the burst ends")
	-- a long bump scrape still shows by MERGE_MAX
	local q = SmashHits.add(nil, 1, 0)
	for i = 1, 20 do
		q = SmashHits.add(q, 1, i * 0.05)
	end
	truthy(q.amount < 21, "a new number after MERGE_MAX")
	local fresh = SmashHits.add(q, 2, 5)
	eq(fresh.amount, 2, "a hit later is a new number")
	eq(SmashHits.text(0.2), "-1", "never -0")
	truthy(
		SmashHits.NUMBER_SECONDS >= 0.3 and SmashHits.FLASH_SECONDS >= 0.3,
		"on screen ≥ 0.3 s"
	)
	for _, w in { "rocket", "nuke", "gun", "mine", "freeze", "bump" } do
		truthy(SmashHits.COLORS[w] ~= nil, "a colour for " .. w)
	end
end)

test("smash hits: the bubble pops in and stays clear enough to see the kart", function()
	local s0 = SmashHits.bubble(0)
	local s1, see1 = SmashHits.bubble(1)
	truthy(s0 < s1, "grows in")
	truthy(see1 > 0.1 and see1 < 0.4, "see-through but there")
end)

test("smash hits: the slow-mo hook is Studio only", function()
	eq(SmashHits.hold(false, true), nil, "never in a live game")
	eq(SmashHits.hold(false, 3), nil)
	eq(SmashHits.hold(true, nil), nil)
	eq(SmashHits.hold(true, false), nil)
	eq(SmashHits.hold(true, true), SmashHits.HOLD)
	eq(SmashHits.hold(true, 30), 10)
	eq(SmashHits.hold(true, 0.1), 0.5)
	eq(SmashHits.hold(true, 0 / 0), nil)
	eq(SmashHits.hold(true, "yes"), nil)
end)

test("smash hits: your own hit is a smaller kick than one you take", function()
	local mine = SmashJuice.feel("myHit", 34)
	local taken = SmashJuice.feel("hit", 34)
	truthy(mine.trauma > 0 and mine.trauma < taken.trauma, "small shake")
	eq(mine.flash, 0, "no red flash for your own hit")
	eq(SmashJuice.feel("myHit", 34, true).trauma, 0, "reduced motion: no shake")
	eq(SmashJuice.feel("myHit", 0).trauma, 0)
end)

test("smash hits: client text checks", function()
	local src = fs.readFile("src/client/SmashHits.client.luau")
	truthy(string.find(src, "SmashHits.hold(studio", 1, true) ~= nil, "slow-mo gated on Studio")
	truthy(string.find(src, "local studio = RunService:IsStudio()", 1, true) ~= nil)
	truthy(string.find(src, "if studio then", 1, true) ~= nil, "the Sfx log is Studio only")
	truthy(string.find(src, '"[Sfx] " .. name', 1, true) ~= nil, "each cue is logged")
	truthy(string.find(src, "SmashFx.boom(at)", 1, true) ~= nil, "booms shake you")
	truthy(string.find(src, "SmashFx.myHit(", 1, true) ~= nil, "your hit shakes you")
	truthy(string.find(src, "Sfx.bump(", 1, true) ~= nil, "bumps are heard")
	truthy(string.find(src, "Sfx.hit(pos)", 1, true) ~= nil, "others' hits are heard")
	truthy(string.find(src, "Match.SHIELD", 1, true) ~= nil, "the bots' bubble lasts the shield")
	truthy(string.find(src, ":FireServer", 1, true) == nil, "looks only: never tells the server")
	for _, locked in { "RCCar", "ChaseCamera", "Controls", "Tuning", "CarMath" } do
		truthy(
			string.find(src, '"' .. locked .. '"', 1, true) == nil,
			"driving stays locked: " .. locked
		)
	end
	local fx = fs.readFile("src/client/SmashFx.luau")
	truthy(string.find(fx, "[SmashFx] back in %.1f s", 1, true) ~= nil, "the back-in log")
	truthy(string.find(fx, "[SmashFx] shown in %d ms: %s", 1, true) ~= nil, "the words log")
end)
