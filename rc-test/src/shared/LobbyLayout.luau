--!strict
-- The walking lobby (carter's picture, /mnt/project-files/rc-game/lobby-target.png): one road with
-- 4 small garden-size plots on each side, fronts facing the road, a yellow DRIVE pad and a sign
-- at each front, and a plaza at the road's end with the car shop and the garage.
-- Stand on a pad and press E to drive that plot's full-size track (the RC plots TrackBuilder
-- builds far away); walking again brings you back to that pad.
-- Plain numbers only (Lune tests load this). Real studs, world space. The road runs along z;
-- the plaza is at its +z end.

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

-- Small plots are the plot shrunk to this (from big size): 320 x 440 -> 32 wide x 44 deep.
LobbyLayout.MINI = 0.1
LobbyLayout.PLOT_W = Kit.WIDTH * LobbyLayout.MINI -- along the road (z)
LobbyLayout.PLOT_D = Kit.DEPTH * LobbyLayout.MINI -- away from the road (x)
LobbyLayout.GAP = 8 -- grass between two small plots on the same side
LobbyLayout.ROAD_W = 14 -- the dark road
LobbyLayout.WALK_W = 6 -- the light footpath on each side of the road
LobbyLayout.EDGE = LobbyLayout.ROAD_W / 2 + LobbyLayout.WALK_W -- plot fronts are this far from x = 0
LobbyLayout.ROWS = 4
LobbyLayout.FIRST_Z = 880 -- middle of the first row of plots (the far end of the road)
LobbyLayout.STEP = LobbyLayout.PLOT_W + LobbyLayout.GAP
LobbyLayout.REACH = 8 -- how close to the pad you must be to start driving
LobbyLayout.PAD = 5 -- pad size
-- The plots in the lobby cycle through these tracks (show is on hold, so it is not in the lobby;
-- key 4 still drives it).
LobbyLayout.TRACKS = { 1, 2, 3 }
-- The copy car on a small plot is drawn this much bigger than true scale (true scale is only
-- half a stud long: too small to see from the street).
LobbyLayout.MINI_CAR = 3
-- ...so keep its middle this far inside the small plot's walls, or its nose pokes through.
LobbyLayout.MINI_CAR_EDGE = 1.2

local LAST_Z = LobbyLayout.FIRST_Z + (LobbyLayout.ROWS - 1) * LobbyLayout.STEP
-- The plaza: from the end of the plots to the back fence.
LobbyLayout.PLAZA = {
	minX = -62,
	maxX = 62,
	minZ = LAST_Z + LobbyLayout.PLOT_W / 2 + 10,
	maxZ = LAST_Z + LobbyLayout.PLOT_W / 2 + 80,
}

function LobbyLayout.slots(): { Slot }
	local out: { Slot } = {}
	for row = 1, LobbyLayout.ROWS do
		local z = LobbyLayout.FIRST_Z + (row - 1) * LobbyLayout.STEP
		for _, side in { -1, 1 } do -- -1 = left of the road (-x), 1 = right
			local index = #out + 1
			local track = LobbyLayout.TRACKS[(index - 1) % #LobbyLayout.TRACKS + 1]
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
				padX = padX,
				padZ = z + 6,
				exitX = side * 1, -- on its own side of the road, just out of reach of the pad
				exitZ = z + 6,
				signX = front - side * 0.8, -- on the footpath edge
				signZ = z - 9,
			})
		end
	end
	return out
end

-- The road (dark) and its footpaths (light), from the far end to the plaza.
function LobbyLayout.road(): Box
	return {
		minX = -LobbyLayout.ROAD_W / 2,
		maxX = LobbyLayout.ROAD_W / 2,
		minZ = LobbyLayout.FIRST_Z - LobbyLayout.PLOT_W / 2 - 14,
		maxZ = LobbyLayout.PLAZA.minZ,
	}
end
function LobbyLayout.walks(): Box
	local r = LobbyLayout.road()
	return { minX = -LobbyLayout.EDGE, maxX = LobbyLayout.EDGE, minZ = r.minZ, maxZ = r.maxZ }
end

-- Grass under everything (the water and shore go round it).
function LobbyLayout.ground(): Box
	local far = LobbyLayout.EDGE + LobbyLayout.PLOT_D + 18
	return {
		minX = -far,
		maxX = far,
		minZ = LobbyLayout.road().minZ - 6,
		maxZ = LobbyLayout.PLAZA.maxZ + 14,
	}
end

-- The plaza buildings (looks only for now). The car shop is in Plaza.luau.
function LobbyLayout.garage(): Spot -- upgrades garage, right
	return { x = 40, z = LobbyLayout.PLAZA.minZ + 18, faceX = -1, faceZ = 0 }
end
-- Lamps along both footpaths (between plots). The plaza's own lamps are in Plaza.luau.
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

-- Tyre stacks across the far end of the road and footpaths (the road stops here).
function LobbyLayout.tires(): { Spot }
	local out: { Spot } = {}
	local z = LobbyLayout.road().minZ + 1.5
	local x = -LobbyLayout.EDGE + 1.5
	while x <= LobbyLayout.EDGE - 1.5 do
		table.insert(out, { x = x, z = z, faceX = 0, faceZ = 1 })
		x += 3
	end
	return out
end

-- Trees: in the grass between plots (at the back), along the outer edges, around the plaza.
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
	local p = LobbyLayout.PLAZA
	for _, c in
		{
			{ -57, 0.04 },
			{ 57, 0.04 },
			{ -56, 0.7 },
			{ 56, 0.7 },
			{ -40, 0.97 },
			{ 40, 0.97 },
			{ -21, 0.62 },
			{ 21, 0.62 },
		}
	do
		table.insert(out, { x = c[1], z = p.minZ + (p.maxZ - p.minZ) * c[2], faceX = 0, faceZ = 1 })
	end
	return out
end

-- Where people appear: the plaza, just past the end of the road, looking up the road.
function LobbyLayout.spawn(): (number, number, number)
	return 0, 3, LobbyLayout.PLAZA.minZ + 14
end

-- Where a parked car waits before its first drive (spread out, one per player): in front of the
-- spawn, so it is in view.
function LobbyLayout.parkSpot(n: number): (number, number)
	local x, _, z = LobbyLayout.spawn()
	return x - 7 + ((n - 1) % 5) * 3.5, z - 7
end

-- A spot on a real plot (plot-local, big units) -> the same spot on its small lobby copy (turned
-- like the copy), or nil when it is off the plot (falling, or the car is somewhere else).
function LobbyLayout.toMini(
	slot: Slot,
	lx: number,
	ly: number,
	lz: number
): (number?, number, number)
	if math.abs(lx) > Kit.WIDTH / 2 or math.abs(lz) > Kit.DEPTH / 2 then
		return nil, 0, 0
	end
	local s = LobbyLayout.MINI
	local hw = LobbyLayout.PLOT_W / 2 - LobbyLayout.MINI_CAR_EDGE
	local hd = LobbyLayout.PLOT_D / 2 - LobbyLayout.MINI_CAR_EDGE
	local x = math.clamp(lx * s, -hw, hw)
	local z = math.clamp(lz * s, -hd, hd)
	-- same turn as CFrame.Angles(0, angle, 0)
	local c, n = math.cos(slot.angle), math.sin(slot.angle)
	return slot.plotX + x * c + z * n, ly * s, slot.plotZ - x * n + z * c
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
