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
export type Point = { x: number, y: number, z: number }

local LobbyLayout = {}

-- The plots at real RC size (from big size): 320 x 440 -> 80 wide x 110 deep.
LobbyLayout.MINI = TrackData.RC_SCALE
LobbyLayout.PLOT_W = Kit.WIDTH * LobbyLayout.MINI -- along the road (z)
LobbyLayout.PLOT_D = Kit.DEPTH * LobbyLayout.MINI -- away from the road (x)
LobbyLayout.GAP = 40 -- grass and trees between two plots on the same side (carter 2026-10-25:
-- "all the plots are too close together"; was 10)
LobbyLayout.ROAD_W = 14 -- the dark road
LobbyLayout.WALK_W = 6 -- the light footpath on each side of the road
LobbyLayout.EDGE = LobbyLayout.ROAD_W / 2 + LobbyLayout.WALK_W -- plot fronts are this far from x = 0
LobbyLayout.ROWS = 4
LobbyLayout.FIRST_Z = 1000 -- middle of the first row of plots (next to the spawn lobby)
LobbyLayout.STEP = LobbyLayout.PLOT_W + LobbyLayout.GAP
LobbyLayout.REACH = 8 -- how close to the pad you must be to start driving
LobbyLayout.PAD = 5 -- pad size
-- The kinds of plot in the lobby (index into TrackData.order; rocks dropped 2026-10-23, show
-- is on hold).
LobbyLayout.TRACKS = { 1, 2 }
-- What each lobby plot is, by slot (left row 1, right row 1, left row 2, ...). Race plots are
-- the ones players own and build their track on (the owner then picks race or drift for it), so
-- 7 of them; one ready-made drift track stays open for everyone so the DRIFT pad always works
-- (carter dropped rocks 2026-10-23): race, race / drift, race / race, race / race, race.
LobbyLayout.SLOT_TRACKS = { 2, 2, 1, 2, 2, 2, 2, 2 }
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

-- The order joining players get plots in: race plots first (the plots you build a track on,
-- carter's game shape v3), then the rest. Slot indexes.
function LobbyLayout.claimOrder(): { number }
	local race, other = {}, {}
	for _, s in LobbyLayout.slots() do
		table.insert(if s.id == "race" then race else other, s.index)
	end
	table.move(other, 1, #other, #race + 1, race)
	return race
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
		-- the end ones just past the end plots (a full half gap would reach the spawn lobby)
		if row == 0 then
			z = LobbyLayout.FIRST_Z - LobbyLayout.PLOT_W / 2 - 5
		elseif row == LobbyLayout.ROWS then
			z = LAST_Z + LobbyLayout.PLOT_W / 2 + 5
		end
		for _, side in { -1, 1 } do
			table.insert(
				out,
				{ x = side * (LobbyLayout.EDGE - 1), z = z, faceX = -side, faceZ = 0 }
			)
		end
	end
	return out
end

-- A plot's star board (Stars.server): on a pole by the footpath, down the road from the pad,
-- turned almost to face the pad, so the whole board is in front of the plot (clear of the
-- gate's posts) and reads from the pad. Returns the centre (y is the middle) and the point it
-- faces. Its road end hangs over the road's edge, above the cars.
LobbyLayout.BOARD_W, LobbyLayout.BOARD_H = 8, 5.6
LobbyLayout.BOARD_Y = 8.9 -- its bottom (6.1) over people's heads
LobbyLayout.BOARD_BACK = 20 -- down the road from the pad (the gate posts are about 11 away)
function LobbyLayout.board(s: Slot): (Point, Point)
	local side = if s.padX < 0 then -1 else 1
	local y = LobbyLayout.BOARD_Y
	return { x = side * (LobbyLayout.EDGE - 5), y = y, z = s.padZ - LobbyLayout.BOARD_BACK }, {
		x = 0,
		y = y,
		z = s.padZ + 10,
	}
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

-- Trees in the grass gaps between plots on the same side: two rows, one near each plot's side
-- wall, staggered from the footpath to the back, clear of the gap's flag and flower bed (at the
-- front).
LobbyLayout.TREE_DZ = 12 -- from the middle of the gap (its walls are GAP / 2 away)
LobbyLayout.TREE_X = { 30, 52, 76, 100 } -- from the plot fronts, toward the back
function LobbyLayout.trees(): { Spot }
	local out: { Spot } = {}
	for row = 1, LobbyLayout.ROWS - 1 do
		local z = LobbyLayout.FIRST_Z + (row - 0.5) * LobbyLayout.STEP
		for _, side in { -1, 1 } do
			for i, dx in LobbyLayout.TREE_X do
				local dz = if i % 2 == 1 then -LobbyLayout.TREE_DZ else LobbyLayout.TREE_DZ
				table.insert(out, {
					x = side * (LobbyLayout.EDGE + dx),
					z = z + dz,
					faceX = 0,
					faceZ = 1,
				})
			end
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

-- The big race maps (RaceMaps) are drivable "slots" after the street's plots: index
-- #slots + k is map k. nil when there is no such map.
function LobbyLayout.mapAt(index: number): any?
	local k = index - #LobbyLayout.slots()
	if k < 1 then
		return nil
	end
	return sibling("RaceMaps").list()[k]
end

function LobbyLayout.mapIndex(k: number): number
	return #LobbyLayout.slots() + k
end

-- A lobby plot as a track: its kind's data (or its owner's own track), placed and turned where
-- that plot sits. A race map's index gives that map's track (map = its id).
function LobbyLayout.track(slotIndex: number): any
	local map = LobbyLayout.mapAt(slotIndex)
	if map then
		local t = map.track()
		t.map = map.id
		return t
	end
	local slot = LobbyLayout.slots()[slotIndex]
	local t = TrackData.get(slot.id)
	t.rcX, t.rcZ, t.rcAngle = slot.plotX, slot.plotZ, slot.angle
	return t
end

-- What a plot's sign says: whose it is (its driver, else its owner), or what kind of plot it is
-- when it is nobody's (so it never stands there blank); "CLOSED" when its owner shut it (plots
-- are open by default, so OPEN on every sign only said nothing new to a new player).
function LobbyLayout.signText(name: string?, label: string, closed: boolean?): string
	if name == nil or name == "" then
		return string.upper(label)
	end
	return if closed then name .. " - CLOSED" else name
end

-- May this person drive this plot now? Nobody else may be on it; then it is theirs, nobody's,
-- or its owner has opened it to friends. (UserIds; owner nil = nobody owns it.)
function LobbyLayout.canDrive(owner: number?, me: number, open: boolean, busy: boolean): boolean
	if busy then
		return false
	end
	return owner == nil or owner == me or open
end

-- What a pad's DRIVE button says to me (UserIds; 0 = nobody): DRIVE when I may drive that
-- plot, BUSY when someone else is driving it, else whose it is and LOCKED.
function LobbyLayout.padButton(
	ownerId: number,
	ownerName: string,
	driverId: number,
	open: boolean,
	me: number
): (boolean, string)
	local owner = if ownerId ~= 0 then ownerId else nil
	-- (a visitor on my own plot doesn't make it busy for me: the owner comes first)
	local busy = driverId ~= 0 and driverId ~= me and ownerId ~= me
	if LobbyLayout.canDrive(owner, me, open, busy) then
		return true, "DRIVE"
	elseif busy then
		return false, "BUSY"
	end
	-- (one line on a phone's DRIVE button: a long name is cut, so the words stay big)
	local who = if ownerName ~= "" then string.upper(string.sub(ownerName, 1, 10)) else "SOMEONE"
	return false, who .. " - LOCKED"
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
