--!strict
-- Car VS Car (carter 10-28, "training on the outskirts", rc-game/plot-layouts/plot-layout-edges.png):
-- your plot is a training yard. The stations run round the edges, one bar a wall: ramps (BOOST)
-- down the left, treadmills (SPEED) along the back, speed tracks (TURN) down the right, the
-- first of each nearest the stand. The middle is a low garage floor: your best waiting car on a
-- podium up front, the other car stands behind it, and on the back wall, high over the
-- treadmills, the scoreboard (who is ahead), the trophy shelf and your name. Plot level 0 has
-- one pad open; each level opens the next (Training.STATIONS), and a locked pad is a quiet
-- grass-green spot with "?" and the level that opens it. A tiny car runs on each station with a
-- car on it (PlotTraining.ride).
-- Plain numbers and Garage pieces (Lune tests load this): PlotGarageBuilder (server) builds the
-- room and the pads, CvcPlot.client puts the cars on them.
--
-- Plot-local, RC size (studs): x across the plot (±40), +z toward the road (the front wall is
-- at z 37, the street wall at 55), y up.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local Finish = sibling("Finish")
local Training = sibling("Training")
local CarStats = sibling("CarStats")

type Piece = Garage.Piece
type V3 = Garage.V3

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local PlotTraining = {}

-- the pads, in station order (Training.STATIONS: treadmill, ramp, track, again and again): each
-- treadmill on the back wall (middle first), each ramp down the left wall and each speed track
-- down the right (front first, nearest the stand)
PlotTraining.GRID = {
	{ x = 0, z = -44 },
	{ x = -27, z = 24 },
	{ x = 27, z = 24 },
	{ x = -25, z = -44 },
	{ x = -27, z = 3 },
	{ x = 27, z = 3 },
	{ x = 25, z = -44 },
	{ x = -27, z = -18 },
	{ x = 27, z = -18 },
}
PlotTraining.PAD = { w = 24, d = 18 } -- each station pad (x by z)
-- the station props and the cars' runs on them, this much bigger than they were drawn (so they
-- read from the stand); ride() and slats() hand back the grown numbers
PlotTraining.K = 1.15
-- each open pad's sign: an upright board w by h studs on two posts, its bottom `low` studs up, at
-- the pad's edge nearest the middle and facing it (signAt). carter 10-28: players walk round the
-- plot while their cars train (no high camera), so the signs are read at eye level; up on posts,
-- you see the station under them.
PlotTraining.PAD_SIGN = { w = 18, h = 3.6, low = 6 }

-- Where pad i's sign stands (plot-local x, z), its yaw in degrees (its words face +z turned by yaw)
-- and how high its bottom is: the side walls' face the middle; the back wall's face the road, and
-- the one right under the scoreboard hangs just below it on the wall (on posts at the pad's front,
-- it hid the board's rows from anyone walking up close, Studio u23).
function PlotTraining.signAt(i: number): (number, number, number, number)
	local g = PlotTraining.GRID[i]
	local P, S, B = PlotTraining.PAD, PlotTraining.PAD_SIGN, PlotTraining.BOARD
	if math.abs(g.x) > P.w / 2 + 1 and g.z > -40 then
		local side = if g.x < 0 then 1 else -1 -- the left wall faces +x, the right -x
		return g.x + side * (P.w / 2 - 0.5), g.z, side * 90, S.low
	end
	if math.abs(g.x - B.x) + S.w / 2 <= B.w / 2 then
		return g.x, B.z + 0.4, 0, B.y - B.h / 2 - 0.4 - S.h
	end
	return g.x, g.z + P.d / 2 - 0.5, 0, S.low
end
PlotTraining.ROOM = { x0 = -14, x1 = 14, z0 = -32, z1 = 30 } -- the garage floor, in the middle
PlotTraining.NEAR = 220 -- studs: a plot farther from the camera than this stops moving its cars
PlotTraining.CAR = 1.55 -- toy car size on the stations and stands (times a 3.6-stud car)
-- the car you race with, on your own plot: this much bigger, with a gold outline and a gold glow
-- round its pad (CvcPlot.client), so you spot it (phone test: it was 0.17% of the screen).
-- carScale keeps it inside the treadmill rails.
PlotTraining.MINE_GROW = 1.2
PlotTraining.MINE_GLOW = { 255, 210, 60 }
PlotTraining.RAIL_X = 2.7 -- the treadmill rails' middles, each side (before K)

-- Half a toy car's width over its wheels at size 1 (Garage.toyCar).
function PlotTraining.halfWidth(style: string?): number
	local ww = if style == "drift" then 0.65 elseif style == "rock" then 0.6 else 0.45
	return 1 + ww + (if style == "rock" then 0.15 else 0)
end

-- A car's size on a station (`kind`) or a stand (kind nil): your race car grows, but on the
-- treadmill only as far as its wheels stay inside the rails.
function PlotTraining.carScale(kind: string?, style: string?, racer: boolean): number
	local s = PlotTraining.CAR
	if not racer then
		return s
	end
	local grow = s * PlotTraining.MINE_GROW
	if kind == "treadmill" then
		local inside = (PlotTraining.RAIL_X - 0.15) * PlotTraining.K - 0.1
		grow = math.min(grow, inside / PlotTraining.halfWidth(style))
	end
	return math.max(s, grow)
end
-- the car stands on the garage floor, in the order they open: the first is the podium up front
-- (raised `lift` studs, gold: CvcPlot.client puts your best waiting car on it), then rows of 3
export type Stand = { x: number, z: number, lift: number? }
local STANDS: { Stand } = {
	{ x = 0, z = 22, lift = 2.4 },
	{ x = -9, z = 8 },
	{ x = 9, z = 8 },
	{ x = 0, z = 8 },
	{ x = -9, z = -4 },
	{ x = 9, z = -4 },
	{ x = 0, z = -4 },
	{ x = -9, z = -16 },
	{ x = 9, z = -16 },
	{ x = 0, z = -16 },
}
PlotTraining.STANDS = STANDS
PlotTraining.SHELF = { x = 28, z = -53.2, w = 18, y = 8 } -- the trophy shelf, high on the back wall
-- the scoreboard on the back wall over the middle treadmill: every car's 3 bars, best on top
-- (CvcPlot.client writes it); w by h studs, its middle at y
-- (high: walking players see it over the back wall's pad signs, carter 10-28)
PlotTraining.BOARD = { x = 0, z = -53.8, w = 34, h = 13, y = 18.5 }
PlotTraining.BOARD_ROWS = 3 -- the top 3, big enough to read on a phone (Studio 10-28: 5 rows were tiny)
PlotTraining.MAX_TROPHIES = 12 -- cups drawn on the shelf (the number on its sign keeps counting)

-- Does a plot this far from the camera move its cars? (phone speed: far ones wait)
function PlotTraining.awake(distance: number): boolean
	return distance < PlotTraining.NEAR
end

-- Car stands at this garage level: 3 at the start, one more each level, up to 10.
function PlotTraining.stands(garageLevel: number): number
	return math.clamp(3 + math.floor(garageLevel), 3, #PlotTraining.STANDS)
end

-- Open pads at this plot level (one at the start, one more each level).
function PlotTraining.open(plotLevel: number): number
	return #Training.stationsFor(plotLevel)
end

-- The station on pad i (Training.STATIONS order).
function PlotTraining.kindAt(index: number): string
	return Training.STATIONS[index] or "treadmill"
end

export type Pad = { kind: string, level: number, car: string } -- car "" = an empty pad

-- The plot's "Stations" attribute ("kind:level:carId;...") as a list, pad i = station i.
function PlotTraining.parse(text: string?): { Pad }
	local out: { Pad } = {}
	if text == nil or text == "" then
		return out
	end
	for _, part in string.split(text, ";") do
		local bits = string.split(part, ":")
		local kind = bits[1]
		if Training.isKind(kind) then
			table.insert(out, {
				kind = kind,
				level = math.max(1, math.floor(tonumber(bits[2]) or 1)),
				car = bits[3] or "",
			})
		end
	end
	return out
end

-- "?" / LV n painted on a locked pad's top (PlotGarageBuilder). A Top-face SurfaceGui
-- has its up edge toward the pad's -x and its right toward -z (Studio score 05: the words read
-- sideways from the gate), so each line is turned 90 to read upright from the road. `at` is
-- how far across the gui's width (the pad's depth, from the road side) the line's middle sits;
-- w runs along the pad's x and h along its z, in studs.
PlotTraining.PAINT = {
	{ at = 0.6, w = 8, h = 6 }, -- ?
	{ at = 0.28, w = 9, h = 3 }, -- LV n
}

-- An open pad's sign with a car on it (CvcPlot.client writes these over padWords): the station
-- and its level, then the car and the one number that station trains, big enough to read from
-- the plot camera on a phone (Studio round 5: the little tags beside the cars couldn't be read).
function PlotTraining.carWords(pad: Pad, carName: string, value: number): (string, string)
	local bar = CarStats.BAR_LABELS[Training.MAIN[pad.kind] or ""] or ""
	local name = Training.NAMES[pad.kind] or string.upper(pad.kind)
	return name .. "  LV " .. pad.level, string.upper(carName) .. "  " .. bar .. " " .. value
end

-- The words on a pad's sign.
function PlotTraining.padWords(pad: Pad?, index: number): (string, string)
	if pad == nil then
		return "?", "LV " .. (index - 1)
	end
	-- the bar it trains most, in the tag's words (the SPEED TRACK trains TURN: say so)
	local bar = CarStats.BAR_LABELS[Training.MAIN[pad.kind] or ""]
	local lv = "LV " .. pad.level
	return Training.NAMES[pad.kind] or string.upper(pad.kind),
		if bar then lv .. "  +" .. bar else lv
end

-- The scoreboard's rows: the cars with the biggest speed + turn + boost first (then by name, so
-- it doesn't flicker), at most BOARD_ROWS.
export type BoardCar = { name: string, speed: number, turn: number, boost: number }
function PlotTraining.board(cars: { BoardCar }): { BoardCar }
	local list = table.clone(cars)
	table.sort(list, function(a: BoardCar, b: BoardCar): boolean
		local ta, tb = a.speed + a.turn + a.boost, b.speed + b.turn + b.boost
		if ta ~= tb then
			return ta > tb
		end
		return a.name < b.name
	end)
	return table.move(list, 1, math.min(#list, PlotTraining.BOARD_ROWS), 1, {})
end
-- the bars' colors on the board, matching the walls: SPEED blue (treadmills), TURN green (speed
-- tracks), BOOST orange (ramps)
PlotTraining.BAR_COLORS = {
	speed = { 60, 160, 230 },
	turn = { 90, 200, 90 },
	boost = { 250, 170, 60 },
}

-- Where a tiny car is on a station at time `t` (seconds): pad-local x, y, z, its yaw in degrees
-- (0 = nose to -z, like Garage.toyCar) and a nose-up tilt in degrees.
PlotTraining.TRACK = { halfW = 7, halfD = 4 } -- the speed track's middle line
-- COACH (Training.COACH_SECS after the owner's CoachAt): the stations run this much faster
PlotTraining.COACH_SPEED = 1.6
function PlotTraining.coaching(coachAt: number?, now: number): boolean
	local at = tonumber(coachAt) or 0
	return at > 0 and now >= at and now < at + Training.COACH_SECS
end

-- The treadmill belt's slats (pad-local z), scrolling back under the running car (+z).
PlotTraining.BELT = { z = -0.5, len = 8.6, slats = 6, speed = 6 }
function PlotTraining.slats(t: number): { number }
	local B = PlotTraining.BELT
	local gap = B.len / B.slats
	local shift = (t * B.speed) % gap
	local out = {}
	for k = 0, B.slats - 1 do
		local z = B.z - B.len / 2 + gap / 2 + ((k * gap + shift) % B.len)
		table.insert(out, z * PlotTraining.K)
	end
	return out
end

-- the name sign stands left on the back wall (the scoreboard is in the middle, the shelf right)
PlotTraining.ROOM_SIGN_X = -28
-- A stand car's tag (in the garage room) sits just over the car, sized in studs. Station cars
-- have no tag: their numbers are on their pad's sign (carWords).
PlotTraining.STAND_TAG = { w = 6.5, h = 3.5, up = 3.6 }
-- The camera while you stand on your own plot's pad (PlotCam.client), plot-local: high over the
-- stand, looking down over the whole yard, so all 3 walls of stations and the scoreboard are on
-- a phone screen at once (16:9 or wider; the plot_training test checks every pad corner).
PlotTraining.STAND_CAM = {
	eye = { x = 0, y = 55, z = 80 },
	look = { x = 0, y = 0, z = -2 },
	fov = 40,
	off = 3, -- studs past the pad's reach before the walking camera comes back
}

PlotTraining.RAMP_SECS = 6 -- one ramp run: up, over the gap, round and back
local function rideBase(kind: string, t: number): (number, number, number, number, number)
	if kind == "treadmill" then
		-- running in place on the belt, with a little bounce
		return 0, 1.2 + 0.08 * math.abs(math.sin(t * 9)), -0.5, 0, 0
	elseif kind == "track" then
		local T = PlotTraining.TRACK
		local a = (t * 1.6) % (2 * math.pi)
		local x, z = math.cos(a) * T.halfW, math.sin(a) * T.halfD - 1
		-- heading = the way round (counter-clockwise seen from above is +a)
		local dx, dz = -math.sin(a) * T.halfW, math.cos(a) * T.halfD
		return x, 0.47, z, math.deg(math.atan2(-dx, -dz)), 0
	end
	-- ramp: up the ramp (+x), a hop over the gap, land, round the back and home again
	local s = (t % PlotTraining.RAMP_SECS) / PlotTraining.RAMP_SECS
	if s < 0.25 then -- up the ramp, x -7 -> -1.5
		local k = s / 0.25
		return -7 + 5.5 * k, 0.32 + 1.98 * k, -2, -90, 15
	elseif s < 0.4 then -- the hop, x -1.5 -> 3
		local k = (s - 0.25) / 0.15
		return -1.5 + 4.5 * k, 2.3 + 2.4 * k - 4.2 * k * k, -2, -90, 15 - 30 * k
	elseif s < 0.5 then -- roll out on the landing, x 3 -> 6
		local k = (s - 0.4) / 0.1
		return 3 + 3 * k, 0.5, -2, -90, 0
	elseif s < 0.62 then -- round the end
		local k = (s - 0.5) / 0.12
		local a = math.pi * k
		return 6 + math.sin(a) * 2, 0.32, -math.cos(a) * 2, -90 - 180 * k, 0
	elseif s < 0.88 then -- back along the near side, x 6 -> -7
		local k = (s - 0.62) / 0.26
		return 6 - 13 * k, 0.32, 2, 90, 0
	end
	local k = (s - 0.88) / 0.12 -- round to the foot of the ramp
	local a = math.pi * k
	return -7 - math.sin(a) * 2, 0.32, math.cos(a) * 2, 90 - 180 * k, 0
end

function PlotTraining.ride(kind: string, t: number): (number, number, number, number, number)
	local x, y, z, yaw, tilt = rideBase(kind, t)
	local K = PlotTraining.K
	return x * K, 0.3 + (y - 0.3) * K, z * K, yaw, tilt
end

-- ===== the pieces (server builds these) =====

local WOOD = { 196, 150, 100 }
local WOOD_DARK = { 120, 80, 50 }
local RUG = { 200, 70, 70 }
local GOLD = { 255, 200, 50 }
local PAD_COL = { 238, 228, 208 }
local PAD_EDGE = { 140, 115, 90 }
local LOCKED = { 140, 190, 110 } -- near the grass: a quiet spot, not a shout
local DARK = { 45, 45, 52 }
local BLUE = { 60, 160, 230 }
local ORANGE = { 250, 170, 60 }
local GREEN = { 120, 190, 90 }
local ROAD = { 64, 66, 74 }
local RED = { 225, 60, 60 }
local WHITE = { 245, 245, 245 }
local SIGN = { 40, 44, 60 }

-- a flat strip from (ax, az) to (bx, bz), `w` wide (looks only)
local function slab(
	add: Garage.Add,
	group: string,
	name: string,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	w: number,
	y: number,
	h: number,
	color: { number }
)
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	add(group, name, v(w, h, len + 0.2), v((ax + bx) / 2, y, (az + bz) / 2), color, {
		rot = v(0, math.deg(math.atan2(-dx, -dz)), 0),
		collide = false,
	})
end

-- One pad: its base, its sign, and (when open) its station.
local function pad(add: Garage.Add, i: number, kind: string?)
	local g = PlotTraining.GRID[i]
	local P = PlotTraining.PAD
	local group = "Pad" .. i
	local x, z = g.x, g.z
	add(group, "PadBase", v(P.w, 0.3, P.d), v(x, 0.15, z), if kind then PAD_COL else LOCKED, {
		collide = false,
	})
	add(
		group,
		"PadEdge",
		v(P.w + 0.6, 0.2, P.d + 0.6),
		v(x, 0.1, z),
		if kind then PAD_EDGE else { 118, 168, 92 },
		{
			collide = false,
		}
	)
	if kind == nil then
		-- locked: no little sign; PlotGarageBuilder paints a quiet "?" and the level on the pad
		return
	end
	-- the sign, up on two posts at the edge nearest the middle, facing it
	local S = PlotTraining.PAD_SIGN
	local sx, sz, yaw, low = PlotTraining.signAt(i)
	local cy = low + S.h / 2
	add(group, "PadSign", v(S.w, S.h, 0.3), v(sx, cy, sz), SIGN, {
		rot = v(0, yaw, 0),
		collide = false,
	})
	local along = math.rad(yaw) -- the sign's own x, in the plot
	for _, e in { -1, 1 } do
		local off = e * (S.w / 2 - 0.4)
		add(
			group,
			"PadSignPost",
			v(0.4, low + 0.2, 0.4),
			v(sx + off * math.cos(along), (low + 0.2) / 2, sz - off * math.sin(along)),
			SIGN,
			{ collide = false }
		)
	end
	-- the station, grown by K about the pad's middle (its floor stays on the pad)
	local K = PlotTraining.K
	local inner = add
	add = function(gr: string, name: string, size: V3, pos: V3, color: { number }, opts: any?)
		return inner(
			gr,
			name,
			v(size.x * K, size.y * K, size.z * K),
			v(x + (pos.x - x) * K, 0.3 + (pos.y - 0.3) * K, z + (pos.z - z) * K),
			color,
			opts
		)
	end :: any
	if kind == "treadmill" then
		add(
			group,
			"TreadFrame",
			v(6, 0.8, 9),
			v(x, 0.7, z - 0.5),
			{ 90, 90, 100 },
			{ collide = false }
		)
		add(group, "TreadBelt", v(4.4, 0.12, 8.6), v(x, 1.12, z - 0.5), DARK, {
			material = "Fabric",
			collide = false,
		})
		for _, sx in { -PlotTraining.RAIL_X, PlotTraining.RAIL_X } do
			add(group, "TreadRail", v(0.3, 0.3, 8.6), v(x + sx, 2.2, z - 0.5), { 200, 200, 210 }, {
				material = "Metal",
				collide = false,
			})
			add(
				group,
				"TreadRailPost",
				v(0.3, 1.2, 0.3),
				v(x + sx, 1.6, z - 4.5),
				{ 200, 200, 210 },
				{
					material = "Metal",
					collide = false,
				}
			)
		end
		-- small, low and behind the car: wider than the car, its COACH orange poked out both sides
		add(group, "TreadScreen", v(3, 1, 0.3), v(x, 2.6, z - 5.6), BLUE, {
			material = "Neon",
			collide = false,
		})
		add(group, "TreadScreenPost", v(0.5, 2, 0.5), v(x, 1.1, z - 5.8), { 90, 90, 100 }, {
			collide = false,
		})
	elseif kind == "ramp" then
		-- the ramp up (+x), a gap, the landing; stripes on the ramp
		local rx0, rx1 = x - 7.5, x - 1.5
		local len = math.sqrt((rx1 - rx0) ^ 2 + 2 ^ 2)
		add(group, "RampSlope", v(len, 0.4, 5), v((rx0 + rx1) / 2, 1.3, z - 2), ORANGE, {
			rot = v(0, 0, math.deg(math.atan2(2, rx1 - rx0))),
			collide = false,
		})
		add(group, "RampLip", v(0.6, 2.2, 5), v(rx1 - 0.3, 1.1, z - 2), { 220, 130, 40 }, {
			collide = false,
		})
		add(group, "RampLanding", v(5, 0.3, 5), v(x + 4.5, 0.35, z - 2), GREEN, { collide = false })
		for k = 0, 2 do
			add(group, "RampFlag", v(0.2, 2.5, 0.2), v(x + 3 + k * 2.5, 1.5, z - 4.8), WHITE, {
				collide = false,
			})
			add(
				group,
				"RampFlagTop",
				v(0.1, 0.8, 1.2),
				v(x + 3 + k * 2.5, 2.4, z - 4.2),
				if k % 2 == 0 then RED else GOLD,
				{ collide = false }
			)
		end
	elseif kind == "track" then
		-- a little oval road with red and white curbs (PlotTraining.TRACK is its middle line)
		local T = PlotTraining.TRACK
		local n = 20
		for k = 0, n - 1 do
			local a0, a1 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
			local function pt(a: number, grow: number): (number, number)
				return x + math.cos(a) * (T.halfW + grow), z - 1 + math.sin(a) * (T.halfD + grow)
			end
			local ax, az = pt(a0, 0)
			local bx, bz = pt(a1, 0)
			slab(add, group, "TrackRoad", ax, az, bx, bz, 2.8, 0.4, 0.12, ROAD)
			for _, side in { -1.7, 1.7 } do
				local cx, cz = pt(a0, side)
				local dx, dz = pt(a1, side)
				slab(
					add,
					group,
					"TrackCurb",
					cx,
					cz,
					dx,
					dz,
					0.5,
					0.45,
					0.16,
					if k % 2 == 0 then RED else WHITE
				)
			end
		end
	end
end

-- Everything on the plot at this plot level, garage level and trophy count.
-- (`showNext`: the next locked pad shows only when you can pay for it, game audit B10; the
-- others stay plain grass until then)
function PlotTraining.pieces(
	plotLevel: number,
	garageLevel: number,
	trophies: number,
	showNext: boolean?
): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local R = PlotTraining.ROOM
	-- the garage floor in the middle: wood boards and a rug under the stands
	local rx, rz = (R.x0 + R.x1) / 2, (R.z0 + R.z1) / 2
	add("Room", "RoomFloor", v(R.x1 - R.x0, 0.2, R.z1 - R.z0), v(rx, 0.1, rz), WOOD, {
		material = "WoodPlanks",
		collide = false,
	})
	add(
		"Room",
		"Rug",
		v(24, 0.1, 30),
		v(0, 0.25, -4),
		RUG,
		{ material = "Fabric", collide = false }
	)
	add(
		"Room",
		"RugTrim",
		v(25, 0.08, 31),
		v(0, 0.22, -4),
		GOLD,
		{ material = "Fabric", collide = false }
	)
	-- the owner's name, left on the back wall, high over the treadmills
	add(
		"Room",
		"RoomSign",
		v(18, 3.6, 0.4),
		v(PlotTraining.ROOM_SIGN_X, 14, -53.4),
		WOOD_DARK,
		{ collide = false }
	)
	for _, side in { -1, 1 } do
		add(
			"RoomSignLegs",
			"Leg",
			v(0.6, 12.2, 0.6),
			v(PlotTraining.ROOM_SIGN_X + side * 8, 6.1, -53.4),
			WOOD_DARK,
			{ collide = false }
		)
	end
	-- the scoreboard and its two legs (CvcPlot.client writes the rows)
	local B = PlotTraining.BOARD
	add("Board", "ScoreBoard", v(B.w, B.h, 0.4), v(B.x, B.y, B.z), SIGN, { collide = false })
	add("Board", "ScoreTrim", v(B.w + 0.8, B.h + 0.8, 0.3), v(B.x, B.y, B.z - 0.15), GOLD, {
		collide = false,
	})
	for _, side in { -1, 1 } do
		add(
			"Board",
			"ScoreLeg",
			v(0.6, B.y - B.h / 2, 0.6),
			v(B.x + side * (B.w / 2 - 1), (B.y - B.h / 2) / 2, B.z),
			WOOD_DARK,
			{ collide = false }
		)
	end
	-- the trophy shelf on the back wall, its cups, and its sign
	local S = PlotTraining.SHELF
	-- a wooden back and two legs, so the shelf boards and the sign don't float over the hillside
	-- (phone playtest u23)
	add(
		"Shelf",
		"ShelfBack",
		v(S.w, 9, 0.3),
		v(S.x, S.y + 3.8, S.z - 0.15),
		WOOD,
		{ collide = false }
	)
	for _, side in { -1, 1 } do
		add(
			"Shelf",
			"ShelfLeg",
			v(0.8, S.y - 0.7, 0.8),
			v(S.x + side * (S.w / 2 - 1), (S.y - 0.7) / 2, S.z - 0.15),
			WOOD_DARK,
			{ collide = false }
		)
	end
	add(
		"Shelf",
		"ShelfBoard",
		v(S.w, 0.4, 2),
		v(S.x, S.y, S.z + 0.8),
		WOOD_DARK,
		{ collide = false }
	)
	add(
		"Shelf",
		"ShelfBoard",
		v(S.w, 0.4, 2),
		v(S.x, S.y + 3.2, S.z + 0.8),
		WOOD_DARK,
		{ collide = false }
	)
	add(
		"Shelf",
		"ShelfSign",
		v(12, 2.2, 0.3),
		v(S.x, S.y + 8, S.z + 0.2),
		WOOD_DARK,
		{ collide = false }
	)
	local cups = math.clamp(math.floor(trophies), 0, PlotTraining.MAX_TROPHIES)
	for k = 1, cups do
		local row = if k <= 6 then 0 else 1
		local col = (k - 1) % 6
		local cx = S.x - S.w / 2 + 2 + col * ((S.w - 4) / 5)
		local cy = S.y + 0.2 + row * 3.2
		add(
			"Shelf",
			"TrophyBase",
			v(1, 0.4, 1),
			v(cx, cy + 0.2, S.z + 0.8),
			WOOD_DARK,
			{ collide = false }
		)
		add("Shelf", "TrophyCup", v(1.4, 1.1, 1.1), v(cx, cy + 1.1, S.z + 0.8), GOLD, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			material = "Foil",
			collide = false,
		})
		add("Shelf", "TrophyStem", v(0.3, 0.6, 0.3), v(cx, cy + 0.6, S.z + 0.8), GOLD, {
			material = "Foil",
			collide = false,
		})
	end
	-- car stands (the first is the podium: raised, all gold)
	for k = 1, PlotTraining.stands(garageLevel) do
		local st = PlotTraining.STANDS[k]
		local lift = st.lift or 0
		if lift > 0 then
			add("Stands", "Podium", v(lift, 8, 8), v(st.x, lift / 2 + 0.2, st.z), GOLD, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				material = "Foil",
				collide = false,
			})
		end
		add("Stands", "Stand", v(0.6, 7, 7), v(st.x, 0.5 + lift, st.z), { 80, 80, 95 }, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
		add("Stands", "StandRing", v(0.4, 7.6, 7.6), v(st.x, 0.3 + lift, st.z), GOLD, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
	end
	-- the station pads
	local open = Training.stationsFor(plotLevel)
	for i = 1, #PlotTraining.GRID do
		if open[i] or (showNext and i == #open + 1) then
			pad(add, i, open[i])
		end
	end
	return Finish.apply(out)
end

-- the room's own pieces, kept when carter's props go in (Garage.useMeshes clears the rest)
local ROOM_KEEP = { "RoomFloor", "Rug", "RugTrim", "RoomSign" }

-- carter's props in the room (Garage.Mesh entries; missing models are skipped)
function PlotTraining.meshes(): { Garage.Mesh }
	local list: { { any } } = {
		-- { model, at, fit, yaw (degrees) }
		-- (the garage door went: the back wall is treadmills now)
		{ "TireRack", v(-10, 0, -29), v(5, 5, 2.5), 180 },
		{ "PaintCans", v(10, 0, -29), v(3, 2, 2.5), 180 },
	}
	local out: { Garage.Mesh } = {}
	for _, m in list do
		local fit: V3 = m[3]
		table.insert(
			out,
			{
				model = m[1],
				group = "Room",
				at = m[2],
				fit = fit,
				long = if fit.z > fit.x then "z" else "x",
				keep = ROOM_KEEP,
				collide = false,
				yaw = m[4],
			} :: any
		)
	end
	return out
end

return PlotTraining
