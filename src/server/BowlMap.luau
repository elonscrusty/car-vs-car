--!strict
-- "Junkyard Bowl": the round battle map, built from BowlLayout (see docs/BOWL_MAP_SPEC.md). Props
-- come from BowlProps. This file lays the floor, the sloped edge, the tire wall, the two humps and
-- the crusher, places everything, and runs the live parts of the map:
--   * breakables (barrels, crates, cones, signs, fences) burst into flying pieces when a car drives
--     into them (no damage, no slowdown worth mentioning); a red barrel also explodes: small
--     damage and a big push to the cars close by;
--   * the crusher slams now and then, with a warning first, and its shock ring hurts the cars it
--     reaches. The press is drawn by every client from the server clock (MapFx, the RoundStart
--     attribute), so the server only has to know when the ring is out and who it caught.
-- Only the floor, the slope, the wall, the humps and the crusher's base collide. Everything else is
-- look-only. Parts tagged "Bouncy" throw a car back (BattleDrive.wallBounce); the slope wedges are
-- tagged "BowlSlope" so that sweep ignores them and sees the wall at the top.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.BowlLayout)
local MapParts = require(script.Parent.MapParts)
local BowlProps = require(script.Parent.BowlProps)

local rgb, part, can, group = MapParts.rgb, MapParts.part, MapParts.can, MapParts.group
local C = Layout.colors

-- A car something on the map hit, and how hard it is thrown.
export type Hit = {
	side: string,
	dir: Vector3, -- flat, away from the blast
	damageFrac: number, -- of the car's max HP
	knockSpeed: number,
	stagger: number,
	text: string, -- what the other player's screen says
}

export type Controls = {
	openDoors: () -> (), -- GO: the crusher's clock starts
	closeDoors: () -> (), -- the round is over / being set up: it rests
	setNames: (a: string, b: string) -> (),
	setTeams: (aIsRed: boolean) -> (),
	-- once per fight frame: breakables burst, red barrels explode, the crusher slams. `bodies` is
	-- each side's car body.
	tick: (dt: number, bodies: { [string]: BasePart }) -> { Hit },
	-- the nearest open spot (world position, facing) to put a stuck or fallen car back
	rescuePoint: (pos: Vector3) -> (Vector3, Vector3),
	resetBreakables: () -> (), -- smashed props come back (new round)
	verify: () -> (), -- call once the map is in the workspace: checks every wedge rises
}

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Walls, the crusher base and the humps' kerbs throw a car back; their bounce wins over the car's
-- (weight 100).
local function bouncy(p: BasePart)
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, Layout.wallBounce, 1, 100)
	CollectionService:AddTag(p, "Bouncy")
end

-- A flat look-only slab lying on the ground (its top is `top` above the floor).
local function paint(
	parent: Instance,
	origin: Vector3,
	name: string,
	x: number,
	z: number,
	sx: number,
	sz: number,
	color: Color3,
	top: number,
	yawDeg: number?
): Part
	return part(
		parent,
		name,
		Vector3.new(sx, 0.08, sz),
		CFrame.new(origin + Vector3.new(x, top - 0.04, z)) * yaw(yawDeg or 0),
		color,
		false
	)
end

-- A flat look-only round disc lying on the ground.
local function disc(
	parent: Instance,
	origin: Vector3,
	name: string,
	x: number,
	z: number,
	diameter: number,
	top: number,
	color: Color3,
	material: Enum.Material?
): Part
	return can(
		parent,
		name,
		diameter,
		0.08,
		origin + Vector3.new(x, top - 0.08, z),
		color,
		false,
		nil,
		material
	)
end

-- The wedges that make a slope, kept with where they stand so verify() can check each one rises.
type Rise = {
	wedge: WedgePart,
	x: number, -- middle of the footprint
	z: number,
	dx: number, -- the way it should rise
	dz: number,
	length: number,
	height: number,
}

local function wedge(
	parent: Instance,
	origin: Vector3,
	name: string,
	x: number,
	z: number,
	dx: number,
	dz: number,
	width: number,
	height: number,
	length: number,
	color: Color3,
	sink: number
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	-- local X is across, Y is the rise, Z is along the slope
	w.Size = Vector3.new(width, height, length)
	local center = origin + Vector3.new(x, height / 2 - sink, z)
	w.CFrame = CFrame.lookAt(center, center - Vector3.new(dx, 0, dz))
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w:SetAttribute("RiseX", dx)
	w:SetAttribute("RiseZ", dz)
	w.Parent = parent
	return w
end

-- ---------------------------------------------------------------------------------------------
-- Floor, paint, starts

local function ground(folder: Folder, origin: Vector3, solids: { Instance })
	local g = group(folder, "Ground")
	can(
		g,
		"Floor",
		Layout.groundRadius * 2,
		2,
		origin + Vector3.new(0, -2, 0),
		rgb(C.floor),
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
	-- the junk areas
	local dirt = group(g, "Dirt")
	for _, p in Layout.patches() do
		disc(dirt, origin, p.name, p.x, p.z, p.radius * 2, 0.06, rgb(C.dirt))
	end
	-- the lane between the starts: white dashes down the middle
	local white = rgb(C.line)
	local marks = group(g, "Marks")
	for _, d in Layout.laneDashes() do
		paint(marks, origin, "Dash", d.x, d.z, d.length, 0.9, white, 0.1)
	end
	-- the two start pads, orange and blue, with a white line across the front
	local pads: { { side: string, color: { number } } } = {
		{ side = "a", color = C.orange },
		{ side = "b", color = C.blue },
	}
	for _, pd in pads do
		local side, color = pd.side, pd.color
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.12, z)
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
			marks,
			"StartLine" .. side,
			Vector3.new(Layout.pad.sz, 0.1, 1.2),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
				* CFrame.new(0, 0.07, -Layout.pad.sx / 2 + 0.6),
			white,
			false
		)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The sloped edge and the tire wall

local function slope(folder: Folder, origin: Vector3, solids: { Instance }, rises: { Rise })
	local grp = group(folder, "Slope")
	for _, f in Layout.facets() do
		local w = wedge(
			grp,
			origin,
			f.name,
			f.x,
			f.z,
			f.dx,
			f.dz,
			f.width,
			f.height,
			f.length,
			rgb(if f.alt then C.slopeAlt else C.slope),
			0.05 -- sunk a hair so the thin toe never flickers against the floor
		)
		CollectionService:AddTag(w, "BowlSlope")
		table.insert(solids, w)
		table.insert(rises, {
			wedge = w,
			x = f.x,
			z = f.z,
			dx = f.dx,
			dz = f.dz,
			length = f.length,
			height = f.height,
		})
	end
end

local function wall(folder: Folder, origin: Vector3, solids: { Instance })
	local grp = group(folder, "Wall")
	local hgt = Layout.slopeRise + Layout.wallAboveRim
	-- the solid wall: dark, so the gaps between the tires read as shadow
	for _, w in Layout.wallSegments() do
		local center = origin + Vector3.new(w.x, hgt / 2, w.z)
		local p = part(
			grp,
			w.name,
			Vector3.new(w.length, hgt, w.thickness),
			CFrame.lookAt(center, Vector3.new(origin.X, center.Y, origin.Z)),
			rgb(C.wallBack),
			true,
			solids
		)
		bouncy(p)
	end
	-- the stacks: a dark tire under a bright toy-coloured one, a pale hub on top
	local tires = group(folder, "Tires")
	local hubs = group(folder, "Detail") -- cut on slow phones
	local T = Layout.tire
	local rainbow = C.rainbow :: { { number } }
	local base = Layout.slopeRise - 0.2
	for _, t in Layout.tires() do
		local pos = origin + Vector3.new(t.x, base, t.z)
		can(
			tires,
			"TireLow",
			T.diameter,
			T.height,
			pos,
			rgb(if t.index % 2 == 0 then C.tireAlt else C.tire),
			false
		)
		can(
			tires,
			"TireHigh",
			T.diameter,
			T.height,
			pos + Vector3.new(0, T.height, 0),
			rgb(rainbow[(t.index - 1) % #rainbow + 1]),
			false
		)
		can(
			hubs,
			"Hub",
			T.diameter * 0.48,
			0.16,
			pos + Vector3.new(0, T.height * 2, 0),
			rgb(C.hub),
			false
		)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The two humps: two wedges back to back, kerbs along the flanks

local function kickers(folder: Folder, origin: Vector3, solids: { Instance }, rises: { Rise })
	local grp = group(folder, "Humps")
	for _, k in Layout.kickers() do
		local half = k.length / 2
		for _, s in { -1, 1 } do
			-- each wedge rises toward the ridge in the middle
			local w = wedge(
				grp,
				origin,
				k.name .. (if s < 0 then "Up" else "Down"),
				k.x + s * half / 2,
				k.z,
				-s,
				0,
				k.width,
				k.height,
				half,
				rgb(C.yellow),
				0
			)
			table.insert(solids, w)
			table.insert(rises, {
				wedge = w,
				x = k.x + s * half / 2,
				z = k.z,
				dx = -s,
				dz = 0,
				length = half,
				height = k.height,
			})
		end
		-- kerbs: a car brushing the side of the hump is thrown back instead of catching its edge
		for _, s in { -1, 1 } do
			local kerb = part(
				grp,
				"Kerb",
				Vector3.new(k.length, k.height + 0.4, 1),
				CFrame.new(
					origin + Vector3.new(k.x, (k.height + 0.4) / 2, k.z + s * (k.width / 2 + 0.5))
				),
				rgb(C.orange),
				true,
				solids
			)
			bouncy(kerb)
		end
		paint(grp, origin, "Ridge", k.x, k.z, 0.9, k.width, rgb(C.ink), k.height + 0.02)
	end
end

-- Casts a ray down near the low end and the high end of every wedge; flips one that drops.
local function verifyWedges(rises: { Rise }, origin: Vector3)
	for _, r in rises do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { r.wedge }
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
		local low, high = top(-0.7), top(0.7)
		if low and high and low > high then
			r.wedge.CFrame = r.wedge.CFrame * CFrame.Angles(0, math.pi, 0)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The crusher

-- A solid yellow-and-black base to drive round, a tall column, and the press above it. The press,
-- its lamps, the warning disc and the shock ring are drawn by MapFx from the server clock.
local function crusher(folder: Folder, origin: Vector3, solids: { Instance }): Model
	local Cr = Layout.crusher
	local model = Instance.new("Model")
	model.Name = "Crusher"
	disc(model, origin, "RingA", 0, 0, Cr.baseRadius * 2 + 5, 0.1, rgb(C.yellow))
	local base =
		can(model, "Base", Cr.baseRadius * 2, Cr.baseHeight, origin, rgb(C.yellow), true, solids)
	bouncy(base)
	can(
		model,
		"BaseBand",
		Cr.baseRadius * 2 + 0.4,
		1.5,
		origin + Vector3.new(0, 2.4, 0),
		rgb(C.ink),
		false
	)
	can(
		model,
		"Column",
		Cr.columnRadius * 2,
		Cr.columnHeight,
		origin + Vector3.new(0, Cr.baseHeight, 0),
		rgb(C.orange),
		false
	)
	MapParts.ball(
		model,
		"Beacon",
		3.4,
		origin + Vector3.new(0, Cr.baseHeight + Cr.columnHeight + 1.2, 0),
		rgb(C.warn),
		false,
		nil,
		Enum.Material.Neon
	)
	-- the press at rest
	local headBottom = origin + Vector3.new(0, Cr.restLift, 0)
	can(model, "Head", Cr.headRadius * 2, Cr.headThick, headBottom, rgb(C.orange), false)
	can(model, "HeadTrim", Cr.headRadius * 2 + 0.5, 0.9, headBottom, rgb(C.ink), false)
	for i, s in { -1, 1 } do
		MapParts.ball(
			model,
			if i == 1 then "LampA" else "LampB",
			2.4,
			headBottom + Vector3.new(s * (Cr.headRadius - 1.4), Cr.headThick - 0.4, 0),
			rgb(C.warn),
			false,
			nil,
			Enum.Material.Neon
		)
	end
	-- the warning on the floor (red, shown only while it warns) and the shock ring (shown only
	-- while it spreads)
	local warn = disc(model, origin, "Warn", 0, 0, Cr.shockRadius * 2, 0.14, rgb(C.warn))
	warn.Transparency = 1
	local wave = disc(
		model,
		origin,
		"Wave",
		0,
		0,
		Cr.baseRadius * 2,
		0.2,
		Color3.fromRGB(255, 200, 120),
		Enum.Material.Neon
	)
	wave.Transparency = 1
	model.PrimaryPart = base
	model:SetAttribute("RoundStart", -1) -- server time of GO; -1 = resting
	CollectionService:AddTag(model, "BowlCrusher")
	model.Parent = folder
	return model
end

-- ---------------------------------------------------------------------------------------------
-- The world round the bowl: containers, trees, hills (all looks only, cut first on slow phones)

local function scenery(folder: Folder, origin: Vector3)
	local far = group(folder, "FarScenery")
	local seed = 11
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local rainbow = C.rainbow :: { { number } }
	-- a ring of bright shipping containers behind the tires, some stacked
	local count = 18
	for i = 1, count do
		local a = (i - 0.5) / count * 2 * math.pi
		local r = 156
		local pos = origin + Vector3.new(math.cos(a) * r, -1, math.sin(a) * r)
		-- the long side runs along the circle (the grass plate is a bit below the floor)
		local cf = CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z))
		BowlProps.container(far, cf, rgb(rainbow[(i * 3) % #rainbow + 1]))
		if i % 3 == 0 then
			BowlProps.container(
				far,
				cf * CFrame.new(0, 8.5, 0),
				rgb(rainbow[(i * 5 + 2) % #rainbow + 1])
			)
		end
	end
	for i = 1, 16 do
		local a = rnd() * math.pi * 2
		local r = 190 + rnd() * 50
		local pos = origin + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r)
		BowlProps.tree(
			far,
			CFrame.new(pos) * yaw(rnd() * 360),
			if i % 3 == 0 then "pine" else "round",
			1.4 + rnd() * 0.8
		)
	end
	for i = 1, 6 do
		local a = (i - 0.5) / 6 * math.pi * 2
		BowlProps.hill(
			far,
			CFrame.new(origin + Vector3.new(math.cos(a) * 232, -1, math.sin(a) * 232)),
			34 + (i % 3) * 5,
			18 + (i % 2) * 6
		)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Breakables

export type Breakable = {
	model: Model,
	body: BasePart,
	rebuild: () -> Model,
	broken: boolean,
	boom: boolean,
}

local SIGN_KINDS = { "arrow", "stop", "diner", "smash" }

-- Places every breakable prop and fence. Returns the live list.
local function breakables(folder: Folder, origin: Vector3): { Breakable }
	local grp = group(folder, "Breakables")
	local list: { Breakable } = {}
	local rainbow = C.rainbow :: { { number } }
	local function add(make: () -> Model, boom: boolean)
		local model = make()
		local body = model.PrimaryPart
		if body then
			table.insert(
				list,
				{ model = model, body = body, rebuild = make, broken = false, boom = boom }
			)
		end
	end
	local fences = 0
	for _, p in Layout.breakables() do
		local cf = CFrame.new(origin + Vector3.new(p.x, 0, p.z)) * yaw(p.yawDeg)
		local color = rgb(rainbow[(p.variant - 1) % #rainbow + 1])
		if p.kind == "boom" then
			add(function()
				return BowlProps.boomBarrel(grp, cf)
			end, true)
		elseif p.kind == "barrel" then
			add(function()
				return BowlProps.barrel(grp, cf, color)
			end, false)
		elseif p.kind == "crate" then
			add(function()
				return BowlProps.crate(grp, cf, color)
			end, false)
		elseif p.kind == "cone" then
			add(function()
				return BowlProps.cone(grp, cf)
			end, false)
		elseif p.kind == "fence" then
			fences += 1
			local railColor = rgb(rainbow[(fences * 2) % #rainbow + 1])
			add(function()
				return BowlProps.fence(grp, cf, 12, railColor)
			end, false)
		else
			add(function()
				return BowlProps.sign(grp, cf, SIGN_KINDS[p.variant] or "arrow")
			end, false)
		end
	end
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

-- The red barrel's boom: a fireball and a ring that spread and fade (looks only; the push and the
-- damage are the Hits tick() returns).
local function explosion(folder: Folder, pos: Vector3)
	local ball = MapParts.ball(
		folder,
		"BoomBall",
		5,
		pos + Vector3.new(0, 3, 0),
		Color3.fromRGB(255, 160, 40),
		false,
		nil,
		Enum.Material.Neon
	)
	ball.Transparency = 0.1
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local grow = Layout.boom.radius * 0.8
	TweenService:Create(ball, info, { Size = Vector3.new(grow, grow, grow), Transparency = 1 })
		:Play()
	local ring = can(
		folder,
		"BoomRing",
		6,
		0.3,
		pos + Vector3.new(0, 0.15, 0),
		Color3.fromRGB(255, 232, 170),
		false,
		nil,
		Enum.Material.Neon
	)
	ring.Transparency = 0.2
	TweenService:Create(ring, info, {
		Size = Vector3.new(0.3, Layout.boom.radius * 2, Layout.boom.radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.6)
	Debris:AddItem(ring, 0.6)
end

local function sounds(folder: Folder, origin: Vector3)
	local grp = group(folder, "Sounds")
	local spots: { { name: string, at: Vector3, loop: boolean } } = {
		{ name = "Birds", at = Vector3.new(0, 30, 0), loop = true },
		{ name = "GoHorn", at = Vector3.new(0, 20, 0), loop = false },
		{ name = "Slam", at = Vector3.new(0, 10, 0), loop = false },
		{ name = "Boom", at = Vector3.new(0, 10, 40), loop = false },
	}
	for _, spec in spots do
		local p = part(
			grp,
			"Spot_" .. spec.name,
			Vector3.new(1, 1, 1),
			CFrame.new(origin + spec.at),
			Color3.new(1, 1, 1),
			false
		)
		p.Transparency = 1
		local s = Instance.new("Sound")
		s.Name = spec.name
		s.SoundId = ""
		s.Looped = spec.loop
		s.Volume = 0.6
		s.RollOffMaxDistance = 260
		s.Parent = p
	end
end

local BowlMap = {}

local function countParts(folder: Instance): number
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

function BowlMap.build(folder: Folder, origin: Vector3, solids: { Instance }): Controls
	local rises: { Rise } = {}
	ground(folder, origin, solids)
	slope(folder, origin, solids, rises)
	wall(folder, origin, solids)
	kickers(folder, origin, solids, rises)
	local crusherModel = crusher(folder, origin, solids)
	scenery(folder, origin)
	sounds(folder, origin)

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

	local Cr = Layout.crusher
	local Bm = Layout.boom
	local roundStart = -1
	local slamHit: { [string]: number } = {} -- the last slam each car was caught by
	local boomFx = group(folder, "Booms")

	local function flatAway(from: Vector3, to: Vector3, fallback: Vector3): Vector3
		local off = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		if off.Magnitude > 1e-3 then
			return off.Unit
		end
		local fb = Vector3.new(fallback.X, 0, fallback.Z)
		return if fb.Magnitude > 1e-3 then fb.Unit else Vector3.new(1, 0, 0)
	end

	local controls: Controls
	controls = {
		openDoors = function()
			roundStart = workspace:GetServerTimeNow()
			table.clear(slamHit)
			crusherModel:SetAttribute("RoundStart", roundStart)
		end,
		closeDoors = function()
			roundStart = -1
			crusherModel:SetAttribute("RoundStart", -1)
		end,
		setNames = function(_a: string, _b: string) end,
		setTeams = function(_aIsRed: boolean) end,
		tick = function(_dt: number, bodies: { [string]: BasePart }): { Hit }
			local hits: { Hit } = {}
			local changed = false
			-- the crusher: the cars its shock ring has reached
			if roundStart >= 0 then
				local state = Layout.crusherState(workspace:GetServerTimeNow() - roundStart)
				local front = Layout.shockFront(state)
				if front > 0 then
					for side, body in bodies do
						if slamHit[side] ~= state.index then
							local off = body.Position - origin
							local flat = Vector3.new(off.X, 0, off.Z)
							-- a car high above the ring (on a hop) is missed
							if flat.Magnitude <= front and off.Y < Cr.baseHeight + 8 then
								slamHit[side] = state.index
								table.insert(hits, {
									side = side,
									dir = flatAway(
										origin,
										body.Position,
										body.AssemblyLinearVelocity
									),
									damageFrac = Cr.damageFrac,
									knockSpeed = Cr.knockSpeed,
									stagger = Cr.stagger,
									text = "Crusher slam!",
								})
							end
						end
					end
				end
			end
			-- props burst under the cars; a red barrel also goes off
			for _, body in bodies do
				for _, p in workspace:GetPartsInPart(body, overlap) do
					local b = byBody[p]
					if b and not b.broken then
						local at = b.body.Position
						burst(b, body.AssemblyLinearVelocity)
						changed = true
						if b.boom then
							explosion(boomFx, Vector3.new(at.X, origin.Y, at.Z))
							for side, car in bodies do
								local off = car.Position - at
								if Vector3.new(off.X, 0, off.Z).Magnitude <= Bm.radius then
									table.insert(hits, {
										side = side,
										dir = flatAway(
											at,
											car.Position,
											car.AssemblyLinearVelocity
										),
										damageFrac = Bm.damageFrac,
										knockSpeed = Bm.knockSpeed,
										stagger = Bm.stagger,
										text = "Barrel boom!",
									})
								end
							end
						end
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
			local best, bestD = nil, math.huge
			for _, r in Layout.rescuePoints() do
				local d = (r.x - lx) ^ 2 + (r.z - lz) ^ 2
				if d < bestD then
					best, bestD = r, d
				end
			end
			local r = best :: { x: number, z: number, fx: number, fz: number }
			return origin + Vector3.new(r.x, 1, r.z), Vector3.new(r.fx, 0, r.fz)
		end,
		resetBreakables = function()
			for _, b in live do
				if b.broken then
					b.model = b.rebuild()
					b.body = b.model.PrimaryPart :: BasePart
					b.broken = false
				end
			end
			refresh()
			boomFx:ClearAllChildren()
		end,
		verify = function() end,
	}

	controls.verify = function()
		verifyWedges(rises, origin)
	end
	folder:SetAttribute("PartCount", countParts(folder))
	folder:SetAttribute("InstanceCount", #folder:GetDescendants())
	return controls
end

return BowlMap
