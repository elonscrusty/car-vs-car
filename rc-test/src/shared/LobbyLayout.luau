--!strict
-- The walking lobby: a small garden-size copy of every plot, side by side, fronts on one street.
-- Stand on the pad in front of a small plot and press E to drive the full-size track (the RC
-- plots TrackBuilder builds far away); walking again brings you back to that pad.
-- Plain numbers only (Lune tests load this). Real studs, world space.

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
	index: number, -- same order as TrackData.order (keys 1-4)
	id: string,
	label: string,
	plotX: number, -- middle of the small plot on the floor
	plotZ: number,
	padX: number, -- the DRIVE pad in front of the small plot
	padZ: number,
	exitX: number, -- where a person is put back after driving
	exitZ: number,
	signX: number, -- the street sign that says who is driving
	signZ: number,
}

local LobbyLayout = {}

-- Small plots are the plot shrunk to this (from big size): 320 x 440 -> 32 x 44 studs.
LobbyLayout.MINI = 0.1
LobbyLayout.PLOT_W = Kit.WIDTH * LobbyLayout.MINI
LobbyLayout.PLOT_D = Kit.DEPTH * LobbyLayout.MINI
LobbyLayout.GAP = 10 -- grass between two small plots
LobbyLayout.FRONT_Z = 1000 -- every small plot's front edge; the street starts here
LobbyLayout.STREET_W = 40 -- street depth (z)
LobbyLayout.REACH = 8 -- how close to the pad you must be to start driving
LobbyLayout.PAD = 6 -- pad size

function LobbyLayout.slots(): { Slot }
	local out: { Slot } = {}
	local n = #TrackData.order
	local step = LobbyLayout.PLOT_W + LobbyLayout.GAP
	for i, id in TrackData.order do
		local t = TrackData.get(id)
		local x = (i - (n + 1) / 2) * step -- the row is centred on x = 0
		local padZ = LobbyLayout.FRONT_Z + 5
		table.insert(out, {
			index = i,
			id = id,
			label = t.label,
			plotX = x,
			plotZ = LobbyLayout.FRONT_Z - LobbyLayout.PLOT_D / 2,
			padX = x,
			padZ = padZ,
			exitX = x,
			exitZ = padZ + LobbyLayout.REACH + 3,
			signX = x + 11,
			signZ = LobbyLayout.FRONT_Z + 2,
		})
	end
	return out
end

-- The street box, with 20 studs past each end plot.
function LobbyLayout.street(): Box
	local slots = LobbyLayout.slots()
	local half = LobbyLayout.PLOT_W / 2
	return {
		minX = slots[1].plotX - half - 20,
		maxX = slots[#slots].plotX + half + 20,
		minZ = LobbyLayout.FRONT_Z,
		maxZ = LobbyLayout.FRONT_Z + LobbyLayout.STREET_W,
	}
end

-- Grass under the small plots, the gaps between them and the street.
function LobbyLayout.ground(): Box
	local st = LobbyLayout.street()
	return {
		minX = st.minX,
		maxX = st.maxX,
		minZ = LobbyLayout.FRONT_Z - LobbyLayout.PLOT_D - 20,
		maxZ = st.maxZ + 20,
	}
end

-- Where people appear: middle of the street, looking at the plots.
function LobbyLayout.spawn(): (number, number, number)
	local st = LobbyLayout.street()
	return (st.minX + st.maxX) / 2, 3, st.maxZ - 10
end

-- Where a parked car waits on the street before its first drive (spread out, one per player),
-- just in front of the start pad so it is in view.
function LobbyLayout.parkSpot(n: number): (number, number)
	local x, _, z = LobbyLayout.spawn()
	return x - 12 + ((n - 1) % 8) * 3.5, z - 6
end

-- Close enough to the pad to start driving? (flat distance)
function LobbyLayout.inReach(slot: Slot, x: number, z: number): boolean
	local dx, dz = x - slot.padX, z - slot.padZ
	return dx * dx + dz * dz <= LobbyLayout.REACH * LobbyLayout.REACH
end

return LobbyLayout
