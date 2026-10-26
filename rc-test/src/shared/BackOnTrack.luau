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

-- Fell off the world? (y in world studs; scale = Tuning.scale, the car's size)
function BackOnTrack.fell(y: number, scale: number): boolean
	return y < BackOnTrack.FALL * scale / TrackData.RC_SCALE
end

-- Stuck long enough to be put back? (rocks: being stuck is part of crawling)
function BackOnTrack.stuck(stuckFor: number, wait: number, trackId: string): boolean
	return stuckFor > wait and trackId ~= "rock"
end

return BackOnTrack
