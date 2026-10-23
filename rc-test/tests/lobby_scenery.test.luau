--!strict
-- Lobby scenery (LobbyScenery.luau): trees, bushes, rocks and fences round the lobby.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local S = require("../src/shared/LobbyScenery")
local W = require("../src/shared/LobbyWater")

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

test("everything stays inside the bank, off its outer 4 studs (docks), or on the island", function()
	local o = S.outer()
	local ix, iz, ir = S.island()
	truthy(ix, "island found")
	local function onIsland(x: number, z: number): boolean
		return ix ~= nil and (x - ix) ^ 2 + (z - iz) ^ 2 < ir * ir
	end
	local island = 0
	for _, p in pieces do
		if onIsland(p.x, p.z) then
			island += 1
		else
			truthy(within(o, p.x, p.z), `{p.kind} out at {p.x}, {p.z}`)
		end
	end
	truthy(island > 0, "something on the island")
	eq(S.BAND, 20)
end)

test("one fence opening per dock and footbridge; their lanes stay clear", function()
	eq(#S.openings(), #W.landings())
	for _, p in pieces do
		if p.solid then
			truthy(not S.inLane(p.x, p.z, -1), `{p.kind} blocks a dock lane at {p.x}, {p.z}`)
		end
	end
	-- and there really is no fence across each opening (posts or rails)
	local g = L.ground()
	local lineOf = {
		left = g.minX + S.FENCE_IN,
		right = g.maxX - S.FENCE_IN,
		back = g.minZ + S.FENCE_IN,
		front = g.maxZ - S.FENCE_IN,
	}
	for _, o in S.openings() do
		local line = lineOf[o.side]
		for _, p in pieces do
			if p.kind == "Fence" then
				local hit
				if o.side == "left" or o.side == "right" then
					hit = math.abs(p.x - line) < 1
						and math.abs(p.z - o.at) < S.OPENING - 1 + p.sz / 2
				else
					hit = math.abs(p.z - line) < 1
						and math.abs(p.x - o.at) < S.OPENING - 1 + p.sx / 2
				end
				truthy(not hit, `fence across the {o.side} opening at {o.at}`)
			end
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

test("each Meshy prop has its block stand-in, a known model name, a size and a turn", function()
	local all, props = S.layout()
	eq(#all, #pieces)
	local known = {
		LeafyTree = true,
		PineTree = true,
		Bush = true,
		BigRock = true,
		FlatRock = true,
		Cactus = true,
		TreeStump = true,
		Log = true,
		RockPile = true,
		HayBale = true,
	}
	local count: { [number]: number } = {}
	for _, p in all do
		if p.prop ~= 0 then
			truthy(props[p.prop], "piece points at a prop")
			count[p.prop] = (count[p.prop] or 0) + 1
		else
			truthy(p.kind == "Fence" or p.kind == "Hedge", `{p.kind} without a prop`)
		end
	end
	local seen: { [string]: number } = {}
	for i, pr in props do
		eq(pr.id, i)
		truthy(known[pr.mesh], "model name " .. pr.mesh)
		truthy((count[i] or 0) > 0, "prop has blocks")
		truthy(pr.height > 1 and pr.height < 25, "height")
		truthy(pr.turn >= 0 and pr.turn <= 360, "turn")
		seen[pr.mesh] = (seen[pr.mesh] or 0) + 1
	end
	for name in known do
		truthy((seen[name] or 0) > 0, "no " .. name)
	end
	-- phones: about 3k triangles each, so keep the count of models down
	truthy(#props <= 400, `props: {#props}`)
end)
