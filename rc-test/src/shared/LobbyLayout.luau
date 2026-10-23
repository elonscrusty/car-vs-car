--!strict
-- The walking lobby (carter's plan v5, /mnt/project-files/rc-game/redesign/lobby-plan-v5.png):
-- one road with 4 real RC-size plots on each side, fronts facing the road, a yellow DRIVE pad
-- and a name sign at each front; the spawn lobby (SpawnLobby) at the road's -z end, the lake at
-- its +z end. The plots ARE the tracks: stand on a pad, tap, and drive right there, live.
-- Plain numbers only (Lune tests load this). Real studs, world space. The road runs along z.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		local node: any = (script :: any).Parent
		for _, part in string.split(name, "/") do
			node = node[part]
		end
		return require(node)
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local TrackData = sibling("TrackData")
local Kit = sibling("Plots/Kit")

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Slot = {
	index: number, -- 1..8: left row 1, right row 1, left row 2, ...
	track: number, -- which real track it drives (index into TrackData.order)
	id: string,
	label: string,
	plotX: number, -- middle of the small plot on the floor
	plotZ: number,
	angle: number, -- turn of the small plot (radians about y): its front faces the road
	padX: number, -- the DRIVE pad in front of the small plot
	padZ: number,
	exitX: number, -- where a person is put back after driving
	exitZ: number,
	signX: number, -- the sign at the plot's front corner
	signZ: number,
}
-- A thing to build somewhere: x, z = middle on the floor; face = the way its open side looks.
export type Spot = { x: number, z: number, faceX: number, faceZ: number }

local LobbyLayout = {}

-- The plots at real RC size (from big size): 320 x 440 -> 80 wide x 110 deep.
LobbyLayout.MINI = TrackData.RC_SCALE
LobbyLayout.PLOT_W = Kit.WIDTH * LobbyLayout.MINI -- along the road (z)
LobbyLayout.PLOT_D = Kit.DEPTH * LobbyLayout.MINI -- away from the road (x)
LobbyLayout.GAP = 10 -- grass between two plots on the same side
LobbyLayout.ROAD_W = 14 -- the dark road
LobbyLayout.WALK_W = 6 -- the light footpath on each side of the road
LobbyLayout.EDGE = LobbyLayout.ROAD_W / 2 + LobbyLayout.WALK_W -- plot fronts are this far from x = 0
LobbyLayout.ROWS = 4
LobbyLayout.FIRST_Z = 1000 -- middle of the first row of plots (next to the spawn lobby)
LobbyLayout.STEP = LobbyLayout.PLOT_W + LobbyLayout.GAP
LobbyLayout.REACH = 8 -- how close to the pad you must be to start driving
LobbyLayout.PAD = 5 -- pad size
-- The kinds of plot in the lobby (index into TrackData.order; show is on hold).
LobbyLayout.TRACKS = { 1, 2, 3 }
-- What each lobby plot is, by slot (left row 1, right row 1, left row 2, ...), as in carter's
-- picture: race, drift / drift, rocks / rocks, drift / race, race.
LobbyLayout.SLOT_TRACKS = { 2, 1, 1, 3, 3, 1, 2, 2 }
-- The lake is past this end of the road (+z).
LobbyLayout.LAKE_SIDE = 1

local LAST_Z = LobbyLayout.FIRST_Z + (LobbyLayout.ROWS - 1) * LobbyLayout.STEP
local ROAD_MIN_Z = LobbyLayout.FIRST_Z - LobbyLayout.PLOT_W / 2 - 10
-- The spawn lobby (SpawnLobby's): 120 x 81 at the top of the road, open toward it.
LobbyLayout.PLAZA = {
	minX = -60,
	maxX = 60,
	minZ = ROAD_MIN_Z - 81,
	maxZ = ROAD_MIN_Z,
}

function LobbyLayout.slots(): { Slot }
	local out: { Slot } = {}
	for row = 1, LobbyLayout.ROWS do
		local z = LobbyLayout.FIRST_Z + (row - 1) * LobbyLayout.STEP
		for _, side in { -1, 1 } do -- -1 = left of the road (-x), 1 = right
			local index = #out + 1
			local track = LobbyLayout.SLOT_TRACKS[index]
			local t = TrackData.get(TrackData.order[track])
			local front = side * LobbyLayout.EDGE -- x of the plot's front edge
			local padX = front - side * (LobbyLayout.WALK_W / 2) -- on the footpath
			table.insert(out, {
				index = index,
				track = track,
				id = t.id,
				label = t.label,
				plotX = side * (LobbyLayout.EDGE + LobbyLayout.PLOT_D / 2),
				plotZ = z,
				-- a plot's front is its local +z; left plots face +x, right plots face -x
				angle = -side * math.pi / 2,
				padX = padX, -- in front of the plot's entrance
				padZ = z,
				exitX = padX, -- people watch their car from the pad, and walk on from there
				exitZ = z,
				signX = front - side * 0.8, -- on the footpath edge
				signZ = z - 16,
			})
		end
	end
	return out
end

-- The road (dark) and its footpaths (light), from the spawn lobby to the lake.
function LobbyLayout.road(): Box
	return {
		minX = -LobbyLayout.ROAD_W / 2,
		maxX = LobbyLayout.ROAD_W / 2,
		minZ = ROAD_MIN_Z,
		maxZ = LAST_Z + LobbyLayout.PLOT_W / 2 + 10,
	}
end
function LobbyLayout.walks(): Box
	local r = LobbyLayout.road()
	return { minX = -LobbyLayout.EDGE, maxX = LobbyLayout.EDGE, minZ = r.minZ, maxZ = r.maxZ }
end

-- Grass under everything (the water and shore go round it).
function LobbyLayout.ground(): Box
	local far = LobbyLayout.EDGE + LobbyLayout.PLOT_D + 12
	return {
		minX = -far,
		maxX = far,
		minZ = LobbyLayout.PLAZA.minZ - 8,
		maxZ = LobbyLayout.road().maxZ + 6,
	}
end

-- The upgrades garage spot in the spawn lobby (looks only for now).
function LobbyLayout.garage(): Spot -- upgrades garage, right
	return { x = 40, z = LobbyLayout.PLAZA.minZ + 18, faceX = -1, faceZ = 0 }
end
-- Lamps along both footpaths (between plots).
function LobbyLayout.lamps(): { Spot }
	local out: { Spot } = {}
	for row = 0, LobbyLayout.ROWS do
		local z = LobbyLayout.FIRST_Z - LobbyLayout.STEP / 2 + row * LobbyLayout.STEP
		for _, side in { -1, 1 } do
			table.insert(
				out,
				{ x = side * (LobbyLayout.EDGE - 1), z = z, faceX = -side, faceZ = 0 }
			)
		end
	end
	return out
end

-- Two cones by each DRIVE pad, on the footpath either side of it.
function LobbyLayout.cones(): { Spot }
	local out: { Spot } = {}
	for _, s in LobbyLayout.slots() do
		for _, dz in { -1, 1 } do
			local face = if s.padX < 0 then 1 else -1
			table.insert(out, {
				x = s.padX,
				z = s.padZ + dz * (LobbyLayout.PAD / 2 + 1.2),
				faceX = face,
				faceZ = 0,
			})
		end
	end
	return out
end

-- Tyre stacks across the lake end of the road and footpaths (the road stops here).
function LobbyLayout.tires(): { Spot }
	local out: { Spot } = {}
	local z = LobbyLayout.road().maxZ - 1.5
	local x = -LobbyLayout.EDGE + 1.5
	while x <= LobbyLayout.EDGE - 1.5 do
		table.insert(out, { x = x, z = z, faceX = 0, faceZ = 1 })
		x += 3
	end
	return out
end

-- Trees: in the grass between plots (at the back) and along the outer edges.
function LobbyLayout.trees(): { Spot }
	local out: { Spot } = {}
	local g = LobbyLayout.ground()
	for row = 0, LobbyLayout.ROWS do
		local z = LobbyLayout.FIRST_Z - LobbyLayout.STEP / 2 + row * LobbyLayout.STEP
		for _, side in { -1, 1 } do
			table.insert(out, {
				x = side * (LobbyLayout.EDGE + LobbyLayout.PLOT_D - 4),
				z = z,
				faceX = 0,
				faceZ = 1,
			})
			table.insert(out, { x = side * (g.maxX - 8), z = z + 10, faceX = 0, faceZ = 1 })
		end
	end
	return out
end

-- Where people appear (until SpawnLobby says otherwise): the spawn lobby, looking down the road.
function LobbyLayout.spawn(): (number, number, number)
	return 0, 3, LobbyLayout.PLAZA.minZ + 40
end

-- Where a car waits before its first drive (spread out, one per player): at the top of the road.
function LobbyLayout.parkSpot(n: number): (number, number)
	return -5.25 + ((n - 1) % 4) * 3.5, LobbyLayout.road().minZ + 4
end

-- A lobby plot as a track: its kind's data, placed and turned where that plot sits.
function LobbyLayout.track(slotIndex: number): any
	local slot = LobbyLayout.slots()[slotIndex]
	local t = TrackData.get(slot.id)
	t.rcX, t.rcZ, t.rcAngle = slot.plotX, slot.plotZ, slot.angle
	return t
end

-- What a plot's sign says: the name of whoever is driving that plot, or what kind of plot it is
-- when nobody is (so it never stands there blank).
function LobbyLayout.signText(driver: string?, label: string): string
	return driver or string.upper(label)
end

-- Close enough to the pad to start driving? (flat distance)
function LobbyLayout.inReach(slot: Slot, x: number, z: number): boolean
	local dx, dz = x - slot.padX, z - slot.padZ
	return dx * dx + dz * dz <= LobbyLayout.REACH * LobbyLayout.REACH
end

-- The first lobby slot that drives this track (for the plot keys while driving).
function LobbyLayout.slotFor(track: number): number?
	for _, s in LobbyLayout.slots() do
		if s.track == track then
			return s.index
		end
	end
	return nil
end

return LobbyLayout
