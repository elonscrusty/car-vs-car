--!strict
-- Car VS Car driver stand (carter said yes to the stand pictures, 10-26): in the big race every
-- racer stands on the map's stand with their remote, at the spot of their grid number (each league
-- has its own race, so the leagues share the 8 spots; screens hide the other leagues). The camera
-- is fixed above and a bit behind your spot and turns to watch your car. Pure, so Lune tests it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local RaceMaps = sibling("RaceMaps")
local TrackData = sibling("TrackData")

export type Spot = { x: number, y: number, z: number, dx: number, dz: number }

local RaceStand = {}

-- the camera from your spot, RC studs: up over the head and back away from the track
RaceStand.CAM_UP = 8
RaceStand.CAM_BACK = 6
RaceStand.CAM_SIDE = 1.5 -- a little to the right: over the shoulder
-- how much of the world round the car fills the view (studs, half height), and the zoom range
RaceStand.VIEW_HALF = 9
RaceStand.FOV_MIN = 10
RaceStand.FOV_MAX = 60

-- Spot k (1..8) on the stand of track t's map, in the world (feet on the deck top), facing the
-- track (dx, dz). nil = not a map, or a map without a stand.
function RaceStand.spot(t: any, k: number): Spot?
	local map = if t and t.map then RaceMaps.get(t.map) else nil
	if not map then
		return nil
	end
	local spots = map.standSpots()
	if #spots == 0 then
		return nil
	end
	local s = spots[math.clamp(math.floor(k), 1, #spots)]
	local x, y, z = TrackData.toWorld(t, true, s.x, s.y, s.z)
	local dx, dz = TrackData.dirToWorld(t, true, 0, -1) -- avatars face -z, towards the track
	return { x = x, y = y, z = z, dx = dx, dz = dz }
end

-- Where the stand camera sits for a spot: over the shoulder, above and behind.
function RaceStand.camAt(s: Spot): (number, number, number)
	-- right of facing (dx, dz) is (-dz, dx)
	return s.x - s.dx * RaceStand.CAM_BACK - s.dz * RaceStand.CAM_SIDE,
		s.y + RaceStand.CAM_UP,
		s.z - s.dz * RaceStand.CAM_BACK + s.dx * RaceStand.CAM_SIDE
end

-- Zoom (field of view, degrees) so a car `dist` studs away still looks a good size.
function RaceStand.fov(dist: number): number
	local d = math.max(dist, 1)
	return math.clamp(
		math.deg(2 * math.atan(RaceStand.VIEW_HALF / d)),
		RaceStand.FOV_MIN,
		RaceStand.FOV_MAX
	)
end

return RaceStand
