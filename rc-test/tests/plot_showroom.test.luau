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
		-- (a standing cylinder: its length is up; a turned piece: its whole diagonal, either way)
		local sx, sy, sz = p.size.x, p.size.y, p.size.z
		if p.rot.z % 180 == 90 then
			sx, sy = sy, sx
		end
		if p.rot.y % 180 == 90 then
			sx, sz = sz, sx
		end
		local turned = p.rot.y % 90 ~= 0
		local diag = math.sqrt(sx ^ 2 + sz ^ 2) / 2
		local hx = if turned then diag else sx / 2
		local hz = if turned then diag else sz / 2
		truthy(p.pos.x - hx >= -40 and p.pos.x + hx <= 40, `{p.name} inside x`)
		truthy(p.pos.z - hz >= -55 and p.pos.z + hz <= 37, `{p.name} inside z`)
		truthy(p.pos.y + sy / 2 <= 17, `{p.name} low`)
	end
	for i, s in R.SPOTS do
		local r = R.STAND.w / 2
		truthy(
			s.x - r >= F.x0 and s.x + r <= F.x1 and s.z - r >= F.z0 and s.z + r <= F.z1,
			`stand {i} on the floor`
		)
	end
end)

test("look bible: SmoothPlastic, Neon only for the glow ring and the sign, round discs", function()
	local round = 0
	for _, p in R.pieces(#R.SPOTS) do
		eq(
			p.material,
			if p.name == "TableGlow" or p.name == "SignGlow" then "Neon" else "SmoothPlastic",
			p.name
		)
		if string.find(p.name, "Stand") or string.find(p.name, "Table") then
			eq(p.shape, "Cylinder", p.name)
			round += 1
		end
	end
	truthy(round > 0)
end)

test("the hero: a pink carpet from the gate end to the turntable", function()
	local T = R.TURNTABLE
	local n = 0
	for _, p in R.pieces(0) do
		if p.name == "Carpet" then
			n += 1
			eq(p.pos.x, T.x)
			truthy(
				math.abs((p.pos.z - p.size.z / 2) - (T.z + (T.w + T.step) / 2)) < 0.01,
				"starts at the table's step"
			)
			truthy(math.abs((p.pos.z + p.size.z / 2) - R.FLOOR.z1) < 0.01, "ends at the gate end")
		end
	end
	eq(n, 1)
end)

test("the floor is warm two-tone sand, not snow-white", function()
	local found = false
	for _, p in R.pieces(0) do
		if p.name == "Floor" then
			found = true
			local c = p.color
			truthy(c[1] + c[2] + c[3] < 640 and c[3] < 200, "not near-white")
			truthy(c[1] - c[3] >= 50, "warm (more red than blue)")
		end
	end
	truthy(found, "there is a floor")
	-- two tones: darker bands over it
	local bands = 0
	for _, p in R.pieces(0) do
		if p.name == "FloorBand" then
			bands += 1
		end
	end
	truthy(bands >= 2, "a second tone")
end)

test("the hero: a raised turntable, a big kart, a spotlight ring clear of the carpet", function()
	local T, L = R.TURNTABLE, R.LAMPS
	truthy(T.top >= 2, "raised")
	truthy(T.car >= 3, "big kart")
	local lamps = 0
	for _, p in R.pieces(0) do
		if p.name == "LampPost" then
			lamps += 1
			truthy(
				math.abs(p.pos.x - T.x) > R.CARPET / 2 + 1,
				"a lamp beside the carpet, not on it"
			)
			truthy(dist(p.pos, T) > (T.w + T.step) / 2, "outside the step")
		end
	end
	eq(lamps, L.n)
	for i, s in R.SPOTS do
		truthy(dist(s, T) >= L.r + R.STAND.w / 2 + 2, `stand {i} clear of the lamps`)
	end
end)

test("a real showroom: banner with words, trophies, little crates, floor edge bands", function()
	local names: { [string]: number } = {}
	for _, p in R.pieces(0) do
		names[p.name] = (names[p.name] or 0) + 1
	end
	eq(names.BannerBoard, 1)
	truthy(#R.BANNER_TEXT > 0)
	eq(names.TrophyCup, #R.TROPHIES)
	eq(names.MiniCrateBody, #R.MINI_CRATES)
	eq(names.FloorEdge, 4)
	eq(names.TableBay, 1) -- painted bays round the turntable and every stand
	-- every bay painted as a parking box with a number tile, even with no stands
	local lines, numbers = 0, 0
	for _, p in R.pieces(0) do
		if p.name == "BayLine" then
			lines += 1
		elseif string.sub(p.name, 1, 9) == "BayNumber" then
			numbers += 1
			-- turned a quarter from its bay, so the number reads upright from the aisle
			local i = tonumber(string.sub(p.name, 10)) :: number
			eq(p.rot.y, R.SPOTS[i].yaw + 90)
		end
	end
	eq(lines, 4 * #R.SPOTS)
	eq(numbers, #R.SPOTS)
	-- the boxes of side-by-side bays don't run into each other
	local B = R.BAY
	truthy(math.sqrt(B.w ^ 2 + B.l ^ 2) <= 12.2, "neighbour bays clear")
	truthy(B.w > R.STAND.w and B.l > R.STAND.w, "a box round the stand")
	eq(names.BackWall, 1)
	eq(names.RollerDoor, 2) -- the back wall has panels, not a flat black face
	-- the little crates sit beside the carpet, clear of the lamps and the stands
	local T, L = R.TURNTABLE, R.LAMPS
	for i, m in R.MINI_CRATES do
		truthy(math.abs(m.x) > R.CARPET / 2 + 3, `mini crate {i} off the carpet`)
		truthy(dist(m, T) > L.r + 3, `mini crate {i} clear of the lamps`)
		for j, st in R.SPOTS do
			truthy(dist(m, st) > R.STAND.w / 2 + 3, `mini crate {i} clear of stand {j}`)
		end
	end
	-- the trophies stand clear of the crate's walk-up and the back stands
	for i, t in R.TROPHIES do
		truthy(dist(t, R.CRATE) > R.CRATE.w / 2 + 1, `trophy {i} off the crate pedestal`)
		for j, st in R.SPOTS do
			truthy(dist(t, st) > R.STAND.w / 2 + 2, `trophy {i} clear of stand {j}`)
		end
	end
end)

test("garage dressing fills the floor and keeps clear of the stands, lamps and carpet", function()
	local names: { [string]: number } = {}
	for _, p in R.pieces(0) do
		names[p.name] = (names[p.name] or 0) + 1
	end
	truthy((names.ToolWall or 0) == 2, "a tool wall each side")
	truthy((names.LiftPost or 0) == 2, "a kart lift")
	truthy((names.BenchCabinet or 0) == 1, "a workbench")
	local T, L = R.TURNTABLE, R.LAMPS
	local keep = function(at: any, r: number, what: string)
		for j, st in R.SPOTS do
			truthy(dist(at, st) >= R.STAND.w / 2 + 0.8 + r, `{what} clear of stand {j}`)
		end
		truthy(dist(at, T) >= L.r + 1 + r, `{what} clear of the lamps`)
		truthy(math.abs(at.x) - r > R.CARPET / 2 + 1, `{what} off the carpet`)
	end
	keep(R.LIFT, 4.6, "lift")
	keep(R.BENCH, 4.3, "bench")
	keep(R.CART, 2.2, "toolbox cart")
	for i, p in R.PROPS do
		keep(p, p.h * 0.6, `prop {i}`)
		truthy(math.abs(p.x) + p.h * 0.6 <= 34 and p.z - p.h * 0.6 >= -55, `prop {i} in the plot`)
	end
	local TW = R.TOOL_WALL
	truthy(
		TW.x - 0.6 > R.FLOOR.x1 + R.FLOOR.border and TW.x + 0.6 < 39.5,
		"tool walls on the margin"
	)
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
	local tp = R.turntablePrompt()
	truthy(
		dist(tp, R.cratePrompt()) >= R.TABLE_RANGE + R.CRATE_RANGE,
		"turntable and crate prompts apart"
	)
	for i, s in R.SPOTS do
		truthy(dist(tp, s) >= R.TABLE_RANGE + R.PICK_RANGE, `turntable prompt clear of stand {i}`)
	end
end)

test("from the gate you see the crate past the turntable (in line, the gate end clear)", function()
	eq(R.CRATE.x, 0)
	eq(R.TURNTABLE.x, 0)
	-- nothing stands in the middle lane between the gate and the turntable
	for i, s in R.SPOTS do
		truthy(math.abs(s.x) >= 13 or s.z < R.TURNTABLE.z, `stand {i} off the gate lane`)
	end
end)
