--!strict
-- "Wreck City": the chase map, built from ChaseMapLayout (see docs/CHASE_MAP_SPEC.md). Props and
-- landmark models come from ChaseProps and ChaseLandmarks. This file lays the ground, roads, deck,
-- ramps and walls, places everything, and runs the two live parts of the map:
--   * breakables (barrels, cones, crates, signs, fences) burst into flying pieces when a car drives
--     into them (no damage, no slowdown worth mentioning);
--   * the wrecking-ball crane hurts any car its ball touches. The crane's swing is drawn by every
--     client from the server clock (MapFx), so the server only has to know where the ball is.
-- Only floor, walls, barriers, the deck, ramps, buildings and the crane base collide. Everything
-- else is look-only. Parts tagged "Bouncy" throw a car back (BattleCar.wallBounce).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.ChaseMapLayout)
local MapParts = require(script.Parent.MapParts)
local ChaseProps = require(script.Parent.ChaseProps)
local ChaseLandmarks = require(script.Parent.ChaseLandmarks)

local rgb, part, can, group = MapParts.rgb, MapParts.part, MapParts.can, MapParts.group
local C = Layout.colors

export type Hit = { side: string, dir: Vector3 } -- a car the crane hit, and the way it is thrown

export type Controls = {
	openDoors: () -> (),
	closeDoors: () -> (),
	setNames: (a: string, b: string) -> (),
	setTeams: (aIsRed: boolean) -> (),
	-- once per fight frame: breakables burst, the crane hits. `bodies` is each side's car body.
	tick: (dt: number, bodies: { [string]: BasePart }) -> { Hit },
	-- the nearest road spot (world position, facing) to put a stuck or fallen car back
	rescuePoint: (pos: Vector3) -> (Vector3, Vector3),
	resetBreakables: () -> (), -- smashed props come back (new round)
	verify: () -> (), -- call once the map is in the workspace: checks every ramp rises
}

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Walls, barriers and blocks throw a car back; their bounce wins over the car's (weight 100).
local function bouncy(p: BasePart)
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, Layout.wallBounce, 1, 100)
	CollectionService:AddTag(p, "Bouncy")
end

-- Every part named "Core" in a model is its collider: solid and bouncy.
local function harden(model: Instance, solids: { Instance })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Core" or d.Name == "Column") then
			bouncy(d)
			table.insert(solids, d)
		end
	end
end

-- A flat look-only slab lying on the ground.
local function paint(
	parent: Instance,
	origin: Vector3,
	name: string,
	x: number,
	z: number,
	sx: number,
	sz: number,
	color: Color3,
	lift: number?,
	yawDeg: number?
): Part
	return part(
		parent,
		name,
		Vector3.new(sx, 0.1, sz),
		CFrame.new(origin + Vector3.new(x, lift or 0.05, z)) * yaw(yawDeg or 0),
		color,
		false
	)
end

local function ground(folder: Folder, origin: Vector3, solids: { Instance })
	local g = group(folder, "Ground")
	local size = Layout.halfX * 2 + 8
	part(
		g,
		"Floor",
		Vector3.new(size, 2, size),
		CFrame.new(origin + Vector3.new(0, -1, 0)),
		rgb(C.plaza),
		true,
		solids
	)
	part(
		g,
		"Grass",
		Vector3.new(Layout.groundSize, 1, Layout.groundSize),
		CFrame.new(origin + Vector3.new(0, -1.6, 0)),
		rgb(C.grass),
		false
	)
	-- the ring road: four light strips, orange and blue edge lines, white dashes down the middle
	local road = group(g, "Road")
	local h, ri = Layout.halfX, Layout.ringInner
	local w = h - ri
	local mid = (h + ri) / 2
	local long = h * 2
	paint(road, origin, "RoadN", 0, -mid, long, w, rgb(C.road))
	paint(road, origin, "RoadS", 0, mid, long, w, rgb(C.road))
	paint(road, origin, "RoadW", -mid, 0, w, ri * 2, rgb(C.road))
	paint(road, origin, "RoadE", mid, 0, w, ri * 2, rgb(C.road))
	local blue, orange, white = rgb(C.roadEdgeB), rgb(C.roadEdgeA), rgb(C.line)
	for _, s in { -1, 1 } do
		paint(road, origin, "EdgeOutN", 0, s * (h - 1.2), long - 4, 1.2, orange, 0.08)
		paint(road, origin, "EdgeOutE", s * (h - 1.2), 0, 1.2, long - 4, orange, 0.08)
	end
	-- a blue line along the road side of every barrier piece
	for _, b in Layout.barriers() do
		local side = string.sub(b.name, 8, 8)
		local out = 4
		local x = b.x + (if side == "E" then out elseif side == "W" then -out else 0)
		local z = b.z + (if side == "S" then out elseif side == "N" then -out else 0)
		local across = side == "N" or side == "S"
		paint(
			road,
			origin,
			"EdgeIn",
			x,
			z,
			if across then b.length else 1.2,
			if across then 1.2 else b.length,
			blue,
			0.08
		)
	end
	-- dashed middle line
	for _, s in { -1, 1 } do
		local x = -h + 20
		while x < h - 20 do
			paint(road, origin, "Dash", x + 5, s * mid, 10, 0.9, white, 0.09)
			x += 20
		end
		local z = -ri + 6
		while z < ri - 6 do
			paint(road, origin, "Dash", s * mid, z + 5, 0.9, 10, white, 0.09, 0)
			z += 20
		end
	end
	-- plaza roads: to every ramp, through the tunnel, and the hidden dirt road
	local dark = rgb(C.road)
	paint(
		road,
		origin,
		"RoadRampN",
		0,
		-(ri + Layout.deck.half) / 2,
		40,
		ri - Layout.deck.half,
		dark
	)
	paint(
		road,
		origin,
		"RoadRampS",
		0,
		(ri + Layout.deck.half) / 2,
		40,
		ri - Layout.deck.half,
		dark
	)
	paint(
		road,
		origin,
		"RoadRampW",
		-(ri + Layout.deck.half) / 2,
		-40,
		ri - Layout.deck.half,
		28,
		dark
	)
	paint(
		road,
		origin,
		"RoadRampE",
		(ri + Layout.deck.half) / 2,
		40,
		ri - Layout.deck.half,
		28,
		dark
	)
	paint(road, origin, "Tunnel", 0, 0, ri * 2, Layout.tunnel.halfWidth * 2, dark, 0.06)
	local sp = Layout.secretPath
	paint(
		g,
		origin,
		"SecretPath",
		sp.x,
		(sp.z0 + sp.z1) / 2,
		sp.width,
		sp.z1 - sp.z0,
		rgb(C.dirt),
		0.06
	)
	-- the two start pads
	for side, color in { a = C.roadEdgeA, b = C.roadEdgeB } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.08, z)
		local pad = part(
			folder,
			"Spawn" .. string.upper(side),
			Vector3.new(Layout.pad.sz, 0.12, Layout.pad.sx),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz)),
			rgb(color),
			false
		)
		pad.Transparency = 0.15
		part(
			g,
			"StartLine" .. side,
			Vector3.new(Layout.pad.sz, 0.1, 1.2),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
				* CFrame.new(0, 0.02, -Layout.pad.sx / 2),
			white,
			false
		)
	end
end

-- Outer walls: a car-height box with orange and blue panels and a glowing light strip.
local function walls(folder: Folder, origin: Vector3, solids: { Instance })
	local grp = group(folder, "Walls")
	local t, hgt = Layout.wallThickness, Layout.wallHeight
	for _, w in Layout.walls() do
		local a = math.rad(w.yawDeg)
		local zAxis = Vector3.new(math.sin(a), 0, math.cos(a))
		local s = if zAxis.X * w.nx + zAxis.Z * w.nz > 0 then 1 else -1 -- which local side faces in
		local center = origin + Vector3.new(w.x - w.nx * t / 2, hgt / 2, w.z - w.nz * t / 2)
		local base = CFrame.new(center) * yaw(w.yawDeg)
		local body =
			part(grp, w.name, Vector3.new(w.length, hgt, t), base, rgb(C.wall), true, solids)
		bouncy(body)
		part(
			grp,
			"Cap",
			Vector3.new(w.length + 0.4, 0.8, t + 0.8),
			base * CFrame.new(0, hgt / 2 + 0.2, 0),
			Color3.fromRGB(226, 232, 242),
			false
		)
		local modules = math.max(1, math.floor(w.length / 12))
		local len = w.length / modules
		for i = 1, modules do
			local u = -w.length / 2 + (i - 0.5) * len
			local on = i % 2 == 0
			part(
				grp,
				"Panel",
				Vector3.new(len - 0.5, hgt - 2.2, 0.3),
				base * CFrame.new(u, -0.3, s * (t / 2 + 0.15)),
				rgb(if on then C.orange else C.blue),
				false
			)
			if i % 2 == 1 then
				part(
					grp,
					"Light",
					Vector3.new(len * 0.5, 0.7, 0.2),
					base * CFrame.new(u, 1.7, s * (t / 2 + 0.4)),
					rgb(C.light),
					false,
					nil,
					Enum.Material.Neon
				)
			end
		end
	end
end

-- A wedge ramp that rises toward (dx, dz). Which face of a wedge is the tall one is checked after
-- the map is in the workspace (see verifyRamps), so a wrong guess cannot ship a ramp that drops.
local function ramps(folder: Folder, origin: Vector3, solids: { Instance }): { WedgePart }
	local grp = group(folder, "Ramps")
	local list: { WedgePart } = {}
	for _, r in Layout.ramps() do
		local w = Instance.new("WedgePart")
		w.Name = r.name
		w.Anchored = true
		-- local X is across, Y is the rise, Z is along the ramp
		w.Size = Vector3.new(r.width, r.height, r.length)
		local center = origin + Vector3.new(r.x, r.height / 2, r.z)
		w.CFrame = CFrame.lookAt(center, center - Vector3.new(r.dx, 0, r.dz))
		w.Color = rgb(C.ramp)
		w.Material = Enum.Material.SmoothPlastic
		w.TopSurface = Enum.SurfaceType.Smooth
		w.BottomSurface = Enum.SurfaceType.Smooth
		w:SetAttribute("RiseX", r.dx)
		w:SetAttribute("RiseZ", r.dz)
		w.Parent = grp
		table.insert(solids, w)
		table.insert(list, w)
		-- painted chevrons and edge stripes on the slope
		local surfaceMid = origin + Vector3.new(r.x, r.height / 2 + 0.1, r.z)
		local up = Vector3.new(r.dx * r.length, r.height, r.dz * r.length).Unit
		ChaseLandmarks.rampDressing(
			grp,
			CFrame.lookAt(surfaceMid, surfaceMid + up),
			r.width,
			math.sqrt(r.length * r.length + r.height * r.height),
			r.height
		)
	end
	return list
end

-- Casts a ray down near the low end and the high end of every ramp; flips one that drops.
local function verifyRamps(list: { WedgePart }, origin: Vector3)
	for i, r in Layout.ramps() do
		local w = list[i]
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { w }
		local function top(along: number): number?
			local p = origin
				+ Vector3.new(
					r.x + r.dx * along * r.length / 2,
					r.height + 6,
					r.z + r.dz * along * r.length / 2
				)
			local hit = workspace:Raycast(p, Vector3.new(0, -(r.height + 12), 0), params)
			return if hit then hit.Position.Y else nil
		end
		local low, high = top(-0.8), top(0.8)
		if low and high and low > high then
			w.CFrame = w.CFrame * CFrame.Angles(0, math.pi, 0)
		end
	end
end

-- The raised deck: a flat roof on two solid side blocks with a tunnel left open between them.
local function deck(folder: Folder, origin: Vector3, solids: { Instance })
	local grp = group(folder, "Deck")
	local d = Layout.deck
	local roof = part(
		grp,
		"DeckTop",
		Vector3.new(d.half * 2, d.thick, d.half * 2),
		CFrame.new(origin + Vector3.new(0, d.top - d.thick / 2, 0)),
		rgb(C.deck),
		true,
		solids
	)
	CollectionService:AddTag(roof, "ChaseDeck") -- the client fades it while the camera is in the tunnel
	local tw = Layout.tunnel.halfWidth
	local side = d.half - tw
	for _, s in { -1, 1 } do
		local block = part(
			grp,
			"TunnelWall",
			Vector3.new(d.half * 2, Layout.tunnel.clear, side),
			CFrame.new(origin + Vector3.new(0, Layout.tunnel.clear / 2, s * (tw + side / 2))),
			rgb(C.tunnel),
			true,
			solids
		)
		bouncy(block)
	end
	-- painted top: border, a cross and a ring
	local orange = rgb(C.deckStripe)
	local y = d.top + 0.06
	for _, s in { -1, 1 } do
		paint(grp, origin, "Border", 0, s * (d.half - 2.5), d.half * 2 - 2, 1.4, orange, y)
		paint(grp, origin, "Border", s * (d.half - 2.5), 0, 1.4, d.half * 2 - 2, orange, y)
	end
	paint(grp, origin, "Cross", 0, 0, d.half * 2 - 16, 3, rgb(C.line), y)
	paint(grp, origin, "Cross", 0, 0, 3, d.half * 2 - 16, rgb(C.line), y)
	can(grp, "Ring", 30, 0.1, origin + Vector3.new(0, d.top, 0), rgb(C.line), false)
	can(grp, "RingFill", 26, 0.12, origin + Vector3.new(0, d.top, 0), rgb(C.deck), false)
	-- tunnel ceiling lights
	for _, z in { -8, 8 } do
		part(
			grp,
			"TunnelLight",
			Vector3.new(d.half * 2 - 6, 0.5, 1.6),
			CFrame.new(origin + Vector3.new(0, Layout.tunnel.clear - 0.4, z)),
			rgb(C.light),
			false,
			nil,
			Enum.Material.Neon
		)
	end
	for _, s in { -1, 1 } do
		local pos = origin + Vector3.new(s * (d.half + 2), 0, 0)
		local portal = ChaseLandmarks.tunnelPortal(
			grp,
			CFrame.lookAt(pos, pos + Vector3.new(s, 0, 0)),
			tw * 2,
			Layout.tunnel.clear
		)
		harden(portal, solids)
	end
	for _, rl in Layout.rails() do
		local rail = ChaseLandmarks.deckRail(
			grp,
			CFrame.new(origin + Vector3.new(rl.x, d.top, rl.z)) * yaw(rl.yawDeg),
			rl.length
		)
		harden(rail, solids)
	end
end

local function barriers(folder: Folder, origin: Vector3, solids: { Instance })
	local grp = group(folder, "Barriers")
	for _, b in Layout.barriers() do
		local team = if (b.x + b.z) % 24 < 12 then "orange" else "blue"
		local m = ChaseLandmarks.jerseyBarrier(
			grp,
			CFrame.new(origin + Vector3.new(b.x, 0, b.z)) * yaw(b.yawDeg),
			b.length,
			team
		)
		harden(m, solids)
	end
end

local function buildings(folder: Folder, origin: Vector3, solids: { Instance })
	local grp = group(folder, "Buildings")
	for _, b in Layout.blockers() do
		local pos = origin + Vector3.new(b.x, 0, b.z)
		local m = ChaseProps.building(
			grp,
			CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)),
			b.w,
			b.d,
			b.h,
			b.palette
		)
		harden(m, solids)
	end
end

-- Look-only world round the map: trees, hills, lamps, billboards.
local function surroundings(folder: Folder, origin: Vector3)
	local far = group(folder, "FarScenery") -- cut this first if phones lag
	local near = group(folder, "Scenery")
	local seed = 7
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for i = 1, 36 do
		local a = rnd() * math.pi * 2
		local r = 175 + rnd() * 65
		local pos = origin + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r)
		ChaseProps.tree(
			far,
			CFrame.new(pos) * yaw(rnd() * 360),
			if i % 3 == 0 then "pine" else "round",
			1.4 + rnd() * 0.8
		)
	end
	for i = 1, 8 do
		local a = (i - 0.5) / 8 * math.pi * 2
		ChaseProps.hill(
			far,
			CFrame.new(origin + Vector3.new(math.cos(a) * 215, -1, math.sin(a) * 215)),
			34 + (i % 3) * 5,
			18 + (i % 2) * 6
		)
	end
	for _, p in { { -112, -112 }, { 112, 112 }, { -112, 112 }, { 112, -112 } } do
		ChaseProps.lampPost(near, CFrame.new(origin + Vector3.new(p[1], 0, p[2])))
	end
	for _, p in { { -64, -64 }, { 64, 64 }, { -64, 64 }, { 64, -64 } } do
		ChaseProps.lampPost(
			near,
			CFrame.lookAt(
				origin + Vector3.new(p[1], 0, p[2]),
				Vector3.new(origin.X + p[1] * 2, origin.Y, origin.Z + p[2] * 2)
			)
		)
	end
	ChaseLandmarks.billboard(
		near,
		CFrame.new(origin + Vector3.new(0, 0, -182)) * yaw(180),
		70,
		20,
		"WRECK CITY"
	)
	ChaseLandmarks.billboard(near, CFrame.new(origin + Vector3.new(0, 0, 182)), 70, 20, "SMASH IT!")
end

export type Breakable = {
	model: Model,
	body: BasePart,
	rebuild: () -> Model,
	broken: boolean,
}

local SIGN_KINDS = { "arrow", "stop", "diner", "wreck" }

-- Places every breakable prop and fence. Returns the live list.
local function breakables(folder: Folder, origin: Vector3): { Breakable }
	local grp = group(folder, "Breakables")
	local list: { Breakable } = {}
	local function add(make: () -> Model)
		local model = make()
		local body = model.PrimaryPart
		if body then
			table.insert(list, { model = model, body = body, rebuild = make, broken = false })
		end
	end
	for _, p in Layout.breakables() do
		local cf = CFrame.new(origin + Vector3.new(p.x, 0, p.z)) * yaw(p.yawDeg)
		if p.kind == "barrel" then
			add(function()
				return ChaseProps.barrel(grp, cf)
			end)
		elseif p.kind == "cone" then
			add(function()
				return ChaseProps.cone(grp, cf)
			end)
		elseif p.kind == "crate" then
			add(function()
				return ChaseProps.crateStack(grp, cf)
			end)
		else
			add(function()
				return ChaseProps.roadSign(grp, cf, SIGN_KINDS[p.variant] or "arrow")
			end)
		end
	end
	local function fence(f: Layout.Seg)
		add(function()
			return ChaseProps.fence(
				grp,
				CFrame.new(origin + Vector3.new(f.x, 0, f.z)) * yaw(f.yawDeg),
				f.length
			)
		end)
	end
	for _, f in Layout.fences() do
		fence(f)
	end
	fence(Layout.secretFence())
	return list
end

-- The pieces fly off the way the car was going, then vanish. They never collide: the car is still
-- overlapping them at the burst, and Studio saw one such overlap launch a car out of the arena.
local function burst(b: Breakable, carVel: Vector3)
	b.broken = true
	local flat = Vector3.new(carVel.X, 0, carVel.Z)
	for _, d in b.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false -- pieces overlap the car at the burst; colliding would shove it out of the arena
			d.CanTouch = false
			d.CanQuery = false
			d.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.3, 0.4, 1, 1)
			d.AssemblyLinearVelocity = flat * 0.7
				+ Vector3.new(
					math.random() * 16 - 8,
					14 + math.random() * 14,
					math.random() * 16 - 8
				)
			d.AssemblyAngularVelocity =
				Vector3.new(math.random() * 12 - 6, math.random() * 12 - 6, math.random() * 12 - 6)
		end
	end
	Debris:AddItem(b.model, 3)
end

local function sounds(folder: Folder, origin: Vector3)
	local grp = group(folder, "Sounds")
	for _, spec in
		{ { "Birds", Vector3.new(0, 30, 0), true }, { "GoHorn", Vector3.new(0, 20, 0), false } }
	do
		local p = part(
			grp,
			"Spot_" .. (spec[1] :: string),
			Vector3.new(1, 1, 1),
			CFrame.new(origin + (spec[2] :: Vector3)),
			Color3.new(1, 1, 1),
			false
		)
		p.Transparency = 1
		local s = Instance.new("Sound")
		s.Name = spec[1] :: string
		s.SoundId = ""
		s.Looped = spec[3] :: boolean
		s.Volume = 0.6
		s.RollOffMaxDistance = 260
		s.Parent = p
	end
end

local ChaseMap = {}

function ChaseMap.build(folder: Folder, origin: Vector3, solids: { Instance }): Controls
	ground(folder, origin, solids)
	walls(folder, origin, solids)
	local wedges = ramps(folder, origin, solids)
	deck(folder, origin, solids)
	barriers(folder, origin, solids)
	buildings(folder, origin, solids)
	surroundings(folder, origin)
	sounds(folder, origin)

	-- the crane: its swing is drawn on every client from the server clock (MapFx "MapCrane")
	local cr = Layout.crane
	local crane = ChaseLandmarks.crane(
		folder,
		CFrame.new(origin + Vector3.new(cr.x, 0, cr.z)) * CFrame.Angles(0, math.pi, 0),
		cr.armLength
	)
	harden(crane.model, solids)
	crane.model:SetAttribute("Amp", cr.amp)
	crane.model:SetAttribute("Period", cr.period)
	crane.model:SetAttribute("Phase", cr.phase)
	CollectionService:AddTag(crane.model, "MapCrane")

	local live = breakables(folder, origin)
	local byBody: { [Instance]: Breakable } = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local function refresh()
		local bodies: { Instance } = {}
		table.clear(byBody)
		for _, b in live do
			if not b.broken then
				byBody[b.body] = b
				table.insert(bodies, b.body)
			end
		end
		overlap.FilterDescendantsInstances = bodies
	end
	refresh()

	local nextHit: { [string]: number } = {}
	local Hz = Layout.hazard
	local ballWorld = Vector3.zero

	local controls: Controls
	controls = {
		openDoors = function() end,
		closeDoors = function() end,
		setNames = function(_a: string, _b: string) end,
		setTeams = function(_aIsRed: boolean) end,
		tick = function(_dt: number, bodies: { [string]: BasePart }): { Hit }
			local hits: { Hit } = {}
			local now = workspace:GetServerTimeNow()
			local bx, bz = Layout.ballPosition(Layout.craneAngle(now))
			ballWorld = origin + Vector3.new(bx, cr.ballRadius, bz)
			local changed = false
			for side, body in bodies do
				-- the crane
				local off = body.Position - ballWorld
				if
					off.Magnitude < cr.ballRadius + body.Size.Z * 0.45
					and now >= (nextHit[side] or 0)
				then
					nextHit[side] = now + Hz.cooldown
					local flat = Vector3.new(off.X, 0, off.Z)
					table.insert(hits, {
						side = side,
						dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0),
					})
				end
				-- breakables
				for _, p in workspace:GetPartsInPart(body, overlap) do
					local b = byBody[p]
					if b and not b.broken then
						burst(b, body.AssemblyLinearVelocity)
						changed = true
					end
				end
			end
			if changed then
				refresh()
			end
			return hits
		end,
		rescuePoint = function(pos: Vector3): (Vector3, Vector3)
			local lx, lz = pos.X - origin.X, pos.Z - origin.Z
			local points = Layout.rescuePoints()
			local best, bestD = points[1], math.huge
			for _, r in points do
				local d = (r.x - lx) ^ 2 + (r.z - lz) ^ 2
				if d < bestD then
					best, bestD = r, d
				end
			end
			return origin + Vector3.new(best.x, 1, best.z), Vector3.new(best.fx, 0, best.fz)
		end,
		verify = function() end,
		resetBreakables = function()
			for _, b in live do
				if b.broken then
					b.model = b.rebuild()
					b.body = b.model.PrimaryPart :: BasePart
					b.broken = false
				end
			end
			refresh()
		end,
	}

	controls.verify = function()
		verifyRamps(wedges, origin)
	end
	folder:SetAttribute("PartCount", #folder:GetDescendants())
	return controls
end

return ChaseMap
