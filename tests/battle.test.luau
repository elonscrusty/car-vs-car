--!strict
local H = require("./harness")
local BattleBrain = require("../src/shared/BattleBrain")
local BattleConfig = require("../src/shared/BattleConfig")
local BattleAim = require("../src/shared/BattleAim")
local BattleFeel = require("../src/shared/BattleFeel")
local BattleGuard = require("../src/shared/BattleGuard")
local BattleCrash = require("../src/shared/BattleCrash")
local BattleSpecial = require("../src/shared/BattleSpecial")
local BattleSelect = require("../src/shared/BattleSelect")
local BattleSeries = require("../src/shared/BattleSeries")
local BattleRecap = require("../src/shared/BattleRecap")
local BattleSetup = require("../src/shared/BattleSetup")
local Gacha = require("../src/shared/Gacha")
local BattleHuman = require("../src/shared/BattleHuman")
local Sim = require("./battlesim")

-- SERIES -------------------------------------------------------------------------------------
H.test("round: zero HP loses, both zero is a draw", function()
	H.eq(BattleSeries.roundOutcome(0, 150, 40, 110, false), "b")
	H.eq(BattleSeries.roundOutcome(10, 150, 0, 110, false), "a")
	H.eq(BattleSeries.roundOutcome(0, 150, 0, 110, false), "draw")
	H.eq(BattleSeries.roundOutcome(10, 150, 10, 110, false), nil, "fight goes on")
end)

H.test("round: timeout compares HP percent, equal percent is a draw", function()
	H.eq(BattleSeries.roundOutcome(75, 150, 80, 110, true), "b") -- 50% vs 73%
	H.eq(BattleSeries.roundOutcome(120, 150, 55, 110, true), "a")
	H.eq(BattleSeries.roundOutcome(75, 150, 55, 110, true), "draw") -- 50% each
end)

H.test("series: first to two wins ends early", function()
	local s = BattleSeries.new()
	BattleSeries.record(s, "a")
	H.eq(s.over, false)
	H.eq(s.round, 2)
	BattleSeries.record(s, "a")
	H.eq(s.over, true)
	H.eq(s.winner, "a")
	H.eq(BattleSeries.record(s, "b"), false, "no scoring after the end")
	H.eq(s.winsB, 0)
end)

H.test("series: after three rounds more wins takes it, equal is a draw", function()
	local s = BattleSeries.new()
	for _, o in { "a", "draw", "draw" } do
		BattleSeries.record(s, o :: any)
	end
	H.eq(s.over, true)
	H.eq(s.winner, "a")
	local d = BattleSeries.new()
	for _, o in { "a", "b", "draw" } do
		BattleSeries.record(d, o :: any)
	end
	H.eq(d.winner, "draw")
	H.eq(BattleSeries.resultFor(d, "a"), "draw")
end)

H.test("series: a drawn round uses up a round", function()
	local s = BattleSeries.new()
	BattleSeries.record(s, "draw")
	BattleSeries.record(s, "draw")
	H.eq(s.over, false)
	H.eq(s.round, 3)
	BattleSeries.record(s, "b")
	H.eq(s.winner, "b")
end)

H.test("series: forfeit gives the other side the match once", function()
	local s = BattleSeries.new()
	H.eq(BattleSeries.forfeit(s, "a"), true)
	H.eq(s.winner, "b")
	H.eq(BattleSeries.forfeit(s, "b"), false, "no second forfeit")
	H.eq(s.winner, "b")
	H.eq(BattleSeries.resultFor(s, "b"), "win")
	H.eq(BattleSeries.resultFor(s, "a"), "loss")
end)

-- SELECT -------------------------------------------------------------------------------------
H.test("select: owned fighters are usable, others locked", function()
	local ctx = { owned = { CannonVan = true }, testUnlock = false }
	H.eq(BattleSelect.access("CannonVan", ctx), "owned")
	H.eq(BattleSelect.access("RamTruck", ctx), "owned", "the free Ram Truck is always yours")
	H.eq(BattleSelect.access("SawBuggy", ctx), nil)
	H.eq(BattleSelect.access("Sedan", ctx), nil, "legacy cars are not fighters")
	H.eq(BattleSelect.access(42, ctx), nil)
end)

H.test("select: with nothing owned only the free Ram Truck is usable", function()
	local ctx = { owned = { Sedan = true }, testUnlock = false }
	H.eq(BattleSelect.access("RamTruck", ctx), "owned")
	H.eq(BattleSelect.access("CannonVan", ctx), nil)
end)

H.test("select: test unlock opens all three, owned still shows owned", function()
	local ctx = { owned = { RamTruck = true }, testUnlock = true }
	H.eq(BattleSelect.access("RamTruck", ctx), "owned")
	H.eq(BattleSelect.access("SawBuggy", ctx), "test")
	H.eq(BattleSelect.label("test"), "Test")
	H.eq(#BattleSelect.choices(ctx), 3)
end)

H.test("select: timeout uses last valid pick, then first owned, then the loaner", function()
	local ctx = { owned = { CannonVan = true, SawBuggy = true }, testUnlock = false }
	H.eq(BattleSelect.resolve("SawBuggy", ctx), "SawBuggy")
	H.eq(BattleSelect.resolve("NotACar", ctx), "CannonVan", "invalid last pick")
	H.eq(BattleSelect.resolve(nil, ctx), "CannonVan", "first in catalog order")
	H.eq(BattleSelect.resolve(nil, { owned = {}, testUnlock = false }), "RamTruck")
	H.eq(BattleSelect.resolve("CannonVan", { owned = {}, testUnlock = false }), "RamTruck")
end)

-- BRAIN: weapons -----------------------------------------------------------------------------
local function arena(): BattleBrain.Arena
	return Sim.arena()
end

H.test("ram: telegraphs 0.6 s, charges straight, 4 s cooldown", function()
	local L = BattleConfig.Fighters.RamTruck.lengthStuds
	local b = BattleBrain.new("RamTruck", L, arena())
	local me = { x = -20, z = 0, fx = 1, fz = 0 }
	local foe = { x = -20 + 2 * L, z = 0, fx = -1, fz = 0 }
	local o = b.step(0.1, me, foe, { ram = false, saw = false })
	H.eq(o.state, "telegraph")
	H.eq(o.hold, true)
	local t = 0.1
	while o.state == "telegraph" do
		o = b.step(0.1, me, foe, { ram = false, saw = false })
		t += 0.1
	end
	H.truthy(t >= 0.6 - 1e-6 and t <= 0.8, "telegraph length " .. t)
	H.eq(o.state, "charge")
	H.near(o.drive, BattleConfig.Ram.chargeMult)
	H.eq(o.turn, 0, "no steering while charging")
	-- foe moves away sideways: still no steering, charge ends as a miss after 1 s
	foe.z = 60
	local missed = false
	for _ = 1, 15 do
		o = b.step(0.1, me, foe, { ram = false, saw = false })
		H.eq(o.turn, 0)
		if o.event == "Ram missed" then
			missed = true
			break
		end
	end
	H.truthy(missed, "miss reported")
	-- cooldown: no new telegraph for 4 s even when lined up
	foe.z, foe.x = 0, -20 + 2 * L
	local tAfter = 0
	while true do
		o = b.step(0.1, me, foe, { ram = false, saw = false })
		tAfter += 0.1
		if o.state == "telegraph" then
			break
		end
		if tAfter > 8 then
			break
		end
	end
	H.truthy(tAfter >= BattleConfig.Ram.cooldownSeconds - 0.15, "next charge after " .. tAfter)
end)

H.test("ram: hit deals 30 once per charge", function()
	local L = BattleConfig.Fighters.RamTruck.lengthStuds
	local b = BattleBrain.new("RamTruck", L, arena())
	local me = { x = 0, z = 20, fx = 1, fz = 0 }
	local foe = { x = 2 * L, z = 20, fx = -1, fz = 0 }
	local o = b.step(0.1, me, foe, { ram = false, saw = false })
	for _ = 1, 8 do
		o = b.step(0.1, me, foe, { ram = false, saw = false })
	end
	H.eq(o.state, "charge")
	local total = 0
	for _ = 1, 8 do
		o = b.step(0.1, me, foe, { ram = true, saw = false })
		total += o.damage
	end
	H.eq(total, BattleConfig.Ram.damage)
end)

H.test("ram: body contact outside the front cone deals nothing", function()
	local L = BattleConfig.Fighters.RamTruck.lengthStuds
	local b = BattleBrain.new("RamTruck", L, arena())
	local me = { x = 0, z = 20, fx = 1, fz = 0 }
	local foe = { x = 2 * L, z = 20, fx = -1, fz = 0 }
	for _ = 1, 8 do
		b.step(0.1, me, foe, { ram = false, saw = false })
	end
	local behind = { x = -L, z = 20, fx = 1, fz = 0 } -- foe now behind the charging truck
	local total = 0
	for _ = 1, 8 do
		total += b.step(0.1, me, behind, { ram = true, saw = false }).damage
	end
	H.eq(total, 0)
end)

H.test("cannon: aims, locks 0.5 s, fires, then cooldown", function()
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local b = BattleBrain.new("CannonVan", L, arena())
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local foe = { x = 3 * L, z = 0, fx = -1, fz = 0 }
	local o = b.step(0.05, me, foe, { ram = false, saw = false })
	H.eq(o.state, "telegraph")
	local t = 0.05
	local fired = 0
	local firstFire = 0.0
	for _ = 1, 200 do
		o = b.step(0.05, me, foe, { ram = false, saw = false })
		t += 0.05
		if o.fire then
			fired += 1
			if fired == 1 then
				firstFire = t
			elseif fired == 2 then
				H.truthy(
					t - firstFire >= BattleConfig.Cannon.cooldownSeconds + 0.5 - 0.1,
					"second shot after " .. (t - firstFire)
				)
				break
			end
		end
	end
	H.truthy(firstFire >= 0.5 - 1e-6 and firstFire <= 0.7, "first shot at " .. firstFire)
	H.eq(fired, 2)
end)

H.test("cannon: too close it backs away, too far it closes in", function()
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local b = BattleBrain.new("CannonVan", L, arena())
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local near = b.step(
		0.05,
		me,
		{ x = 0, z = 1 * L, fx = -1, fz = 0 },
		{ ram = false, saw = false }
	)
	H.eq(near.state, "flee", "runs away when close")
	H.truthy(math.abs(near.turn) > 0.5, "turns tail to the foe")
	local far = b.step(
		0.05,
		me,
		{ x = 8 * L, z = 0, fx = -1, fz = 0 },
		{ ram = false, saw = false }
	)
	H.truthy(far.drive > 0, "drives in when far")
end)

H.test("saw: damage ticks at no less than 0.5 s, only with front contact", function()
	local L = BattleConfig.Fighters.SawBuggy.lengthStuds
	local b = BattleBrain.new("SawBuggy", L, arena())
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local foe = { x = 0.9 * L, z = 0, fx = -1, fz = 0 }
	local times: { number } = {}
	local t = 0
	for _ = 1, 100 do
		t += 0.05
		local o = b.step(0.05, me, foe, { ram = false, saw = true })
		if o.damage > 0 then
			H.truthy(
				o.damage >= BattleConfig.Saw.damage
					and o.damage <= BattleConfig.Saw.damage * BattleConfig.Saw.maxMult
			)
			table.insert(times, t)
		end
	end
	H.truthy(#times >= 9 and #times <= 11, "ticks in 5 s: " .. #times)
	for i = 2, #times do
		H.truthy(times[i] - times[i - 1] >= 0.5 - 1e-6, "interval")
	end
	-- foe behind the saw: body contact, no damage
	local behind = { x = -0.9 * L, z = 0, fx = 1, fz = 0 }
	for _ = 1, 40 do
		H.eq(b.step(0.05, me, behind, { ram = false, saw = true }).damage, 0)
	end
end)

H.test("stuck: no progress while driving makes the car reverse and turn away", function()
	local L = BattleConfig.Fighters.SawBuggy.lengthStuds
	local b = BattleBrain.new("SawBuggy", L, arena())
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local foe = { x = 60, z = 0, fx = -1, fz = 0 }
	local reversed = false
	for _ = 1, 100 do
		local o = b.step(0.05, me, foe, { ram = false, saw = false }) -- the car never moves
		if o.state == "recover" and o.drive < 0 then
			reversed = true
			break
		end
	end
	H.truthy(reversed)
end)

-- SIMULATED FIGHTS ---------------------------------------------------------------------------
local FIGHTERS = { "RamTruck", "CannonVan", "SawBuggy" }

H.test("all six pairings end with a valid result on both spawn sides", function()
	local pairs = {
		{ "RamTruck", "RamTruck" },
		{ "CannonVan", "CannonVan" },
		{ "SawBuggy", "SawBuggy" },
		{ "RamTruck", "CannonVan" },
		{ "RamTruck", "SawBuggy" },
		{ "CannonVan", "SawBuggy" },
	}
	for _, p in pairs do
		local winsA, winsB, draws, hitsA, hitsB, secs = 0, 0, 0, 0, 0, 0
		local runs = 24
		for i = 1, runs do
			local r = Sim.fight(p[1], p[2], i % 2 == 0, 1000 + i)
			H.truthy(r.seconds <= BattleConfig.Timing.fightSeconds + 0.1, "fight ends in time")
			H.truthy(r.a.hp >= 0 and r.b.hp >= 0)
			if r.outcome == "a" then
				winsA += 1
			elseif r.outcome == "b" then
				winsB += 1
			else
				draws += 1
			end
			hitsA += r.a.hits
			hitsB += r.b.hits
			secs += r.seconds
		end
		print(
			`       {p[1]} vs {p[2]}: {winsA}-{winsB} draws {draws}, hits {hitsA}/{hitsB}, avg {math.floor(
				secs / runs
			)} s`
		)
		H.truthy(hitsA + hitsB > 0, "weapons landed something")
	end
end)

H.test("the cannon cannot kite forever: fights vs ram/saw resolve by the clock at worst", function()
	for _, foe in { "RamTruck", "SawBuggy" } do
		for i = 1, 6 do
			local r = Sim.fight("CannonVan", foe, i % 2 == 0, 77 + i)
			H.truthy(r.seconds <= BattleConfig.Timing.fightSeconds + 0.1)
		end
	end
end)

H.test("cannon fires, and shells can miss", function()
	local fired, missed = 0, 0
	for i = 1, 12 do
		local r = Sim.fight("CannonVan", "CannonVan", i % 2 == 0, 300 + i)
		for _, e in r.a.log do
			if e.kind == "fire" then
				fired += 1
			elseif e.kind == "shellMiss" then
				missed += 1
			end
		end
	end
	H.truthy(fired > 0, "the cannon fires")
	local _ = missed
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local b = BattleBrain.new("CannonVan", L, Sim.arena())
	H.eq(b.shellResolved(false), "Cannon missed")
	H.eq(b.shellResolved(true), "Cannon hit")
end)

H.test("two cannon vans in the middle of the arena line up and shoot (no standoff)", function()
	local r = Sim.fight("CannonVan", "CannonVan", false, 5)
	H.truthy(r.a.hits + r.b.hits > 0, "someone got hit")
end)

H.test("brain: nothing near a block or wall pulls a car off a straight approach", function()
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local b = BattleBrain.new("CannonVan", L, Sim.arena())
	local o = b.step(
		1 / 60,
		{ x = -50, z = 0, fx = 1, fz = 0 },
		{ x = 50, z = 0, fx = -1, fz = 0 },
		{ ram = false, saw = false }
	)
	H.near(o.turn, 0, 1e-6)
	H.truthy(o.drive > 0.5)
end)

H.test("config: every fighter is complete", function()
	for _, id in BattleConfig.Order do
		local f = BattleConfig.Fighters[id]
		H.truthy(f ~= nil and f.id == id)
		H.truthy(f.hp > 0 and f.cruiseL > 0 and f.turnDeg > 0 and f.lengthStuds > 0)
		H.truthy(#f.blurb > 0 and #f.weakness > 0 and #f.weaponName > 0)
	end
	H.eq(BattleConfig.Fighters.RamTruck.hp, 150)
	H.eq(BattleConfig.Fighters.CannonVan.hp, 150)
	H.eq(BattleConfig.Fighters.SawBuggy.hp, 105)
	local _ = FIGHTERS
end)

-- SAVES --------------------------------------------------------------------------------------
local Inventory = require("../src/shared/Inventory")

H.test("saves: fighters survive migrate, old cars and coins stay", function()
	local p =
		Inventory.migrate({ coins = 50, owned = { Sedan = true, CannonVan = true }, wins = 3 })
	H.eq(p.owned.CannonVan, true)
	H.eq(p.owned.Sedan, true)
	H.eq(p.coins, 50)
	H.eq(p.wins, 3)
	local q = Inventory.migrate({ owned = { Sedan = true, NotACar = true } })
	H.eq(q.owned.NotACar, nil)
	H.eq(q.owned.RamTruck, nil, "no free fighters are added to a save")
end)

H.test("saves: a new player owns no fighter, but the Ram Truck is always theirs", function()
	local p = Inventory.default()
	H.eq(BattleSelect.access("RamTruck", { owned = p.owned, testUnlock = false }), "owned")
end)

H.test("gumball: drops only gumball fighters, odds add to 100, saves ownership", function()
	Gacha.useFighters()
	local total = 0
	local seen: { [string]: boolean } = {}
	for _, row in Gacha.oddsTable() do
		total += row.percent
		for _, id in row.cars do
			seen[id] = true
		end
	end
	Gacha.useCars()
	H.eq(math.floor(total + 0.5), 100)
	H.eq(seen.CannonVan, true)
	H.eq(seen.SawBuggy, true)
	H.eq(seen.RamTruck, nil, "the Ram is the free starter, not a drop")
end)

H.test(
	"gumball: a rarity with no car is not in the odds (no Legendary until one exists)",
	function()
		Gacha.useFighters()
		local have: { [string]: boolean } = {}
		for _, id in BattleConfig.Order do
			local f = BattleConfig.Fighters[id]
			if f.gumball and f.enabled then
				have[f.rarity] = true
			end
		end
		for _, row in Gacha.oddsTable() do
			H.eq(have[row.rarity], true, row.rarity .. " is shown but has no car")
			H.truthy(#row.cars > 0)
		end
		Gacha.useCars()
	end
)

H.test("gumball: a pull grants a fighter once, a duplicate gives nothing", function()
	Gacha.useFighters()
	local p: any = Inventory.default()
	p.coins = 1000
	p.freePullUsed = true
	local r1 = Gacha.pull(p, function()
		return 0
	end)
	local r2 = Gacha.pull(p, function()
		return 0
	end)
	Gacha.useCars()
	H.eq(p.owned[r1.carId], true)
	H.eq(r1.isNew, true)
	H.eq(r2.carId, r1.carId)
	H.eq(r2.isNew, false)
	H.eq(r2.refund, 0, "a duplicate gives nothing")
end)

H.test("cannon: just inside max range and a few degrees off, it still turns and creeps", function()
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local b = BattleBrain.new("CannonVan", L, Sim.arena())
	local a = math.rad(8)
	local o = b.step(
		0.05,
		{ x = -40, z = 0, fx = math.cos(a), fz = math.sin(a) },
		{ x = 40, z = 0, fx = -1, fz = 0 },
		{ ram = false, saw = false }
	)
	H.truthy(math.abs(o.turn) >= 0.5, "real turn command")
	H.truthy(o.drive > 0, "creeps so the turn bites")
end)

H.test("saw (bounce): long steady contact overheats and pauses the damage", function()
	local L = BattleConfig.Fighters.SawBuggy.lengthStuds
	local b = BattleBrain.new("SawBuggy", L, Sim.arena(), true)
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local foe = { x = 0.9 * L, z = 0, fx = -1, fz = 0 }
	local pauseStart = BattleConfig.Saw.heatSeconds + 0.3
	local ticksAfter, ticksBefore = 0, 0
	for i = 1, 200 do
		local t = i * 0.05
		local o = b.step(0.05, me, foe, { ram = false, saw = true })
		if o.damage > 0 then
			if t < BattleConfig.Saw.heatSeconds then
				ticksBefore += 1
			elseif
				t > pauseStart
				and t < BattleConfig.Saw.heatSeconds + BattleConfig.Saw.stallSeconds
			then
				ticksAfter += 1
			end
		end
	end
	H.truthy(ticksBefore > 0, "damage before the overheat")
	H.eq(ticksAfter, 0)
end)

H.test("saw: steady contact builds damage, losing contact resets it", function()
	local L = BattleConfig.Fighters.SawBuggy.lengthStuds
	local b = BattleBrain.new("SawBuggy", L, Sim.arena())
	local me = { x = 0, z = 0, fx = 1, fz = 0 }
	local foe = { x = 0.9 * L, z = 0, fx = -1, fz = 0 }
	local first, last = 0, 0
	for i = 1, 100 do
		local o = b.step(0.05, me, foe, { ram = false, saw = true })
		if o.damage > 0 then
			if first == 0 then
				first = o.damage
			end
			last = o.damage
		end
		_ = i
	end
	H.eq(first, BattleConfig.Saw.damage)
	H.eq(last, BattleConfig.Saw.damage * BattleConfig.Saw.maxMult)
	for _ = 1, 10 do
		b.step(0.05, me, foe, { ram = false, saw = false }) -- 0.5 s apart
	end
	local again = 0
	for _ = 1, 20 do
		local o = b.step(0.05, me, foe, { ram = false, saw = true })
		if o.damage > 0 and again == 0 then
			again = o.damage
		end
	end
	H.eq(again, BattleConfig.Saw.damage, "build-up restarted")
end)

H.test("ram: a faster charge hits harder", function()
	local L = BattleConfig.Fighters.RamTruck.lengthStuds
	local function hitWith(speedFrac: number): number
		local b = BattleBrain.new("RamTruck", L, Sim.arena())
		local me = { x = 0, z = 0, fx = 1, fz = 0 }
		local foe = { x = 2 * L, z = 0, fx = -1, fz = 0 }
		local dmg = 0
		for _ = 1, 80 do
			local o = b.step(0.05, me, foe, { ram = true, saw = false, speedFrac = speedFrac })
			if o.damage > 0 then
				dmg = o.damage
				break
			end
		end
		return dmg
	end
	H.eq(hitWith(1), BattleConfig.Ram.damage)
	H.eq(hitWith(0), BattleConfig.Ram.damageMin)
	H.truthy(hitWith(0.5) > hitWith(0))
end)

H.test("final phase: faster tempo gives the cannon its next shot sooner", function()
	local L = BattleConfig.Fighters.CannonVan.lengthStuds
	local function secondShot(tempo: number): number
		local b = BattleBrain.new("CannonVan", L, Sim.arena())
		local me = { x = -40, z = 0, fx = 1, fz = 0 }
		local foe = { x = 40, z = 0, fx = -1, fz = 0 }
		local t, fired, first = 0, 0, 0
		while t < 20 do
			t += 0.05
			local o = b.step(0.05, me, foe, { ram = false, saw = false, tempo = tempo })
			if o.fire then
				fired += 1
				if fired == 1 then
					first = t
				else
					return t - first
				end
			end
		end
		return 99
	end
	H.truthy(secondShot(2) < secondShot(1) - 0.5)
end)

H.test("setup: bad numbers fall back, spots and aims place the car where they say", function()
	local spot, aim = BattleSetup.clean("x", 5)
	H.eq(spot, 0)
	H.eq(aim, 0)
	H.eq(select(1, BattleSetup.clean(1, -1)), 1)
	local x, z, fx, fz = BattleSetup.place("a", 80, 55, 18, 0, 0)
	H.eq(x, -62)
	H.eq(z, 0)
	H.near(fx, 1, 1e-9)
	H.near(fz, 0, 1e-9)
	local _, zFar = BattleSetup.place("a", 80, 55, 18, -1, 0)
	H.truthy(zFar < 0)
	local bx, _, bfx, bfz = BattleSetup.place("b", 80, 55, 18, 0, 1)
	H.eq(bx, 62)
	H.truthy(bfx < 0)
	H.truthy(bfz > 0, "left for the right-hand car points down the screen")
	local _, _, lx, lz = BattleSetup.place("a", 80, 55, 18, 0, 1)
	H.truthy(lz < 0, "left for the left-hand car points up the screen")
	H.near(lx * lx + lz * lz, 1, 1e-9)
end)

H.test("recap: plain facts about each weapon", function()
	local mine = BattleRecap.newStats()
	local foe = BattleRecap.newStats()
	mine.shots, mine.shotHits = 4, 1
	foe.ramHits = 3
	local lines = BattleRecap.lines("CannonVan", mine, foe)
	H.eq(lines[1], "Your cannon landed 1 of 4 shots")
	H.eq(lines[2], "You took 3 ram hits")
	local quiet = BattleRecap.lines("RamTruck", BattleRecap.newStats(), BattleRecap.newStats())
	H.eq(quiet[1], "Your ram landed 0 of 0 charges")
	H.eq(quiet[2], "You took no hits")
end)

H.test("momentum brains keep rolling: no standing still to aim or wind up", function()
	local Lc = BattleConfig.Fighters.CannonVan.lengthStuds
	local c = BattleBrain.new("CannonVan", Lc, Sim.arena(), true)
	local me = { x = -40, z = 0, fx = 1, fz = 0 }
	local foe = { x = 40, z = 0, fx = -1, fz = 0 }
	local fired = false
	for _ = 1, 40 do
		local o = c.step(0.05, me, foe, { ram = false, saw = false })
		H.eq(o.hold, false, "never holds still")
		H.truthy(o.drive > 0, "keeps rolling")
		if o.fire then
			fired = true
		end
	end
	H.truthy(fired, "fires when the gun points at the foe")
	local Lr = BattleConfig.Fighters.RamTruck.lengthStuds
	local r = BattleBrain.new("RamTruck", Lr, Sim.arena(), true)
	local rme = { x = 0, z = 0, fx = 1, fz = 0 }
	local rfoe = { x = 3 * Lr, z = 0, fx = -1, fz = 0 }
	local sawCharge = false
	for _ = 1, 40 do
		local o = r.step(0.05, rme, rfoe, { ram = false, saw = false })
		H.eq(o.hold, false)
		if o.state == "charge" then
			sawCharge = true
		end
	end
	H.truthy(sawCharge, "the ram surges into a charge")
end)

-- Manual driving ------------------------------------------------------------------------------

local function bodies(dist: number): ({ x: number, z: number, fx: number, fz: number }, {
	x: number,
	z: number,
	fx: number,
	fz: number,
})
	return { x = 0, z = 0, fx = 1, fz = 0 }, { x = dist, z = 0, fx = -1, fz = 0 }
end

H.test("human: the stick drives and steers (stick right = turn right)", function()
	local b = BattleHuman.new("RamTruck")
	local me, foe = bodies(200)
	b.setInput(1, 1, false)
	local o = b.step(0.05, me, foe, { ram = false, saw = false })
	H.eq(o.drive, 1)
	H.truthy(o.turn < 0, "right is a negative (clockwise) turn")
	b.setInput(0, -1, false)
	local back = b.step(0.05, me, foe, { ram = false, saw = false })
	H.eq(back.drive, -1)
	H.eq(back.fire, false)
end)

H.test("human ram: attack starts a straight charge, a hit deals damage, then it recoils", function()
	local b = BattleHuman.new("RamTruck")
	local me, foe = bodies(40)
	b.setInput(1, 1, true)
	local o = b.step(0.05, me, foe, { ram = false, saw = false })
	H.eq(o.state, "charge")
	local hit = b.step(0.05, me, foe, { ram = true, saw = false, speedFrac = 1 })
	H.eq(math.abs(hit.turn + BattleConfig.Ram.playerSteer) < 1e-9, true) -- the stick steers a charge a little (right = negative)
	H.eq(BattleSeries.paysCoins(14, BattleConfig.Rewards.minFightSeconds), false)
	H.eq(BattleSeries.paysCoins(15, BattleConfig.Rewards.minFightSeconds), true)
	H.eq(hit.damage, BattleConfig.Ram.damage)
	H.eq(hit.event, "Ram hit")
	H.eq(hit.state, "recoil")
	-- cooling down: another press does nothing
	b.setInput(0, 1, false)
	for _ = 1, 20 do
		b.step(0.05, me, foe, { ram = false, saw = false })
	end
	b.setInput(0, 1, true)
	local again = b.step(0.05, me, foe, { ram = false, saw = false })
	H.truthy(again.state ~= "charge")
	H.truthy(again.ready < 1, "the button is still filling up")
end)

H.test("human ram: a missed charge ends in a skid and the cooldown", function()
	local b = BattleHuman.new("RamTruck")
	local me, foe = bodies(500)
	b.setInput(0, 1, true)
	b.step(0.05, me, foe, { ram = false, saw = false })
	local missed = false
	for _ = 1, 40 do
		local o = b.step(0.05, me, foe, { ram = false, saw = false })
		if o.event == "Ram missed" then
			missed = true
		end
	end
	H.truthy(missed, "the charge timed out as a miss")
end)

H.test("human cannon: each new press fires once, then the 6 s wait", function()
	local b = BattleHuman.new("CannonVan")
	local me, foe = bodies(100)
	H.eq(BattleConfig.Cannon.cooldownSeconds, 6)
	local fired = 0
	-- 8 s of pressing again and again (a press every half second)
	for i = 1, 160 do
		b.setInput(0, 0, (i // 10) % 2 == 0)
		local o = b.step(0.05, me, foe, { ram = false, saw = false })
		if o.fire then
			fired += 1
		end
	end
	-- the first shot at once, the next one only after 6 s
	H.eq(fired, 2)
	-- a held button fires once per wait: at once, then again when the 6 s are up
	local c = BattleHuman.new("CannonVan")
	local shots = 0
	for _ = 1, 140 do -- 7 s
		c.setInput(0, 0, true)
		if c.step(0.05, me, foe, { ram = false, saw = false }).fire then
			shots += 1
		end
	end
	H.eq(shots, 2)
end)

H.test("human saw: hold ATTACK to grind, then a 6 s wait", function()
	local b = BattleHuman.new("SawBuggy")
	local me, foe = bodies(14)
	-- touching but not holding: no grinding
	local idle = 0
	for _ = 1, 20 do
		b.setInput(0, 0, false)
		idle += b.step(0.05, me, foe, { ram = false, saw = true }).damage
	end
	H.eq(idle, 0)
	-- holding: damage while touching
	local dmg = 0
	for _ = 1, 20 do
		b.setInput(0, 0, true)
		dmg += b.step(0.05, me, foe, { ram = false, saw = true }).damage
	end
	H.truthy(dmg >= BattleConfig.Saw.damage, "damage while holding and touching")
	-- the foe is not in front: no grinding even when held
	local away = { x = 0, z = 100, fx = 0, fz = -1 }
	local c = BattleHuman.new("SawBuggy")
	local none = 0
	for _ = 1, 20 do
		c.setInput(0, 0, true)
		none += c.step(0.05, me, away, { ram = false, saw = true }).damage
	end
	H.eq(none, 0)
	-- the grind lasts at most sawGrindSeconds even if held, then the wait
	local d = BattleHuman.new("SawBuggy")
	local grindSteps = 0
	for _ = 1, 150 do -- 7.5 s held: one grind, then the wait
		d.setInput(0, 0, true)
		if d.step(0.05, me, foe, { ram = false, saw = true }).state == "grind" then
			grindSteps += 1
		end
	end
	H.truthy(grindSteps * 0.05 <= BattleConfig.Human.sawGrindSeconds + 0.1, "grind time is capped")
end)

H.test("human: input values are clamped", function()
	local b = BattleHuman.new("CannonVan")
	local me, foe = bodies(100)
	b.setInput(9, -9, false)
	local o = b.step(0.05, me, foe, { ram = false, saw = false })
	H.eq(o.drive, -1)
	H.truthy(o.turn >= -1 and o.turn <= 1)
end)

H.test(
	"crash damage: faster car hurts more, 5 full-speed crashes kill, slow bumps do nothing",
	function()
		local C = BattleConfig.Crash
		local hp = 150
		local cruise = 43
		H.eq(BattleCrash.damage(hp, cruise, cruise) * C.hitsToKill, hp)
		H.truthy(
			BattleCrash.damage(hp, cruise * 0.6, cruise) < BattleCrash.damage(hp, cruise, cruise)
		)
		H.eq(BattleCrash.damage(hp, cruise * 0.1, cruise), 0)
		H.eq(BattleCrash.damage(hp, cruise * 5, cruise), BattleCrash.damage(hp, cruise, cruise)) -- capped
		H.eq(BattleCrash.speedToward(10, 0, 1, 0), 10)
		H.eq(BattleCrash.speedToward(-10, 0, 1, 0), 0) -- moving away: no crash
		H.eq(BattleCrash.speedToward(0, 10, 1, 0), 0) -- sideways to the line between them
	end
)

H.test("only the round that ends the match counts as the final knock-out", function()
	local s = BattleSeries.new()
	H.eq(BattleSeries.endsMatch(s, "a"), false)
	BattleSeries.record(s, "a")
	H.eq(BattleSeries.endsMatch(s, "a"), true)
	H.eq(BattleSeries.endsMatch(s, "b"), false)
	H.eq(#s.results, 1) -- nothing was recorded by the question
end)

H.test("one top speed for every car, and a capped slide", function()
	H.eq(BattleConfig.Human.topSpeed, 42)
	H.eq(BattleConfig.Human.slideMaxFrac <= 0.5, true)
end)

H.test("every car has a driver and a line for the VS screen", function()
	for id in BattleConfig.Fighters do
		H.eq(#BattleConfig.driverLine(id) > 0, true)
	end
	H.eq(BattleConfig.driverLine("nope"), "")
	H.eq(BattleConfig.Timing.firstPrepSeconds > BattleConfig.Timing.prepSeconds, true)
end)

H.test("auto-aim curves a shot toward a foe that is nearly ahead, not one behind", function()
	-- heading +x, foe up-left at 30 degrees: turns toward it by at most the step
	local x, z = BattleAim.curve(1, 0, math.cos(0.52), math.sin(0.52), 0.1, 0.8)
	H.eq(z > 0 and math.abs(math.atan2(z, x) - 0.1) < 1e-6, true)
	-- a tiny gap is closed exactly
	local x2, z2 = BattleAim.curve(1, 0, math.cos(0.05), math.sin(0.05), 0.1, 0.8)
	H.eq(math.abs(math.atan2(z2, x2) - 0.05) < 1e-6, true)
	-- foe behind (outside the cone): unchanged
	local x3, z3 = BattleAim.curve(1, 0, -1, 0.1, 0.1, 0.8)
	H.eq(x3 == 1 and z3 == 0, true)
	-- charge nudge: zero outside the cone, signed inside, never above strength
	H.eq(BattleAim.chargeTurn(1.2, 0.6, 0.5), 0)
	H.eq(BattleAim.chargeTurn(0.3, 0.6, 0.5), 0.25)
	H.eq(BattleAim.chargeTurn(-0.6, 0.6, 0.5), -0.5)
end)

H.test("special energy fills by hitting and is ready only when full", function()
	local e = 0
	H.eq(BattleSpecial.ready(e), false)
	e = BattleSpecial.gain(e, 30) -- about one ram hit
	H.eq(e > 0.3 and e < 0.4, true)
	H.eq(BattleSpecial.ready(e), false)
	e = BattleSpecial.gain(e, 100)
	H.eq(e, 1) -- capped
	H.eq(BattleSpecial.ready(e), true)
	H.eq(BattleSpecial.gain(0.5, -20), 0.5) -- no negative gain
end)

H.test("a car past the walls or below the floor is out of the arena", function()
	H.eq(BattleCrash.outside(0, 0, 1, 85, 40), false)
	H.eq(BattleCrash.outside(84, -39, 0.5, 85, 40), false)
	H.eq(BattleCrash.outside(86, 0, 1, 85, 40), true)
	H.eq(BattleCrash.outside(0, -41, 1, 85, 40), true)
	H.eq(BattleCrash.outside(0, 0, -5, 85, 40), true)
end)

H.test("every weapon waits 6 seconds, rounds last 60", function()
	H.eq(BattleConfig.Ram.cooldownSeconds, 6)
	H.eq(BattleConfig.Cannon.cooldownSeconds, 6)
	H.eq(BattleConfig.Human.sawCooldownSeconds, 6)
	H.eq(BattleConfig.Timing.fightSeconds, 60)
end)

H.test(
	"a car has weight: about 0.7 s to top speed, rolls on when the gas is let go, turns less when fast",
	function()
		local top = BattleConfig.Human.topSpeed
		local dt = 1 / 60
		-- full gas from a standstill
		local v, t = 0, 0
		while v < 0.95 * top and t < 5 do
			v = BattleFeel.nextSpeed(v, top, dt, top)
			t += dt
		end
		H.eq(t >= 0.55 and t <= 0.95, true)
		-- gas released at top speed: coasts, takes a while to stop
		local c, ct = top, 0
		while c > 0.05 * top and ct < 10 do
			c = BattleFeel.nextSpeed(c, 0, dt, top)
			ct += dt
		end
		H.eq(ct >= 0.7 and ct <= 1.6, true)
		-- pulling back (gas the other way) stops sooner than coasting but not in a blink
		local b, bt = top, 0
		while b > 0 and bt < 10 do
			b = BattleFeel.nextSpeed(b, -0.6 * top, dt, top)
			bt += dt
			if b <= 0 then
				break
			end
		end
		H.eq(bt >= 0.25 and bt < ct, true)
		-- top speed itself is unchanged
		H.eq(BattleFeel.nextSpeed(top, top, dt, top), top)
		-- turning: full when crawling, about half at top speed
		H.eq(BattleFeel.turnScale(0), 1)
		H.eq(BattleFeel.turnScale(1), BattleConfig.Human.turnTopScale)
		H.eq(BattleFeel.turnScale(5), BattleConfig.Human.turnTopScale) -- never below the top-speed share
		-- the wheel swings: full lock takes about 1/6 s, not one frame
		local w, wt = 0, 0
		while w < 1 do
			w = BattleFeel.smoothTurn(w, 1, dt)
			wt += dt
		end
		H.eq(wt >= 0.12 and wt <= 0.25, true)
	end
)

H.test("the chase camera trails the nose and never swings faster than the cap", function()
	local dt = 1 / 60
	local cap = math.rad(BattleConfig.Human.camSwingDegPerSec)
	-- car turned 150 degrees away at once: each step moves at most the cap
	local y = 0
	local steps = 0
	while math.abs(y - math.rad(150)) > 0.01 and steps < 600 do
		local n = BattleFeel.trailYaw(y, math.rad(150), dt)
		H.eq(math.abs(n - y) <= cap * dt + 1e-9, true)
		y = n
		steps += 1
	end
	H.eq(steps > 60 and steps < 600, true) -- about 1.6 s or more, not instant
	-- the short way round: from +170 to -170 degrees is a 20 degree swing, not 340
	local a = BattleFeel.trailYaw(math.rad(170), math.rad(-170), dt)
	H.eq(a > math.rad(170), true)
	-- already facing the same way: stays put
	H.eq(BattleFeel.trailYaw(1, 1, dt), 1)
end)

H.test("cheat checks: normal driving passes, a teleport and a speed hack are caught", function()
	local top = BattleConfig.Human.topSpeed
	local dt = 1 / 20 -- the server step
	H.eq(BattleGuard.teleported(top * dt, 0, dt, top), false) -- top speed
	H.eq(BattleGuard.teleported(1.5 * BattleConfig.Ram.chargeMult * top * dt, 0, dt, top), false) -- a charge
	H.eq(BattleGuard.teleported(30, 0, dt, top), true) -- 30 studs in one step
	H.eq(BattleGuard.teleported(0, -80, dt, top), true)
	H.eq(BattleGuard.tooFast(top, top), false)
	H.eq(BattleGuard.tooFast(top * BattleConfig.Ram.chargeMult, top), false) -- a full charge
	H.eq(BattleGuard.tooFast(top * 4, top), true)
end)

H.test("crash hit power grows with the damage and stays between 0 and 1", function()
	H.eq(BattleCrash.power(0, 150), 0)
	H.eq(BattleCrash.power(15, 150) < BattleCrash.power(30, 150), true)
	H.eq(BattleCrash.power(30, 150), 1)
	H.eq(BattleCrash.power(500, 150), 1)
	H.eq(BattleCrash.power(10, 0), 0)
end)

H.test(
	"weapon balance on paper: best-case damage per 6 s wait is close for all three cars",
	function()
		local ramD = BattleConfig.Ram.damage
		local vanD = BattleConfig.Cannon.damage
		local S = BattleConfig.Saw
		local grind = BattleConfig.Human.sawGrindSeconds
		-- the saw ticks every tickSeconds for up to grindSeconds, building from x1 to maxMult over buildSeconds
		local sawD = 0
		local t = 0
		while t < grind do
			local build = math.clamp(t / S.buildSeconds, 0, 1)
			sawD += S.damage * (1 + (S.maxMult - 1) * build)
			t += S.tickSeconds
		end
		local best, worst = math.max(ramD, vanD, sawD), math.min(ramD, vanD, sawD)
		H.eq(best / worst <= 1.5, true)
		H.eq(worst >= 20, true)
	end
)

H.test(
	"floor friction does not eat the getaway: the commanded speed carries on, a crash resets it",
	function()
		local top = BattleConfig.Human.topSpeed
		local dt = 1 / 60
		local cmd: number? = nil
		local actual = 0
		local t = 0
		while actual < 0.9 * top and t < 5 do
			local base = BattleFeel.trust(cmd, actual, top)
			local nextV = BattleFeel.nextSpeed(base, top, dt, top)
			cmd = nextV
			actual = nextV - 2.5 -- the floor takes up to 2.5 studs/s off every step
			t += dt
		end
		H.eq(t >= 0.55 and t <= 1.2, true)
		-- a crash or shove that moves the car a lot: the real speed wins
		H.eq(BattleFeel.trust(40, 5, top), 5)
		-- a small difference (friction): the commanded speed stays
		H.eq(BattleFeel.trust(40, 37.5, top), 40)
		H.eq(BattleFeel.trust(nil, 12, top), 12)
	end
)
