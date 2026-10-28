--!strict
-- Car VS Car big race: off the world, stuck or R puts the car back on the road at the last gate it
-- passed, facing the way to go. The small loss is the bit since that gate, from a standstill (it
-- used to be the grid: a whole lap). Race feel stays locked: this only says where, never how the
-- car drives. Pure (LapTimer-style gates, TrackData sizes), so Lune tests it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local TrackData = sibling("TrackData")

local BackOnTrack = {}

BackOnTrack.FALL = -8 -- big-size studs: below this the car fell off the world

-- The gate last passed when the lap timer waits for gate `next` (LapTimer: next = 2 right after
-- the line, so the line itself; it counts past the last gate to `count + 1` = the line again).
function BackOnTrack.lastGate(count: number, next: number): number
	return ((next - 2) % count) + 1
end

-- Where to put the car (track-local, big units) and which way it faces: on the last gate's
-- middle, on the road (never under the start's height), looking along the gate.
export type Spot = { x: number, y: number, z: number, dx: number, dz: number }

function BackOnTrack.spot(t: any, gates: { any }, next: number): Spot?
	if #gates == 0 then
		return nil
	end
	local g = gates[BackOnTrack.lastGate(#gates, next)]
	return { x = g.x, y = math.max(g.y, t.spawn.y), z = g.z, dx = g.dx, dz = g.dz }
end

-- Where to put the car instead (Studio after-810: stuck on the first bend's wall, put back on the
-- START LINE every time): on the main road nearest `x`, `z` (where the car last was on the road),
-- a little behind it, facing along the road. Only between the last gate passed and the next one,
-- so it never skips a gate. `loop` = the map's centre line in driving order (map.loop()); track-
-- local big units like the gates. nil = no road to use (then spot()).
-- `push` = this many samples further on (a first race's kid put back at the same wall again and
-- again: AUTO GAS with no steering drove into it every time, held up 40 s, Studio pr841). Never
-- onto the next gate.
BackOnTrack.BACK_SAMPLES = 2 -- this many road samples (5 to 15 apart) behind that spot
function BackOnTrack.roadSpot(
	t: any,
	loop: { { x: number, z: number, tx: number, tz: number } },
	gates: { any },
	next: number,
	x: number,
	z: number,
	push: number?
): Spot?
	local n, count = #loop, #gates
	if n < 2 or count == 0 then
		return nil
	end
	local function nearest(px: number, pz: number): number
		local best, at = math.huge, 1
		for k, s in loop do
			local d = (s.x - px) ^ 2 + (s.z - pz) ^ 2
			if d < best then
				best, at = d, k
			end
		end
		return at
	end
	local last = gates[BackOnTrack.lastGate(count, next)]
	local ahead = gates[((next - 1) % count) + 1]
	local from = nearest(last.x, last.z)
	local to = if count > 1 then nearest(ahead.x, ahead.z) else from
	local span = (to - from) % n
	if span == 0 then
		span = n
	end
	-- the nearest sample to (x, z) from the last gate on to the next one
	local best, step = math.huge, 0
	for i = 0, span do
		local s = loop[(from - 1 + i) % n + 1]
		local d = (s.x - x) ^ 2 + (s.z - z) ^ 2
		if d < best then
			best, step = d, i
		end
	end
	step = math.clamp(step - BackOnTrack.BACK_SAMPLES + (push or 0), 0, math.max(0, span - 1))
	local s = loop[(from - 1 + step) % n + 1]
	local len = math.sqrt(s.tx * s.tx + s.tz * s.tz)
	if len < 1e-6 then
		return nil
	end
	return {
		x = s.x,
		y = math.max(last.y or 0, t.spawn.y),
		z = s.z,
		dx = s.tx / len,
		dz = s.tz / len,
	}
end

-- Fell off the world? (y in world studs; scale = Tuning.scale, the car's size)
function BackOnTrack.fell(y: number, scale: number): boolean
	return y < BackOnTrack.FALL * scale / TrackData.RC_SCALE
end

-- Stuck long enough to be put back? (rocks: being stuck is part of crawling)
function BackOnTrack.stuck(stuckFor: number, wait: number, trackId: string): boolean
	return stuckFor > wait and trackId ~= "rock"
end

-- Lost in a big race (critic run 1: nose in a wall with no pedal held, off the road in the giant
-- grass, WRONG WAY with no idea where to go). Each one, held long enough, is the same R: back on
-- the road at the last gate. Only where the car is put, never how it drives.
BackOnTrack.STILL_WAIT = 2.5 -- nearly still after you got going, pedal or not
BackOnTrack.OFF_WAIT = 3 -- on the ground, off every road
BackOnTrack.WRONG_WAIT = 3 -- WRONG WAY the whole time
BackOnTrack.GO_CALM = 3 -- none of it in the first seconds after GO (the pack shoves about)
BackOnTrack.AIR_MAX = 1.5 -- longer than any hop in the air: wheels hanging off a prop, not a jump
BackOnTrack.OFF_MARGIN = 20 -- big units past a road's curb before it counts as off the road
BackOnTrack.CURB = 3 -- (MapKit.CURB_WIDTH)
-- map-local big units: under the floor (the road is at 0, a car sits at 2.5) but not yet FALL
BackOnTrack.UNDER = -12

-- A map's roads for offRoad: the main loop and every side road (shortcuts and the secret), each
-- with how far from its centre line still counts as on it.
export type Road = { ring: { { x: number, z: number } }, reach: number }
function BackOnTrack.roads(map: any): { Road }
	local out: { Road } = {}
	local def = map.def
	local function add(ring: { any }, width: number)
		table.insert(
			out,
			{ ring = ring, reach = width / 2 + BackOnTrack.CURB + BackOnTrack.OFF_MARGIN }
		)
	end
	add(map.loop(), def.road)
	for i, p in def.paths do
		add(map.path(i), p.width)
	end
	return out
end

-- Off every road? (map-local x, z, big units; a road's own samples are 5 to 15 apart, inside
-- the margin)
function BackOnTrack.offRoad(roads: { Road }, x: number, z: number): boolean
	for _, r in roads do
		local reach2 = r.reach * r.reach
		for _, s in r.ring do
			local dx, dz = s.x - x, s.z - z
			if dx * dx + dz * dz <= reach2 then
				return false
			end
		end
	end
	return true
end

-- The lost clocks, one frame. `sinceGo` = seconds from GO (nil = not racing yet), `moved` = got
-- going since GO (a car still on the line is HOLD GAS!, not lost), `still` = nearly no ground
-- speed, `off` = offRoad, `air` = no wheel down (a jump: the off clock waits, up to AIR_MAX),
-- `wrong` = driving away from the next gate. Returns why to put the car back, or nil.
-- The off clock runs down (not back to 0) while back near a road: a kid wandering round just off
-- the bend, now and then within reach of it, sat 45 s off the road (critic run 2, kitchen).
export type Lost = { still: number, off: number, wrong: number, air: number }
function BackOnTrack.newLost(): Lost
	return { still = 0, off = 0, wrong = 0, air = 0 }
end

function BackOnTrack.lost(
	l: Lost,
	dt: number,
	sinceGo: number?,
	moved: boolean,
	still: boolean,
	off: boolean,
	air: boolean,
	wrong: boolean
): ("still" | "off" | "wrong")?
	if sinceGo == nil or sinceGo < BackOnTrack.GO_CALM or not moved then
		l.still, l.off, l.wrong, l.air = 0, 0, 0, 0
		return nil
	end
	l.still = if still then l.still + dt else 0
	l.air = if air then l.air + dt else 0
	if not air or l.air >= BackOnTrack.AIR_MAX then
		l.off = if off then l.off + dt else math.max(0, l.off - dt)
	end
	l.wrong = if wrong then l.wrong + dt else 0
	local why: ("still" | "off" | "wrong")? = nil
	if l.still >= BackOnTrack.STILL_WAIT then
		why = "still"
	elseif l.off >= BackOnTrack.OFF_WAIT then
		why = "off"
	elseif l.wrong >= BackOnTrack.WRONG_WAIT then
		why = "wrong"
	end
	if why then
		l.still, l.off, l.wrong, l.air = 0, 0, 0, 0
	end
	return why
end

return BackOnTrack
