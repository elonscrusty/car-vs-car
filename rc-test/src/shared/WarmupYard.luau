--!strict
-- Car VS Car Smash's WARM-UP YARD (FINISH-JOBS, GO 22:13, auditor C2): a kid who walks into the
-- SMASH! portal while a round is on waits up to ~2:50 for the next one. They drive here meanwhile:
-- "?" boxes (BoxServer, its own set), live weapons (WeaponServer) and target dummy karts that pop
-- (BOTS), no score and no coins, under a big NEXT MATCH IN m:ss (workspace NextMatchAt, MATCH's).
-- At the start, MatchRunner takes everyone waiting into the arena.
-- A small map like the arena (ArenaData): map-local "big" units, shrunk to RC size
-- (TrackData.RC_SCALE) at RC_X / RC_Z, so the karts drive it the same way (LobbyLayout.yardIndex).
-- Pure (Lune tests it): where it is, its pieces, the spots, and the clock words.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local TrackData = sibling("TrackData")

type V3 = { x: number, y: number, z: number }
local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local WarmupYard = {}

WarmupYard.id = "yard"

-- Is Smash on? Features.SMASH, or in Studio the workspace attribute Smash (Main's MatchRunner
-- switch). Lune: just the flag.
function WarmupYard.on(): boolean
	local Features = sibling("Features")
	if not Features.CVC then
		return false
	end
	if Features.SMASH then
		return true
	end
	return script ~= nil
		and game:GetService("RunService"):IsStudio()
		and workspace:GetAttribute("Smash") == true
end
-- World spot (RC studs). Far from everything: the lobby and plots are at z 900+, the old race
-- maps at x +-3000, the arena at z -3000; nothing else is in view while you play here.
WarmupYard.RC_X, WarmupYard.RC_Z, WarmupYard.RC_ANGLE = 0, -2000, 0
-- map-local big units (a kart is 3 x 5.5): about half the arena's 360 across
WarmupYard.W = 200 -- x
WarmupYard.D = 140 -- z
WarmupYard.WALL_H = 8 -- low, so it reads as a play yard; karts bounce off it
WarmupYard.WALL_T = 6

-- low-poly palette (FINISH-JOBS look rule): grass green, sunny yellow, hot pink, dark navy, and
-- the arena's purple wall
local GRASS = { 104, 196, 82 }
local SAND = { 246, 214, 140 }
local PURPLE = { 132, 84, 214 }
local PINK = { 255, 64, 160 }
local NAVY = { 32, 40, 74 }
local YELLOW = { 255, 210, 60 }

export type Spot = { x: number, y: number, z: number, dx: number, dz: number }

-- start spots (big units), facing +z toward the board: 8, as many as a round takes
WarmupYard.spawns = {} :: { Spot }
for i = 0, 7 do
	local row = i // 4
	table.insert(
		WarmupYard.spawns,
		{ x = -54 + (i % 4) * 36, y = 2.5, z = -52 + row * 18, dx = 0, dz = 1 }
	)
end
-- "?" box spots (big units, y = the floor's top): BoxServer.start, name WarmupBoxes
WarmupYard.boxSpots = {
	v(-70, 0, -8),
	v(0, 0, -18),
	v(70, 0, -8),
	v(-34, 0, 30),
	v(34, 0, 30),
	v(0, 0, 50),
} :: { V3 }
-- target karts (BOTS' ArenaBots.dummy): two still, two circling slowly (their loop is 12 RC
-- studs = 48 big across, so they sit well inside the walls)
WarmupYard.DUMMIES = {
	{ at = v(-50, 0, 14), mode = "still" },
	{ at = v(50, 0, 14), mode = "still" },
	{ at = v(-26, 0, 2), mode = "circle" },
	{ at = v(26, 0, 2), mode = "circle" },
} :: { { at: V3, mode: string } }
-- the NEXT MATCH board: across the far end, facing the spawns (-z)
WarmupYard.BOARD = { at = v(0, 30, WarmupYard.D / 2 - 6), w = 120, h = 28 }

-- The yard as a track (TrackData.Track), so the driving code places karts in it like a map.
-- mode "arena": no lights, no laps (Main.client).
function WarmupYard.track(): any
	local s = WarmupYard.spawns[1]
	return {
		id = WarmupYard.id,
		label = "WARM-UP YARD",
		originX = 0,
		mode = "arena",
		grip = 1,
		spawn = { x = s.x, y = s.y, z = s.z, dx = s.dx, dz = s.dz },
		gates = {},
		rcX = WarmupYard.RC_X,
		rcZ = WarmupYard.RC_Z,
		rcAngle = WarmupYard.RC_ANGLE,
		map = WarmupYard.id,
	}
end

-- World position (RC studs) of a map-local point.
function WarmupYard.world(p: V3): V3
	local x, y, z = TrackData.toWorld(WarmupYard.track(), true, p.x, p.y, p.z)
	return v(x, y, z)
end

-- The yard's parts (Garage.Piece, map-local big units): grass floor, a sand patch in the
-- middle, low purple walls, pink corner posts and the navy board with a yellow rim.
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
	add("Ground", "Floor", v(W + 2 * T, 4, D + 2 * T), v(0, -2, 0), GRASS)
	add("Ground", "Sand", v(110, 0.4, 64), v(0, 0.2, 10), SAND, { collide = false })
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
				v(T + 3, H + 6, T + 3),
				v(sx * (W / 2 + T / 2), (H + 6) / 2, sz * (D / 2 + T / 2)),
				PINK
			)
		end
	end
	local b = WarmupYard.BOARD
	add("Board", "Rim", v(b.w + 4, b.h + 4, 2), v(b.at.x, b.at.y, b.at.z + 1.2), YELLOW)
	add("Board", "Face", v(b.w, b.h, 2), v(b.at.x, b.at.y, b.at.z), NAVY)
	local legH = b.at.y - b.h / 2
	for _, sx in { -1, 1 } do
		add("Board", "Leg", v(4, legH, 4), v(sx * (b.w / 2 - 10), legH / 2, b.at.z + 1.2), NAVY)
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

-- Only worth the trip when the round is at least this far off (else wait by the portal: a round
-- with nobody in it starts in ~5 s).
WarmupYard.MIN_WAIT = 12

-- Should this player be in the yard now? Queued, not in a round, and the next round far enough
-- off (a round going on, or one planned more than MIN_WAIT away). Pure.
function WarmupYard.wants(
	queued: boolean,
	inMatch: boolean,
	endsAt: number?,
	nextAt: number?,
	now: number
): boolean
	if not queued or inMatch then
		return false
	end
	if endsAt and endsAt > now then
		return true
	end
	return nextAt ~= nil and nextAt - now > WarmupYard.MIN_WAIT
end

-- Is a world point (RC studs) over the yard's floor? Who is warming up.
function WarmupYard.inside(p: V3): boolean
	local x, y, z = TrackData.toLocal(WarmupYard.track(), true, p.x, p.y, p.z)
	return math.abs(x) <= WarmupYard.W / 2 + WarmupYard.WALL_T
		and math.abs(z) <= WarmupYard.D / 2 + WarmupYard.WALL_T
		and y > -40
		and y < 240
end

-- Build it under `parent` (server), at RC size. The board's Face carries the clock
-- (WarmupYard.client draws on it).
function WarmupYard.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "WarmupYard"
	Garage.makeParts(WarmupYard.parts(), model, CFrame.identity)
	model.WorldPivot = CFrame.identity
	model:ScaleTo(TrackData.RC_SCALE)
	model:PivotTo(
		CFrame.new(WarmupYard.RC_X, 0, WarmupYard.RC_Z) * CFrame.Angles(0, WarmupYard.RC_ANGLE, 0)
	)
	model.Parent = parent
	return model
end

return WarmupYard
