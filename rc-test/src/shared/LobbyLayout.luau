--!strict
-- The walking lobby ("plot street"): every RC-size plot side by side, fronts on one street.
-- Plain numbers only (Lune tests load this). Real studs, world space. The plots themselves
-- are built by TrackBuilder; the lobby only adds the street around their fronts.

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

export type Slot = {
	index: number, -- same order as TrackData.order (keys 1-4)
	id: string,
	label: string,
	standX: number, -- top-middle of the driver stand
	standY: number,
	standZ: number,
	exitX: number, -- where a person is put back on the street after driving
	exitZ: number,
	signX: number, -- the street sign that says who is driving
	signZ: number,
}

local LobbyLayout = {}

local S = TrackData.RC_SCALE
LobbyLayout.STREET_W = 60 -- street depth (z), in front of the plot entrances
LobbyLayout.REACH = 10 -- how close to the stand you must be to start driving
LobbyLayout.EXIT = 8 -- how far into the street you step off after driving

-- Plot fronts all sit on this line (RC size).
LobbyLayout.FRONT_Z = TrackData.RC_Z + Kit.DEPTH / 2 * S

function LobbyLayout.slots(): { Slot }
	local out: { Slot } = {}
	for i, id in TrackData.order do
		local t = TrackData.get(id)
		local sx, _, sz = TrackData.toWorld(t, true, Kit.STAND.x, 0, Kit.STAND.z)
		local ex, _, _ = TrackData.toWorld(t, true, 0, 0, 0)
		table.insert(out, {
			index = i,
			id = id,
			label = t.label,
			standX = sx,
			standY = Kit.STAND_H * S,
			standZ = sz,
			exitX = ex,
			exitZ = LobbyLayout.FRONT_Z + LobbyLayout.EXIT,
			-- left of the entrance gap, on the street edge (the plot's own big sign is on the right)
			signX = ex - 20,
			signZ = LobbyLayout.FRONT_Z + 3,
		})
	end
	return out
end

-- The street box (x from minX to maxX, z from minZ to maxZ), with 30 studs past each end plot.
function LobbyLayout.street(): { minX: number, maxX: number, minZ: number, maxZ: number }
	local slots = LobbyLayout.slots()
	local half = Kit.WIDTH / 2 * S
	return {
		minX = slots[1].exitX - half - 30,
		maxX = slots[#slots].exitX + half + 30,
		minZ = LobbyLayout.FRONT_Z,
		maxZ = LobbyLayout.FRONT_Z + LobbyLayout.STREET_W,
	}
end

-- Grass under everything (plots and the gaps between them), so there are no holes to fall in.
function LobbyLayout.ground(): { minX: number, maxX: number, minZ: number, maxZ: number }
	local st = LobbyLayout.street()
	return {
		minX = st.minX,
		maxX = st.maxX,
		minZ = TrackData.RC_Z - Kit.DEPTH / 2 * S - 30,
		maxZ = st.maxZ + 30,
	}
end

-- Where people appear: middle of the street, looking at the plots.
function LobbyLayout.spawn(): (number, number, number)
	local st = LobbyLayout.street()
	return (st.minX + st.maxX) / 2, 3, st.maxZ - 20
end

-- Where a parked car waits on the street before its first drive (spread out, one per player),
-- just in front of the start pad so it is in view.
function LobbyLayout.parkSpot(n: number): (number, number)
	local x, _, z = LobbyLayout.spawn()
	return x - 12 + ((n - 1) % 8) * 3.5, z - 8
end

-- Close enough to the stand to start driving? (flat distance)
function LobbyLayout.inReach(slot: Slot, x: number, z: number): boolean
	local dx, dz = x - slot.standX, z - slot.standZ
	return dx * dx + dz * dz <= LobbyLayout.REACH * LobbyLayout.REACH
end

return LobbyLayout
