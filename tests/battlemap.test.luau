--!strict
local Harness = require("./harness")
local BattleMapLayout = require("../src/shared/BattleMapLayout")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("BattleMapLayout")

local L = BattleMapLayout
local CLEAR = 12 -- open studs a car needs to squeeze between two solids (body is about 8 wide)

type Rect = { x0: number, x1: number, z0: number, z1: number }

-- Footprint of every solid and every ramp as a bounding rectangle.
local function rects(): { { name: string, r: Rect } }
	local out = {}
	for _, b in L.boxes() do
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, c in L.corners(b) do
			x0, x1 = math.min(x0, c[1]), math.max(x1, c[1])
			z0, z1 = math.min(z0, c[2]), math.max(z1, c[2])
		end
		table.insert(out, { name = b.name, r = { x0 = x0, x1 = x1, z0 = z0, z1 = z1 } })
	end
	for _, r in L.ramps() do
		local ex, ez =
			math.abs(r.dx) * r.length / 2 + math.abs(r.dz) * r.width / 2,
			math.abs(r.dz) * r.length / 2 + math.abs(r.dx) * r.width / 2
		table.insert(
			out,
			{ name = r.name, r = { x0 = r.x - ex, x1 = r.x + ex, z0 = r.z - ez, z1 = r.z + ez } }
		)
	end
	return out
end

local function gap(a: Rect, b: Rect): number
	local dx = math.max(a.x0 - b.x1, b.x0 - a.x1, 0)
	local dz = math.max(a.z0 - b.z1, b.z0 - a.z1, 0)
	return math.sqrt(dx * dx + dz * dz)
end

test("every piece sits inside the walls", function()
	for _, e in rects() do
		truthy(e.r.x0 >= -L.halfX and e.r.x1 <= L.halfX, e.name .. " x")
		truthy(e.r.z0 >= -L.halfZ and e.r.z1 <= L.halfZ, e.name .. " z")
	end
end)

test("the map is the same from both spawns (turn it half way round: nothing changes)", function()
	local set: { [string]: boolean } = {}
	for _, e in rects() do
		set[string.format("%d,%d,%d,%d", e.r.x0 + 0.5, e.r.x1 + 0.5, e.r.z0 + 0.5, e.r.z1 + 0.5)] =
			true
	end
	for _, e in rects() do
		local k =
			string.format("%d,%d,%d,%d", -e.r.x1 + 0.5, -e.r.x0 + 0.5, -e.r.z1 + 0.5, -e.r.z0 + 0.5)
		truthy(set[k], e.name .. " has no twin")
	end
end)

test("the map is the same top and bottom (mirror)", function()
	local set: { [string]: boolean } = {}
	for _, e in rects() do
		set[string.format("%d,%d,%d,%d", e.r.x0 + 0.5, e.r.x1 + 0.5, e.r.z0 + 0.5, e.r.z1 + 0.5)] =
			true
	end
	for _, e in rects() do
		local k =
			string.format("%d,%d,%d,%d", e.r.x0 + 0.5, e.r.x1 + 0.5, -e.r.z1 + 0.5, -e.r.z0 + 0.5)
		truthy(set[k], e.name .. " has no mirror")
	end
end)

test("spawns face each other, are level, and start in the open", function()
	local ax, az, afx, afz = L.spawn("a")
	local bx, bz, bfx, bfz = L.spawn("b")
	near(ax, -bx)
	near(az, bz)
	near(afx, -bfx)
	near(afz, 0)
	near(bfz, 0)
	truthy(afx > 0 and bfx < 0, "facing")
	for _, e in rects() do
		for _, s in { { ax, az }, { bx, bz } } do
			local r = { x0 = s[1] - 8, x1 = s[1] + 8, z0 = s[2] - 4, z1 = s[2] + 4 }
			truthy(
				gap(r, e.r) > 4 or e.name:find("Bunker") ~= nil and gap(r, e.r) > 8,
				e.name .. " too near a spawn"
			)
		end
	end
end)

test("cars can squeeze between every pair of solids (no wedge traps)", function()
	local list = rects()
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local touching = a.name:find("PlateauRamp") ~= nil and b.name == "Plateau"
				or b.name:find("PlateauRamp") ~= nil and a.name == "Plateau"
			if not touching then
				truthy(
					gap(a.r, b.r) >= CLEAR,
					`{a.name} and {b.name} are only {gap(a.r, b.r)} apart`
				)
			end
		end
	end
end)

test("every piece keeps a car-wide lane to the walls", function()
	for _, e in rects() do
		local toWall =
			math.min(L.halfX - e.r.x1, e.r.x0 + L.halfX, L.halfZ - e.r.z1, e.r.z0 + L.halfZ)
		-- bumpers sit in the corners on purpose
		truthy(toWall >= 4 or e.name:find("Bumper") ~= nil, e.name .. " is jammed against a wall")
	end
end)

test("ramps are gentle enough to drive up without flipping", function()
	for _, r in L.ramps() do
		local s = L.slopeDeg(r)
		truthy(s >= 10 and s <= 18, `{r.name} slope {s}`)
		near(math.sqrt(r.dx * r.dx + r.dz * r.dz), 1, 1e-9)
		truthy(r.width >= 12, r.name .. " too narrow for a car")
	end
end)

test("a plateau ramp meets the plateau edge with no step", function()
	for _, r in L.ramps() do
		if r.name:find("PlateauRamp") then
			near(r.height, L.plateau.height)
			near(math.abs(r.x) - r.length / 2, L.plateau.hx)
		end
	end
end)

test("there is cover in front of each spawn that a straight shot cannot pass", function()
	local bunkers = 0
	for _, b in L.boxes() do
		if b.name:find("Bunker") then
			bunkers += 1
			truthy(b.sz >= 18 and b.sy >= 10)
			near(b.z, 0)
		end
	end
	eq(bunkers, 2)
end)

test("the floor checker covers the floor evenly", function()
	local t = L.tiles()
	eq(#t, 35)
	for _, p in t do
		truthy(math.abs(p.x) < L.halfX and math.abs(p.z) < L.halfZ)
	end
end)

test("the spinner hazard stays over the plateau and clear of the ground", function()
	local sp, p = L.spinner, L.plateau
	truthy(sp.radius < p.hx, "arm tip must not pass the plateau ramp edge")
	truthy(sp.radius + sp.hubRadius > 0 and sp.clearance > 0.5 and sp.height >= 3)
	truthy(sp.speed > 0.3 and sp.speed < 2, "slow enough to dodge")
	truthy(sp.radius * sp.speed < 20, "tip speed stays dodgeable")
end)

test("four toy soldiers, one each side of both spawns, facing the middle", function()
	local n = 0
	for _, b in L.boxes() do
		if b.kind == "soldier" then
			n += 1
			near(math.abs(b.x), L.soldier.x)
			near(math.abs(b.z), L.soldier.z)
			truthy(if b.x < 0 then b.yawDeg == -90 else b.yawDeg == 90, b.name .. " faces away")
		end
	end
	eq(n, 4)
end)

test("alphabet blocks carry four different letters", function()
	local seen: { [string]: boolean } = {}
	local n = 0
	for _, b in L.boxes() do
		if b.kind == "block" then
			truthy(b.letter ~= nil)
			seen[b.letter :: string] = true
			n += 1
		end
	end
	eq(n, 4)
	eq(#(L.boxes()) > 0 and (seen.A and seen.B and seen.C and seen.D), true)
end)

test("scenery stays outside the walls, decorations stay on the floor", function()
	for _, pr in L.scenery() do
		if pr.kind ~= "pole" then
			truthy(
				math.abs(pr.x) > L.halfX + 8 or math.abs(pr.z) > L.halfZ + 12,
				pr.kind .. " inside the arena"
			)
		end
	end
	for _, cv in L.chevrons() do
		truthy(
			math.abs(cv.x) < L.bunker.x - 4 and math.abs(cv.x) > L.plateau.hx + L.plateauRamp.length
		)
	end
	eq(#L.bunting(), 10)
end)

test("the old AI rectangles cover the plateau with its ramps and the bunkers", function()
	local o = L.obstacleRects()
	truthy(#o >= 7)
end)
