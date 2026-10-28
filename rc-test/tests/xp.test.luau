--!strict
-- XP and levels (Smash plan, REWARDS row): match XP, the level bar, level-up coins, saves.
local H = require("./harness")
local Xp = require("../src/shared/Xp")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Xp")

test("xp: level 1 starts at 0 / 100, each level needs a bit more", function()
	local level, into, need = Xp.levelOf(0)
	eq(level, 1)
	eq(into, 0)
	eq(need, 100)
	eq(Xp.need(2), 125)
	for l = 2, 50 do
		truthy(Xp.need(l) > Xp.need(l - 1))
	end
	level, into, need = Xp.levelOf(100)
	eq(level, 2)
	eq(into, 0)
	eq(need, 125)
	level, into = Xp.levelOf(99)
	eq(level, 1)
	eq(into, 99)
end)

test("xp: a match pays for playing, each smash and a top 3 place", function()
	eq(Xp.forMatch(5, 0), Xp.MATCH)
	eq(Xp.forMatch(1, 4), Xp.MATCH + 4 * Xp.SMASH + Xp.PLACE[1])
	eq(Xp.forMatch(2, 0), Xp.MATCH + Xp.PLACE[2])
	eq(Xp.forMatch(3, 0), Xp.MATCH + Xp.PLACE[3])
	truthy(Xp.forMatch(1, 0) > Xp.forMatch(2, 0))
	truthy(Xp.forMatch(2, 0) > Xp.forMatch(3, 0))
	-- a new kid's first good match (2nd, 3 smashes) gets level 2 in one or two matches
	truthy(Xp.forMatch(2, 3) >= 50)
end)

test("xp: junk and huge numbers can't farm XP", function()
	local junk: { any } = { nil, "9", -5, 0 / 0, math.huge, -math.huge, {} }
	for _, v in junk do
		local got = Xp.forMatch(v, v)
		truthy(got >= Xp.MATCH and got <= Xp.MATCH + Xp.SMASH * Xp.SMASH_CAP + Xp.PLACE[1])
	end
	eq(Xp.forMatch(1, 1e9), Xp.MATCH + Xp.SMASH * Xp.SMASH_CAP + Xp.PLACE[1])
	local d = { xp = 0, coins = 0 }
	eq(Xp.add(d, -50).xp, 0)
	eq(Xp.add(d, 0 / 0).xp, 0)
	eq(d.xp, 0)
	eq(d.coins, 0)
end)

test("xp: a level up pays coins once per new level", function()
	local d = { xp = 90, coins = 10 }
	local g = Xp.add(d, 5)
	eq(g.from, 1)
	eq(g.to, 1)
	eq(g.coins, 0)
	eq(d.coins, 10)
	g = Xp.add(d, 5) -- 100 = level 2
	eq(g.to, 2)
	eq(g.coins, Xp.LEVEL_COINS)
	eq(d.coins, 10 + Xp.LEVEL_COINS)
	g = Xp.add(d, 125 + 150) -- two more levels at once
	eq(g.from, 2)
	eq(g.to, 4)
	eq(g.coins, 2 * Xp.LEVEL_COINS)
end)

test("xp: very big XP stops at the top level without hanging", function()
	local level = Xp.levelOf(Xp.MAX_XP)
	truthy(level >= 1 and level <= Xp.MAX_LEVEL)
	local d = { xp = Xp.MAX_XP, coins = 0 }
	Xp.add(d, 1e12)
	eq(d.xp, Xp.MAX_XP)
end)

test(
	"xp: saved with the profile; old saves start at 0; a late visit adds what it earned",
	function()
		eq(Profile.new().xp, 0)
		local old = Profile.new() :: any
		old.xp = nil
		eq(Profile.migrate(old).xp, 0)
		local raw = Profile.new() :: any
		raw.xp = 345.7
		eq(Profile.migrate(raw).xp, 345)
		raw.xp = -3
		eq(Profile.migrate(raw).xp, 0)
		raw.xp = "lots"
		eq(Profile.migrate(raw).xp, 0)
		local stored = Profile.new()
		stored.xp = 500
		local base = Profile.new()
		local session = Profile.new()
		session.xp = 120
		eq(Profile.mergeVisit(stored, session, base).xp, 620)
	end
)

test("xp: the top level's bar never overflows; Xp's coin cap is the save's", function()
	eq(Xp.MAX_COINS, Profile.MAX_COINS)
	local level, into, need = Xp.levelOf(Xp.MAX_XP)
	eq(level, Xp.MAX_LEVEL)
	truthy(into <= need)
end)

test("xp: a late visit's level-up coins come from the merged save's levels", function()
	-- stored is high up; the visit (from a blank base) went 1 -> 3 and was paid 2 levels
	local stored = Profile.new()
	stored.xp = 10000
	stored.coins = 1000
	local base = Profile.new()
	local session = Profile.new()
	Xp.add(session, 300)
	eq(session.coins, 2 * Xp.LEVEL_COINS)
	local lv0 = Xp.levelOf(10000)
	local lv1 = Xp.levelOf(10300)
	local out = Profile.mergeVisit(stored, session, base)
	eq(out.xp, 10300)
	eq(out.coins, 1000 + (lv1 - lv0) * Xp.LEVEL_COINS)
	-- a visit that earned other coins too keeps those
	stored = Profile.new()
	stored.xp = 10000
	stored.coins = 1000
	session = Profile.new()
	Xp.add(session, 300)
	session.coins += 70
	out = Profile.mergeVisit(stored, session, base)
	eq(out.coins, 1000 + 70 + (lv1 - lv0) * Xp.LEVEL_COINS)
	-- a low save that crosses more levels than the visit did gets those coins
	stored = Profile.new()
	stored.xp = 90
	session = Profile.new()
	session.xp = 50 -- no level up on the visit
	out = Profile.mergeVisit(stored, session, base)
	eq(out.xp, 140)
	eq(out.coins, Xp.LEVEL_COINS)
end)
