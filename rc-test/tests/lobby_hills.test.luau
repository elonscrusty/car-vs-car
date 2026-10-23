--!strict
-- Lobby hills (LobbyHills.luau): hills that close the lobby in on its three dry sides.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local Hills = require("../src/shared/LobbyHills")

local test, truthy = H.test, H.truthy

print("Lobby hills")

local hills, trees, props, marks = Hills.layout()
local g = L.ground()
local lake = L.LAKE_SIDE or 1

test("light enough for phones", function()
	truthy(#hills > 20 and #hills <= Hills.MAX_HILLS, `hills: {#hills}`)
	truthy(#trees > 30 and #trees <= Hills.MAX_TREES, `trees: {#trees}`)
end)

test("no hill or tree reaches onto the lobby grass", function()
	for _, h in hills do
		local reach = math.max(h.w, h.d) / 2
		local inX = h.x + reach > g.minX and h.x - reach < g.maxX
		local inZ = h.z + reach > g.minZ and h.z - reach < g.maxZ
		-- a hill may sit beside the grass on one axis, never over it on both
		truthy(
			not (inX and inZ and h.x > g.minX and h.x < g.maxX and h.z > g.minZ and h.z < g.maxZ),
			"hill on the grass"
		)
		truthy(
			not (h.x > g.minX and h.x < g.maxX and h.z > g.minZ and h.z < g.maxZ),
			"hill middle on the grass"
		)
	end
	for _, t in trees do
		truthy(
			not (t.x > g.minX and t.x < g.maxX and t.z > g.minZ and t.z < g.maxZ),
			"tree on the grass"
		)
	end
end)

test("hills wrap the lake, off the sand, near bank open", function()
	local keep = Hills.keepBox()
	local lk = Hills.lakeBox()
	truthy(
		keep.maxX - lk.maxX >= Hills.SAND + 6 and lk.minX - keep.minX >= Hills.SAND + 6,
		"6 off the sand"
	)
	for _, h in hills do
		truthy(not Hills.touches(h, keep), `hill on the lake/sand/near bank at {h.x}, {h.z}`)
	end
	for _, t in trees do
		truthy(
			not (t.x > keep.minX and t.x < keep.maxX and t.z > keep.minZ and t.z < keep.maxZ),
			"tree by the lake"
		)
	end
	local far = 0
	for _, h in hills do
		if
			h.x > lk.minX
			and h.x < lk.maxX
			and ((lake > 0 and h.z > keep.maxZ) or (lake < 0 and h.z < keep.minZ))
		then
			far += 1
		end
	end
	truthy(far > 3, `hills on the lake's far side: {far}`)
end)

test("hills on the left, right and dry end; none between street and lake", function()
	local keep = Hills.keepBox()
	local left, right, dry, lakeEnd = 0, 0, 0, 0
	for _, h in hills do
		if h.x < g.minX then
			left += 1
		elseif h.x > g.maxX then
			right += 1
		elseif (lake > 0 and h.z < g.minZ) or (lake < 0 and h.z > g.maxZ) then
			dry += 1
		elseif not ((lake > 0 and h.z > keep.maxZ) or (lake < 0 and h.z < keep.minZ)) then
			lakeEnd += 1
		end
	end
	truthy(left > 5 and right > 5 and dry > 3, `left {left} right {right} dry {dry}`)
	H.eq(lakeEnd, 0, "hills across the lake")
end)

test("near rows are low, far rows tall; every tree stands on a hill", function()
	for _, h in hills do
		local spec = Hills.ROWS[h.row]
		truthy(h.h >= spec.h[1] * 0.6 and h.h <= spec.h[2] * 2, "height near its row's range")
	end
	for _, t in trees do
		local on = false
		for _, h in hills do
			if Hills.surface(h, t.x, t.z) then
				on = true
				break
			end
		end
		truthy(on, `tree off the hills at {t.x}, {t.z}`)
		truthy(t.y > 0, "tree above the ground")
	end
end)

test("grass under every hill, never over the lobby or the lake", function()
	local boxes = Hills.baseBoxes(hills)
	local keep = Hills.keepBox()
	local function over(a, b)
		return a.minX < b.maxX - 0.01
			and a.maxX > b.minX + 0.01
			and a.minZ < b.maxZ - 0.01
			and a.maxZ > b.minZ + 0.01
	end
	for _, b in boxes do
		truthy(not over(b, g), "base over the lobby grass")
		truthy(not over(b, keep), "base over the lake")
	end
	for _, h in hills do
		local lakeEnd = (lake > 0 and h.z > g.maxZ) or (lake < 0 and h.z < g.minZ)
		if not lakeEnd then
			local under = false
			for _, b in boxes do
				if h.x >= b.minX and h.x <= b.maxX and h.z >= b.minZ and h.z <= b.maxZ then
					under = true
				end
			end
			truthy(under, `no grass under the hill at {h.x}, {h.z}`)
		end
	end
end)

test("the ring mixes kinds of hill, tree and foot detail", function()
	local kinds, meshes, props2 = {}, {}, {}
	for _, h in hills do
		kinds[h.kind] = (kinds[h.kind] or 0) + 1
		truthy(h.row == 3 or h.kind ~= "peak", "near rows are never peaks")
	end
	for _, k in { "meadow", "forest", "autumn", "rock", "peak" } do
		truthy((kinds[k] or 0) >= 4, `few {k} hills: {kinds[k] or 0}`)
	end
	for _, t in trees do
		meshes[t.mesh] = true
		truthy(t.mesh ~= "BlockTree" or t.color ~= nil, "block tree has a colour")
	end
	truthy(
		meshes.PineTree
			and meshes.LeafyTree
			and meshes.BlockTree
			and meshes.AutumnTree
			and meshes.BirchTree,
		"five kinds of tree"
	)
	truthy(#props > 40 and #props <= Hills.MAX_PROPS, `props: {#props}`)
	local keep = Hills.keepBox()
	for _, p in props do
		props2[p.mesh] = true
		truthy(
			not (p.x > g.minX and p.x < g.maxX and p.z > g.minZ and p.z < g.maxZ),
			"prop on the lobby grass"
		)
		truthy(
			not (p.x > keep.minX and p.x < keep.maxX and p.z > keep.minZ and p.z < keep.maxZ),
			"prop by the lake"
		)
	end
	truthy(props2.Flowers and props2.Bush and props2.RockPile, "flowers, bushes and rocks")
end)

test("a cabin, a windmill and a watch tower on the hills, with paths, clear of trees", function()
	local seen = {}
	for _, m in marks do
		seen[m.mesh] = true
		truthy(#m.path >= 2, `{m.mesh} has a path`)
		truthy(
			not (m.x > g.minX and m.x < g.maxX and m.z > g.minZ and m.z < g.maxZ),
			"set piece on the lobby grass"
		)
		for _, t in trees do
			truthy(
				(t.x - m.x) ^ 2 + (t.z - m.z) ^ 2 >= Hills.LANDMARK_CLEAR ^ 2,
				`tree in the {m.mesh} yard`
			)
		end
	end
	truthy(seen.Cabin and seen.Windmill and seen.WatchTower, "all three kinds")
end)
