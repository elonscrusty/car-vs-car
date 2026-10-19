--!strict
-- A flat 2D copy of the auto-battle for tests: cars drive by BattleBrain, shells fly, HP drops.
-- It mirrors the server rules (arena, limits, hit regions) closely enough to catch one-sided or
-- stuck behavior. It is NOT the real physics.

local BattleBrain = require("../src/shared/BattleBrain")
local BattleConfig = require("../src/shared/BattleConfig")
local BattleSeries = require("../src/shared/BattleSeries")

local DEG = math.pi / 180

export type Car = {
	id: string,
	L: number,
	x: number,
	z: number,
	fx: number,
	fz: number,
	speed: number,
	hp: number,
	maxHp: number,
	brain: BattleBrain.Brain,
	hits: number, -- damage events dealt
	log: { { t: number, kind: string } },
}

local Sim = {}

local function arenaOf(): BattleBrain.Arena
	local a = BattleConfig.Arena
	return { halfX = a.halfX, halfZ = a.halfZ, obstacles = a.obstacles }
end
Sim.arena = arenaOf

function Sim.car(id: string, x: number, z: number, fx: number, fz: number): Car
	local f = BattleConfig.Fighters[id]
	local L = f.lengthStuds
	return {
		id = id,
		L = L,
		x = x,
		z = z,
		fx = fx,
		fz = fz,
		speed = 0,
		hp = f.hp,
		maxHp = f.hp,
		brain = BattleBrain.new(id, L, arenaOf()),
		hits = 0,
		log = {},
	}
end

local function pushOutOfBoxes(c: Car, arena: BattleBrain.Arena)
	local r = 0.45 * c.L
	for _, ob in arena.obstacles do
		local nx = math.clamp(c.x, ob.x - ob.hx, ob.x + ob.hx)
		local nz = math.clamp(c.z, ob.z - ob.hz, ob.z + ob.hz)
		local vx, vz = c.x - nx, c.z - nz
		local d = math.sqrt(vx * vx + vz * vz)
		if d < r then
			if d < 1e-4 then
				vx, vz, d =
					c.x - ob.x,
					c.z - ob.z,
					math.max(math.sqrt((c.x - ob.x) ^ 2 + (c.z - ob.z) ^ 2), 1e-3)
			end
			c.x += vx / d * (r - d)
			c.z += vz / d * (r - d)
			c.speed *= 0.3
		end
	end
end

local function move(c: Car, out: BattleBrain.Output, dt: number, arena: BattleBrain.Arena)
	local f = BattleConfig.Fighters[c.id]
	local cruise = f.cruiseL * c.L
	local want = out.drive * cruise
	if want < 0 then
		want *= BattleConfig.Move.reverseScale
	end
	local rate = if math.abs(want) > math.abs(c.speed)
		then BattleConfig.Move.accel
		else BattleConfig.Move.brake
	local step = rate * cruise * dt
	c.speed += math.clamp(want - c.speed, -step, step)
	-- no turning when standing still, full turn from a little speed up
	local turnScale = math.clamp(math.abs(c.speed) / (0.5 * cruise) + 0.35, 0, 1)
	if out.state == "charge" then
		turnScale = 0
	end
	local ang = out.turn * f.turnDeg * DEG * dt * turnScale
	local cs, sn = math.cos(ang), math.sin(ang)
	-- positive angle = counterclockwise = left
	c.fx, c.fz = c.fx * cs + c.fz * sn, -c.fx * sn + c.fz * cs
	c.x += c.fx * c.speed * dt
	c.z += c.fz * c.speed * dt
	local r = 0.45 * c.L
	local limX, limZ = arena.halfX - r, arena.halfZ - r
	if math.abs(c.x) > limX or math.abs(c.z) > limZ then
		c.x = math.clamp(c.x, -limX, limX)
		c.z = math.clamp(c.z, -limZ, limZ)
		c.speed *= 0.2
	end
	pushOutOfBoxes(c, arena)
end

local function contactOf(me: Car, foe: Car): BattleBrain.Contact
	local dx, dz = foe.x - me.x, foe.z - me.z
	local along = dx * me.fx + dz * me.fz
	local lateral = math.abs(-dx * me.fz + dz * me.fx)
	local inBox = along >= 0.2 * me.L and along <= 1.0 * me.L and lateral <= 0.45 * me.L
	return { ram = inBox, saw = inBox }
end

export type Result = { outcome: BattleSeries.Outcome, seconds: number, a: Car, b: Car }

-- One fight. `seed` mixes the start spots a little so repeats differ.
function Sim.fight(idA: string, idB: string, swap: boolean, seed: number): Result
	math.randomseed(seed)
	local arena = arenaOf()
	local inset = BattleConfig.Arena.spawnInset
	local ax, bx = -(arena.halfX - inset), arena.halfX - inset
	local jz = (math.random() * 16 - 8)
	local a = Sim.car(idA, if swap then bx else ax, jz, if swap then -1 else 1, 0)
	local b = Sim.car(idB, if swap then ax else bx, -jz, if swap then 1 else -1, 0)
	local dt = 1 / 30
	local t = 0
	local shells: { { owner: Car, foe: Car, x: number, z: number, dx: number, dz: number, life: number } } =
		{}
	local cannon = BattleConfig.Cannon
	local outcome: BattleSeries.Outcome? = nil
	local total = BattleConfig.Timing.fightSeconds
	while outcome == nil do
		t += dt
		local dmgA, dmgB = 0, 0
		for _, pair in { { a, b }, { b, a } } do
			local me, foe = pair[1], pair[2]
			local out = me.brain.step(
				dt,
				{ x = me.x, z = me.z, fx = me.fx, fz = me.fz },
				{ x = foe.x, z = foe.z, fx = foe.fx, fz = foe.fz },
				contactOf(me, foe)
			)
			move(me, out, dt, arena)
			if out.fire then
				table.insert(shells, {
					owner = me,
					foe = foe,
					x = me.x + me.fx * 0.425 * me.L,
					z = me.z + me.fz * 0.425 * me.L,
					dx = me.fx,
					dz = me.fz,
					life = cannon.shellLifeSeconds,
				})
				table.insert(me.log, { t = t, kind = "fire" })
			end
			if out.damage > 0 then
				me.hits += 1
				table.insert(me.log, { t = t, kind = "melee" })
				if me == a then
					dmgB += out.damage
				else
					dmgA += out.damage
				end
			end
		end
		-- shells
		for i = #shells, 1, -1 do
			local s = shells[i]
			local v = cannon.shellSpeedL * s.owner.L * dt
			s.x += s.dx * v
			s.z += s.dz * v
			s.life -= dt
			local gone = s.life <= 0
			local hit = false
			if math.abs(s.x) > arena.halfX or math.abs(s.z) > arena.halfZ then
				gone = true
			end
			for _, ob in arena.obstacles do
				if math.abs(s.x - ob.x) < ob.hx and math.abs(s.z - ob.z) < ob.hz then
					gone = true
				end
			end
			local d = math.sqrt((s.x - s.foe.x) ^ 2 + (s.z - s.foe.z) ^ 2)
			if d < 0.45 * s.foe.L + cannon.shellRadiusL * s.owner.L then
				hit, gone = true, true
				s.owner.hits += 1
				if s.foe == a then
					dmgA += cannon.damage
				else
					dmgB += cannon.damage
				end
				table.insert(s.owner.log, { t = t, kind = "shellHit" })
			end
			if gone then
				if not hit then
					table.insert(s.owner.log, { t = t, kind = "shellMiss" })
				end
				table.remove(shells, i)
			end
		end
		-- cars push each other apart
		local sx, sz = b.x - a.x, b.z - a.z
		local sd = math.max(math.sqrt(sx * sx + sz * sz), 1e-3)
		local minD = 0.5 * (a.L + b.L) * 0.75
		if sd < minD then
			local push = (minD - sd) / 2
			a.x -= sx / sd * push
			a.z -= sz / sd * push
			b.x += sx / sd * push
			b.z += sz / sd * push
			a.speed *= 0.6
			b.speed *= 0.6
		end
		a.hp = math.max(0, a.hp - dmgA)
		b.hp = math.max(0, b.hp - dmgB)
		outcome = BattleSeries.roundOutcome(a.hp, a.maxHp, b.hp, b.maxHp, t >= total)
	end
	return { outcome = outcome :: BattleSeries.Outcome, seconds = t, a = a, b = b }
end

return Sim
