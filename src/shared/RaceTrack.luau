--!strict
-- Crazy Race track geometry (no Roblox calls): lengths, directions, the start grid, ramp spots.
-- Numbers: RaceTrackConfig. Unit tested.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("RaceTrackConfig")

local RaceTrack = {}

export type Spot = { x: number, z: number, yaw: number }

-- Number of waypoints.
function RaceTrack.count(): number
	return #Config.waypoints
end

-- Waypoint `i`, wrapping (0 = last, N + 1 = first).
function RaceTrack.point(i: number): { x: number, z: number }
	local n = #Config.waypoints
	return Config.waypoints[(i - 1) % n + 1]
end

-- Length of the stretch from waypoint i to the next one.
function RaceTrack.segmentLength(i: number): number
	local a, b = RaceTrack.point(i), RaceTrack.point(i + 1)
	return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
end

function RaceTrack.lapLength(): number
	local sum = 0
	for i = 1, #Config.waypoints do
		sum += RaceTrack.segmentLength(i)
	end
	return sum
end

-- Unit direction of the stretch from waypoint i to the next.
function RaceTrack.direction(i: number): (number, number)
	local a, b = RaceTrack.point(i), RaceTrack.point(i + 1)
	local len = RaceTrack.segmentLength(i)
	return (b.x - a.x) / len, (b.z - a.z) / len
end

-- A car faces -Z at yaw 0; facing (dx, dz) needs yaw = atan2(-dx, -dz).
function RaceTrack.yawFor(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

-- Start grid: `count` spots in rows just behind waypoint 1, all facing waypoint 2.
function RaceTrack.grid(count: number): { Spot }
	local out: { Spot } = {}
	local start = RaceTrack.point(1)
	local dx, dz = RaceTrack.direction(1)
	local sx, sz = -dz, dx -- sideways (left of the driving direction)
	local cols = Config.gridColumns
	for k = 0, count - 1 do
		local row, col = k // cols, k % cols
		local back = Config.gridBack + row * Config.gridSpacing
		local side = (col - (cols - 1) / 2) * Config.gridWidth
		table.insert(out, {
			x = start.x - dx * back + sx * side,
			z = start.z - dz * back + sz * side,
			yaw = RaceTrack.yawFor(dx, dz),
		})
	end
	return out
end

-- Where a car goes back to after a fall: on the road at the waypoint it last passed, facing the next.
function RaceTrack.respawn(lastPassed: number, slot: number): Spot
	local p = RaceTrack.point(lastPassed)
	local dx, dz = RaceTrack.direction(lastPassed)
	local sx, sz = -dz, dx
	local side = ((slot - 1) % 3 - 1) * 10
	local ahead = 12 -- a little past the gate, clear of the start grid
	return {
		x = p.x + dx * ahead + sx * side,
		z = p.z + dz * ahead + sz * side,
		yaw = RaceTrack.yawFor(dx, dz),
	}
end

-- Corners of the world the ground must cover: min x, max x, min z, max z (with the margin).
function RaceTrack.bounds(): (number, number, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in Config.waypoints do
		minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
		minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
	end
	local m = Config.groundMargin
	return minX - m, maxX + m, minZ - m, maxZ + m
end

-- Is flat (x, z) on the road? (Within half a road width of some stretch.)
function RaceTrack.onRoad(x: number, z: number): boolean
	for i = 1, #Config.waypoints do
		local a, b = RaceTrack.point(i), RaceTrack.point(i + 1)
		local vx, vz = b.x - a.x, b.z - a.z
		local len2 = vx * vx + vz * vz
		local t = math.clamp(((x - a.x) * vx + (z - a.z) * vz) / len2, 0, 1)
		local px, pz = a.x + vx * t, a.z + vz * t
		if (x - px) ^ 2 + (z - pz) ^ 2 <= (Config.roadWidth / 2) ^ 2 then
			return true
		end
	end
	return false
end

return RaceTrack
