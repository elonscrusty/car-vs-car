--!strict
-- Car soccer bot brain. Pure: no Roblox types, unit tested. Each frame it gets a view of the car,
-- the ball and the nearest rival, and returns steering, gas, boost and ability presses.
-- Keeps: a keeper that holds the goal, a chaser that goes round the ball (never pushes it toward
-- its own goal), no endless circling, no standing still, no reversing into its own goal.
-- Numbers: SoccerBotConfig (+ SoccerFieldConfig, BotLevels). The server (GroupMatch) drives with it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("SoccerBotConfig")
local Field = sibling("SoccerFieldConfig")
local SoccerField = sibling("SoccerField")
local Flow = sibling("SoccerFieldFlow")
local BotLevels = sibling("BotLevels")

local Rules = {}

export type Memory = {
	idle: number, -- seconds hardly moving
	wrong: number, -- seconds moving with the aim point far off the nose
	unstick: number, -- seconds left of an unstick manoeuvre
	unstickSign: number, -- -1 / 1: which way it steers during it
	unstickBack: boolean, -- reversing during it
}

export type View = {
	now: number,
	seed: number,
	team: number, -- 1 defends the -X goal, 2 the +X goal
	isKeeper: boolean,
	x: number,
	z: number,
	fx: number, -- unit nose direction (flat)
	fz: number,
	speed: number, -- speed along the nose (negative = reversing)
	maxSpeed: number,
	bx: number,
	bz: number,
	bvx: number,
	bvz: number,
	hasRival: boolean,
	rx: number, -- nearest rival car
	rz: number,
	boostReady: boolean,
	specialReady: boolean,
	kind: string, -- ability kind ("" = none)
	radius: number,
	level: any, -- BotLevels.Level
	useMoves: boolean,
}

export type Cmd = {
	steer: number, -- -1 left .. 1 right (same as a player's)
	throttle: number, -- -1 .. 1
	boost: boolean,
	special: boolean,
	tx: number,
	tz: number,
}

function Rules.newMemory(): Memory
	return { idle = 0, wrong = 0, unstick = 0, unstickSign = 1, unstickBack = false }
end

local function hash01(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function signedAngle(fx: number, fz: number, tx: number, tz: number): number
	return math.atan2(fz * tx - fx * tz, fx * tx + fz * tz)
end

local function ownSign(team: number): number
	return if team == 1 then -1 else 1
end

-- Reversing from (x, z) along -nose: would the car reach the own goal mouth within `look` studs?
function Rules.reverseUnsafe(team: number, x: number, z: number, fx: number, fz: number): boolean
	local s = ownSign(team)
	local dx, dz = -fx, -fz
	if dx * s <= 0.05 then
		return false -- backing away from (or along) its own goal line
	end
	local t = (s * Field.length / 2 - x) / dx -- distance along the backward line to the goal line
	if t < 0 or t > Config.reverseLook then
		return false
	end
	return math.abs(z + dz * t) <= Field.goalWidth / 2 + Config.reverseGoalPad
end

-- Distance from the point (px, pz) to the segment a -> b.
local function segDist(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	px: number,
	pz: number
): number
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = if l2 < 1e-9 then 0 else math.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1)
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function clampField(x: number, z: number): (number, number)
	local hx = Field.length / 2 - Config.aimMargin
	local hz = Field.width / 2 - Config.aimMargin
	return math.clamp(x, -hx, hx), math.clamp(z, -hz, hz)
end

-- Free run ahead along the nose before a side wall / end wall.
local function runAhead(x: number, z: number, fx: number, fz: number): number
	local best = math.huge
	local hz = Field.width / 2
	if fz > 1e-4 then
		best = math.min(best, (hz - z) / fz)
	elseif fz < -1e-4 then
		best = math.min(best, (-hz - z) / fz)
	end
	local hx = Field.length / 2
	if fx > 1e-4 then
		best = math.min(best, (hx - x) / fx)
	elseif fx < -1e-4 then
		best = math.min(best, (-hx - x) / fx)
	end
	return math.max(best, 0)
end

-- Where the bot drives: the ball (led a little), going round it when needed. Returns the point
-- and whether it is the keeper's post.
function Rules.aim(v: View): (number, number, boolean)
	local dist = math.sqrt((v.bx - v.x) ^ 2 + (v.bz - v.z) ^ 2)
	local t = math.min(Config.leadMax, dist / math.max(math.abs(v.speed), 12))
	local lbx, lbz = clampField(v.bx + v.bvx * t, v.bz + v.bvz * t)
	local tx, tz = Flow.botAim(v.isKeeper, v.team, lbx, lbz, v.x, v.z)
	if v.isKeeper then
		local kx, kz = Flow.keeperTarget(v.team, lbz)
		if tx == kx and tz == kz then
			return tx, tz, true
		end
	end
	if tx == lbx and tz == lbz then
		return lbx, lbz, false -- lined up: straight at the ball
	end
	tx, tz = clampField(tx, tz) -- staging point behind the ball: stay on the field
	-- Would the straight path to it brush the ball? Swing out to the car's side of the ball.
	if segDist(v.x, v.z, tx, tz, v.bx, v.bz) < Config.detourClear then
		local ax, az = SoccerField.attackPoint(v.team)
		local dx, dz = ax - v.bx, az - v.bz
		local l = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		dx, dz = dx / l, dz / l
		local side = if dx * (v.z - v.bz) - dz * (v.x - v.bx) >= 0 then 1 else -1
		local wx, wz =
			clampField(v.bx - dz * side * Config.detourSide, v.bz + dx * side * Config.detourSide)
		return wx, wz, false
	end
	return tx, tz, false
end

-- Boost / ability presses: level's moveUse sets how often a good chance is taken.
local function wantMoves(
	v: View,
	mem: Memory,
	angle: number,
	tx: number,
	tz: number,
	holding: boolean
): (boolean, boolean)
	if not v.useMoves or holding then
		return false, false
	end
	if hash01(math.floor(v.now / Config.moveCheck), v.seed) >= v.level.moveUse then
		return false, false
	end
	local dist = math.sqrt((tx - v.x) ^ 2 + (tz - v.z) ^ 2)
	local bdist = math.sqrt((v.bx - v.x) ^ 2 + (v.bz - v.z) ^ 2)
	local aimed = math.abs(angle) < math.rad(Config.boostAimDeg)
	local slow = v.speed < v.maxSpeed * Config.boostSpeedShare
	local toOwn = (v.fx * ownSign(v.team)) > Config.boostOwnGoalDot
	-- Lane: wall room for a boosted run, no rival in the way.
	local run = math.max(v.speed, v.maxSpeed * Config.boostTopShare * 0.6) * Config.boostRunTime
	local clear = runAhead(v.x, v.z, v.fx, v.fz) > run
	local rdist = math.huge
	if v.hasRival then
		local rdx, rdz = v.rx - v.x, v.rz - v.z
		rdist = math.sqrt(rdx * rdx + rdz * rdz)
		local ahead = rdx * v.fx + rdz * v.fz
		local side = math.abs(rdx * v.fz - rdz * v.fx)
		if ahead > 0 and ahead < Config.boostEnemyAhead and side < Config.boostEnemyCone then
			clear = false
		end
	end
	local boost = v.boostReady
		and mem.unstick <= 0
		and not v.isKeeper
		and slow
		and aimed
		and not toOwn
		and clear
		and dist >= Config.boostMinDist
		and dist <= Config.boostMaxDist
	local special = false
	if v.specialReady and v.kind ~= "" then
		local k = v.kind
		local reach = math.max(v.radius, 1)
		local ballAngle = signedAngle(v.fx, v.fz, v.bx - v.x, v.bz - v.z)
		if k == "dash" then
			special = slow
				and aimed
				and not toOwn
				and clear
				and dist >= Config.dashMin
				and dist <= Config.dashMax
		elseif k == "slam" then
			special = bdist <= reach * 0.8 and not v.isKeeper
		elseif k == "magnet" then
			special = rdist >= reach * 0.35 and rdist <= reach * 0.95
		elseif k == "ram" then
			special = math.abs(ballAngle) < math.rad(Config.ramAngleDeg)
				and bdist <= Config.ramDist
				and not toOwn
		elseif k == "shield" then
			special = rdist <= Config.shieldDist
		elseif k == "jump" then
			special = v.isKeeper and bdist <= Config.jumpDist
		end
	end
	return boost, special
end

local function cmd(steer: number, throttle: number, tx: number, tz: number): Cmd
	return { steer = steer, throttle = throttle, boost = false, special = false, tx = tx, tz = tz }
end

-- One frame. Updates `mem` and returns what to do.
function Rules.step(mem: Memory, v: View, dt: number): Cmd
	local lv = v.level
	local tx, tz, holding = Rules.aim(v)
	local dist = math.sqrt((tx - v.x) ^ 2 + (tz - v.z) ^ 2)
	local angle = signedAngle(v.fx, v.fz, tx - v.x, tz - v.z)
	if not holding and dist > 20 then
		angle += math.rad(BotLevels.wanderOffsetDeg(lv, v.now, v.seed))
	end
	local steerFull = Config.steerFullRad / math.max(lv.turnGainMult, 0.2)

	-- Keeper on its post: stop, face the ball.
	if holding and dist < Config.keeperHold then
		mem.idle, mem.wrong, mem.unstick = 0, 0, 0
		local ba = signedAngle(v.fx, v.fz, v.bx - v.x, v.bz - v.z)
		return cmd(-math.clamp(ba / steerFull, -1, 1), 0, tx, tz)
	end

	-- Standing still too long: back off / swing out for a moment.
	if mem.unstick <= 0 then
		if math.abs(v.speed) < Config.idleSpeed then
			mem.idle += dt
		else
			mem.idle = 0
		end
		if mem.idle >= BotLevels.stuckLimit(lv, Config.idleSeconds) then
			mem.idle = 0
			mem.unstick = Config.unstickSeconds
			mem.unstickSign = if hash01(math.floor(v.now), v.seed) < 0.5 then -1 else 1
			mem.unstickBack = not Rules.reverseUnsafe(v.team, v.x, v.z, v.fx, v.fz)
		end
	end
	if mem.unstick > 0 then
		mem.unstick -= dt
		return cmd(mem.unstickSign, if mem.unstickBack then -1 else 0.8, tx, tz)
	end

	-- Circling: aim point stays off the nose while moving -> slow down and turn in.
	if math.abs(angle) > math.rad(Config.circleAngleDeg) and v.speed > Config.circleSpeed then
		mem.wrong += dt
	else
		mem.wrong = math.max(0, mem.wrong - dt * 2)
	end

	local throttle = math.max(Config.minThrottle, math.cos(angle))
	if math.abs(angle) > math.rad(Config.tightAngleDeg) then
		if mem.wrong > Config.circleSeconds then
			throttle = 0 -- brake: a slower car turns on the spot
		elseif dist < Config.tightDist then
			throttle = Config.tightThrottle
		end
	end
	local steer = -math.clamp(angle / steerFull, -1, 1)

	-- Target close and right behind: back onto it, unless that points at the own goal.
	if
		math.abs(angle) > math.rad(130)
		and dist < Config.reverseNear
		and not holding
		and not Rules.reverseUnsafe(v.team, v.x, v.z, v.fx, v.fz)
	then
		throttle = -0.8
		local rear = angle - (if angle > 0 then math.pi else -math.pi)
		steer = -math.clamp(rear / steerFull, -1, 1)
	end

	if throttle > 0 and lv.speedMult < 1 and v.speed > v.maxSpeed * lv.speedMult then
		throttle = 0 -- slower bot: coast above its lower top speed
	end
	local out = cmd(steer, throttle, tx, tz)
	out.boost, out.special = wantMoves(v, mem, angle, tx, tz, holding)
	return out
end

return Rules
