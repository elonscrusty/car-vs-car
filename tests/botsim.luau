--!strict
-- Tiny headless 2D kinematic duel sim for the bot brain. No Roblox. It runs the REAL pure rules
-- (Ai, BotLevels, Abilities, Moves, Damage, Logic) with the real numbers from the configs, on a
-- flat X/Z plane, and models the bowl as: flat disc, then an inward slope pull, then a low lip.
-- The physics here is a MODEL (a simplified stand-in for Roblox), so the numbers it prints say
-- "the rules behave", not "the live game feels exactly like this". Sim-only guesses are in SIM.

local Abilities = require("../src/shared/Abilities")
local Ai = require("../src/shared/Ai")
local BotLevels = require("../src/shared/BotLevels")
local CarConfig = require("../src/shared/CarConfig")
local CombatConfig = require("../src/shared/CombatConfig")
local Damage = require("../src/shared/Damage")
local GameConfig = require("../src/shared/GameConfig")
local Logic = require("../src/shared/Logic")
local Moves = require("../src/shared/Moves")
local MovesConfig = require("../src/shared/MovesConfig")

local Sim: any = {}

-- Sim-only guesses (not game numbers).
local SIM = {
	dt = 1 / 30,
	gravity = 196.2, -- Workspace.Gravity default
	lipOutSpeed = 35, -- going out faster than this at the rim = over the lip = ring-out
	lipBounce = 0.4, -- slower than that: bounces back off the lip
	bleed = 40, -- studs/s^2 lost above top speed (rolling friction guess)
	restitution = 0.4, -- car-vs-car bounce
	accidentWindow = 2, -- ring-out with no contact for this many seconds = "by accident"
}

export type Car = {
	idx: number,
	stats: CarConfig.CarStats,
	lv: BotLevels.Level,
	mem: Ai.Memory,
	ability: Abilities.Ability?,
	x: number,
	z: number,
	vx: number,
	vz: number,
	fx: number,
	fz: number,
	hp: number,
	boostAt: number,
	specialAt: number,
	shieldUntil: number,
	ramUntil: number,
	lastContact: number,
	out: boolean,
}

export type Result = {
	winner: number, -- 1, 2 or 0 (draw)
	seconds: number,
	firstContact: number, -- math.huge = never touched
	contacts: number,
	ringOut: boolean,
	accident: boolean, -- somebody left the bowl with no contact in the last accidentWindow s
	boosts: number,
	specials: number,
}

-- Small deterministic random numbers (so the 200 duels are the same every run).
local function makeRng(seed: number): () -> number
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end
Sim.makeRng = makeRng

local function rot(x: number, z: number, ang: number): (number, number)
	local c, s = math.cos(ang), math.sin(ang)
	return x * c + z * s, -x * s + z * c
end

local function newCar(idx: number, carId: string, lv: BotLevels.Level): Car
	local stats = CarConfig.Cars[carId]
	local mem = Ai.newMemory(stats.ai, if idx == 1 then 1 else -1)
	mem.runUp = lv.runUpMult
	return {
		idx = idx,
		stats = stats,
		lv = lv,
		mem = mem,
		ability = Abilities.forCar(stats :: any),
		x = 0,
		z = 0,
		vx = 0,
		vz = 0,
		fx = 0,
		fz = 1,
		hp = stats.hp,
		boostAt = -math.huge,
		specialAt = -math.huge,
		shieldUntil = 0,
		ramUntil = 0,
		lastContact = -math.huge,
		out = false,
	}
end

local function radiusOf(c: Car): number
	return (c.stats.size[1] + c.stats.size[3]) / 4
end

-- One bot (or "decent human": a perfect-aim medium bot that uses its moves well) drives a frame.
local function drive(
	c: Car,
	e: Car,
	now: number,
	dt: number,
	count: { boosts: number, specials: number }
)
	local P = GameConfig.Ai
	local lv = c.lv
	local stats = c.stats
	local speed = math.sqrt(c.vx * c.vx + c.vz * c.vz)
	c.mem.vx, c.mem.vz, c.mem.fx, c.mem.fz = c.vx, c.vz, c.fx, c.fz
	c.mem.evx, c.mem.evz, c.mem.lead = e.vx, e.vz, lv.lead
	c.mem.runUp, c.mem.accel, c.mem.turnRate = lv.runUpMult, stats.accel, stats.turnRate
	Ai.noteSpeed(c.mem, speed, dt, BotLevels.stuckLimit(lv, P.stuckSeconds), P.retreatTime)
	local center = { x = 0, z = 0 }
	local cmd = Ai.decide(
		stats.ai,
		{ x = c.x, z = c.z },
		{ x = e.x, z = e.z },
		c.mem,
		dt,
		P,
		center
	)
	local angle = Ai.signedAngle(c.fx, c.fz, cmd.tx - c.x, cmd.tz - c.z)
	angle += math.rad(BotLevels.wanderOffsetDeg(lv, now, c.idx))

	-- Boost and ability decisions.
	local toEx, toEz = e.x - c.x, e.z - c.z
	local dist = math.sqrt(toEx * toEx + toEz * toEz)
	local toEnemy = Ai.signedAngle(c.fx, c.fz, toEx, toEz)
	local ab = c.ability
	local boostReady = Moves.ready(c.boostAt, MovesConfig.Boost.cooldown, now)
	local specialReady = ab ~= nil and Moves.ready(c.specialAt, ab.cooldown, now)
	local wantBoost, wantSpecial = Ai.wantMoves({
		now = now,
		seed = c.idx,
		dist = dist,
		angle = toEnemy,
		me = { x = c.x, z = c.z },
		fx = c.fx,
		fz = c.fz,
		center = center,
		hpShare = c.hp / stats.hp,
		speed = c.vx * c.fx + c.vz * c.fz,
		maxSpeed = stats.maxSpeed,
		accel = stats.accel,
		dashForward = if ab then ab.dashForward else 0,
		boostReady = boostReady,
		specialReady = specialReady,
		kind = if ab then ab.kind else "",
		radius = if ab then ab.radius else 0,
		moveUse = lv.moveUse,
	}, P)
	if wantBoost then
		c.boostAt = now
		c.vx += c.fx * MovesConfig.Boost.kick
		c.vz += c.fz * MovesConfig.Boost.kick
		count.boosts += 1
	end
	if wantSpecial and ab then
		c.specialAt = now
		count.specials += 1
		if ab.kind == "dash" then
			c.vx += c.fx * ab.dashForward
			c.vz += c.fz * ab.dashForward
		elseif ab.kind == "shield" then
			c.shieldUntil = now + ab.seconds
		elseif ab.kind == "ram" then
			c.ramUntil = now + ab.seconds
		elseif (ab.kind == "slam" or ab.kind == "magnet") and dist < ab.radius and dist > 0.01 then
			local sign = if ab.kind == "slam" then 1 else -1
			local k = math.clamp(60 / e.stats.mass, 0.4, 1.6)
			e.vx += toEx / dist * ab.push * k * sign
			e.vz += toEz / dist * ab.push * k * sign
		end
	end
	local sinceBoost = now - c.boostAt
	local speedScale = Moves.boostSpeedMult(sinceBoost, MovesConfig.Boost)
	local accelScale = Moves.boostAccelMult(sinceBoost, MovesConfig.Boost)

	-- Steer and gas (same as server/Autopilot.step).
	local spin = Ai.steer(angle, GameConfig.Drive.turnGain * lv.turnGainMult, stats.turnRate)
	c.fx, c.fz = rot(c.fx, c.fz, spin * dt)
	local throttle = Ai.driveScale(angle, cmd.throttle)
	local fwdSpeed = c.vx * c.fx + c.vz * c.fz
	local maxSpeed = stats.maxSpeed * speedScale
	if throttle > 0 and lv.speedMult < 1 and fwdSpeed > stats.maxSpeed * lv.speedMult then
		throttle = 0
	end

	-- Slope pull toward the middle (cancelled along the nose while the gas is on, like slopeAssist).
	local r = math.sqrt(c.x * c.x + c.z * c.z)
	local gx, gz = 0, 0
	if r > GameConfig.Arena.flatRadius then
		local pull = SIM.gravity * math.sin(math.rad(GameConfig.Arena.tiltDeg))
		gx, gz = -c.x / r * pull, -c.z / r * pull
	end
	c.vx += gx * dt
	c.vz += gz * dt
	if (throttle > 0 and fwdSpeed < maxSpeed) or (throttle < 0 and fwdSpeed > -maxSpeed * 0.6) then
		c.vx += c.fx * throttle * stats.accel * accelScale * dt
		c.vz += c.fz * throttle * stats.accel * accelScale * dt
		local along = gx * c.fx + gz * c.fz
		if throttle > 0 and along < 0 then
			c.vx += c.fx * -along * GameConfig.Drive.slopeAssist * dt
			c.vz += c.fz * -along * GameConfig.Drive.slopeAssist * dt
		end
	end
	if
		lv.speedMult > 1
		and throttle > 0
		and fwdSpeed >= stats.maxSpeed
		and fwdSpeed < stats.maxSpeed * lv.speedMult
	then
		c.vx += c.fx * stats.accel * dt
		c.vz += c.fz * stats.accel * dt
	end
	-- Side grip.
	local rx, rz = -c.fz, c.fx
	local side = c.vx * rx + c.vz * rz
	local k = math.min(1, GameConfig.Drive.grip * dt)
	c.vx -= rx * side * k
	c.vz -= rz * side * k
	-- Rolling loss above top speed.
	local sp = math.sqrt(c.vx * c.vx + c.vz * c.vz)
	local cap = math.max(maxSpeed, stats.maxSpeed * lv.speedMult)
	if sp > cap * 1.02 then
		local cut = math.min(sp - cap, SIM.bleed * dt)
		c.vx -= c.vx / sp * cut
		c.vz -= c.vz / sp * cut
	end
end

local function move(c: Car, dt: number): boolean
	c.x += c.vx * dt
	c.z += c.vz * dt
	local rim = GameConfig.Arena.rimRadius
	local r = math.sqrt(c.x * c.x + c.z * c.z)
	if r >= rim then
		local ux, uz = c.x / r, c.z / r
		local vOut = c.vx * ux + c.vz * uz
		if vOut > SIM.lipOutSpeed then
			return true
		end
		if vOut > 0 then
			c.vx -= ux * vOut * (1 + SIM.lipBounce)
			c.vz -= uz * vOut * (1 + SIM.lipBounce)
		end
		c.x, c.z = ux * (rim - 0.01), uz * (rim - 0.01)
	end
	return false
end

-- Run one duel. `levels`: bot level names per side; `human1`/`human2`: that side is a "decent
-- human" (perfect launch, medium driving, good move use) instead of a bot of that level.
-- `badLaunch`: launches are sloppy (stress case: nobody comes in straight).
export type Setup = {
	cars: { string },
	levels: { string },
	humans: { boolean }?,
	badLaunch: boolean?,
	seed: number,
}

local HUMAN: BotLevels.Level = {
	name = "human",
	noiseDeg = 0,
	powerMin = 0.85,
	powerMax = 1,
	turnGainMult = 1.2,
	speedMult = 1,
	wanderEvery = 0,
	wanderDeg = 0,
	wanderFade = 1,
	runUpMult = 1.2,
	rewardMult = 1,
	moveUse = 0.9,
	lead = 0.5,
}

function Sim.duel(setup: Setup): Result
	local rng = makeRng(setup.seed)
	local dt = SIM.dt
	local cars: { Car } = {}
	for i = 1, 2 do
		local human = setup.humans ~= nil and setup.humans[i]
		local lv = if human then HUMAN else BotLevels.get(setup.levels[i])
		cars[i] = newCar(i, setup.cars[i], lv)
	end
	-- Launch: from opposite spawn spots, aimed at the other car with the level's noise and power.
	local spawn = GameConfig.Arena.spawnRadius
	local startAngle = rng() * math.pi * 2
	for i = 1, 2 do
		local c = cars[i]
		local sgn = if i == 1 then 1 else -1
		c.x, c.z = math.cos(startAngle) * spawn * sgn, math.sin(startAngle) * spawn * sgn
		local aimX, aimZ = -c.x, -c.z
		local len = math.sqrt(aimX * aimX + aimZ * aimZ)
		aimX, aimZ = aimX / len, aimZ / len
		local noise = (rng() * 2 - 1) * c.lv.noiseDeg
		local power = BotLevels.launchPower(c.lv, rng())
		if setup.badLaunch then
			noise = (rng() * 2 - 1) * 90
			power = rng() * 0.3
		end
		c.fx, c.fz = rot(aimX, aimZ, math.rad(noise))
		local speed = GameConfig.Launch.minSpeed
			+ (GameConfig.Launch.maxSpeed - GameConfig.Launch.minSpeed) * power
		c.vx, c.vz = c.fx * speed, c.fz * speed
	end

	local res: Result = {
		winner = 0,
		seconds = GameConfig.Match.maxMatchSeconds,
		firstContact = math.huge,
		contacts = 0,
		ringOut = false,
		accident = false,
		boosts = 0,
		specials = 0,
	}
	local count = { boosts = 0, specials = 0 }
	local lastHitAt = -math.huge
	local touching = false
	local steps = math.floor(GameConfig.Match.maxMatchSeconds / dt)
	for step = 1, steps do
		local now = step * dt
		local a, b = cars[1], cars[2]
		-- Velocities before this frame's collision (damage uses the closing speed).
		drive(a, b, now, dt, count)
		drive(b, a, now, dt, count)
		local pa, pb = { vx = a.vx, vz = a.vz }, { vx = b.vx, vz = b.vz }
		local outA, outB = move(a, dt), move(b, dt)
		if Sim.trace then
			Sim.trace(now, a, b)
		end
		if outA or outB then
			res.ringOut = true
			res.seconds = now
			-- A ring-out is an accident when the car that left had not been touched lately.
			local function lone(c: Car): boolean
				return now - c.lastContact > SIM.accidentWindow
			end
			if outA and outB then
				res.winner = 0
			elseif outA then
				res.winner = 2
			else
				res.winner = 1
			end
			res.accident = (outA and lone(a)) or (outB and lone(b))
			break
		end
		-- Car vs car.
		local dx, dz = b.x - a.x, b.z - a.z
		local d = math.sqrt(dx * dx + dz * dz)
		local minD = radiusOf(a) + radiusOf(b)
		if d < minD and d > 0.001 then
			local nx, nz = dx / d, dz / d
			if not touching then
				touching = true
				res.contacts += 1
				if res.firstContact == math.huge then
					res.firstContact = now
				end
			end
			a.lastContact, b.lastContact = now, now
			local closing = (a.vx - b.vx) * nx + (a.vz - b.vz) * nz
			if closing > 0 then
				local rel = math.sqrt((pa.vx - pb.vx) ^ 2 + (pa.vz - pb.vz) ^ 2)
				if now - lastHitAt >= GameConfig.Damage.hitCooldown then
					local atkA = (pa.vx * nx + pa.vz * nz) > -(pb.vx * nx + pb.vz * nz)
					local atk, def = if atkA then a else b, if atkA then b else a
					local dmg = Logic.impactDamage(
						rel,
						atk.stats.damageMult,
						GameConfig.Damage.scale,
						GameConfig.Damage.minImpactSpeed
					)
					if dmg > 0 then
						local look = Damage.cosFlat(def.fx, def.fz, atk.x - def.x, atk.z - def.z)
						dmg *= Damage.zoneMult(
							Damage.zone(look, CombatConfig.Zones),
							CombatConfig.Zones
						)
						if now < atk.ramUntil and atk.ability then
							dmg *= atk.ability.damageMult
						end
						if now < def.shieldUntil then
							def.shieldUntil = 0
							dmg = 0
						end
						def.hp = math.max(0, def.hp - dmg)
						lastHitAt = now
						a.mem.hit, b.mem.hit = true, true
					end
				end
				local ma, mb = a.stats.mass, b.stats.mass
				local j = (1 + SIM.restitution) * closing / (1 / ma + 1 / mb)
				a.vx -= j / ma * nx
				a.vz -= j / ma * nz
				b.vx += j / mb * nx
				b.vz += j / mb * nz
			end
			local push = (minD - d) / 2
			a.x -= nx * push
			a.z -= nz * push
			b.x += nx * push
			b.z += nz * push
		else
			touching = false
		end
		if a.hp <= 0 or b.hp <= 0 then
			res.seconds = now
			res.winner = if a.hp <= 0 and b.hp <= 0 then 0 elseif a.hp <= 0 then 2 else 1
			break
		end
	end
	if res.seconds >= GameConfig.Match.maxMatchSeconds and not res.ringOut then
		-- Time up: higher HP wins.
		local a, b = cars[1], cars[2]
		res.winner = if a.hp > b.hp then 1 elseif b.hp > a.hp then 2 else 0
	end
	res.boosts, res.specials = count.boosts, count.specials
	return res
end

-- A batch of duels with random cars from the roster. Returns every result.
function Sim.batch(
	n: number,
	seed: number,
	levels: { string },
	humans: { boolean }?,
	badLaunch: boolean?
): { Result }
	local rng = makeRng(seed)
	local out: { Result } = {}
	local order = CarConfig.Order
	for i = 1, n do
		local carA = order[math.floor(rng() * #order) + 1]
		local carB = order[math.floor(rng() * #order) + 1]
		out[i] = Sim.duel({
			cars = { carA, carB },
			levels = levels,
			humans = humans,
			badLaunch = badLaunch,
			seed = seed * 1000 + i,
		})
	end
	return out
end

function Sim.median(list: { number }): number
	local copy = table.clone(list)
	table.sort(copy)
	if #copy == 0 then
		return 0
	end
	return copy[math.floor((#copy + 1) / 2)]
end

return Sim
