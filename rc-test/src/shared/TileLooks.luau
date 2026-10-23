--!strict
-- How the build-your-own-track tiles look (carter's grid tiles, 2026-10-23), on top of the road
-- and curbs TrackTiles builds: lane lines, a start gantry, glowing arrows on the boost pad, a
-- shiny oil puddle with a tipped barrel, chevron signs round the sharp turn, warning signs and
-- splats by the hazards, and a few bushes and tyre stacks on the grass. Names starting "Skin"
-- draw TrackTiles' own cones, barrels, bumps, squeeze blocks and island, which it hides
-- (Transparency 1) when this module is there: same spots (u / v in cells), same sizes. Looks only: nothing solid, nothing the car can hit or feel
-- (the builder also turns CanQuery off), and nothing on the road taller than a painted line.
--
-- Tile-local space in plot BIG units (like Race.luau; the plot is shrunk later): centre (0, 0),
-- +x east, -z north, edges at +-CELL/2. A piece at rot 0 runs as TrackTiles says: start /
-- straight / chicane / boost / oil N-S (you drive S to N), turn and sharp N-E, cross N-S + E-W.
-- The road top is at y = ROAD_TOP. Plain numbers (Lune tests load it).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")

type V3 = Garage.V3
type Piece = Garage.Piece

local TileLooks = {}

TileLooks.CELL = 58 -- TrackTiles.CELL
TileLooks.ROAD = 30 -- Race.luau ROAD
TileLooks.CURB = 3 -- Race.luau CURB_WIDTH
TileLooks.ROAD_TOP = 0.1 -- Kit.ribbon's road slab top
TileLooks.PAINT = 0.04 -- painted lines and puddles: this thin, just over the road
TileLooks.SHARP = 0.2 -- the sharp turn's arc radius, in cells (TrackTiles bend(0.2))
TileLooks.MAX_PARTS = 24 -- per tile, phone budget (a big grid has many tiles)
TileLooks.IDS = {
	"start",
	"straight",
	"turn",
	"sharp",
	"chicane",
	"cross",
	"split",
	"narrow",
	"cones",
	"barrels",
	"bumps",
	"mud",
	"puddle",
	"sand",
	"oil",
	"boost",
	"jump",
}

local WHITE = { 240, 240, 240 }
local YELLOW = { 255, 210, 50 }
local RED = { 220, 50, 44 }
local DARK = { 40, 40, 46 }
local BUSH = { 76, 160, 70 }
local BUSH2 = { 100, 186, 80 }
local TYRE = { 34, 34, 38 }
local BOOST = { 60, 220, 255 }
local OIL = { 16, 16, 22 }
local ORANGE = { 255, 130, 30 }
local BLUE = { 40, 110, 220 }
local MUD = { 110, 78, 46 }
local SAND = { 222, 196, 130 }
local WATER = { 70, 140, 210 }

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- The road's centre line at rot 0, as points (x, z) from the S end on (for the tests and the
-- lane dashes). The chicane is left out (its wiggle is TrackTiles' own).
function TileLooks.centre(id: string, cell: number): { { number } }
	local H = cell / 2
	local out = {}
	if id == "turn" or id == "sharp" then
		-- from the N edge to the E edge round the NE corner
		local r = if id == "turn" then H else TileLooks.SHARP * cell
		local cx, cz = r, -r -- the arc's centre (the turn's is the NE corner itself)
		-- the N straight (sharp only), the arc, the E straight (sharp only)
		if id == "sharp" then
			for z = -H, -r, 2 do
				table.insert(out, { 0, z })
			end
		end
		for i = 0, 16 do
			local a = math.rad(180 - 90 * i / 16) -- from west of the centre round to south
			table.insert(out, { cx + r * math.cos(a), cz + r * math.sin(a) })
		end
		if id == "sharp" then
			for x = r, H, 2 do
				table.insert(out, { x, 0 })
			end
		end
	elseif id ~= "chicane" then
		for z = H, -H, -2 do
			table.insert(out, { 0, z })
		end
		if id == "cross" then
			for x = -H, H, 2 do
				table.insert(out, { x, 0 })
			end
		end
	end
	return out
end

-- The pieces for tile `id` (TileLooks.IDS), tile-local at rot 0. Group "TileLooks".
function TileLooks.parts(id: string, cell: number?): { Piece }
	local C = cell or TileLooks.CELL
	local H = C / 2
	local edge = TileLooks.ROAD / 2 + TileLooks.CURB -- road + curb, from the centre line
	local grass = (edge + H) / 2 -- middle of the grass strip beside a N-S road
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local G = "TileLooks"
	local paintY = TileLooks.ROAD_TOP + TileLooks.PAINT / 2
	local paint = { collide = false }
	local noHit = { collide = false }
	local function dash(x: number, z: number, yaw: number, color: { number }?)
		add(G, "Line", v(0.7, TileLooks.PAINT, 6), v(x, paintY, z), color or WHITE, {
			rot = v(0, yaw, 0),
			collide = false,
		})
	end
	local function bush(x: number, z: number)
		add(G, "Bush", v(3.6, 3.6, 3.6), v(x, 1.4, z), BUSH, { shape = "Ball", collide = false })
		add(G, "Bush", v(2.4, 2.4, 2.4), v(x + 1.6, 1, z + 0.8), BUSH2, {
			shape = "Ball",
			collide = false,
		})
	end
	local function tyres(x: number, z: number)
		for i = 0, 2 do
			add(G, "Tyre", v(1.2, 3, 3), v(x, 0.6 + i * 1.2, z), TYRE, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				collide = false,
			})
		end
	end

	-- a yellow warning diamond on the grass before the tile (both ways), with a picture dot
	local function sign(icon: { number })
		for _, s in { -1, 1 } do
			local x, z = s * (edge + 4), s * (H - 6)
			add(G, "WarnPost", v(0.5, 4.5, 0.5), v(x, 2.25, z), DARK, noHit)
			add(G, "WarnSign", v(3, 3, 0.3), v(x, 5.4, z), YELLOW, {
				rot = v(0, 0, 45),
				collide = false,
			})
			add(G, "WarnIcon", v(0.5, 1.4, 1.4), v(x, 5.4, z), icon, {
				shape = "Cylinder",
				rot = v(0, 90, 0),
				collide = false,
			})
		end
	end

	if id == "straight" then
		for _, z in { -C / 3, 0, C / 3 } do
			dash(0, z, 0)
		end
		bush(-grass, C / 5)
		bush(grass, -C / 5)
	elseif id == "start" then
		-- a gantry over the line: two posts on the grass, a beam, three start lamps
		local px = edge + 3
		for _, sx in { -1, 1 } do
			add(G, "GantryPost", v(1.2, 13, 1.2), v(sx * px, 6.5, 0), DARK, noHit)
		end
		add(G, "GantryBeam", v(2 * px + 1.2, 2, 1.6), v(0, 13.6, 0), DARK, noHit)
		for i = -1, 1 do
			add(G, "StartLamp", v(1.4, 1.4, 0.4), v(i * 3, 13.6, 0.9), RED, {
				shape = "Ball",
				material = "Neon",
				collide = false,
			})
		end
		-- the grid boxes behind the line (S of it)
		for _, sx in { -1, 1 } do
			local x, z = sx * 6, 7 + (if sx > 0 then 6 else 0)
			add(G, "GridBox", v(5, TileLooks.PAINT, 0.6), v(x, paintY, z), WHITE, paint)
			add(G, "GridBox", v(0.6, TileLooks.PAINT, 3), v(x - 2.2, paintY, z + 1.5), WHITE, paint)
			add(G, "GridBox", v(0.6, TileLooks.PAINT, 3), v(x + 2.2, paintY, z + 1.5), WHITE, paint)
		end
	elseif id == "turn" then
		-- lane dashes round the arc (radius H about the NE corner)
		for _, deg in { 157.5, 135, 112.5 } do
			local a = math.rad(deg)
			local x, z = H + H * math.cos(a), -H + H * math.sin(a)
			-- along the arc: the tangent (-sin a, cos a)
			dash(x, z, -deg)
		end
		tyres(H - 4, -H + 4) -- inside the corner
		bush(-H + 5, H - 5) -- outside, in the far corner
	elseif id == "chicane" then
		-- striped marker posts in the four corners (the road wiggles through the middle)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x, z = sx * (H - 2.5), sz * (H - 2.5)
				add(G, "Marker", v(0.8, 3, 0.8), v(x, 1.5, z), WHITE, noHit)
				add(G, "MarkerTop", v(0.9, 1, 0.9), v(x, 3.5, z), RED, noHit)
			end
		end
	elseif id == "cross" then
		-- a yellow box junction in the middle, and a bush in two corners
		local half = TileLooks.ROAD / 2 - 1
		local len = math.sqrt(2) * 2 * half
		for _, yaw in { 45, -45 } do
			add(G, "Junction", v(0.8, TileLooks.PAINT, len), v(0, paintY, 0), YELLOW, {
				rot = v(0, yaw, 0),
				collide = false,
			})
		end
		bush(-H + 5, -H + 5)
		bush(H - 5, H - 5)
	elseif id == "boost" then
		-- three glowing arrows pointing the way you drive (north, -z)
		local arm, a = 8, 40
		for _, tz in { -9, 0, 9 } do
			for _, s in { -1, 1 } do
				-- each arm runs back (south) and out from the tip
				local cx = s * (arm / 2) * math.sin(math.rad(a))
				local cz = tz + (arm / 2) * math.cos(math.rad(a))
				add(G, "BoostArrow", v(arm, TileLooks.PAINT * 2, 1.4), v(cx, paintY, cz), BOOST, {
					rot = v(0, -s * (90 - a), 0),
					material = "Neon",
					collide = false,
				})
			end
		end
		-- glowing strips along both road edges
		for _, s in { -1, 1 } do
			add(
				G,
				"BoostStrip",
				v(0.8, TileLooks.PAINT * 2, C - 6),
				v(s * (TileLooks.ROAD / 2 - 1.5), paintY, 0),
				BOOST,
				{ material = "Neon", collide = false }
			)
		end
	elseif id == "oil" then
		-- a shiny black puddle (flat discs) with a purple-blue sheen, and a tipped barrel
		for _, d in { { -3, 2, 14 }, { 4, -3, 10 }, { -1, -7, 7 } } do
			add(G, "Oil", v(TileLooks.PAINT, d[3], d[3]), v(d[1], paintY, d[2]), OIL, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				material = "Glass",
				collide = false,
			})
		end
		for _, d in { { -4, 1, 5, { 150, 90, 255 } }, { 5, -4, 4, { 70, 200, 230 } } } do
			add(
				G,
				"OilSheen",
				v(TileLooks.PAINT, d[3], d[3] * 0.6),
				v(d[1], paintY + TileLooks.PAINT / 2, d[2]),
				d[4] :: { number },
				{ shape = "Cylinder", rot = v(0, 0, 90), material = "Glass", collide = false }
			)
		end
		local bx, bz = grass, 4
		add(G, "Barrel", v(4, 2.6, 2.6), v(bx, 1.3, bz), { 30, 90, 160 }, {
			shape = "Cylinder",
			rot = v(0, 30, 0),
			collide = false,
		})
		add(G, "BarrelBand", v(0.5, 2.75, 2.75), v(bx, 1.3, bz), YELLOW, {
			shape = "Cylinder",
			rot = v(0, 30, 0),
			collide = false,
		})
	elseif id == "sharp" then
		-- three red chevron boards round the outside of the hairpin, facing the driver
		local r = TileLooks.SHARP * C
		local cx, cz = r, -r
		local dist = r + edge + 3
		for _, deg in { 112, 135, 158 } do
			local a = math.rad(deg)
			local dx, dz = math.cos(a), math.sin(a)
			local x, z = cx + dist * dx, cz + dist * dz
			local yaw = math.deg(math.atan2(dx, dz))
			add(G, "SignPost", v(0.5, 4, 0.5), v(x, 2, z), DARK, noHit)
			add(
				G,
				"Sign",
				v(4, 2.6, 0.3),
				v(x, 4.6, z),
				RED,
				{ rot = v(0, yaw, 0), collide = false }
			)
			-- the chevron points the way the road bends (clockwise seen from above)
			for _, s in { -1, 1 } do
				add(G, "Chevron", v(1.6, 0.4, 0.5), v(x, 4.6 + s * 0.45, z), WHITE, {
					rot = v(0, yaw, s * 40),
					collide = false,
				})
			end
		end
	elseif id == "cones" then
		-- skins over TrackTiles' cone colliders (3 x 4 x 3 at these u / v spots): striped cones
		for _, sp in { { -0.13, -0.3 }, { 0.13, -0.1 }, { -0.13, 0.1 }, { 0.13, 0.3 } } do
			local x, z = sp[1] * C, -sp[2] * C
			add(G, "SkinConeBase", v(3.2, 0.4, 3.2), v(x, 0.2, z), DARK, noHit)
			for i, c in { { 2.8, ORANGE }, { 2.1, WHITE }, { 1.4, ORANGE } } do
				add(
					G,
					"SkinCone",
					v(1.2, c[1] :: number, c[1] :: number),
					v(x, 0.4 + (i - 0.5) * 1.2, z),
					c[2] :: { number },
					{
						shape = "Cylinder",
						rot = v(0, 0, 90),
						collide = false,
					}
				)
			end
		end
		sign(ORANGE)
	elseif id == "barrels" then
		-- skins over the two 12 x 5 x 6 barrel blocks: two red drums each, white bands
		for _, sp in { { -0.15, -0.2 }, { 0.15, 0.2 } } do
			local x, z = sp[1] * C, -sp[2] * C
			for _, dx in { -3, 3 } do
				add(G, "SkinDrum", v(5, 6, 6), v(x + dx, 2.5, z), RED, {
					shape = "Cylinder",
					rot = v(0, 0, 90),
					collide = false,
				})
				add(G, "SkinDrumBand", v(0.6, 6.15, 6.15), v(x + dx, 3.4, z), WHITE, {
					shape = "Cylinder",
					rot = v(0, 0, 90),
					collide = false,
				})
			end
		end
		sign(RED)
	elseif id == "bumps" then
		-- skins over the three speed bumps: yellow with black stripes
		local w = TileLooks.ROAD - 2
		for _, vv in { -0.25, 0, 0.25 } do
			local z = -vv * C
			add(G, "SkinBump", v(w, 0.8, 3), v(0, 0.4, z), YELLOW, noHit)
			for i = -1, 1 do
				add(G, "SkinBumpStripe", v(3, 0.06, 3.02), v(i * 8, 0.83, z), DARK, noHit)
			end
		end
		sign(DARK)
	elseif id == "narrow" then
		-- skins over the squeeze blocks: grey barriers with red / white tops
		local len = C * 0.4
		for _, s in { -1, 1 } do
			local x = s * (TileLooks.ROAD / 2 - 3.5)
			add(G, "SkinBarrier", v(7, 2.6, len), v(x, 1.3, 0), { 170, 170, 176 }, noHit)
			local n = 5
			for i = 1, n do
				local z = (i - (n + 1) / 2) * len / n
				add(
					G,
					"SkinBarrierTop",
					v(7.05, 0.45, len / n),
					v(x, 2.8, z),
					if i % 2 == 0 then WHITE else RED,
					noHit
				)
			end
		end
		sign(RED)
	elseif id == "split" then
		-- the island: a curb round it, a bush at each end, a sign with an arrow each way
		local len = C * 0.55
		for _, s in { -1, 1 } do
			add(G, "SkinIslandCurb", v(0.6, 2.1, len), v(s * 4.05, 1.05, 0), WHITE, noHit)
			add(
				G,
				"SkinIslandCurb",
				v(8.7, 2.1, 0.6),
				v(0, 1.05, s * (len / 2 + 0.05)),
				WHITE,
				noHit
			)
		end
		bush(0, len / 2 - 4)
		add(G, "SplitPost", v(0.5, 4, 0.5), v(0, 4, -len / 2 + 4), DARK, noHit)
		add(G, "SplitSign", v(3, 3, 0.3), v(0, 6.6, -len / 2 + 4), BLUE, {
			shape = "Cylinder",
			rot = v(0, 90, 0),
			collide = false,
		})
		for _, s in { -1, 1 } do
			add(G, "SplitArrow", v(1.4, 0.4, 0.45), v(s * 0.6, 6.6, -len / 2 + 4), WHITE, {
				rot = v(0, 0, s * 35),
				collide = false,
			})
		end
	elseif id == "jump" then
		-- yellow / black posts and flags either side of the ramp, chevrons on the run-up
		for _, s in { -1, 1 } do
			for _, z in { -C * 0.3, C * 0.3 } do
				add(G, "JumpPost", v(0.6, 7, 0.6), v(s * (edge + 2), 3.5, z), DARK, noHit)
				add(
					G,
					"JumpFlag",
					v(0.15, 2, 3),
					v(s * (edge + 2), 6, z + 1.6),
					if s > 0 then YELLOW else ORANGE,
					noHit
				)
			end
		end
		for _, z in { -C * 0.45, C * 0.45 } do
			for _, s in { -1, 1 } do
				add(G, "JumpArrow", v(6, TileLooks.PAINT, 1), v(s * 2.2, paintY, z), YELLOW, {
					rot = v(0, s * (if z > 0 then 30 else -30), 0),
					collide = false,
				})
			end
		end
	elseif id == "mud" or id == "sand" or id == "puddle" then
		-- splats on the grass beside the patch, ripples on a puddle, and a picture sign
		local col = if id == "mud" then MUD elseif id == "sand" then SAND else WATER
		for _, sp in { { -1, -8 }, { 1, 6 }, { -1, 10 } } do
			local x = sp[1] * (edge + 3)
			add(G, "Splat", v(0.3, 5, 3.5), v(x, 0.15, sp[2] :: number), col, {
				shape = "Cylinder",
				rot = v(0, 30, 90),
				collide = false,
			})
		end
		if id == "puddle" then
			for _, r in { { -3, -4, 6 }, { 4, 5, 4 } } do
				add(G, "Ripple", v(0.06, r[3], r[3]), v(r[1], 0.17, r[2]), { 150, 200, 240 }, {
					shape = "Cylinder",
					rot = v(0, 0, 90),
					material = "Glass",
					collide = false,
				})
			end
		elseif id == "sand" then
			add(G, "Cactus", v(1.2, 5, 1.2), v(edge + 5, 2.5, -4), { 70, 150, 80 }, noHit)
			add(G, "CactusArm", v(2, 0.9, 0.9), v(edge + 5.8, 3.2, -4), { 70, 150, 80 }, noHit)
		end
		sign(col)
	end
	return out
end

-- Server / Studio: build tile `id`'s looks in a "TileLooks" folder under `parent`, at `at` (the
-- tile's centre on the ground, already turned for its rot). Nothing collides, touches or queries.
function TileLooks.make(id: string, parent: Instance, at: CFrame, cell: number?): Instance
	local folder = Instance.new("Folder")
	folder.Name = "TileLooks"
	local holder = Instance.new("Model")
	Garage.makeParts(TileLooks.parts(id, cell), holder, at)
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CastShadow = false
			d.Parent = folder
		end
	end
	holder:Destroy()
	folder.Parent = parent
	return folder
end

return TileLooks
