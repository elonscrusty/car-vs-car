--!strict
-- The lobby plaza at the end of the street: paving, lamps, and a spot for each big building
-- (car shop, upgrades garage). Looks only for now.
-- Plain numbers only (Lune tests load this). Plaza-local studs: x = right, z = away from the
-- street (0 = the street's end edge), y = up. PlazaBuilder turns them into world space with an
-- anchor CFrame (LookVector = into the plaza).

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Spot = {
	name: string, -- building module, server/PlazaParts/<name> or Shared/<name> (skipped if missing)
	box: Box, -- the building must stay inside this
	face: number, -- which way its open front looks, degrees about y (0 = +z, 90 = +x, -90 = -x)
}

local Plaza = {}

-- Matches LobbyLayout.PLAZA (x -62..62, z 1026..1096): the street ends at z = 1026.
Plaza.WIDTH = 124
Plaza.DEPTH = 70
Plaza.CORNER = 16 -- the two far corners are cut off at 45 degrees
Plaza.MOUTH = 28 -- open lane from the street into the plaza: nothing stands in it
Plaza.BORDER = 2 -- darker kerb around the edge

function Plaza.box(): Box
	return { minX = -Plaza.WIDTH / 2, maxX = Plaza.WIDTH / 2, minZ = 0, maxZ = Plaza.DEPTH }
end

-- Buildings sit around the open middle. Shop on the left and garage on the right open toward the
-- middle lane; the back of the plaza stays open paving.
Plaza.spots = {
	{ name = "Shop", box = { minX = -58, maxX = -30, minZ = 6, maxZ = 34 }, face = 90 },
	{ name = "Garage", box = { minX = 32, maxX = 48, minZ = 6, maxZ = 30 }, face = -90 },
} :: { Spot }

function Plaza.spot(name: string): Spot?
	for _, s in Plaza.spots do
		if s.name == name then
			return s
		end
	end
	return nil
end

-- Street lamps (x, z): a pair at the street mouth, then down both sides.
Plaza.lamps = {
	{ -16, 3 },
	{ 16, 3 },
	{ -32, 40 },
	{ 32, 40 },
	{ -50, 46 },
	{ 50, 46 },
	{ -30, 64 },
	{ 30, 64 },
}

-- Planter boxes with a bush (x, z, width along x, depth along z), between lamps and buildings.
Plaza.planters = {
	{ -42, 40, 8, 3 },
	{ 42, 40, 8, 3 },
	{ -32, 54, 3, 8 },
	{ 32, 54, 3, 8 },
}

-- Little things on the paving, from carter's Meshy props (ServerStorage.LobbyMeshes) with block
-- stand-ins. name = the prop, x/z = spot, face = which way its front looks (degrees, like
-- Spot.face), h = height in studs, r = how far it reaches from its spot (for the tests).
export type Decor = { name: string, x: number, z: number, face: number, h: number, r: number }
Plaza.decor = {
	-- benches along the open lane, looking in at it, a bin between each pair
	{ name = "ParkBench", x = -19, z = 21, face = 90, h = 2.6, r = 2.6 },
	{ name = "ParkBench", x = -19, z = 33, face = 90, h = 2.6, r = 2.6 },
	{ name = "ParkBench", x = 19, z = 21, face = -90, h = 2.6, r = 2.6 },
	{ name = "ParkBench", x = 19, z = 33, face = -90, h = 2.6, r = 2.6 },
	{ name = "TrashCan", x = -19, z = 27, face = 90, h = 2.4, r = 1 },
	{ name = "TrashCan", x = 19, z = 27, face = -90, h = 2.4, r = 1 },
	-- picnic tables on the open paving at the back
	{ name = "PicnicTable", x = -11, z = 57, face = 0, h = 2.6, r = 3.2 },
	{ name = "PicnicTable", x = 11, z = 57, face = 0, h = 2.6, r = 3.2 },
	-- flower pots by the shop and garage fronts
	{ name = "FlowerPot", x = -28, z = 3.5, face = 180, h = 2, r = 1 },
	{ name = "FlowerPot", x = 28, z = 3.5, face = 180, h = 2, r = 1 },
	{ name = "FlowerPot", x = -28, z = 37, face = 180, h = 2, r = 1 },
	{ name = "FlowerPot", x = 28, z = 37, face = 180, h = 2, r = 1 },
	-- a mailbox and a hydrant either side of where people appear
	{ name = "Mailbox", x = -16.5, z = 9.5, face = 90, h = 3.4, r = 1 },
	{ name = "Hydrant", x = 16.5, z = 9.5, face = -90, h = 2.2, r = 0.8 },
} :: { Decor }

-- Inside the cut-off corners and the box? (plaza-local)
function Plaza.onPaving(x: number, z: number): boolean
	local b = Plaza.box()
	if x < b.minX or x > b.maxX or z < b.minZ or z > b.maxZ then
		return false
	end
	-- far corners: distance in from the back edge plus in from the side must reach CORNER
	local fromBack = b.maxZ - z
	local fromSide = math.min(x - b.minX, b.maxX - x)
	return fromBack + fromSide >= Plaza.CORNER
end

return Plaza
