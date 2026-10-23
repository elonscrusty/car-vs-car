--!strict
-- Lobby water (LobbyWater.luau): bank, shore, water, docks, island, footbridge round the lobby.
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

test("the footbridge reaches the island", function()
	local isl = named("IslandGrass")[1]
	truthy(isl ~= nil and isl.round == true, "round island")
	local farX = -math.huge
	for _, p in named("BridgeDeck") do
		farX = math.max(farX, p.x + p.sx / 2)
	end
	truthy(farX > isl.x - isl.sx / 2, "bridge lands on the island grass")
end)

test("an invisible wall keeps people near the lobby", function()
	eq(#named("EdgeWall"), 4)
	for _, p in named("EdgeWall") do
		eq(p.hidden, true)
		truthy(p.y + p.sy / 2 > 10, "tall enough")
	end
end)
