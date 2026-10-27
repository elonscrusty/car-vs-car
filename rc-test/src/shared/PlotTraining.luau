--!strict
-- Car VS Car (carter 10-26, yes to rc-game/cvc/pics/plot-training-topdown-2.png): your plot is a
-- training garage. At the back, a cozy garage room (wood floor, a rug, the garage door, a trophy
-- shelf on the back wall, car stands down both sides). In the middle, a 3 by 3 grid of station
-- pads: treadmill, ramp, speed track, over and over (Training.STATIONS). Plot level 0 has one pad
-- open; each level opens the next, and a locked pad says which level opens it. A tiny car runs
-- on each station with a car on it (PlotTraining.ride).
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

type Piece = Garage.Piece
type V3 = Garage.V3

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local PlotTraining = {}

-- the pads, in station order (Training.STATIONS): back row first, left to right
PlotTraining.GRID = {
	{ x = -25, z = -12 },
	{ x = 0, z = -12 },
	{ x = 25, z = -12 },
	{ x = -25, z = 8 },
	{ x = 0, z = 8 },
	{ x = 25, z = 8 },
	{ x = -25, z = 27 },
	{ x = 0, z = 27 },
	{ x = 25, z = 27 },
}
PlotTraining.PAD = { w = 22, d = 16 } -- each station pad (x by z)
PlotTraining.ROOM = { x0 = -38, x1 = 38, z0 = -53, z1 = -25 } -- the garage room's floor
PlotTraining.NEAR = 220 -- studs: a plot farther from the camera than this stops moving its cars
PlotTraining.CAR = 0.9 -- toy car size on the stations and stands (times a 3.6-stud car)
-- the car stands down both sides of the room, in the order they open
PlotTraining.STANDS = {
	{ x = -33, z = -44 },
	{ x = 33, z = -44 },
	{ x = -33, z = -32 },
	{ x = 33, z = -32 },
	{ x = -24, z = -44 },
	{ x = 24, z = -44 },
	{ x = -24, z = -32 },
	{ x = 24, z = -32 },
	{ x = -15, z = -32 },
	{ x = 15, z = -32 },
}
PlotTraining.SHELF = { x = 24, z = -53.2, w = 24, y = 4.5 } -- the trophy shelf, on the back wall
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

-- The words on a pad's sign.
function PlotTraining.padWords(pad: Pad?, index: number): (string, string)
	if pad == nil then
		return "LOCKED", "PLOT LV " .. (index - 1)
	end
	return Training.NAMES[pad.kind] or string.upper(pad.kind), "LV " .. pad.level
end

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
		table.insert(out, B.z - B.len / 2 + gap / 2 + ((k * gap + shift) % B.len))
	end
	return out
end

-- The car tags on the plot are sized in studs (so they shrink with distance, not cover the next
-- pad): a station car's tag hangs still over the back of its pad, above the car's whole run;
-- a stand car's sits just over the car.
PlotTraining.TAG = { w = 9, h = 4.8, y = 8.6, back = 6 }
PlotTraining.STAND_TAG = { w = 6.5, h = 3.5, up = 3.6 }
function PlotTraining.tagSpot(index: number): (number, number, number)
	local g = PlotTraining.GRID[index]
	local T = PlotTraining.TAG
	return g.x, T.y, g.z - T.back
end

PlotTraining.RAMP_SECS = 6 -- one ramp run: up, over the gap, round and back
function PlotTraining.ride(kind: string, t: number): (number, number, number, number, number)
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

-- ===== the pieces (server builds these) =====

local WOOD = { 196, 150, 100 }
local WOOD_DARK = { 120, 80, 50 }
local RUG = { 200, 70, 70 }
local GOLD = { 255, 200, 50 }
local PAD_COL = { 238, 228, 208 }
local PAD_EDGE = { 140, 115, 90 }
local LOCKED = { 170, 196, 150 }
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
		if kind then PAD_EDGE else { 120, 150, 110 },
		{
			collide = false,
		}
	)
	-- the sign at the pad's front edge, facing the road (+z); its posts stand behind it
	add(group, "PadSign", v(11, 2.2, 0.3), v(x, 1.9, z + P.d / 2 - 0.6), SIGN, { collide = false })
	for _, sx in { -4.5, 4.5 } do
		add(group, "PadSignPost", v(0.3, 1.6, 0.3), v(x + sx, 0.8, z + P.d / 2 - 1.1), SIGN, {
			collide = false,
		})
	end
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
		for _, sx in { -2.7, 2.7 } do
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
		add(group, "TreadScreen", v(5, 2, 0.3), v(x, 3.4, z - 5.6), BLUE, {
			material = "Neon",
			collide = false,
		})
		add(group, "TreadScreenPost", v(0.5, 2.6, 0.5), v(x, 1.4, z - 5.8), { 90, 90, 100 }, {
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
function PlotTraining.pieces(plotLevel: number, garageLevel: number, trophies: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local R = PlotTraining.ROOM
	-- the garage room: wood floor with boards, a rug, a low wood rail where it meets the yard
	local rx, rz = (R.x0 + R.x1) / 2, (R.z0 + R.z1) / 2
	add("Room", "RoomFloor", v(R.x1 - R.x0, 0.2, R.z1 - R.z0), v(rx, 0.1, rz), WOOD, {
		material = "WoodPlanks",
		collide = false,
	})
	add(
		"Room",
		"Rug",
		v(20, 0.1, 11),
		v(0, 0.25, -37),
		RUG,
		{ material = "Fabric", collide = false }
	)
	add(
		"Room",
		"RugTrim",
		v(21, 0.08, 12),
		v(0, 0.22, -37),
		GOLD,
		{ material = "Fabric", collide = false }
	)
	for _, side in { -1, 1 } do
		add(
			"Room",
			"RoomRail",
			v(28, 1, 0.5),
			v(side * 24, 0.5, R.z1),
			WOOD_DARK,
			{ collide = false }
		)
	end
	add("Room", "RoomSign", v(18, 3.6, 0.4), v(0, 11.2, -53.4), WOOD_DARK, { collide = false })
	-- the trophy shelf on the back wall, its cups, and its sign
	local S = PlotTraining.SHELF
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
		v(S.x, S.y + 6.6, S.z + 0.2),
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
	-- car stands
	for k = 1, PlotTraining.stands(garageLevel) do
		local st = PlotTraining.STANDS[k]
		add("Stands", "Stand", v(0.6, 7, 7), v(st.x, 0.5, st.z), { 80, 80, 95 }, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
		add("Stands", "StandRing", v(0.4, 7.6, 7.6), v(st.x, 0.3, st.z), GOLD, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
	end
	-- the station pads
	local open = Training.stationsFor(plotLevel)
	for i = 1, #PlotTraining.GRID do
		pad(add, i, open[i])
	end
	return Finish.apply(out)
end

-- the room's own pieces, kept when carter's props go in (Garage.useMeshes clears the rest)
local ROOM_KEEP = { "RoomFloor", "Rug", "RugTrim", "RoomRail", "RoomSign" }

-- carter's props in the room (Garage.Mesh entries; missing models are skipped)
function PlotTraining.meshes(): { Garage.Mesh }
	local list: { { any } } = {
		-- { model, at, fit, yaw (degrees) }
		{ "GarageDoor", v(0, 0, -51.5), v(16, 9, 3), 180 },
		{ "TireRack", v(-14, 0, -51.5), v(5, 5, 2.5), 180 },
		{ "PaintCans", v(-36, 0, -51.5), v(3, 2, 2.5), 180 },
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
