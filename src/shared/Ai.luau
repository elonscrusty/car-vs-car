--!strict
-- Auto-pilot "brain". Pure math on the flat (X/Z) ground plane, so it can be unit tested.
-- Each frame the server asks: "where should I aim, and gas or reverse?"

export type Point = { x: number, z: number }

export type Params = {
	chargeMax: number,
	backupTime: number,
	circleTime: number,
	diveMax: number,
	circleRadius: number,
	circleAngleDeg: number,
}

-- Per-car memory between frames. `hit` is set by the server when a hit happened.
export type Memory = { phase: string, t: number, side: number, hit: boolean }

export type Command = { tx: number, tz: number, throttle: number }

local Ai = {}

function Ai.newMemory(style: string, side: number): Memory
	local phase = "charge"
	if style == "CircleDive" then
		phase = "circle"
	end
	return { phase = phase, t = 0, side = side, hit = false }
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

local function rotate(x: number, z: number, ang: number): (number, number)
	local c, s = math.cos(ang), math.sin(ang)
	return x * c + z * s, -x * s + z * c
end

-- Decide what to do this frame. Changes `mem` as phases switch.
function Ai.decide(
	style: string,
	me: Point,
	enemy: Point,
	mem: Memory,
	dt: number,
	p: Params
): Command
	mem.t += dt
	local hit = mem.hit
	mem.hit = false

	if style == "BackupCharge" then
		-- Heavy: charge straight; after a hit (or too long) back up, then charge again.
		if mem.phase == "charge" and (hit or mem.t > p.chargeMax) then
			mem.phase, mem.t = "backup", 0
		elseif mem.phase == "backup" and mem.t > p.backupTime then
			mem.phase, mem.t = "charge", 0
		end
		return { tx = enemy.x, tz = enemy.z, throttle = if mem.phase == "charge" then 1 else -1 }
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
