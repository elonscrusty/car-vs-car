--!strict
-- Lobby lake (LobbyWater.luau): bank, beach, water, docks and boat past the end of the street.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local W = require("../src/shared/LobbyWater")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby water")

local pieces = W.pieces()

local function named(prefix: string): { W.Piece }
	local out = {}
	for _, p in pieces do
		if string.sub(p.name, 1, #prefix) == prefix then
			table.insert(out, p)
		end
	end
	return out
end

test("light for phones: a few hundred plain parts, none too big for Roblox", function()
	truthy(#pieces < 400, `{#pieces} parts`)
	for _, p in pieces do
		truthy(p.sx <= 2048 and p.sy <= 2048 and p.sz <= 2048, p.name .. " too big")
		truthy(p.sx > 0 and p.sy > 0 and p.sz > 0, p.name .. " flat")
	end
end)

test("nothing pokes up inside the lobby: only the bank grass sits under it", function()
	local g = L.ground()
	for _, p in pieces do
		local r = math.max(p.sx, p.sz) / 2
		local inside = p.x + r > g.minX
			and p.x - r < g.maxX
			and p.z + r > g.minZ
			and p.z - r < g.maxZ
		if inside and not p.hidden then
			truthy(p.y + p.sy / 2 <= -0.05, p.name .. " pokes into the lobby")
		end
	end
end)

test("docks start on the outer strip of the bank, clear of the landscaping props", function()
	local inner = W.bankBox()
	inner = {
		minX = inner.minX + W.DOCK_FREE,
		maxX = inner.maxX - W.DOCK_FREE,
		minZ = inner.minZ + W.DOCK_FREE,
		maxZ = inner.maxZ - W.DOCK_FREE,
	}
	local planks = named("DockPlank")
	truthy(#planks > 0, "has docks")
	for _, p in planks do
		-- planks are only ever square to the world (0 or 90 degrees)
		local ex, ez = p.sx / 2, p.sz / 2
		if p.ry == 90 then
			ex, ez = ez, ex
		end
		local clear = p.x + ex <= inner.minX
			or p.x - ex >= inner.maxX
			or p.z + ez <= inner.minZ
			or p.z - ez >= inner.maxZ
		truthy(clear, `plank at {p.x}, {p.z} is in the props band`)
		H.near(p.y + p.sy / 2, W.DECK_TOP, 1e-6, "deck height")
	end
end)

test("you can walk from the grass onto a dock (low step) and wade the water", function()
	truthy(W.DECK_TOP - W.GRASS_TOP < 1, "dock step")
	truthy(W.WATER_TOP - W.BED_TOP < 3, "waist deep, not over your head")
	for _, p in named("Water") do
		eq(p.collide, false)
	end
	for _, p in named("LakeBed") do
		eq(p.collide, true)
	end
end)

test("invisible walls keep people from wandering off across the lake", function()
	eq(#named("EdgeWall"), 3)
	for _, p in named("EdgeWall") do
		eq(p.hidden, true)
		truthy(p.y + p.sy / 2 > 10, "tall enough")
	end
end)

test("the lake is only past the street end: nothing beside or behind the lobby", function()
	local g = L.ground()
	local s = L.LAKE_SIDE or 1
	local edge = if s > 0 then g.maxZ else g.minZ
	for _, p in pieces do
		if p.name ~= "Bank" and not p.hidden then
			local r = math.max(p.sx, p.sz) / 2
			truthy((p.z - edge) * s > -r - 0.01, `{p.name} at z {p.z} is on the wrong side`)
		end
	end
end)

test("landings: one per dock, on the bank edge, pointing out over the lake", function()
	local bank = W.bankBox()
	local s = L.LAKE_SIDE or 1
	local ls = W.landings()
	eq(#ls, #named("DockFrame"))
	eq(#ls, 2)
	for _, l in ls do
		eq(l.dx, 0)
		eq(l.dz, s)
		H.near(l.z, if s > 0 then bank.maxZ else bank.minZ)
	end
end)

test(
	"you can walk back out of the water: small steps from the lake floor up to the sand",
	function()
		local last = W.BED_TOP
		for i = #W.STEPS, 1, -1 do
			local top = W.STEPS[i][1]
			truthy(top - last <= 0.55, `step {i} too tall`)
			last = top
		end
		truthy(W.SAND_TOP - last <= 0.55, "last step up to the sand")
	end
)

test("a rowboat floats beside each dock, and two docks have a life ring", function()
	local hull = named("BoatHull")
	eq(#hull, 2)
	for _, h in hull do
		truthy(
			h.y - h.sy / 2 < W.WATER_TOP and h.y + h.sy / 2 > W.WATER_TOP,
			"hull sits in the water"
		)
	end
	eq(#named("BuoyPost"), 2)
	local ring = 0
	for _, p in pieces do
		if p.name == "Buoy" then
			ring += 1
		end
	end
	eq(ring, 2 * 8, "two rings of 8")
end)
