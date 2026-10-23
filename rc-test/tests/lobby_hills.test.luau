--!strict
-- Lobby hills (LobbyHills.luau): hills that close the lobby in on its three dry sides.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local Hills = require("../src/shared/LobbyHills")

local test, truthy = H.test, H.truthy

print("Lobby hills")

local hills, trees = Hills.layout()
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

test("hills on the left, right and dry end; none across the lake", function()
	local left, right, dry, lakeEnd = 0, 0, 0, 0
	for _, h in hills do
		if h.x < g.minX then
			left += 1
		elseif h.x > g.maxX then
			right += 1
		elseif (lake > 0 and h.z < g.minZ) or (lake < 0 and h.z > g.maxZ) then
			dry += 1
		else
			lakeEnd += 1
		end
	end
	truthy(left > 5 and right > 5 and dry > 3, `left {left} right {right} dry {dry}`)
	H.eq(lakeEnd, 0, "hills across the lake")
end)

test("near rows are low, far rows tall; every tree stands on a hill", function()
	for _, h in hills do
		local spec = Hills.ROWS[h.row]
		truthy(h.h >= spec.h[1] and h.h <= spec.h[2], "height in its row's range")
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
