--!strict
-- Lobby scenery (LobbyScenery.luau): trees, bushes, rocks and fences round the lobby.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local S = require("../src/shared/LobbyScenery")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby scenery")

local pieces = S.pieces()

local function within(
	b: { minX: number, maxX: number, minZ: number, maxZ: number },
	x: number,
	z: number
)
	return x >= b.minX and x <= b.maxX and z >= b.minZ and z <= b.maxZ
end

test("light enough for phones, and every kind is there", function()
	truthy(#pieces > 200 and #pieces <= S.MAX_PIECES, `pieces: {#pieces}`)
	local kinds: { [string]: number } = {}
	for _, p in pieces do
		kinds[p.kind] = (kinds[p.kind] or 0) + 1
	end
	for _, k in { "Tree", "Pine", "Bush", "Hedge", "Rock", "Cliff", "Fence" } do
		truthy((kinds[k] or 0) > 0, "missing " .. k)
	end
end)

test("same pieces every run", function()
	local again = S.pieces()
	eq(#again, #pieces)
	for i = 1, #pieces, 37 do
		eq(again[i].x, pieces[i].x)
		eq(again[i].rz, pieces[i].rz)
	end
end)

test("nothing stands on a plot, the road, the footpaths or the plaza", function()
	for _, p in pieces do
		for _, b in S.keepOut() do
			-- a little slack: tilted canopy blocks may lean over a padded edge
			local shrunk =
				{ minX = b.minX + 1, maxX = b.maxX - 1, minZ = b.minZ + 1, maxZ = b.maxZ - 1 }
			truthy(not within(shrunk, p.x, p.z), `{p.kind} at {p.x}, {p.z}`)
		end
	end
end)

test("everything stays inside the bank, off its outer 4 studs (docks)", function()
	local o = S.outer()
	for _, p in pieces do
		truthy(within(o, p.x, p.z), `{p.kind} out at {p.x}, {p.z}`)
	end
	eq(S.BAND, 20)
end)

test("the fence openings stay clear so you can walk out to a dock", function()
	local g = L.ground()
	local op = S.openings()
	for _, p in pieces do
		if p.solid then
			local onSide = math.abs(p.z - op.side) < S.OPENING - 1
				and (p.x < g.minX + 3 or p.x > g.maxX - 3)
			local onEnd = math.abs(p.x - op.back) < S.OPENING - 1
				and (p.z < g.minZ + 3 or p.z > g.maxZ - 3)
			truthy(not onSide and not onEnd, `{p.kind} blocks an opening at {p.x}, {p.z}`)
		end
	end
end)

test("gap fences leave the gap's mouth open by the footpath", function()
	for _, p in pieces do
		if p.kind == "Fence" and math.abs(p.x) < L.EDGE + 5 then
			truthy(
				p.z < L.ground().minZ + 3 or p.z > L.ground().maxZ - 3,
				`fence at gap mouth {p.x}, {p.z}`
			)
		end
	end
end)
