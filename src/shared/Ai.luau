--!strict
-- Auto-pilot "brain". Pure math on the flat (X/Z) ground plane, so it can be unit tested.
-- Each frame the server asks: "where should I aim, and gas or reverse?"

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
}

-- Per-car memory between frames. `hit` is set by the server when a hit happened.
export type Memory = {
	phase: string,
	t: number,
	side: number,
	hit: boolean,
	retreatT: number, -- > 0: drive away (run-up) for this many more seconds
	stuckT: number, -- seconds spent barely moving
}

export type Command = { tx: number, tz: number, throttle: number }

local Ai = {}

function Ai.newMemory(style: string, side: number): Memory
	local phase = "charge"
	if style == "CircleDive" then
		phase = "circle"
	end
	return { phase = phase, t = 0, side = side, hit = false, retreatT = 0, stuckT = 0 }
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
-- standoff, so drive away for `retreatTime` seconds.
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

-- Decide what to do this frame. Changes `mem` as phases switch.
function Ai.decide(
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

	-- Run-up: drive away (forward, not reverse), then come back with speed.
	if hit and (style == "Direct" or style == "BackupCharge") then
		mem.retreatT = p.retreatTime
	elseif style == "BackupCharge" and mem.t > p.chargeMax then
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
		-- Heavy: charge straight; after a hit (or too long) run away, then charge again.
		return { tx = enemy.x, tz = enemy.z, throttle = 1 }
	elseif style == "CircleDive" then
		-- Light: circle around the enemy, then dive in from the side.
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

return Ai
