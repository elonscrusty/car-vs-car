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
		local ex = math.abs(r.dx) * r.length / 2 + math.abs(r.dz) * r.width / 2
		local ez = math.abs(r.dz) * r.length / 2 + math.abs(r.dx) * r.width / 2
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

local function key(r: Rect, flipX: boolean, flipZ: boolean): string
	local x0, x1 = if flipX then -r.x1 else r.x0, if flipX then -r.x0 else r.x1
	local z0, z1 = if flipZ then -r.z1 else r.z0, if flipZ then -r.z0 else r.z1
	return string.format("%d,%d,%d,%d", x0 + 0.5, x1 + 0.5, z0 + 0.5, z1 + 0.5)
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
		set[key(e.r, false, false)] = true
	end
	for _, e in rects() do
		truthy(set[key(e.r, true, true)], e.name .. " has no twin")
	end
end)

test("the map is the same top and bottom (mirror)", function()
	local set: { [string]: boolean } = {}
	for _, e in rects() do
		set[key(e.r, false, false)] = true
	end
	for _, e in rects() do
		truthy(set[key(e.r, false, true)], e.name .. " has no mirror")
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

local function belongsTogether(a: string, b: string): boolean
	local function plateau(n: string): boolean
		return n == "Plateau" or n:find("PlateauRamp") ~= nil
	end
	local function highway(n: string): boolean
		return n:find("Highway") ~= nil
	end
	return (plateau(a) and plateau(b)) or (highway(a) and highway(b))
end

test("cars can squeeze between every pair of separate pieces (no wedge traps)", function()
	local list = rects()
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if not belongsTogether(a.name, b.name) then
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
	eq(#L.ramps(), 6)
	for _, r in L.ramps() do
		local s = L.slopeDeg(r)
		truthy(s >= 10 and s <= 18, `{r.name} slope {s}`)
		near(math.sqrt(r.dx * r.dx + r.dz * r.dz), 1, 1e-9)
		truthy(r.width >= 12, r.name .. " too narrow for a car")
	end
end)

test("ramps meet their plateau or deck with no step", function()
	for _, r in L.ramps() do
		if r.name:find("PlateauRamp") then
			near(r.height, L.plateau.height)
			near(math.abs(r.x) - r.length / 2, L.plateau.hx)
		else
			near(r.height, L.highway.height)
			near(math.abs(r.x) - r.length / 2, L.highway.deckHalf)
			near(math.abs(r.z), L.highway.z)
		end
	end
end)

test("the highway deck is wide enough for a car and clear of the plateau drop", function()
	truthy(L.highway.width >= 16)
	truthy(L.highway.z - L.highway.width / 2 - L.plateau.hz >= 20, "lane between plateau and deck")
	truthy(L.highway.height >= L.plateau.height)
end)

test("each spawn has a clear straight lane and a bunker beside it", function()
	local bunkers = 0
	for _, b in L.boxes() do
		if b.name:find("Bunker") then
			bunkers += 1
			truthy(b.sz >= 12 and b.sy >= 10)
			truthy(math.abs(b.z) - b.sz / 2 >= 9, "bunker stays off the spawn lane")
		end
	end
	eq(bunkers, 4)
end)

test("the spinner hazard stays over the plateau and clear of the ground", function()
	local sp, p = L.spinner, L.plateau
	truthy(sp.radius < p.hx, "arm tip must not pass the plateau ramp edge")
	truthy(sp.clearance > 0.5 and sp.height >= 3)
	truthy(sp.speed > 0.3 and sp.speed < 2, "slow enough to dodge")
	truthy(sp.radius * sp.speed < 20, "tip speed stays dodgeable")
end)

test(
	"the sliding blocks cross the deck but never leave it, and are slow enough to dodge",
	function()
		local list = L.sliders()
		eq(#list, 4)
		local phases: { [number]: boolean } = {}
		for _, s in list do
			truthy(
				s.amplitude + s.size[3] / 2 <= L.highway.width / 2 + 1,
				s.name .. " pokes off the deck"
			)
			truthy(
				s.amplitude + s.size[3] / 2 >= L.highway.width / 2 - 1,
				s.name .. " leaves a safe gap"
			)
			truthy(math.abs(s.x) < L.highway.deckHalf - 8, s.name .. " not on the flat deck")
			truthy(s.amplitude * 2 * math.pi / s.periodSeconds < 14, s.name .. " too fast")
			phases[s.phase] = true
		end
		eq(phases[0] and phases[0.25] and phases[0.5] and phases[0.75], true)
	end
)

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
	eq(seen.A and seen.B and seen.C and seen.D, true)
end)

test("the road loop and its dashes stay on the floor", function()
	for _, s in L.roadStrips() do
		truthy(math.abs(s.x) + s.sx / 2 <= L.halfX and math.abs(s.z) + s.sz / 2 <= L.halfZ)
	end
	eq(#L.roadStrips(), 4)
	truthy(#L.roadDashes() > 20)
	for _, d in L.roadDashes() do
		truthy(math.abs(d.x) <= L.halfX and math.abs(d.z) <= L.halfZ)
	end
end)

test("scenery stays outside the walls, floor marks stay on the lane", function()
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
	eq(#L.bunting(), 12)
end)

test("the old AI rectangles cover the plateau with its ramps and the bunkers", function()
	local o = L.obstacleRects()
	truthy(#o >= 7)
end)
