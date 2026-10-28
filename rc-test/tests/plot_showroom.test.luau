--!strict
-- Car VS Car SMASH garage (PlotShowroom.luau): one stand per kart and never an empty one, the
-- kart you play with on the turntable, rarest karts first, everything inside the plot, the
-- low-poly look (SmoothPlastic, no Neon), and walk-up prompts that never overlap.
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local R = require("../src/shared/PlotShowroom")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot showroom (Smash garage)")

local function groups(pieces: { any }): { [string]: number }
	local out = {}
	for _, p in pieces do
		out[p.group] = (out[p.group] or 0) + 1
	end
	return out
end

local function standsIn(pieces: { any }): number
	local n = 0
	for g in groups(pieces) do
		if string.sub(g, 1, 5) == "Stand" then
			n += 1
		end
	end
	return n
end

local function dist(a: any, b: any): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- a car id of each rarity
local byRarity: { [string]: string } = {}
for id in CarCatalog.LOOKS do
	local r = CarCatalog.rarity(id).id
	if CarCatalog.get(id) and (byRarity[r] == nil or id < byRarity[r]) then
		byRarity[r] = id
	end
end

test("one stand per kart, never an empty one", function()
	eq(R.standCount(0, false), 0)
	eq(R.standCount(1, true), 0, "your only kart is on the turntable")
	eq(R.standCount(3, true), 2)
	eq(R.standCount(3, false), 3)
	eq(R.standCount(99, true), #R.SPOTS, "no more stands than spots")
	for n = 0, #R.SPOTS do
		eq(standsIn(R.pieces(n)), n, `{n} stands drawn`)
	end
end)

test("the kart you play with goes on the turntable; the rest rarest first", function()
	local common, legend = byRarity.common, byRarity.legend
	truthy(common ~= nil and legend ~= nil, "catalog has a common and a legend")
	local mine = {
		{ id = common, uid = "a" },
		{ id = legend, uid = "b" },
		{ id = common, uid = "c" },
	}
	local top, rest = R.order(mine, "c")
	eq(top and top.uid, "c", "your pick (by uid) on the turntable")
	eq(#rest, 2)
	eq(rest[1].id, legend, "the legend first")
	-- someone else's plot: ids only, the racer by car id, only one of two the same goes up
	local theirs = { { id = common }, { id = common }, { id = legend } }
	local top2, rest2 = R.order(theirs, common)
	eq(top2 and top2.id, common)
	eq(#rest2, 2)
	-- no racer yet: everyone on stands
	local top3, rest3 = R.order(theirs, nil)
	eq(top3, nil)
	eq(#rest3, 3)
	-- a big garage fills the stands and stops
	local many = {}
	for i = 1, 30 do
		table.insert(many, { id = common, uid = tostring(i) })
	end
	local _, rest4 = R.order(many, "1")
	eq(#rest4, #R.SPOTS)
end)

test("the showroom fits in the plot, inside its floor", function()
	local F = R.FLOOR
	for _, p in R.pieces(#R.SPOTS) do
		-- (a turned piece: its whole diagonal, either way)
		local turned = p.rot.y % 180 ~= 0
		local diag = math.sqrt(p.size.x ^ 2 + p.size.z ^ 2) / 2
		local hx = if turned then diag else p.size.x / 2
		local hz = if turned then diag else p.size.z / 2
		truthy(p.pos.x - hx >= -40 and p.pos.x + hx <= 40, `{p.name} inside x`)
		truthy(p.pos.z - hz >= -55 and p.pos.z + hz <= 37, `{p.name} inside z`)
		truthy(p.pos.y + p.size.y / 2 <= 12, `{p.name} low`)
	end
	for i, s in R.SPOTS do
		local r = R.STAND.w / 2
		truthy(
			s.x - r >= F.x0 and s.x + r <= F.x1 and s.z - r >= F.z0 and s.z + r <= F.z1,
			`stand {i} on the floor`
		)
	end
end)

test("low-poly look: SmoothPlastic only, nothing glows", function()
	for _, p in R.pieces(#R.SPOTS) do
		eq(p.material, "SmoothPlastic", p.name)
		eq(p.shape, "Block", p.name)
	end
end)

test("stands, turntable and crate keep apart; prompts never overlap", function()
	local T, C = R.TURNTABLE, R.CRATE
	for i, a in R.SPOTS do
		truthy(dist(a, T) >= T.w / 2 + R.STAND.w / 2 + 4, `stand {i} clear of the turntable`)
		truthy(
			dist(a, C) >= R.PICK_RANGE + R.CRATE_RANGE - 1,
			`stand {i} prompt clear of the crate's`
		)
		for j, b in R.SPOTS do
			if i < j then
				truthy(dist(a, b) >= 2 * R.PICK_RANGE, `stands {i} and {j} apart`)
			end
		end
	end
	truthy(dist(T, C) >= T.w / 2 + C.w / 2 + 8, "a walk between the turntable and the crate")
end)

test("from the gate you see the crate past the turntable (in line, the gate end clear)", function()
	eq(R.CRATE.x, 0)
	eq(R.TURNTABLE.x, 0)
	-- nothing stands in the middle lane between the gate and the turntable
	for i, s in R.SPOTS do
		truthy(math.abs(s.x) >= 13 or s.z < R.TURNTABLE.z, `stand {i} off the gate lane`)
	end
end)
