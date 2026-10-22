--!strict
-- The plots as plain numbers (no Roblox objects at load time, so Lune can test them).
-- Each plot lives in Plots/<Type>.luau; this file lines them up in the world.
-- All positions are plot-local and BIG size; add the origin to get the world spot.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function plotModule(name: string): any
	if script then
		return require((script :: any).Parent.Plots[name])
	end
	local luneRequire: any = require
	return luneRequire("./Plots/" .. name)
end

local Kit = plotModule("Kit")

export type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	halfWidth: number,
	depth: number,
}
export type Spawn = { x: number, y: number, z: number, dx: number, dz: number }

export type Track = {
	id: string,
	label: string,
	originX: number,
	mode: string, -- "free", "loop" or "oneway"
	grip: number, -- floor grip multiplier (1 = normal)
	spawn: Spawn,
	gates: { Gate },
}

local TrackData = {}

TrackData.order = { "drift", "race", "rock", "show" }
TrackData.modules = { drift = "Drift", race = "Race", rock = "Rock", show = "Show" }
-- Real RC size: everything is this much smaller than the big build.
TrackData.RC_SCALE = 0.25
TrackData.RC_Z = 1500 -- the small plots sit here, away from the big ones
TrackData.GAP = 120 -- space between plots (big units)

-- The plot module itself (Plots/<Type>.luau).
function TrackData.plot(id: string): any
	return plotModule(TrackData.modules[id])
end

function TrackData.index(id: string): number
	return table.find(TrackData.order, id) or 1
end

function TrackData.get(id: string): Track
	local p = TrackData.plot(id)
	return {
		id = p.id,
		label = p.label,
		originX = (TrackData.index(id) - 1) * (Kit.WIDTH + TrackData.GAP),
		mode = p.mode,
		grip = p.grip,
		spawn = p.spawn,
		gates = p.gates,
	}
end

-- Where a plot's middle sits in the world at this size.
function TrackData.origin(t: Track, rc: boolean): (number, number)
	if rc then
		return t.originX * TrackData.RC_SCALE, TrackData.RC_Z
	end
	return t.originX, 0
end

-- Plot-local spot -> world spot at this size.
function TrackData.toWorld(
	t: Track,
	rc: boolean,
	x: number,
	y: number,
	z: number
): (number, number, number)
	local s = if rc then TrackData.RC_SCALE else 1
	local ox, oz = TrackData.origin(t, rc)
	return ox + x * s, y * s, oz + z * s
end

-- World spot -> plot-local spot (for the lap timer).
function TrackData.toLocal(
	t: Track,
	rc: boolean,
	x: number,
	y: number,
	z: number
): (number, number, number)
	local s = if rc then TrackData.RC_SCALE else 1
	local ox, oz = TrackData.origin(t, rc)
	return (x - ox) / s, y / s, (z - oz) / s
end

-- Where the player stands with the remote (same spot on every plot), facing the car's start.
function TrackData.standSpot(t: Track): (Spawn, number, number)
	local s = t.spawn
	local spot = { x = Kit.STAND.x, y = 0, z = Kit.STAND.z, dx = 0, dz = -1 }
	return spot, s.x, s.z
end

return TrackData
