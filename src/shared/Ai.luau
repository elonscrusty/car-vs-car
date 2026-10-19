--!strict
-- Auto-pilot "brain". Pure math on the flat (X/Z) ground plane, so it can be unit tested.
-- Each frame the server asks: "where should I aim, and gas or reverse?" and, a few times a
-- second, "should I boost or use my ability now?".

export type Point = { x: number, z: number }

export type Params = {
	chargeMax: number,
	retreatTime: number, -- seconds spent driving away for a run-up
	retreatDist: number, -- how far away (studs) it aims while retreating
	maxRadius: number, -- retreat target stays inside this distance from bowl center
	circleTime: number,
	diveMax: number,
	circleRadius: number,
	circleAngleDeg: number,
	edgeRadius: number, -- predicted distance from center that triggers the rim guard
	edgeLook: number, -- reaction seconds the rim guard adds to its stopping-distance guess
	leadAfter: number, -- seconds with no hit before the bot aims where the enemy will be
	leadRamp: number, -- ...then over this many more seconds the lead grows to a full intercept
	ambushAfter: number, -- seconds with no hit before one of two orbiting cars cuts through the middle
	ambushHold: number, -- ...and waits once it is this close to the middle
	leadMax: number, -- longest look-ahead (seconds) of that
	turnInDeg: number, -- chasing with the enemy this far off the nose: check the turn is possible
	turnInSlack: number, -- brake when faster than (turn rate x needed radius) x this
	turnInMinSpeed: number, -- ...but never slow below this
	brakeShare: number, -- share of the car's accel the guard counts on when braking (0..1)
	brakeSpeed: number, -- outward speed above which the guard brakes (gas against the motion)
	commitAfter: number, -- seconds without a hit before a circler stops circling and just charges
	backupDist: number, -- Heavy only backs up when the enemy is this close (else keep closing)
	closeDist: number, -- "nose-to-nose" distance
	closeSeconds: number, -- sitting this close with no hit = back off for a run-up
	moveCheck: number, -- seconds between "should I boost / use my ability" rolls
	boostMinDist: number,
	boostMaxDist: number,
	boostAimDeg: number, -- boost only when pointing within this angle of the enemy
	boostTopShare: number, -- top speed during a boost, as a share of normal (MovesConfig.Boost.speedBonus + 1)
	moveSpeedShare: number, -- boost / dash only while slower than this share of top speed
	lowHp: number, -- HP share under which the bot gets desperate and uses its ability early
}

-- Per-car memory between frames. `hit` is set by the server when a hit happened.
export type Memory = {
	phase: string,
	t: number,
	side: number,
	hit: boolean,
	retreatT: number, -- > 0: drive away (run-up) for this many more seconds
	stuckT: number, -- seconds spent barely moving
	idle: number, -- seconds since the last hit (or since the start)
	closeT: number, -- seconds spent nose-to-nose with no hit
	vx: number, -- own flat velocity, set by the server each frame (rim guard)
	vz: number,
	evx: number, -- enemy flat velocity, set by the server each frame (lead aiming)
	evz: number,
	lead: number, -- level lead-aiming share 0..1
	turnRate: number, -- own max spin (rad/s), set by the server
	accel: number, -- own accel (studs/s^2), set by the server; sizes the braking guess
	fx: number, -- own unit nose direction (the guard brakes along it)
	fz: number,
	runUp: number, -- level run-up multiplier (higher = backs off sooner)
}

export type Command = { tx: number, tz: number, throttle: number }

-- What the bot sees when it decides about boost / ability. Flat studs; ability numbers are the
-- car's resolved ones.
export type MoveView = {
	now: number,
	seed: number,
	dist: number, -- to the enemy
	angle: number, -- radians from own nose to the enemy
	me: Point,
	fx: number, -- own unit heading
	fz: number,
	center: Point,
	hpShare: number, -- 0..1
	speed: number, -- own forward speed
	maxSpeed: number, -- own top speed (no boost)
	accel: number, -- own accel (sizes the braking room it needs)
	dashForward: number, -- speed the ability adds when it is a dash (0 otherwise)
	boostReady: boolean,
	specialReady: boolean,
	kind: string, -- ability kind ("" = none)
	radius: number, -- ability reach (slam / magnet)
	moveUse: number, -- level skill 0..1: how often it takes a good chance
}

local Ai = {}

function Ai.newMemory(style: string, side: number): Memory
	local phase = "charge"
	if style == "CircleDive" then
		phase = "circle"
	end
	return {
		phase = phase,
		t = 0,
		side = side,
		hit = false,
		retreatT = 0,
		stuckT = 0,
		idle = 0,
		closeT = 0,
		vx = 0,
		vz = 0,
		evx = 0,
		evz = 0,
		lead = 0,
		turnRate = 3,
		accel = 140,
		fx = 0,
		fz = -1,
		runUp = 1,
	}
end

-- Angle (radians) to turn from facing (fx,fz) to point at (tx,tz).
-- Positive = turn counter-clockwise seen from above (Roblox +Y rotation).
function Ai.signedAngle(fx: number, fz: number, tx: number, tz: number): number
	local cross = fz * tx - fx * tz
	local dot = fx * tx + fz * tz
	return math.atan2(cross, dot)
end

-- Spin speed to set: proportional to the angle, capped at turnRate.
function Ai.steer(angle: number, gain: number, turnRate: number): number
	return math.max(-turnRate, math.min(turnRate, angle * gain))
end

-- Slow the gas when the car is facing the wrong way, so it turns first.
function Ai.driveScale(angle: number, throttle: number): number
	if throttle <= 0 then
		return throttle
	end
	return throttle * math.max(0.15, math.cos(angle))
end

-- Called each frame with ground speed. Barely moving for `limit` seconds = nose-to-nose
-- standoff (or wedged on the wall), so drive away for `retreatTime` seconds.
function Ai.noteSpeed(mem: Memory, speed: number, dt: number, limit: number, retreatTime: number)
	if speed > 4 or mem.retreatT > 0 then
		mem.stuckT = 0
		return
	end
	mem.stuckT += dt
	if mem.stuckT >= limit then
		mem.stuckT = 0
		mem.retreatT = retreatTime
	end
end

local function rotate(x: number, z: number, ang: number): (number, number)
	local c, s = math.cos(ang), math.sin(ang)
	return x * c + z * s, -x * s + z * c
end

-- Run-up point: straight away from the enemy, kept inside the bowl, so the car gains speed
-- on the slope and swings back for a hard hit.
function Ai.retreatTarget(me: Point, enemy: Point, center: Point, p: Params): (number, number)
	local dx, dz = me.x - enemy.x, me.z - enemy.z
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.001 then
		dx, dz, len = 1, 0, 1
	end
	local tx, tz = me.x + dx / len * p.retreatDist, me.z + dz / len * p.retreatDist
	local cx, cz = tx - center.x, tz - center.z
	local r = math.sqrt(cx * cx + cz * cz)
	if r > p.maxRadius then
		tx, tz = center.x + cx / r * p.maxRadius, center.z + cz / r * p.maxRadius
	end
	return tx, tz
end

-- The raw plan for this frame (before the rim guard). Changes `mem` as phases switch.
local function plan(
	style: string,
	me: Point,
	enemy: Point,
	mem: Memory,
	dt: number,
	p: Params,
	center: Point
): Command
	mem.t += dt
	local hit = mem.hit
	mem.hit = false

	-- Time since the last hit, and time spent close without hitting (nose-to-nose).
	local dist = math.sqrt((me.x - enemy.x) ^ 2 + (me.z - enemy.z) ^ 2)
	if hit then
		mem.idle, mem.closeT = 0, 0
	else
		mem.idle += dt
		mem.closeT = if dist < p.closeDist then mem.closeT + dt else 0
	end
	local sitting = mem.closeT >= p.closeSeconds / math.max(mem.runUp, 0.05)
	if sitting then
		mem.closeT = 0
	end

	-- Run-up: drive away (forward, not reverse), then come back with speed.
	local hitAndRun = hit and (style == "Direct" or style == "BackupCharge")
	local tooLong = style == "BackupCharge" and mem.t > p.chargeMax and dist < p.backupDist
	if hitAndRun or tooLong or sitting then
		mem.retreatT = p.retreatTime
	end
	if mem.retreatT > 0 then
		mem.retreatT -= dt
		if mem.retreatT <= 0 then
			mem.t = 0 -- charge timer restarts after the run-up
		end
		local tx, tz = Ai.retreatTarget(me, enemy, center, p)
		return { tx = tx, tz = tz, throttle = 1 }
	end

	if style == "BackupCharge" then
		-- Heavy: charge straight; after a hit (or too long up close) run away, then charge again.
		return { tx = enemy.x, tz = enemy.z, throttle = 1 }
	elseif style == "CircleDive" then
		-- Light: circle around the enemy, then dive in from the side. Circling too long with no
		-- contact at all is dropped: it just dives.
		if mem.phase == "circle" and mem.idle > p.commitAfter then
			mem.phase, mem.t = "dive", 0
		end
		if mem.phase == "circle" then
			if mem.t > p.circleTime then
				mem.phase, mem.t = "dive", 0
			end
			local rx, rz = me.x - enemy.x, me.z - enemy.z
			local len = math.sqrt(rx * rx + rz * rz)
			if len < 0.001 then
				rx, rz, len = 1, 0, 1
			end
			local ox, oz = rotate(rx / len, rz / len, mem.side * math.rad(p.circleAngleDeg))
			return {
				tx = enemy.x + ox * p.circleRadius,
				tz = enemy.z + oz * p.circleRadius,
				throttle = 1,
			}
		end
		if hit or mem.t > p.diveMax then
			mem.phase, mem.t = "circle", 0
			mem.side = -mem.side
		end
		return { tx = enemy.x, tz = enemy.z, throttle = 1 }
	end

	-- "Direct" (Ramp, Spike): just aim at the enemy and push.
	return { tx = enemy.x, tz = enemy.z, throttle = 1 }
end

-- Rim guard. Estimates where the car stops if it brakes now (distance travelled while reacting
-- plus v^2 / (2 x braking)); when that is past `edgeRadius` and it is going out, it brakes (gas
-- against the motion, nose kept where it is), then turns for the middle. When it is outside the
-- ring and only the target pulls outward, it turns for the middle too. Otherwise it leaves the
-- plan alone.
local function guard(me: Point, cmd: Command, mem: Memory, p: Params, center: Point): Command
	local cx, cz = me.x - center.x, me.z - center.z
	local r = math.sqrt(cx * cx + cz * cz)
	if r < 0.001 then
		return cmd
	end
	local vOut = (mem.vx * cx + mem.vz * cz) / r
	local stop = math.max(vOut, 0) * p.edgeLook
		+ math.max(vOut, 0) ^ 2 / (2 * math.max(mem.accel * p.brakeShare, 1))
	if vOut > p.brakeSpeed and r + stop > p.edgeRadius then
		-- Gas against the motion: nose along the motion = reverse, nose against it = forward.
		local along = mem.vx * mem.fx + mem.vz * mem.fz
		return {
			tx = me.x + mem.fx * 50,
			tz = me.z + mem.fz * 50,
			throttle = if along >= 0 then -1 else 1,
		}
	end
	local tx, tz = cmd.tx - center.x, cmd.tz - center.z
	local targetOut = (tx * cx + tz * cz) / r > r
	if r + stop > p.edgeRadius and (vOut > 0 or (r > p.edgeRadius and targetOut)) then
		return { tx = center.x, tz = center.z, throttle = 1 }
	end
	return cmd
end

-- Gas while chasing. A car that cannot turn tight enough just orbits its enemy forever (both
-- chasing each other's tail), so when the enemy is off to the side and closer than the turn
-- allows, it brakes until it can bring the nose round, then goes again.
function Ai.turnIn(me: Point, enemy: Point, mem: Memory, p: Params): number
	local dx, dz = enemy.x - me.x, enemy.z - me.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local angle = math.abs(Ai.signedAngle(mem.fx, mem.fz, dx, dz))
	if angle < math.rad(p.turnInDeg) or dist < 0.001 then
		return 1
	end
	local fwdSpeed = mem.vx * mem.fx + mem.vz * mem.fz
	-- Turn radius needed to reach the enemy: chord / (2 sin angle), angle capped at 90 degrees.
	local need = dist / (2 * math.sin(math.min(angle, math.pi / 2)))
	if fwdSpeed > mem.turnRate * need * p.turnInSlack and fwdSpeed > p.turnInMinSpeed then
		return -1
	end
	return 1
end

-- Decide what to do this frame. Changes `mem` as phases switch. The server sets mem.vx / mem.vz
-- (own flat velocity), mem.fx / mem.fz (own nose) and mem.runUp (level) before calling; tests may leave them at 0 / 1.
function Ai.decide(
	style: string,
	me: Point,
	enemy: Point,
	mem: Memory,
	dt: number,
	p: Params,
	center: Point
): Command
	local cmd = plan(style, me, enemy, mem, dt, p, center)
	if cmd.tx == enemy.x and cmd.tz == enemy.z then
		cmd.throttle = Ai.turnIn(me, enemy, mem, p)
		-- Chased for a while without a hit: aim where the enemy is going, not where it is.
		if mem.idle > p.leadAfter then
			local dist = math.sqrt((enemy.x - me.x) ^ 2 + (enemy.z - me.z) ^ 2)
			local speed = math.max(math.sqrt(mem.vx * mem.vx + mem.vz * mem.vz), 30)
			-- A long chase with no contact (an orbit) ramps the lead up to a full intercept.
			local ramp = math.min(1, (mem.idle - p.leadAfter) / math.max(p.leadRamp, 0.01))
			local lead = mem.lead + (1 - mem.lead) * ramp
			local t = math.min(dist / speed, p.leadMax) * lead
			cmd.tx, cmd.tz = enemy.x + mem.evx * t, enemy.z + mem.evz * t
		end
		-- Still no contact after a long time (two cars orbiting each other): one of them stops
		-- chasing and cuts through the middle, so the orbit breaks.
		if mem.idle > p.ambushAfter and mem.side > 0 then
			cmd.tx, cmd.tz = center.x, center.z
			if (me.x - center.x) ^ 2 + (me.z - center.z) ^ 2 < p.ambushHold ^ 2 then
				-- Sit still in the middle (brake while still rolling) and let the other come.
				local rolling = mem.vx * mem.vx + mem.vz * mem.vz > 100
				cmd.throttle = if rolling then -1 else 0
			end
		end
	end
	return guard(me, cmd, mem, p, center)
end

local function hash01(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- Would the car still be able to stop inside the safe ring if it ends up going `speedAfter` along
-- its nose? (reaction distance + v^2 / (2 x braking), from here along the heading)
local function safeRun(v: MoveView, speedAfter: number, p: Params): boolean
	local travel = speedAfter * p.edgeLook
		+ speedAfter * speedAfter / (2 * math.max(v.accel * p.brakeShare, 1))
	local x, z = v.me.x + v.fx * travel - v.center.x, v.me.z + v.fz * travel - v.center.z
	return math.sqrt(x * x + z * z) < p.edgeRadius
end

-- Boost / ability decisions -> (boost, special). A person boosts when pointing at a far enemy,
-- fires the ability when it fits (slam up close, magnet at mid range, shield when threatened ...)
-- and panics with it when low on HP. `moveUse` (level) is how often it takes a good chance.
function Ai.wantMoves(v: MoveView, p: Params): (boolean, boolean)
	local desperate = v.hpShare < p.lowHp
	local skill = if desperate then math.min(1, v.moveUse * 1.5) else v.moveUse
	if hash01(math.floor(v.now / math.max(p.moveCheck, 0.01)), v.seed) >= skill then
		return false, false
	end
	local aimed = math.abs(v.angle) < math.rad(p.boostAimDeg)
	local slow = v.speed < v.maxSpeed * p.moveSpeedShare -- already flying: a boost only throws it out
	local boost = v.boostReady
		and slow
		and aimed
		and v.dist >= p.boostMinDist
		and v.dist <= p.boostMaxDist
		and safeRun(v, math.max(v.speed, v.maxSpeed * p.boostTopShare), p)

	local special = false
	if v.specialReady and v.kind ~= "" then
		local k = v.kind
		local reach = math.max(v.radius, 1)
		if k == "dash" then
			special = slow
				and aimed
				and v.dist >= 18
				and v.dist <= 65
				and safeRun(v, math.max(v.speed, 0) + v.dashForward, p)
		elseif k == "slam" then
			special = v.dist <= reach * 0.8
		elseif k == "magnet" then
			special = v.dist >= reach * 0.35 and v.dist <= reach * 0.95
		elseif k == "ram" then
			special = v.dist <= 45 and math.abs(v.angle) < math.rad(30)
		elseif k == "shield" then
			special = v.dist <= 32 or (desperate and v.dist <= 50)
		elseif k == "jump" then
			special = desperate and v.dist <= 14
		end
		if desperate and v.dist <= 30 and k ~= "jump" then
			special = true -- last-ditch: anything that is ready goes off
		end
	end
	return boost, special
end

return Ai
