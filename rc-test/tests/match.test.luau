--!strict
-- Match: the Smash round's rules (health, smash, respawn + shield, spawns, places, coins, bumps).
local H = require("./harness")
local Match = require("../src/shared/Match")

local test, eq, truthy = H.test, H.eq, H.truthy

local function round(n: number?): Match.State
	local m = Match.new(0)
	for i = 1, n or 2 do
		Match.add(m, i, `P{i}`, true, 0)
	end
	return m
end

test("Match: 3 hits smash a kart, the attacker scores, junk does nothing", function()
	local m = round(2)
	local now = Match.SHIELD + 1
	eq(select(1, Match.damage(m, 2, 1, Match.HIT, now)), Match.HIT)
	eq(m.karts[2].health, Match.HEALTH - Match.HIT)
	Match.damage(m, 2, 1, Match.HIT, now)
	local took, smashed = Match.damage(m, 2, 1, Match.HIT, now)
	truthy(smashed, "the third hit smashes")
	eq(took, Match.HEALTH - 2 * Match.HIT)
	eq(m.karts[1].smashes, 1)
	eq(m.karts[2].deaths, 1)
	eq(m.karts[2].lastBy, 1)
	truthy(not m.karts[2].alive, "smashed")
	-- a smashed kart can't be hit again
	eq(select(1, Match.damage(m, 2, 1, Match.HIT, now)), 0)
	for _, junk in { 0 / 0, math.huge, -5, 0 } do
		eq(select(1, Match.damage(m, 1, 2, junk, now)), 0)
	end
	eq(select(1, Match.damage(m, 99, 1, 10, now)), 0)
end)

test("Match: the shield blocks hits; respawn after 3 s with a fresh shield", function()
	local m = round(2)
	eq(select(1, Match.damage(m, 2, 1, Match.HIT, Match.SHIELD - 0.1)), 0)
	local t = Match.SHIELD + 0.5
	for _ = 1, 3 do
		Match.damage(m, 2, 1, Match.HIT, t)
	end
	eq(#Match.due(m, t + Match.RESPAWN - 0.1), 0)
	local due = Match.due(m, t + Match.RESPAWN)
	eq(#due, 1)
	eq(due[1].id, 2)
	local back = t + Match.RESPAWN
	Match.respawn(m, 2, back)
	eq(m.karts[2].health, Match.HEALTH)
	truthy(m.karts[2].alive and Match.shielded(m.karts[2], back + 1.9), "bubble on")
	eq(select(1, Match.damage(m, 2, 1, 10, back + 1)), 0)
	truthy(select(1, Match.damage(m, 2, 1, 10, back + Match.SHIELD)) > 0, "bubble gone")
end)

test("Match: own hits hurt but score nobody; nothing counts after the clock", function()
	local m = round(2)
	local now = 5
	for _ = 1, 3 do
		Match.damage(m, 1, 1, Match.HIT, now, "Mine")
	end
	truthy(not m.karts[1].alive, "own mine smashed it")
	eq(m.karts[1].smashes, 0)
	eq(m.karts[1].lastBy, nil)
	eq(select(1, Match.damage(m, 2, 1, 10, Match.LENGTH)), 0)
	m.over = true
	eq(select(1, Match.damage(m, 2, 1, 10, 10)), 0)
end)

test("Match: at most 8 karts, no doubles, remove frees a seat", function()
	local m = Match.new(0)
	for i = 1, 10 do
		Match.add(m, -i, `Bot{i}`, false, 0)
	end
	eq(#m.list, Match.MAX)
	eq(Match.add(m, -1, "again", false, 0), nil)
	Match.remove(m, -3)
	eq(#m.list, Match.MAX - 1)
	truthy(Match.add(m, 7, "Kid", true, 0) ~= nil, "a seat again")
end)

test("Match: respawn spot is the free one farthest from enemies", function()
	local spawns = { { x = 0, z = 0 }, { x = 50, z = 0 }, { x = 100, z = 0 } }
	eq(Match.pickSpawn(spawns, { { x = 0, z = 0 } }), 3)
	eq(Match.pickSpawn(spawns, { { x = 100, z = 0 } }), 1)
	eq(Match.pickSpawn(spawns, { { x = 0, z = 0 }, { x = 100, z = 0 } }), 2)
	eq(Match.pickSpawn(spawns, { { x = 0, z = 0 } }, { [3] = true }), 2)
	eq(Match.pickSpawn(spawns, { { x = 0, z = 0 } }, { [1] = true, [2] = true, [3] = true }), 3)
	eq(Match.pickSpawn(spawns, {}), 1)
end)

test("Match: places by smashes, then fewest deaths, then join order; coins", function()
	local m = round(4)
	local now = 5
	local function smash(v: number, a: number)
		for _ = 1, 3 do
			Match.damage(m, v, a, Match.HIT, now)
		end
		Match.respawn(m, v, now - Match.SHIELD) -- (back with no bubble, for the test)
	end
	smash(1, 3)
	smash(2, 3)
	smash(1, 4)
	local p = Match.places(m)
	eq(p[1].id, 3)
	eq(p[2].id, 4)
	eq(p[3].id, 2) -- 0 smashes, 1 death
	eq(p[4].id, 1) -- 0 smashes, 2 deaths
	eq(Match.placeOf(m, 3), 1)
	eq(Match.placeOf(m, 99), 0)
	eq(Match.coinsFor(1, 2), Match.PLACE_COINS[1] + 2 * Match.SMASH_COINS)
	eq(Match.coinsFor(3, 0), Match.PLACE_COINS[3])
	eq(Match.coinsFor(7, 1), Match.PLAY_COINS + Match.SMASH_COINS)
	eq(Match.coinsFor(0, 0), 0)
end)

test("Match: bumps hurt by speed into the other kart, once per pair per cooldown", function()
	local m = round(2)
	local now = 5
	local a, b = { x = 0, z = 0 }, { x = 1, z = 0 }
	local still = { x = 0, z = 0 }
	-- a slow nudge does nothing
	local toB, toA = Match.ram(m, 1, a, { x = 3, z = 0 }, 2, b, still, now)
	eq(toB + toA, 0)
	-- full speed into a parked kart: one whole hit to it, none back
	toB, toA = Match.ram(m, 1, a, { x = 30, z = 0 }, 2, b, still, now)
	eq(toB, Match.HIT)
	eq(toA, 0)
	-- the same pair straight away: nothing (one touch, not 30 a second)
	toB, toA = Match.ram(m, 2, b, still, 1, a, { x = 30, z = 0 }, now + 0.1)
	eq(toB + toA, 0)
	-- head-on later: both hurt (b's speed toward a is what hurts a)
	toB, toA = Match.ram(m, 1, a, { x = 14, z = 0 }, 2, b, { x = -14, z = 0 }, now + 1)
	truthy(toB > 0 and toA > 0 and toB == toA, "head-on hurts both")
	-- apart: nothing
	toB, toA = Match.ram(m, 1, a, { x = 30, z = 0 }, 2, { x = 9, z = 0 }, still, now + 5)
	eq(toB + toA, 0)
	eq(Match.ramDamage(0 / 0), 0)
end)

test("Match: a whole round with 8 karts plays out to places and coins", function()
	local m = Match.new(0)
	for i = 1, Match.MAX do
		Match.add(m, if i == 1 then 1 else -i, `K{i}`, i == 1, 0)
	end
	-- every second, the kid hits the next kart (that isn't shielded); respawns run as they come due
	local smashes = 0
	for t = 0, Match.LENGTH - 1, 0.5 do
		for _, k in Match.due(m, t) do
			Match.respawn(m, k.id, t)
		end
		for _, k in m.list do
			if k.id ~= 1 and Match.hittable(m, k.id, t) then
				local _, smashed = Match.damage(m, k.id, 1, Match.HIT, t, "rocket")
				if smashed then
					smashes += 1
				end
				break
			end
		end
	end
	truthy(smashes > 10, "lots of smashes in 3:00")
	eq(m.karts[1].smashes, smashes)
	eq(select(1, Match.damage(m, -2, 1, Match.HIT, Match.LENGTH)), 0)
	local p = Match.places(m)
	eq(#p, Match.MAX)
	eq(p[1].id, 1)
	eq(Match.coinsFor(1, p[1].smashes), Match.PLACE_COINS[1] + smashes * Match.SMASH_COINS)
end)

test("LobbyLayout: the arena's slot comes after the race maps (when it's built)", function()
	local LobbyLayout = require("../src/shared/LobbyLayout")
	local RaceMaps = require("../src/shared/RaceMaps")
	local i = LobbyLayout.arenaIndex()
	if i then
		eq(i, #LobbyLayout.slots() + #RaceMaps.list() + 1)
		eq(LobbyLayout.track(i).map, "arena")
	end
	-- the race maps keep their own slots
	eq(LobbyLayout.mapAt(LobbyLayout.mapIndex(1)), RaceMaps.list()[1])
	-- then the warm-up yard (WarmupYard), then nothing
	eq(LobbyLayout.mapAt(#LobbyLayout.slots() + #RaceMaps.list() + 2).id, "yard")
	eq(LobbyLayout.yardIndex(), #LobbyLayout.slots() + #RaceMaps.list() + 2)
	eq(LobbyLayout.mapAt(#LobbyLayout.slots() + #RaceMaps.list() + 3), nil)
end)

test("Match: bot names come from a fixed pool, shuffled, never 'Bot 28'", function()
	local i = 0
	local names = Match.botNames(function(n: number): number
		i += 1
		return (i % n) + 1
	end)
	eq(#names, #Match.BOT_NAMES)
	local seen = {}
	for _, n in names do
		truthy(table.find(Match.BOT_NAMES, n) ~= nil and not seen[n], n)
		seen[n] = true
	end
	truthy(#Match.BOT_NAMES >= Match.MAX - 1, "enough for 7 bots")
end)

test("Match: new-kid safety, bots see a first-round kid as shielded for 15 s", function()
	local list = {
		{ id = 1, pos = { x = 0 }, alive = true, shield = false, human = true },
		{ id = 2, pos = { x = 0 }, alive = true, shield = false, human = true },
		{ id = -1, pos = { x = 0 }, alive = true, shield = false, human = false },
		{ id = -2, pos = nil, alive = true, shield = false, human = false },
	}
	local new = { [1] = true }
	local early = Match.forBots(list :: any, new, 100 + Match.NEW_KID_SAFE - 1, 100)
	eq(#early, 3) -- (no place: left out)
	eq(early[1].shield, true) -- the new kid
	eq(early[2].shield, false) -- an old hand
	eq(early[3].shield, false)
	local later = Match.forBots(list :: any, new, 100 + Match.NEW_KID_SAFE, 100)
	eq(later[1].shield, false)
	-- and the bots really leave a shielded kid alone (ArenaBrain never picks one)
	local ArenaBrain = require("../src/shared/ArenaBrain")
	local function shots(shield: boolean): number
		local bot = ArenaBrain.new(-1, 0, 0, 0, { skill = 1 }, ArenaBrain.rng(7))
		local world = {
			half = 170,
			solids = {},
			boxes = {},
			karts = {
				{ id = -1, x = 0, z = 0, alive = true },
				{ id = 1, x = 0, z = -20, alive = true, shield = shield, human = true },
			},
		}
		local n = 0
		for f = 1, 300 do
			local s = ArenaBrain.step(bot, world :: any, 1 / 30, f / 30, "rocket", 3, {})
			if s.fire then
				n += 1
			end
		end
		return n
	end
	eq(shots(true), 0)
	truthy(shots(false) > 0, "fires at a kid once the 15 s are up")
end)

test('Match: no smashes yet = Place 0 (the HUD\'s "-"), shared by everyone on 0', function()
	local m = Match.new(0)
	Match.add(m, 1, "a", true, 0)
	Match.add(m, 2, "b", true, 0)
	Match.add(m, 3, "c", true, 0)
	for i, k in Match.places(m) do
		eq(Match.shownPlace(k, i), 0)
	end
	for _ = 1, 3 do
		Match.damage(m, 2, 3, Match.HIT, 5)
	end
	local shown = {}
	for i, k in Match.places(m) do
		shown[k.id] = Match.shownPlace(k, i)
	end
	eq(shown[3], 1)
	eq(shown[1], 0)
	eq(shown[2], 0)
end)
