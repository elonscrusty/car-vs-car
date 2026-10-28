--!strict
-- The server's own eye on one drive (carter's stars loop, phase 1): from the car's position a few
-- times a second it times laps and climbs (LapTimer) and scores drift slides itself, so a run the
-- client makes up never counts. Pure maths in plot-local, big-size units, so Lune can test it.
-- A car that jumps further than it could drive is a reset: back at the start = a fresh run, at a
-- rock checkpoint flag = the climb goes on (like the client), anywhere else = the run is thrown out.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarMath = sibling("CarMath")
local LapTimer = sibling("LapTimer")
local Tuning = sibling("Tuning")

export type Spot = { x: number, z: number }
export type Event = { kind: string, value: number } -- "lap", "finish", "drift", "start", "void"
export type State = {
	mode: string, -- plot kind: "race", "drift", "rock"
	timer: any, -- LapTimer.State
	start: Spot,
	checkpoints: { Spot },
	x: number,
	y: number,
	z: number,
	t: number,
	still: number, -- seconds with no new position (the server didn't hear from the car)
	chain: number, -- drift: points of the slide going on now
	held: number,
	hold: number,
}

local RunCheck = {}

RunCheck.STEP = 2 -- gate checks every this many studs of travel (big size)
RunCheck.SNAP = 8 -- a jump that lands this close to a spawn spot is a reset, not a cheat
-- fastest a car can really go along the ground, studs/s big size (top speeds 95 / 105 / 16)
RunCheck.MAX_SPEED = { race = 170, drift = 180, rock = 60 } :: { [string]: number }

-- The big race (Car VS Car): between two gate crossings the car can't have gone further, in a
-- straight line, than it could drive (+ a gate's width of slack). False = speed hack / teleport.
RunCheck.LEG_SLACK = 30
function RunCheck.legOk(
	fromX: number,
	fromZ: number,
	fromT: number,
	x: number,
	z: number,
	t: number,
): boolean
	local dist = math.sqrt((x - fromX) ^ 2 + (z - fromZ) ^ 2)
	return dist <= RunCheck.MAX_SPEED.race * math.max(t - fromT, 0) + RunCheck.LEG_SLACK
end

function RunCheck.new(
	gates: { any },
	timerMode: string,
	mode: string,
	start: Spot,
	checkpoints: { Spot },
	now: number,
	x: number,
	y: number,
	z: number
): State
	return {
		mode = mode,
		timer = LapTimer.new(gates, timerMode),
		start = start,
		checkpoints = checkpoints,
		x = x,
		y = y,
		z = z,
		t = now,
		still = 0,
		chain = 0,
		held = 0,
		hold = 0,
	}
end

local function near(s: Spot, x: number, z: number): boolean
	local dx, dz = s.x - x, s.z - z
	return dx * dx + dz * dz <= RunCheck.SNAP * RunCheck.SNAP
end

local function forget(s: State)
	LapTimer.reset(s.timer)
	s.chain, s.held, s.hold = 0, 0, 0
end

-- Drift points for one stretch: speed in big studs/s, slip in radians (same sums as the client).
function RunCheck.driftGain(
	s: State,
	speed: number,
	slip: number,
	grounded: boolean,
	dt: number
): number?
	local gain = CarMath.driftPoints(speed * Tuning.scale, slip, dt)
	if gain > 0 and grounded then
		s.held += dt
		s.chain += gain * CarMath.driftCombo(s.held)
		s.hold = 0.8
	elseif s.chain > 0 then
		s.hold -= dt
		if s.hold <= 0 or speed < 8 then
			local done = s.chain
			s.chain, s.held = 0, 0
			return done
		end
	end
	return nil
end

-- One look at the car: position (plot-local, big size), which way its nose points (fx, fz) and
-- whether it touches the ground. Returns what happened since the last look.
function RunCheck.step(
	s: State,
	now: number,
	x: number,
	y: number,
	z: number,
	fx: number,
	fz: number,
	grounded: boolean
): { Event }
	local out: { Event } = {}
	local dt = now - s.t
	if dt <= 0 then
		return out
	end
	local dx, dy, dz = x - s.x, y - s.y, z - s.z
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat < 1e-4 and math.abs(dy) < 1e-4 then
		-- no news from the car yet: wait (a gap in the updates mustn't end a slide)
		s.still += dt
		s.t = now
		if s.still < 0.5 then
			return out
		end
		dt = s.still
	end
	local span = dt + (if flat < 1e-4 then 0 else s.still)
	s.still = 0
	local fromX, fromY, fromZ, fromT = s.x, s.y, s.z, now - span
	s.x, s.y, s.z, s.t = x, y, z, now

	if flat > (RunCheck.MAX_SPEED[s.mode] or 170) * span then
		s.chain, s.held, s.hold = 0, 0, 0
		if near(s.start, x, z) then
			forget(s)
			return out -- R / RESET / out of the plot: a fresh run from the start
		end
		for _, cp in s.checkpoints do
			if near(cp, x, z) then
				-- back to a rock checkpoint flag: the climb clock keeps going (like the client)
				return out
			end
		end
		forget(s)
		table.insert(out, { kind = "void", value = 0 })
		return out
	end

	-- gates: walk the line in short steps so a thin gate between two looks is never missed
	local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / RunCheck.STEP))
	for i = 1, n do
		local a = i / n
		local e = LapTimer.update(
			s.timer,
			fromT + span * a,
			fromX + dx * a,
			fromY + dy * a,
			fromZ + dz * a
		)
		if e == "lap" or e == "finish" then
			table.insert(out, { kind = e, value = s.timer.last :: number })
		elseif e == "start" then
			table.insert(out, { kind = e, value = 0 })
		end
	end

	if s.mode == "drift" then
		local vx, vz = dx / span, dz / span
		local fl = math.sqrt(fx * fx + fz * fz)
		if fl > 1e-6 then
			fx, fz = fx / fl, fz / fl
		end
		local vLong = vx * fx + vz * fz
		local vLat = vx * -fz + vz * fx
		local slip = math.atan2(vLat, math.max(math.abs(vLong), 1))
		local done = RunCheck.driftGain(s, flat / span, slip, grounded, span)
		if done then
			table.insert(out, { kind = "drift", value = done })
		end
	end
	return out
end

-- Forget the run in progress (left the plot, car rebuilt).
RunCheck.forget = forget

return RunCheck
