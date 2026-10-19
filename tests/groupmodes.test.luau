--!strict
-- Audit fixes for the many-car modes: soccer stats / own goals / pads / sudden death, tag first IT and
-- short rounds, race stuck / reset / checkpoint text / places / start order, group results.
local Harness = require("./harness")
local Modes = require("../src/shared/Modes")
local ModesConfig = require("../src/shared/ModesConfig")
local Race = require("../src/shared/Race")
local RaceTrack = require("../src/shared/RaceTrack")
local RaceConfig = require("../src/shared/RaceTrackConfig")
local SoccerBoost = require("../src/shared/SoccerBoost")
local SoccerChaos = require("../src/shared/SoccerChaos")
local SoccerOrbs = require("../src/shared/SoccerOrbs")
local BrawlRules = require("../src/shared/BrawlRules")
local SoccerField = require("../src/shared/SoccerField")
local SoccerFieldConfig = require("../src/shared/SoccerFieldConfig")
local SoccerStats = require("../src/shared/SoccerStats")
local GroupResults = require("../src/server/GroupResults")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("Group modes (audit fixes)")

----------------------------------------------------------------------------------------------
-- Soccer stats, own goals

test(
	"touches: the same car inside the cooldown counts once, the last toucher is remembered",
	function()
		local s = SoccerStats.new()
		eq(SoccerStats.touch(s, 2, 10, 0.4), true)
		eq(SoccerStats.touch(s, 2, 10.2, 0.4), false)
		eq(SoccerStats.touch(s, 2, 10.6, 0.4), true)
		eq(s.touches[2], 2)
		SoccerStats.touch(s, 5, 11, 0.4)
		eq(s.lastTouch, 5)
	end
)

test("goal is credited to the last toucher of the scoring team", function()
	local s = SoccerStats.new()
	SoccerStats.touch(s, 1, 1, 0.4) -- team 1 car touches last
	local credited, own = SoccerStats.goal(s, 2, 3) -- team 2 conceded
	eq(credited, 1)
	eq(own, 0)
	eq(s.goals[1], 1)
	eq(s.lastTouch, 0, "touch memory resets after a goal")
end)

test("own goal: flagged, credits nobody, never gives a negative bonus", function()
	local s = SoccerStats.new()
	SoccerStats.touch(s, 2, 1, 0.4) -- team 1 car
	local credited, own = SoccerStats.goal(s, 1, 3) -- team 1 conceded
	eq(credited, 0)
	eq(own, 2)
	eq(s.ownGoals[2], 1)
	eq(s.goals[2] or 0, 0)
	eq(SoccerStats.goalBonus(s.goals[2] or 0, 5), 0)
	truthy(SoccerStats.goalBonus(-3, 5) >= 0)
	eq(SoccerStats.goalBonus(2, ModesConfig.Soccer.goalCoins), 2 * ModesConfig.Soccer.goalCoins)
end)

test("goal with no touch credits nobody", function()
	local s = SoccerStats.new()
	local credited, own = SoccerStats.goal(s, 2, 3)
	eq(credited, 0)
	eq(own, 0)
end)

test("goal text names an own goal for both sides", function()
	eq(SoccerStats.goalText(1, 1, false), "GOAL!")
	eq(SoccerStats.goalText(2, 1, false), "THEY SCORED!")
	eq(SoccerStats.goalText(2, 1, true), "OWN GOAL!")
	truthy(string.find(SoccerStats.goalText(1, 1, true), "OWN GOAL", 1, true) ~= nil)
end)

test("idle time: total and longest stretch", function()
	local s = SoccerStats.new()
	for _ = 1, 10 do
		SoccerStats.idleStep(s, 3, 0.5, 0.1, 2)
	end
	SoccerStats.idleStep(s, 3, 20, 0.1, 2) -- moving: the stretch ends
	for _ = 1, 4 do
		SoccerStats.idleStep(s, 3, 0.5, 0.1, 2)
	end
	near(s.idle[3], 1.4, 1e-9)
	near(s.idleMax[3], 1.0, 1e-9)
end)

test("touching: reach = ball radius + car half + slack", function()
	truthy(SoccerStats.isTouching(10, 0, 0, 4.5, 3, 2.5))
	truthy(not SoccerStats.isTouching(11, 0, 0, 4.5, 3, 2.5))
	truthy(not SoccerStats.isTouching(8, 8, 0, 4.5, 3, 2.5)) -- diagonal and high
end)

test("summary line has one entry per car and marks humans", function()
	local s = SoccerStats.new()
	SoccerStats.touch(s, 1, 1, 0.4)
	local line = SoccerStats.summary(s, { true, false }, 2)
	truthy(string.find(line, "#1H", 1, true) ~= nil)
	truthy(string.find(line, "#2B", 1, true) ~= nil)
	truthy(string.find(line, "t1", 1, true) ~= nil)
end)

test("sudden death starts only on 0-0 at the configured time", function()
	local at = ModesConfig.Soccer.suddenDeathAt
	truthy(at > 0 and at < ModesConfig.Soccer.maxSeconds)
	truthy(SoccerStats.suddenDeathNow(0, 0, at, at, false))
	truthy(not SoccerStats.suddenDeathNow(0, 0, at - 1, at, false))
	truthy(not SoccerStats.suddenDeathNow(1, 0, at + 5, at, false))
	truthy(not SoccerStats.suddenDeathNow(0, 0, at + 5, at, true))
	truthy(not SoccerStats.suddenDeathNow(0, 0, 999, 0, false), "0 = never")
end)

----------------------------------------------------------------------------------------------
-- Boost pads

test("pads: 4 to 6, mirrored, on the field, clear of goals, start spots and the centre", function()
	local n = SoccerBoost.count()
	truthy(n >= 4 and n <= 6)
	local hx, hz = SoccerField.halfLength(), SoccerField.halfWidth()
	local spawn = SoccerField.spawnSpots(ModesConfig.Soccer.teamSize)
	for i = 1, n do
		local x, z = SoccerBoost.spot(i)
		truthy(math.abs(x) < hx - 10 and math.abs(z) < hz - 8, "pad " .. i .. " inside the field")
		eq(SoccerField.goalConceded(x, z), 0)
		truthy(x * x + z * z > SoccerFieldConfig.centerCircleRadius ^ 2, "off the ball spawn")
		for _, sp in spawn do
			truthy(
				(sp.x - x) ^ 2 + (sp.z - z) ^ 2 > 12 ^ 2,
				"pad " .. i .. " is not on a start spot"
			)
		end
		-- mirrored across the middle line (x -> -x)
		local mirrored = false
		for j = 1, n do
			local mx, mz = SoccerBoost.spot(j)
			if math.abs(mx + x) < 1e-6 and math.abs(mz - z) < 1e-6 then
				mirrored = true
			end
		end
		truthy(mirrored, "pad " .. i .. " has a mirror")
	end
end)

test("pad: a car on it takes it once, it comes back after the respawn time", function()
	local p = SoccerBoost.new()
	local x, z = SoccerBoost.spot(1)
	eq(SoccerBoost.take(p, x + 100, z, 0), 0)
	eq(SoccerBoost.take(p, x + 1, z, 0), 1)
	eq(SoccerBoost.take(p, x, z, 1), 0, "taken pads give nothing")
	truthy(not SoccerBoost.lit(p, 1, 1))
	eq(SoccerBoost.take(p, x, z, SoccerFieldConfig.boostPadRespawn + 0.1), 1)
	SoccerBoost.reset(p)
	truthy(SoccerBoost.lit(p, 1, 0))
end)

----------------------------------------------------------------------------------------------
-- Tag

test("tag: first IT is a bot when one is alive (never a human first)", function()
	local l = Modes.lastNew(6)
	local humans = { true, true, false, false, false, false }
	for k = 0, 20 do
		local it = Modes.tagFirstIt(l, humans, k / 20)
		truthy(it >= 3 and it <= 6, "got " .. it)
	end
	-- a dead bot is not picked
	Modes.lastEliminate(l, 3)
	eq(Modes.tagFirstIt(l, humans, 0), 4)
end)

test("tag: first IT falls back to a human only when no bot is alive", function()
	local l = Modes.lastNew(2)
	local it = Modes.tagFirstIt(l, { true, true }, 0.5)
	truthy(it == 1 or it == 2)
	eq(Modes.tagFirstIt(Modes.lastNew(0), {}, 0.5), 0)
end)

test("tag rounds are short and an all-out round ends", function()
	truthy(ModesConfig.Tag.maxSeconds <= 90)
	truthy(ModesConfig.Tag.firstItBot)
	truthy(ModesConfig.Tag.allOutEndSeconds > 0 and ModesConfig.Tag.allOutEndSeconds <= 5)
	local l = Modes.lastNew(4)
	local humans = { true, true, false, false }
	truthy(not Modes.allHumansOut(l, humans))
	Modes.lastEliminate(l, 1)
	truthy(not Modes.allHumansOut(l, humans))
	Modes.lastEliminate(l, 2)
	truthy(Modes.allHumansOut(l, humans))
end)

test("tag time up: the alive car nearest the middle", function()
	local l = Modes.lastNew(3)
	Modes.lastEliminate(l, 2)
	eq(Modes.tagTimeoutWinner(l, { 30, 1, 10 }, { 0, 0, 0 }), 3)
	eq(Modes.tagTimeoutWinner(Modes.lastNew(0), {}, {}), 0)
end)

test("leaving: soccer, tag and race hand the car to a bot", function()
	eq(Modes.leaverRule("soccer"), "bot")
	eq(Modes.leaverRule("tag"), "bot")
	eq(Modes.leaverRule("race"), "bot")
	eq(Modes.leaverRule("lastStanding"), "eliminate")
end)

----------------------------------------------------------------------------------------------
-- Race

test("progress: no progress counts up, a new gate or real gain resets it", function()
	local p = Race.progressNew(0)
	near(Race.progressStep(p, 0, 100, 0, 3), 0)
	near(Race.progressStep(p, 0, 99, 1, 3), 1, 1e-9, "1 stud is not progress")
	near(Race.progressStep(p, 0, 96, 2, 3), 0, 1e-9, "4 studs closer is")
	near(Race.progressStep(p, 0, 120, 5, 3), 3, 1e-9, "going backwards is none")
	near(Race.progressStep(p, 1, 120, 6, 3), 0, 1e-9, "a new gate is")
end)

test("auto reset: bots at stuckSeconds, humans at humanStuckSeconds (6 s)", function()
	local bot, human = RaceConfig.stuckSeconds, RaceConfig.humanStuckSeconds
	eq(human, 6)
	truthy(Race.shouldReset(human, true, bot, human))
	truthy(not Race.shouldReset(5.5, true, bot, human))
	truthy(Race.shouldReset(5.5, false, bot, human))
end)

test("manual reset: after 3 s without progress, rate limited", function()
	eq(RaceConfig.resetButtonSeconds, 3)
	truthy(not Race.canManualReset(2.9, 100, 3, 4))
	truthy(Race.canManualReset(3, 100, 3, 4))
	truthy(not Race.canManualReset(10, 1, 3, 4), "cooldown after the last reset")
	truthy(Race.canManualReset(10, 4, 3, 4))
	truthy(
		RaceConfig.humanStuckSeconds > RaceConfig.resetButtonSeconds,
		"button comes before the auto reset"
	)
end)

test("checkpoint text", function()
	local n = RaceTrack.count()
	eq(Race.checkpointText(2, n, 1, 3), "CHECKPOINT 1/" .. (n - 1))
	eq(Race.checkpointText(n, n, 1, 3), "CHECKPOINT " .. (n - 1) .. "/" .. (n - 1))
	eq(Race.checkpointText(1, n, 2, 3), "LAP 2/3")
end)

test("checkpoint text follows a real run round the first gate", function()
	local s = Race.new(1, 3, RaceTrack.count())
	local p = RaceTrack.point(2)
	truthy(Race.reach(s, 1, p.x, p.z, p.x, p.z, 30, 1))
	eq(Race.lastPassed(s, 1), 2)
	eq(
		Race.checkpointText(Race.lastPassed(s, 1), s.count, s.cars[1].lap, s.laps),
		"CHECKPOINT 1/" .. (s.count - 1)
	)
end)

test("place bonus: table by place, never below what is already paid", function()
	local t = ModesConfig.Race.placeCoins
	eq(#t, ModesConfig.Race.cars)
	for i = 2, #t do
		truthy(t[i] <= t[i - 1], "coins never rise with a worse place")
	end
	eq(Race.placeBonus(1, t, 60), 0)
	eq(Race.placeBonus(2, t, 20), t[2] - 20)
	eq(Race.placeBonus(6, t, 20), 0)
	eq(Race.placeBonus(9, t, 20), 0, "a place past the table uses the last row")
end)

test("race places cover 1..N once for every car, finished cars first", function()
	local s = Race.new(6, 3, RaceTrack.count())
	s.cars[4].finishedAt = 50
	table.insert(s.order, 4)
	s.cars[4].passed = 30
	s.cars[2].passed = 12
	s.cars[5].passed = 20
	local pos = Race.positions(s, { 10, 10, 10, 10, 10, 10 })
	eq(pos[4], 1)
	eq(pos[5], 2)
	eq(pos[2], 3)
	local seen: { [number]: boolean } = {}
	for _, p in pos do
		seen[p] = true
	end
	for p = 1, 6 do
		truthy(seen[p], "place " .. p)
	end
end)

test("start order: front-row humans first, a veteran human sits mid pack, one slot each", function()
	local humans = { true, true, false, false, false, false }
	local front = { true, true, false, false, false, false }
	local slot = RaceTrack.startOrder(6, front, humans)
	eq(slot[1], 1)
	eq(slot[2], 2)
	local seen: { [number]: boolean } = {}
	for _, s in slot do
		truthy(not seen[s], "slot used twice")
		seen[s] = true
	end
	-- veterans: not front row any more, but not last either
	local back = RaceTrack.startOrder(6, { false, false, false, false, false, false }, humans)
	truthy(back[1] > 1 and back[1] < 6)
	truthy(back[2] > 1 and back[2] < 6)
	local seen2: { [number]: boolean } = {}
	for _, s in back do
		truthy(not seen2[s])
		seen2[s] = true
	end
	truthy(RaceTrack.humanFront(0, RaceConfig.frontRowMatches))
	truthy(not RaceTrack.humanFront(RaceConfig.frontRowMatches, RaceConfig.frontRowMatches))
end)

test("one human with 5 bots: first matches start in the first grid row", function()
	local humans = { true, false, false, false, false, false }
	local slot = RaceTrack.startOrder(6, { true, false, false, false, false, false }, humans)
	eq(slot[1], 1)
	truthy((slot[1] - 1) // RaceConfig.gridColumns == 0)
end)

test("out of the world: beyond the ground, under it, or flying", function()
	local p = RaceTrack.point(1)
	local c = RaceConfig.ceiling
	truthy(not RaceTrack.outOfWorld(p.x, 2, p.z, c))
	truthy(not RaceTrack.outOfWorld(p.x, RaceConfig.ramps[1].height + 6, p.z, c), "a jump is fine")
	truthy(RaceTrack.outOfWorld(p.x, c + 1, p.z, c))
	truthy(RaceTrack.outOfWorld(p.x, RaceConfig.fallBelow - 1, p.z, c))
	truthy(RaceTrack.outOfWorld(p.x + 5000, 2, p.z, c))
	local minX, _, minZ, _ = RaceTrack.bounds()
	truthy(not RaceTrack.outOfWorld(minX + 1, 2, minZ + 1, c))
end)

test("the whole grid is in the world", function()
	for _, sp in RaceTrack.grid(ModesConfig.Race.cars) do
		truthy(not RaceTrack.outOfWorld(sp.x, 3, sp.z, RaceConfig.ceiling))
	end
end)

----------------------------------------------------------------------------------------------
-- Results handed to the lobby

test("group results: set once, taken once, per player", function()
	local a, b = {}, {}
	GroupResults.set(a, { mode = "race", won = false, place = 2, placeOf = 6, coinsBonus = 25 })
	local r = GroupResults.take(a)
	truthy(r ~= nil)
	eq((r :: GroupResults.Result).place, 2)
	eq(GroupResults.take(a), nil, "taken once")
	eq(GroupResults.take(b), nil)
end)

test("group result attributes carry place, goals, tags and survived seconds", function()
	local attrs = GroupResults.attributes({
		mode = "tag",
		won = false,
		place = 3,
		placeOf = 6,
		survivedSeconds = 41.6,
		tags = 2,
		coinsBonus = 0,
	})
	eq(attrs.MatchPlace, 3)
	eq(attrs.MatchPlaceOf, 6)
	eq(attrs.MatchSurvived, 42)
	eq(attrs.MatchTags, 2)
	eq(attrs.MatchGoals, nil)
	local soccer = GroupResults.attributes({
		mode = "soccer",
		won = true,
		goals = 2,
		ownGoals = 1,
		coinsBonus = 10,
	})
	eq(soccer.MatchGoals, 2)
	eq(soccer.MatchOwnGoals, 1)
	eq(soccer.MatchCoinsBonus, 10)
	eq(
		GroupResults.attributes({ mode = "soccer", won = false, coinsBonus = -5 }).MatchCoinsBonus,
		0
	)
	for name in attrs do
		truthy(
			table.find(GroupResults.attributeNames, name) ~= nil,
			name .. " is cleaned up at match start"
		)
	end
end)

----------------------------------------------------------------------------------------------
-- Chaos moments (fun pass)

test("soccer chaos: first event on time, then every N seconds, kinds take turns", function()
	local cfg = ModesConfig.Soccer.Chaos
	local s = SoccerChaos.new(cfg)
	eq(SoccerChaos.step(s, cfg, cfg.firstSeconds - 0.1), nil)
	eq(SoccerChaos.step(s, cfg, cfg.firstSeconds), cfg.kinds[1])
	eq(SoccerChaos.step(s, cfg, cfg.firstSeconds + cfg.everySeconds - 0.1), nil)
	eq(SoccerChaos.step(s, cfg, cfg.firstSeconds + cfg.everySeconds), cfg.kinds[2])
end)

test("soccer chaos: first event comes before the match is half over", function()
	local cfg = ModesConfig.Soccer.Chaos
	truthy(cfg.firstSeconds < ModesConfig.Soccer.maxSeconds / 4)
	truthy(cfg.blastSpeed > 0)
end)

test(
	"super kick orbs: mirrored, on the field, taken once, come back, kick away from the car",
	function()
		local cfg = ModesConfig.Soccer.Orbs
		local hx, hz = SoccerField.halfLength(), SoccerField.halfWidth()
		for _, sp in cfg.spots do
			truthy(math.abs(sp.x) < hx - 20 and math.abs(sp.z) < hz - 8)
			local mirrored = false
			for _, o in cfg.spots do
				if o.x == -sp.x and o.z == -sp.z then
					mirrored = true
				end
			end
			truthy(mirrored, "orb has a mirror twin")
		end
		local s = SoccerOrbs.new(cfg)
		local sp = cfg.spots[1]
		eq(SoccerOrbs.take(s, cfg, sp.x, sp.z, 1), 1)
		eq(SoccerOrbs.take(s, cfg, sp.x, sp.z, 2), 0)
		eq(SoccerOrbs.take(s, cfg, sp.x, sp.z, 1 + cfg.respawn + 0.1), 1)
		local vx, vy, vz = SoccerOrbs.kick(cfg, 3, 4)
		near(vx, 0.6 * cfg.kickSpeed, 1e-6)
		near(vz, 0.8 * cfg.kickSpeed, 1e-6)
		eq(vy, cfg.kickLift)
		local ux = SoccerOrbs.kick(cfg, 0, 0)
		eq(ux, cfg.kickSpeed)
	end
)

test("brawl hits: under the limit nothing flies, harder hits launch and scatter more", function()
	local hit = ModesConfig.LastStanding.Hit
	local p0 = BrawlRules.launch(hit.from - 0.01, hit)
	eq(p0, 0)
	eq(BrawlRules.scrapCount(hit.from - 0.01, hit), 0)
	local pa, ua = BrawlRules.launch(0.5, hit)
	local pb, ub = BrawlRules.launch(1, hit)
	truthy(pa > 0 and ua > 0 and pb > pa and ub > ua)
	truthy(BrawlRules.scrapCount(1, hit) >= BrawlRules.scrapCount(0.5, hit))
	eq(BrawlRules.scrapCount(1, hit), hit.scrapMax)
	truthy(
		BrawlRules.peels(1, hit) and not BrawlRules.peels(hit.from, hit) or hit.peelFrom <= hit.from
	)
end)

test(
	"fight mode: 4 cars, flat arena, mirrored obstacles, only the fight is in the rotation",
	function()
		local ls = ModesConfig.LastStanding
		eq(ls.cars, 4)
		eq(ls.Arena.tiltDeg, 0)
		eq(ls.Arena.flatRadius, ls.Arena.rimRadius)
		for _, o in ls.Arena.obstacles do
			truthy(math.sqrt(o.x * o.x + o.z * o.z) < ls.Arena.rimRadius - 10)
			local twin = false
			for _, q in ls.Arena.obstacles do
				if q.kind == o.kind and q.x == -o.x and q.z == -o.z then
					twin = true
				end
			end
			truthy(twin, "obstacle has a mirror twin")
		end
		eq(table.concat(ModesConfig.Order, ","), "lastStanding")
	end
)

test("fight: the real fight never closes the walls (carter: no closing walls)", function()
	local full = ModesConfig.LastStanding.Arena.rimRadius
	local sh = ModesConfig.LastStanding.Shrink
	eq(BrawlRules.safeRadius(9999, full, sh), full)
	eq(ModesConfig.LastStanding.maxSeconds, 60)
end)

test("brawl rules: walls hold, then close in to the minimum (when a config asks)", function()
	local sh = { startSeconds = 40, endSeconds = 110, minRadius = 36 }
	local full = 60
	eq(BrawlRules.safeRadius(0, full, sh), full)
	eq(BrawlRules.safeRadius(sh.startSeconds, full, sh), full)
	local mid = BrawlRules.safeRadius((sh.startSeconds + sh.endSeconds) / 2, full, sh)
	truthy(mid < full and mid > sh.minRadius)
	eq(BrawlRules.safeRadius(sh.endSeconds, full, sh), sh.minRadius)
	eq(BrawlRules.safeRadius(9999, full, sh), sh.minRadius)
end)

test(
	"fight: best of 3, first to 2; after 3 rounds most wins, a tie goes to the last winner",
	function()
		local rc = ModesConfig.LastStanding.Rounds
		eq(BrawlRules.matchWinner({ [2] = 1 }, 1, rc.winsNeeded, rc.maxRounds, 2), 0)
		eq(BrawlRules.matchWinner({ [2] = 2 }, 2, rc.winsNeeded, rc.maxRounds, 2), 2)
		eq(BrawlRules.matchWinner({ [1] = 1, [3] = 1 }, 2, rc.winsNeeded, rc.maxRounds, 3), 0)
		eq(
			BrawlRules.matchWinner({ [1] = 1, [3] = 1, [4] = 1 }, 3, rc.winsNeeded, rc.maxRounds, 4),
			4
		)
		eq(BrawlRules.matchWinner({ [1] = 1, [3] = 1, [4] = 0 }, 3, 2, 3, 3), 3)
		eq(BrawlRules.matchWinner({}, 3, 2, 3, 1), 1)
	end
)

test("fight: the shield is the only item and it is a real pickup kind", function()
	local items = ModesConfig.LastStanding.Items
	eq(#items.kinds, 1)
	eq(items.kinds[1], "shield")
	truthy(items.ringMax < ModesConfig.LastStanding.Arena.rimRadius)
	truthy(items.ringMax >= items.ringMin)
end)

test("fight rewards: the winner gets big coins, a bounty beats a plain knock-out", function()
	local lc = ModesConfig.LastStanding
	truthy(lc.winBonus > lc.bountyCoins and lc.bountyCoins > lc.koCoins and lc.koCoins > 0)
	truthy(lc.creditSeconds > 0)
	local a = {}
	GroupResults.set(a, { mode = "lastStanding", won = true, kos = 3, coinsBonus = lc.winBonus })
	local r = GroupResults.take(a) :: any
	eq(GroupResults.attributes(r).MatchKos, 3)
end)

test(
	"tutorial: smash first, each step ends on its action or its timer, about 30 seconds",
	function()
		local Tutorial = require("../src/shared/Tutorial")
		truthy(Tutorial.total() >= 25 and Tutorial.total() <= 40)
		eq(Tutorial.Steps[1].id, "smash")
		local s = Tutorial.new()
		local first = Tutorial.tick(s, 0) :: any
		eq(first.id, "smash")
		eq(Tutorial.tick(s, 1), nil)
		eq(Tutorial.event(s, "boost", 2), nil) -- wrong action: stays on smash
		local second = Tutorial.event(s, "hit", 3) :: any
		eq(second.id, "boost")
		local third = Tutorial.tick(s, 3 + Tutorial.Steps[2].maxSeconds) :: any -- timer
		eq(third.id, "ability")
		local fourth = Tutorial.event(s, "special", 20) :: any
		eq(fourth.id, "fight")
		eq(Tutorial.finished(s), false)
		eq(Tutorial.tick(s, 20 + Tutorial.Steps[4].maxSeconds), nil)
		eq(Tutorial.finished(s), true)
	end
)
