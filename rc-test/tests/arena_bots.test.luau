--!strict
-- Arena bots (Smash): the brain's choices, and a small match sim on the real arena (ArenaData:
-- hills up their ramps, the sand's gaps, cover, trees) with stand-in weapons, bumps, boxes and respawns:
-- the first smash comes inside 30 s in 20 of 20 seeded runs, and no bot is ever stuck 3 s.
-- (LOOPTEST's sim runs the real server; this one checks the brain on its own.)
local H = require("./harness")
local B = require("../src/shared/ArenaBrain")
local Boxes = require("../src/shared/Boxes")
local Match = require("../src/shared/Match")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Arena bots")

local function world(): B.World
	return { half = 116, solids = {}, boxes = {}, karts = {} }
end

local function run(bot: B.Bot, w: B.World, secs: number, weapon: string?, ammo: number?): B.Step
	local s: B.Step = { x = bot.x, z = bot.z, yaw = bot.yaw }
	local t = 0
	while t < secs do
		t += 0.05
		s = B.step(bot, w, 0.05, t, weapon, ammo)
	end
	return s
end

test("no weapon: drives to the nearest box", function()
	local w = world()
	w.boxes = { { x = 60, z = 0 }, { x = -100, z = 100 } }
	local bot = B.new(1, 0, 0, 0, { skill = 0.5 })
	local closest = math.huge
	local t = 0
	while t < 4 do
		t += 0.05
		B.step(bot, w, 0.05, t)
		closest = math.min(closest, math.sqrt((bot.x - 60) ^ 2 + bot.z ^ 2))
	end
	truthy(closest < 4, "drove through the near box: " .. closest)
end)

test(
	"armed: closes in and fires only when the target is in front, in range and in sight",
	function()
		local w = world()
		w.karts =
			{ { id = 1, x = 0, z = 0, alive = true }, { id = 2, x = 0, z = -70, alive = true } }
		local bot = B.new(1, 0, 0, math.pi, { skill = 1 }) -- facing away (+z)
		local s = B.step(bot, w, 0.05, 0, "Rockets", 3)
		eq(s.fire, nil)
		local fired: { x: number, z: number }? = nil
		local t = 0
		while t < 5 and not fired do
			t += 0.05
			w.karts[1].x, w.karts[1].z = bot.x, bot.z
			fired = B.step(bot, w, 0.05, t, "Rockets", 3).fire
		end
		truthy(fired ~= nil, "fires once turned round")
		-- a wall in the way: no shot
		local w2 = world()
		w2.solids = { { x = 0, z = -30, r = 8 } }
		w2.karts =
			{ { id = 1, x = 0, z = 0, alive = true }, { id = 2, x = 0, z = -60, alive = true } }
		local b2 = B.new(1, 0, 0, 0, { skill = 1 })
		for k = 1, 40 do
			b2.x, b2.z, b2.yaw, b2.speed = 0, 0, 0, 0
			eq(B.step(b2, w2, 0.05, k * 0.05, "Rockets", 3).fire, nil)
		end
		-- no ammo, or a shielded target: no shot
		local b3 = B.new(1, 0, 0, 0, { skill = 1 })
		local w3 = world()
		w3.karts = {
			{ id = 1, x = 0, z = 0, alive = true },
			{ id = 2, x = 0, z = -40, alive = true, shield = true },
		}
		for k = 1, 40 do
			eq(B.step(b3, w3, 0.05, k * 0.05, "Rockets", 3).fire, nil)
			eq(B.step(b3, w, 0.05, k * 0.05, "Rockets", 0).fire, nil)
		end
	end
)

test(
	"fair to a new kid: one bot hunts a player at a time; easy bots wait longer to shoot",
	function()
		local w = world()
		w.karts = {
			{ id = 1, x = 0, z = 0, alive = true, human = true },
			{ id = -1, x = 6, z = 6, alive = true },
			{ id = -2, x = -6, z = 6, alive = true },
			{ id = -3, x = 0, z = -6, alive = true },
			{ id = -4, x = 150, z = 150, alive = true },
		}
		-- three new bots by the kid, all deciding in the same frame; the others' karts are put
		-- far off, so the kid is the nearest for every one of them
		w.karts[2].x, w.karts[3].x, w.karts[4].z = 140, -140, -140
		local bots = {
			B.new(-1, 6, 6, 0, { easy = true }),
			B.new(-2, -6, 6, 0, { easy = true }),
			B.new(-3, 0, -6, 0, { easy = true }),
		}
		for k = 1, 10 do
			local hunters = B.hunters(bots)
			for _, b in bots do
				B.step(b, w, 0.05, k * 0.05, "Rockets", 3, hunters)
			end
		end
		truthy((B.hunters(bots)[1] or 0) <= B.TOKENS, "at most one on the kid")
	end
)

test("no shot past a rookie: the weapons' lock-on would take it onto them", function()
	local w = world()
	local bot = B.new(-1, 0, 0, 0, { skill = 1 })
	w.karts = {
		{ id = -1, x = 0, z = 0, alive = true },
		{ id = 201, x = 3, z = -30, alive = true, human = true, rookie = true },
		{ id = -2, x = 0, z = -60, alive = true },
	}
	-- shooting at -2 (60 ahead): the rookie 30 ahead, just off the line, is in the cone
	eq(B.rookieInLock(bot, w, 0, -60, 60), true)
	-- off to the side (60 degrees): clear
	w.karts[2].x, w.karts[2].z = 30, -17
	eq(B.rookieInLock(bot, w, 0, -60, 60), false)
	-- behind the target: the shot locks onto the target first
	w.karts[2].x, w.karts[2].z = 0, -80
	eq(B.rookieInLock(bot, w, 0, -60, 60), false)
	-- not a rookie any more: fair game
	w.karts[2].x, w.karts[2].z, w.karts[2].rookie = 3, -30, false
	eq(B.rookieInLock(bot, w, 0, -60, 60), false)
end)

test("stuck against a wall: backs up and gets away", function()
	local w = world()
	w.solids = { { x = 0, z = -12, r = 8 } }
	w.boxes = { { x = 0, z = -60 } }
	local bot = B.new(1, 0, 0, 0, { skill = 0.5 }) -- nose on the post, the box behind it
	run(bot, w, 6)
	truthy(bot.z < -30, "got round the post: " .. bot.z)
end)

-- ===== a match sim on the real arena (shared/ArenaData) =====

local Arena = require("../src/shared/ArenaData")

local function arena(): B.World
	local w = B.fromArena(Arena)
	for _, b in Arena.boxSpots do
		table.insert(w.boxes, { x = b.x, z = b.z })
	end
	return w
end

local SPAWNS = Arena.spawns
local PICK = Boxes.RADIUS -- big units: a kart this close takes a box
test(
	"the real arena: up the ramp to a box on the high hill, in through a gap to the sand",
	function()
		for _, case in
			{
				{ goal = { 170, 80 }, from = { 120, 140 }, name = "high hill" },
				{ goal = { 85, 130 }, from = { 150, 200 }, name = "sand" },
			}
		do
			local w = B.fromArena(Arena)
			local gx, gz = Arena.at(case.goal)
			local x, z = Arena.at(case.from)
			w.boxes = { { x = gx, z = gz } }
			local bot = B.new(1, x, z, 0, { skill = 0.5 })
			local closest, t = math.huge, 0
			while t < 15 and closest > 4 do
				t += 0.05
				B.step(bot, w, 0.05, t)
				closest = math.min(closest, math.sqrt((bot.x - gx) ^ 2 + (bot.z - gz) ^ 2))
			end
			truthy(closest <= 4, case.name .. ": got to the box (closest " .. closest .. ")")
		end
	end
)

local AMMO = { Rockets = 3, Gun = 6, Mine = 2 }
local KINDS = { "Rockets", "Gun", "Mine" }

-- One match of 8 karts (kart 1 plays the kid: a so-so driver with the same brain). Returns the
-- first smash's time (math.huge = none) and the longest a living bot went without moving 3 studs.
local function match(seed: number, secs: number): (number, number, number, number)
	local rng = B.rng(seed)
	local w = arena()
	local all = table.clone(w.boxes)
	local boxBack: { number } = {}
	local karts = {}
	for i = 1, 8 do
		local sp = SPAWNS[i]
		local x, z = sp.x, sp.z
		local id = if i == 1 then 1 else -i
		local brain = B.new(
			id,
			x,
			z,
			math.atan2(x, z),
			{ skill = if i == 1 then 0.35 else 0.3 + 0.1 * (i % 4), easy = true },
			B.rng(seed * 31 + i)
		)
		table.insert(karts, {
			id = id,
			brain = brain,
			hp = 100,
			alive = true,
			backAt = 0,
			shieldTo = 0,
			weapon = nil :: string?,
			ammo = 0,
			trail = {} :: { { t: number, x: number, z: number } },
		})
	end
	local mines = {}
	local bumped: { [string]: number } = {}
	local first = math.huge
	local worstStuck = 0
	local dt = 0.05
	local t = 0
	local smashes, kidSmashes = 0, 0
	local function smash(k: any, now: number, by: any?)
		smashes += 1
		if by and by.id == 1 then
			kidSmashes += 1
		end
		k.alive, k.hp, k.weapon, k.ammo, k.backAt = false, 0, nil, 0, now + 3
		k.trail = {}
		if now < first then
			first = now
		end
	end
	local function hurt(k: any, dmg: number, now: number, by: any?)
		-- (MatchRunner.damage: no bot hurts a new kid in their first NEW_KID_SAFE s)
		local safe = k.id == 1 and by ~= nil and by.id < 0 and now < Match.NEW_KID_SAFE
		if k.alive and now >= k.shieldTo and not safe then
			k.hp -= dmg
			if k.hp <= 0 then
				smash(k, now, by)
			end
		end
	end
	while t < secs do
		t += dt
		-- boxes back after 8 s
		w.boxes = {}
		for i, b in all do
			if (boxBack[i] or 0) <= t then
				table.insert(w.boxes, b)
			end
		end
		w.karts = {}
		for _, k in karts do
			table.insert(w.karts, {
				id = k.id,
				x = k.brain.x,
				z = k.brain.z,
				alive = k.alive,
				-- (the kid, in their first match: no bot goes for them in the first NEW_KID_SAFE s,
				-- as Match.forBots shows it, and bots go easy on a rookie)
				shield = t < k.shieldTo or (k.id == 1 and t < Match.NEW_KID_SAFE),
				human = k.id == 1,
				rookie = k.id == 1,
			})
		end
		local brains = {}
		for _, k in karts do
			if k.alive then
				table.insert(brains, k.brain)
			end
		end
		local hunters = B.hunters(brains)
		for _, k in karts do
			if not k.alive then
				if t >= k.backAt then
					-- back at the spawn farthest from everyone, with a 2 s shield
					local best, bestD = SPAWNS[1], -1
					for _, sp in SPAWNS do
						local x, z = sp.x, sp.z
						local near = math.huge
						for _, o in karts do
							if o.alive then
								near = math.min(near, (o.brain.x - x) ^ 2 + (o.brain.z - z) ^ 2)
							end
						end
						if near > bestD then
							best, bestD = sp, near
						end
					end
					local x, z = best.x, best.z
					k.brain = B.new(
						k.id,
						x,
						z,
						math.atan2(x, z),
						{ skill = k.brain.skill, easy = true },
						B.rng(rng:NextNumber() * 1e9)
					)
					k.alive, k.hp, k.shieldTo = true, 100, t + 2
				end
				continue
			end
			local s = B.step(k.brain, w, dt, t, k.weapon, k.ammo, hunters)
			-- pick up a box
			for i, b in all do
				if (boxBack[i] or 0) <= t and (b.x - s.x) ^ 2 + (b.z - s.z) ^ 2 < PICK * PICK then
					boxBack[i] = t + 8
					if not k.weapon or k.ammo <= 0 then
						k.weapon = KINDS[math.floor(rng:NextNumber() * 3) + 1]
						k.ammo = AMMO[k.weapon]
					end
				end
			end
			if s.fire and k.weapon and k.ammo > 0 then
				k.ammo -= 1
				local aim = s.fire
				if k.weapon == "Mine" then
					table.insert(mines, { x = s.x, z = s.z, owner = k.id, armAt = t + 0.5 })
				else
					local reach = if k.weapon == "Rockets" then 7 else 4
					local dmg = if k.weapon == "Rockets" then 40 else 12
					for _, o in karts do
						if
							o ~= k
							and o.alive
							and (o.brain.x - aim.x) ^ 2 + (o.brain.z - aim.z) ^ 2 < reach * reach
							and B.sight(w, s.x, s.z, o.brain.x, o.brain.z)
						then
							hurt(o, dmg, t, k)
							break
						end
					end
				end
				if k.ammo <= 0 then
					k.weapon = nil
				end
			end
			-- trail for the stuck check
			table.insert(k.trail, { t = t, x = s.x, z = s.z })
			while #k.trail > 0 and k.trail[1].t < t - 3 do
				table.remove(k.trail, 1)
			end
			-- stuck = hardly driving at all for 3 s (circling in a fight still counts as driving)
			local o = k.trail[1]
			if o and t - o.t > 2.9 then
				local moved = 0
				for i = 2, #k.trail do
					local a, b = k.trail[i - 1], k.trail[i]
					moved += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
				end
				if moved < 6 then
					if worstStuck == 0 then
						local pp = B.toPic(Arena, s.x, s.z)
						print(
							"STUCK",
							seed,
							k.id,
							t,
							s.x,
							s.z,
							pp[1],
							pp[2],
							k.weapon,
							k.brain.lostFor,
							k.brain.target
						)
					end
					worstStuck = math.max(worstStuck, 3)
				end
			end
		end
		-- mines and bumps
		for i = #mines, 1, -1 do
			local m = mines[i]
			for _, k in karts do
				if
					k.alive
					and k.id ~= m.owner
					and t >= m.armAt
					and (k.brain.x - m.x) ^ 2 + (k.brain.z - m.z) ^ 2 < 25
				then
					local owner = nil
					for _, o in karts do
						if o.id == m.owner then
							owner = o
						end
					end
					hurt(k, 50, t, owner)
					table.remove(mines, i)
					break
				end
			end
		end
		for i, a in karts do
			for j = i + 1, #karts do
				local b = karts[j]
				local key = i .. ":" .. j
				if
					a.alive
					and b.alive
					and (a.brain.x - b.brain.x) ^ 2 + (a.brain.z - b.brain.z) ^ 2 < 36
					and (bumped[key] or 0) <= t
				then
					bumped[key] = t + 1
					hurt(a, 10, t, b)
					hurt(b, 10, t, a)
				end
			end
		end
	end
	return first, worstStuck, smashes, kidSmashes
end

test(
	"match sim (the real arena, 8 karts, 3:00): first smash inside 30 s, at least 1 smash a kart-minute, the kid smashes someone, never stuck 3 s (20 of 20)",
	function()
		local times = {}
		local stuck = 0
		local fewest, kidFewest, total = math.huge, math.huge, 0
		for seed = 1, 20 do
			local first, worst, n, kid = match(seed, 180)
			print(
				string.format(
					"       seed %d: first %.1f s, %d smashes, kid %d",
					seed,
					first,
					n,
					kid
				)
			)
			table.insert(times, first)
			stuck = math.max(stuck, worst)
			fewest, kidFewest, total = math.min(fewest, n), math.min(kidFewest, kid), total + n
		end
		table.sort(times)
		print(
			string.format(
				"       first smash: fastest %.1f s, middle %.1f s, slowest %.1f s; smashes a match: fewest %d, average %.1f (%.2f a kart-minute); kid fewest %d",
				times[1],
				times[10],
				times[20],
				fewest,
				total / 20,
				total / 20 / 24,
				kidFewest
			)
		)
		truthy(times[20] <= 30, "slowest first smash " .. times[20])
		truthy(fewest >= 24, "fewest smashes in a match " .. fewest .. " (8 karts x 3 min = 24)")
		truthy(kidFewest >= 1, "the kid smashed nobody in a match")
		eq(stuck, 0)
	end
)
