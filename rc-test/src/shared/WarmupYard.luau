--!strict
-- Car VS Car Smash's WARM-UP YARD (FINISH-JOBS, GO 22:13, auditor C2): a kid who walks into the
-- SMASH! portal while a match is on waits up to ~2:50 for the next round. They drive here meanwhile:
-- "?" boxes (BoxServer, its own set), live weapons (WeaponServer) and target dummy karts that pop
-- (BOTS), no score and no coins, under a big NEXT MATCH IN m:ss (workspace NextMatchAt, MATCH's).
-- At 0, MatchRunner takes everyone waiting into the arena. Pure (Lune tests it): where it is, its
-- pieces, the spots, and the clock words.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")

type V3 = { x: number, y: number, z: number }
local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local WarmupYard = {}

-- World space. Far from everything (the lobby and plots are at z 900+, the old race maps at
-- x +-3000), so nothing of the lobby is in view while you play here.
WarmupYard.ORIGIN = v(0, 0, -2000)
WarmupYard.W = 100 -- x
WarmupYard.D = 70 -- z
WarmupYard.WALL_H = 3 -- low, so it reads as a play yard; karts bounce off it
WarmupYard.WALL_T = 2

-- low-poly palette (FINISH-JOBS look rule): grass green, sky blue, sunny yellow, cherry red, hot
-- pink, dark navy
local GRASS = { 104, 196, 82 }
local SAND = { 246, 214, 140 }
local PURPLE = { 132, 84, 214 }
local PINK = { 255, 64, 160 }
local NAVY = { 32, 40, 74 }
local YELLOW = { 255, 210, 60 }

-- yard-local spots (x across, z along; 0,0 = the middle, on the floor)
WarmupYard.SPAWNS = { -- karts start here, facing +z (8: MatchRunner takes up to 8 players)
	v(-30, 0, -26),
	v(-18, 0, -26),
	v(-6, 0, -26),
	v(6, 0, -26),
	v(18, 0, -26),
	v(30, 0, -26),
	v(-24, 0, -18),
	v(24, 0, -18),
} :: { V3 }
WarmupYard.BOXES = { -- "?" boxes (BoxServer.start, name WarmupBoxes)
	v(-32, 0, 0),
	v(0, 0, -8),
	v(32, 0, 0),
	v(-16, 0, 18),
	v(16, 0, 18),
	v(0, 0, 26),
} :: { V3 }
WarmupYard.DUMMIES = { -- target karts (BOTS): two still, two circling slowly
	{ at = v(-20, 0, 8), mode = "still" },
	{ at = v(20, 0, 8), mode = "still" },
	{ at = v(-8, 0, 22), mode = "circle" },
	{ at = v(8, 0, 22), mode = "circle" },
} :: { { at: V3, mode: string } }
-- the NEXT MATCH board: across the far end, facing the spawns (-z)
WarmupYard.BOARD = { at = v(0, 9, WarmupYard.D / 2 - 1), w = 28, h = 7 }

-- World position of a yard-local point.
function WarmupYard.world(p: V3): V3
	local o = WarmupYard.ORIGIN
	return v(o.x + p.x, o.y + p.y, o.z + p.z)
end

-- The yard's parts (Garage.Piece, yard-local): grass floor, a sand ring round the middle, low
-- purple walls, pink corner posts and the navy board with a yellow rim.
function WarmupYard.parts(): { any }
	local out: { any } = {}
	local function add(
		group: string,
		name: string,
		size: V3,
		pos: V3,
		color: { number },
		opts: any?
	)
		local o = opts or {}
		table.insert(out, {
			group = group,
			name = name,
			shape = o.shape or "Block",
			size = size,
			pos = pos,
			rot = o.rot or v(0, 0, 0),
			color = color,
			material = o.material or "SmoothPlastic",
			collide = if o.collide == nil then true else o.collide,
		})
	end
	local W, D, H, T = WarmupYard.W, WarmupYard.D, WarmupYard.WALL_H, WarmupYard.WALL_T
	add("Ground", "Floor", v(W, 1, D), v(0, -0.5, 0), GRASS)
	add("Ground", "Sand", v(30, 0.1, 22), v(0, 0.05, 6), SAND, { collide = false })
	for _, sx in { -1, 1 } do
		add("Walls", "Side", v(T, H, D + 2 * T), v(sx * (W / 2 + T / 2), H / 2, 0), PURPLE)
	end
	for _, sz in { -1, 1 } do
		add("Walls", "End", v(W, H, T), v(0, H / 2, sz * (D / 2 + T / 2)), PURPLE)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Walls",
				"Post",
				v(T + 1, H + 1.5, T + 1),
				v(sx * (W / 2 + T / 2), (H + 1.5) / 2, sz * (D / 2 + T / 2)),
				PINK
			)
		end
	end
	local b = WarmupYard.BOARD
	add("Board", "Rim", v(b.w + 1, b.h + 1, 0.5), v(b.at.x, b.at.y, b.at.z + 0.3), YELLOW)
	add("Board", "Face", v(b.w, b.h, 0.5), v(b.at.x, b.at.y, b.at.z), NAVY)
	for _, sx in { -1, 1 } do
		add(
			"Board",
			"Leg",
			v(1, b.at.y - b.h / 2, 1),
			v(sx * (b.w / 2 - 2), (b.at.y - b.h / 2) / 2, b.at.z + 0.3),
			NAVY
		)
	end
	return out
end

-- The board's words for `left` seconds until the next round (nil = no round planned yet).
function WarmupYard.clock(left: number?): string
	if left == nil or left ~= left then
		return "WARM UP!"
	end
	if left <= 0.5 then
		return "GET READY!"
	end
	local s = math.ceil(left)
	return string.format("NEXT MATCH IN %d:%02d", s // 60, s % 60)
end

-- Is a world point inside the yard (over its floor, below a high ceiling)? Who is warming up.
function WarmupYard.inside(p: V3): boolean
	local o = WarmupYard.ORIGIN
	return math.abs(p.x - o.x) <= WarmupYard.W / 2
		and math.abs(p.z - o.z) <= WarmupYard.D / 2
		and p.y > o.y - 10
		and p.y < o.y + 60
end

-- Build it under `parent` (server). Returns the model; the board's Face carries the clock
-- (WarmupYard.client draws on it).
function WarmupYard.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "WarmupYard"
	local o = WarmupYard.ORIGIN
	Garage.makeParts(WarmupYard.parts(), model, CFrame.new(o.x, o.y, o.z))
	model.Parent = parent
	return model
end

return WarmupYard
