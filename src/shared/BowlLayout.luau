--!strict
-- "Junkyard Bowl": the round battle map (docs/BOWL_MAP_SPEC.md). Pure data and maths, no Roblox
-- objects, so the tests can check every number. The server builds it in BowlMap.
--
-- Arena-local studs: the middle is (0, 0), x runs east, z runs south, y up; the floor top is
-- y = 0. A flat round floor (radius 92) is ringed by a gentle 10 degree slope that climbs 5.2
-- studs over 28 studs, and a wall of stacked tires closes the bowl on top of it. In the middle
-- stands the crusher: a solid round base you drive round, with a press above it that slams now and
-- then (a warning first) and sends a shock ring out over the floor. The two starts sit at the ends
-- of a straight clear lane south of the crusher, so the cars charge head-on at GO. Junk (barrels,
-- crates, cones, signs, fences) lies in dirt patches; the red barrels explode. Cars are about 16
-- studs long and 8 wide and cruise at 42 studs/s.

local Layout = {}

Layout.floorRadius = 92 -- the flat round floor
Layout.slopeRun = 28 -- the slope ring around it, this wide ...
Layout.slopeRise = 5.2 -- ... and this much higher at the outer edge (10.5 degrees)
Layout.rimRadius = Layout.floorRadius + Layout.slopeRun -- top of the slope
Layout.wallRadius = Layout.rimRadius + 1 -- inner face of the tire wall
Layout.wallThickness = 4
Layout.wallAboveRim = 9.2 -- the tire wall stands this high above the top of the slope
Layout.wallBounce = 1 -- elasticity of everything a car bounces off (carter M18: bigger bounce)
Layout.groundRadius = 136 -- the solid floor disc runs out under the slope and the tire wall
Layout.groundSize = 516 -- slots are 520 apart, so neighbours never overlap -- the grass plate under and round everything
Layout.facetCount = 32 -- wedges that make the slope ring
Layout.yardRadius = 250 -- the yard outside the tire wall is level with the slope's top out to here
Layout.wallCount = 32 -- boxes that make the invisible solid wall the tire stacks touch

Layout.colors = {
	floor = { 88, 82, 88 }, -- old warm asphalt (sunset light renders tops brighter)
	floorPatch = { { 74, 70, 76 }, { 104, 92, 84 }, { 66, 60, 62 } }, -- worn spots, oil, packed dirt
	dirt = { 128, 98, 68 }, -- the junk patches
	dirtDark = { 112, 84, 58 },
	slope = { 152, 128, 92 }, -- the sloped edge, warm sand
	slopeAlt = { 140, 118, 84 },
	line = { 244, 246, 240 },
	orange = { 196, 98, 42 }, -- rusty orange
	blue = { 37, 141, 221 },
	red = { 214, 58, 52 },
	yellow = { 186, 146, 60 }, -- worn hazard yellow
	ink = { 36, 39, 43 },
	tire = { 46, 48, 58 },
	tireAlt = { 60, 62, 74 },
	hub = { 198, 204, 216 },
	grass = { 96, 78, 64 }, -- the yard round the bowl: packed dusty dirt
	warn = { 255, 70, 50 }, -- the crusher's warning
	-- low-poly sunset junk (carter, 2026-10-20): rust, faded paint, steel. Red is left out on
	-- purpose: red barrels are the ones that explode.
	rainbow = {
		{ 168, 92, 54 }, -- rust
		{ 200, 160, 72 }, -- faded yellow
		{ 74, 122, 118 }, -- faded teal
		{ 84, 102, 132 }, -- steel blue
		{ 112, 82, 140 }, -- dusk purple
		{ 120, 118, 78 }, -- olive
		{ 186, 176, 156 }, -- dirty white
	},
	-- the far city against the sunset: dark purple blocks, warm lit windows
	city = { { 58, 44, 84 }, { 72, 52, 98 }, { 48, 40, 72 }, { 86, 60, 104 } },
	window = { 255, 186, 96 },
} :: { [string]: any }

-- The tire wall: stacks of two big tires on top of the slope, all the way round.
-- gap < 0: neighbours overlap a little, so no light shows between the stacks (Studio saw a plain dark
-- wall where the tires should be; the tires now stand in view, the solid wall behind them is invisible)
Layout.tire = { diameter = 13, height = 4.6, gap = -0.3 }

-- The two starts sit on one line (z = laneZ), facing each other. Nothing stands within `laneClear`
-- of the line between them.
Layout.laneZ = 42
Layout.laneHalf = 8 -- the lane itself (a car is 8 wide)
Layout.laneClear = 16 -- no prop closer than this to the line
Layout.spawnX = 64
Layout.pad = { sx = 22, sz = 14 } -- start pad: sx along the heading, sz across

-- The crusher in the middle. A solid base to drive round; the press above it is look-only.
Layout.crusher = {
	baseRadius = 11,
	baseHeight = 6.5,
	headRadius = 12,
	headThick = 4,
	columnRadius = 4,
	columnHeight = 20,
	restLift = 15, -- bottom of the press head, hanging at rest
	warnLift = 19, -- ... lifting to here while it warns
	slamLift = 6.6, -- ... and landing here (just above the base top)
	shockRadius = 27, -- how far the shock ring reaches over the floor
	first = 8, -- seconds after GO until the first slam
	period = 12, -- seconds from one slam to the next
	warn = 1.8, -- the warning (flashing lights, red floor) lasts this long and ends at the slam
	drop = 0.14, -- seconds the press takes to fall
	wave = 0.45, -- seconds the shock ring takes to reach full size
	lift = 1.2, -- seconds to lift back up after the wave
	damageFrac = 0.08, -- of max HP, per slam a car is caught by (a plain full-speed crash is 20%)
	knockSpeed = 36,
	stagger = 0.7,
}

-- A red barrel's explosion: small damage, a big push.
Layout.boom = {
	radius = 24, -- cars this close to the barrel are caught
	damageFrac = 0.05,
	knockSpeed = 46,
	stagger = 0.85,
}

export type Facet = {
	name: string,
	x: number, -- middle of the footprint
	z: number,
	dx: number, -- unit direction the wedge rises toward (straight out from the middle)
	dz: number,
	length: number,
	width: number,
	height: number,
	alt: boolean,
}

-- The slope ring: wedges side by side, each rising straight out. Wide enough at the outer end that
-- neighbours meet there and overlap further in (the thin inner ends sit on the floor).
function Layout.facets(): { Facet }
	local list: { Facet } = {}
	local n = Layout.facetCount
	local r0 = Layout.floorRadius
	local r1 = Layout.rimRadius + 0.8
	local length = r1 - r0
	local height = Layout.slopeRise * length / Layout.slopeRun
	local width = 2 * r1 * math.tan(math.pi / n)
	local mid = (r0 + r1) / 2
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		local dx, dz = math.cos(a), math.sin(a)
		table.insert(list, {
			name = "Slope" .. i,
			x = dx * mid,
			z = dz * mid,
			dx = dx,
			dz = dz,
			length = length,
			width = width,
			height = height,
			alt = i % 2 == 0,
		})
	end
	return list
end

export type WallSeg = {
	name: string,
	x: number, -- middle of the box
	z: number,
	nx: number, -- unit vector pointing to the middle of the bowl (the inner face looks this way)
	nz: number,
	length: number,
	thickness: number,
}

-- The solid wall (what a car really bounces off): boxes round the circle. They are invisible; the
-- tire stacks that touch their inner face are what a player sees.
function Layout.wallSegments(): { WallSeg }
	local list: { WallSeg } = {}
	local n = Layout.wallCount
	local t = Layout.wallThickness
	local length = 2 * Layout.wallRadius * math.tan(math.pi / n) + 1.2
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		local ox, oz = math.cos(a), math.sin(a)
		local r = Layout.wallRadius + t / 2
		table.insert(list, {
			name = "Wall" .. i,
			x = ox * r,
			z = oz * r,
			nx = -ox,
			nz = -oz,
			length = length,
			thickness = t,
		})
	end
	return list
end

export type Tire = { x: number, z: number, angle: number, index: number }

-- Where the tire stacks stand: round the wall, just touching it, shoulder to shoulder.
function Layout.tires(): { Tire }
	local list: { Tire } = {}
	local T = Layout.tire
	local r = Layout.wallRadius + T.diameter / 2
	local n = math.floor(2 * math.pi * r / (T.diameter + T.gap))
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		table.insert(list, { x = math.cos(a) * r, z = math.sin(a) * r, angle = a, index = i })
	end
	return list
end

function Layout.spawn(side: string): (number, number, number, number)
	if side == "a" then
		return -Layout.spawnX, Layout.laneZ, 1, 0
	end
	return Layout.spawnX, Layout.laneZ, -1, 0
end

-- White dashes down the middle of the lane, between the two start pads.
function Layout.laneDashes(): { { x: number, z: number, length: number } }
	local list = {}
	local x = -Layout.spawnX + Layout.pad.sx / 2 + 10
	local last = Layout.spawnX - Layout.pad.sx / 2 - 10
	while x <= last do
		table.insert(list, { x = x, z = Layout.laneZ, length = 6 })
		x += 12
	end
	return list
end

export type Kicker = {
	name: string,
	x: number,
	z: number,
	length: number, -- along x: both slopes together
	width: number, -- along z
	height: number, -- of the ridge
}

-- Two small humps, one each side of the middle, with kerbs along their flanks. Cars cross them
-- going east-west; fewer and lower than Wreck City's five ramps, no big jump.
function Layout.kickers(): { Kicker }
	return {
		{ name = "KickerW", x = -44, z = 12, length = 24, width = 18, height = 2.8 },
		{ name = "KickerE", x = 44, z = 12, length = 24, width = 18, height = 2.8 },
	}
end

-- Junk areas: round dirt patches that props lie in, mirrored left and right, with one on the axis.
export type Patch = { name: string, x: number, z: number, radius: number, rot: number }

function Layout.patches(): { Patch }
	return {
		{ name = "PatchNW", x = -44, z = -48, radius = 24, rot = 0 },
		{ name = "PatchNE", x = 44, z = -48, radius = 24, rot = 0 },
		{ name = "PatchW", x = -60, z = -22, radius = 16, rot = 0 },
		{ name = "PatchE", x = 60, z = -22, radius = 16, rot = 0 },
		{ name = "PatchSW", x = -30, z = 66, radius = 14, rot = 0 },
		{ name = "PatchSE", x = 30, z = 66, radius = 14, rot = 0 },
		{ name = "PatchN", x = 0, z = -62, radius = 14, rot = 0 },
	}
end

Layout.propMinRadius = 34 -- keep the crusher's surroundings open
Layout.propMaxRadius = 80 -- and a car's width of floor between the props and the slope
Layout.propSpacing = 8.6 -- middle to middle
Layout.boomSpacing = 14 -- red barrels stay this far from each other

-- Is the flat spot (x, z) clear of everything big, with `margin` studs to spare? Props are placed
-- with it and the tests check every one.
function Layout.clear(x: number, z: number, margin: number): boolean
	local r = math.sqrt(x * x + z * z)
	if r < Layout.propMinRadius + margin or r > Layout.propMaxRadius - margin then
		return false
	end
	-- the lane between the starts, and the pads at its ends
	local reach = Layout.spawnX + Layout.pad.sx / 2 + 6
	if math.abs(z - Layout.laneZ) < Layout.laneClear + margin and math.abs(x) < reach then
		return false
	end
	for _, k in Layout.kickers() do
		-- the hump and its kerbs (a little wider than the hump)
		if
			math.abs(x - k.x) < k.length / 2 + 4 + margin
			and math.abs(z - k.z) < k.width / 2 + 5 + margin
		then
			return false
		end
	end
	return true
end

export type Prop = {
	kind: string, -- barrel | boom | crate | cone | sign | fence
	x: number,
	z: number,
	yawDeg: number,
	variant: number, -- colour / sign picture / fence length
	patch: string,
}

-- What each patch holds, per side (the mirror patch gets the same): { patch, kind, count }.
-- Totals over both sides: 8 boom + 18 barrel + 26 crate + 8 cone + 5 sign + 6 fence = 71 (the
-- same as Wreck City). Crates and barrels, red ones too, are 52 of the 71: they break most.
local PLAN: { { any } } = {
	{ "NW", "boom", 1 },
	{ "NW", "barrel", 5 },
	{ "NW", "crate", 7 },
	{ "NW", "cone", 2 },
	{ "NW", "sign", 1 },
	{ "NW", "fence", 2 },
	{ "W", "boom", 1 },
	{ "W", "barrel", 2 },
	{ "W", "crate", 3 },
	{ "W", "cone", 2 },
	{ "W", "sign", 1 },
	{ "W", "fence", 1 },
	{ "SW", "boom", 1 },
	{ "SW", "barrel", 1 },
	{ "SW", "crate", 2 },
	{ "N", "boom", 1 },
	{ "N", "barrel", 1 },
	{ "N", "crate", 1 },
}
-- the one prop on the axis
local AXIS_SIGN = { x = 0, z = -62 }
-- the patch a mirrored prop lands in
local MIRROR: { [string]: string } = { NW = "NE", W = "E", SW = "SE", N = "N" }

local cached: { Prop }? = nil

-- Breakable props, laid out the same way every time (a small LCG), mirrored left and right so
-- neither start has the better side. Red ("boom") barrels are placed first, in the best spots.
function Layout.breakables(): { Prop }
	if cached then
		return cached
	end
	local seed = 20261021
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local patches: { [string]: Patch } = {}
	for _, p in Layout.patches() do
		patches[string.sub(p.name, 6)] = p
	end
	-- the left half (and the middle patch): every prop is mirrored afterwards
	local list: { Prop } = {
		{ kind = "sign", x = AXIS_SIGN.x, z = AXIS_SIGN.z, yawDeg = 0, variant = 1, patch = "N" },
	}
	local function farEnough(x: number, z: number, kind: string): boolean
		if 4 * x * x < Layout.propSpacing ^ 2 then
			return false -- too near the axis: it would sit on its own mirror image
		end
		for _, o in list do
			local need = Layout.propSpacing
			if kind == "boom" and o.kind == "boom" then
				need = Layout.boomSpacing
			end
			if (o.x - x) ^ 2 + (o.z - z) ^ 2 < need * need then
				return false
			end
			-- the mirror image of a candidate must not crowd the real thing either
			if (o.x + x) ^ 2 + (o.z - z) ^ 2 < need * need then
				return false
			end
		end
		return true
	end
	local variantCount: { [string]: number } =
		{ boom = 1, barrel = 7, crate = 7, cone = 1, sign = 4, fence = 1 }
	-- the kinds in a fixed order: boom first, then the rest
	for _, kind in { "boom", "barrel", "crate", "cone", "sign", "fence" } do
		for _, row in PLAN do
			if row[2] ~= kind then
				continue
			end
			local patch = patches[row[1]]
			for _ = 1, row[3] do
				local placed = false
				for _ = 1, 800 do
					local a = rnd() * 2 * math.pi
					local d = math.sqrt(rnd()) * patch.radius * 1.35 -- junk spills a little past the dirt
					local x = patch.x + math.cos(a) * d
					local z = patch.z + math.sin(a) * d
					local yaw = if kind == "fence" then math.floor(rnd() * 12) * 15 else rnd() * 360
					local variant = 1 + math.floor(rnd() * variantCount[kind])
					local ok = Layout.clear(x, z, 0) and farEnough(x, z, kind)
					if ok and kind == "fence" then
						-- a fence is 12 long: both ends must be clear as well
						local ca, sa = math.cos(math.rad(yaw)), -math.sin(math.rad(yaw))
						for _, e in { -6, 6 } do
							ok = ok and Layout.clear(x + ca * e, z + sa * e, 0)
						end
					end
					if ok then
						table.insert(list, {
							kind = kind,
							x = x,
							z = z,
							yawDeg = yaw,
							variant = variant,
							patch = row[1],
						})
						placed = true
						break
					end
				end
				if not placed then
					error("cannot place " .. kind .. " in patch " .. row[1])
				end
			end
		end
	end
	local out: { Prop } = {}
	for _, p in list do
		table.insert(out, p)
		if math.abs(p.x) > 0.01 then
			table.insert(out, {
				kind = p.kind,
				x = -p.x,
				z = p.z,
				yawDeg = -p.yawDeg,
				variant = p.variant,
				patch = MIRROR[p.patch] or p.patch,
			})
		end
	end
	cached = out
	return out
end

-- Where a car can be put back when it is stuck or has fallen: on open floor, facing along the
-- circle. Twelve spots round the middle of the floor.
function Layout.rescuePoints(): { { x: number, z: number, fx: number, fz: number } }
	local list = {}
	local r = 68
	for k = 0, 11 do
		local a = math.rad(30 * k)
		table.insert(list, {
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			fx = -math.sin(a),
			fz = math.cos(a),
		})
	end
	return list
end

-- Round obstacles for the bots: the crusher's base.
function Layout.circles(): { { x: number, z: number, r: number } }
	return { { x = 0, z = 0, r = Layout.crusher.baseRadius } }
end

-- ---------------------------------------------------------------------------------------------
-- The crusher's clock. `since` is seconds since GO (the round start); before that, or when the
-- round is over, the press just hangs. Server and every client use this same function, so the
-- press falls in the same moment on every screen.
-- phase: idle | warn | drop | wave | lift | rest; `u` runs 0..1 through the phase; `index` counts
-- the slams (0 = the first).

export type CrusherState = { phase: string, u: number, index: number }

function Layout.crusherState(since: number): CrusherState
	local C = Layout.crusher
	local start = C.first - C.warn
	if since < start then
		return { phase = "idle", u = 0, index = 0 }
	end
	local index = math.floor((since - start) / C.period)
	local t = (since - start) - index * C.period
	if t < C.warn then
		return { phase = "warn", u = t / C.warn, index = index }
	end
	t -= C.warn
	if t < C.drop then
		return { phase = "drop", u = t / C.drop, index = index }
	end
	t -= C.drop
	if t < C.wave then
		return { phase = "wave", u = t / C.wave, index = index }
	end
	t -= C.wave
	if t < C.lift then
		return { phase = "lift", u = t / C.lift, index = index }
	end
	return { phase = "rest", u = 0, index = index }
end

-- Bottom of the press head above the floor.
function Layout.crusherLift(state: CrusherState): number
	local C = Layout.crusher
	local p, u = state.phase, state.u
	if p == "warn" then
		return C.restLift + (C.warnLift - C.restLift) * math.sin(u * math.pi / 2)
	elseif p == "drop" then
		return C.warnLift + (C.slamLift - C.warnLift) * u * u
	elseif p == "wave" then
		return C.slamLift
	elseif p == "lift" then
		return C.slamLift + (C.restLift - C.slamLift) * u * u * (3 - 2 * u)
	end
	return C.restLift
end

-- How far the shock ring has spread (0 when there is no ring): the cars it has reached are hit.
function Layout.shockFront(state: CrusherState): number
	local C = Layout.crusher
	if state.phase ~= "wave" then
		return 0
	end
	return C.baseRadius + (C.shockRadius - C.baseRadius) * math.sqrt(state.u)
end

return Layout
