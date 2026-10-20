--!strict
-- Builds the 1v1 battle map "Duel Car Arena" from `DuelArenaLayout` (all numbers live there): a dark
-- asphalt floor with rounded corners, painted orange and blue wall modules with steady lights and
-- tire stacks, four striped cover blocks, two big garages with roller doors, flags and name signs
-- behind the end walls, and a grassy world round it (trees, pines, rocks, bushes, flowers, dirt
-- paths, hills, light towers, a CAR VS CAR sign). Only the floor, walls, cover and the two garage
-- gates collide; everything else is looks only. It returns the little controls the fight code uses:
-- names on the garage signs, red/blue team colors, doors up and down.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.DuelArenaLayout)
local MapParts = require(script.Parent.MapParts)

local DuelArena = {}

export type Controls = {
	openDoors: () -> (),
	closeDoors: () -> (),
	setNames: (a: string, b: string) -> (),
	setTeams: (aIsRed: boolean) -> (),
}

local rgb, part, can, ball, group =
	MapParts.rgb, MapParts.part, MapParts.can, MapParts.ball, MapParts.group
local C = Layout.colors

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Walls and cover throw a car back: their bounce wins over the car's (weight 100), so a hit is a
-- visible rebound and not a dead stop. No damage comes from it.
local function bouncy(p: Part): Part
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, Layout.wallBounce, 1, 100)
	CollectionService:AddTag(p, "Bouncy") -- BattleCar throws a car that runs into a tagged part back
	return p
end

-- A stack of tires standing at `pos` (bottom of the stack): thin gaps between the tires, each one a
-- little off the one below, and a pale hole on the top one, so it reads as tires and not as a block.
local function tires(parent: Instance, pos: Vector3, scale: number, solids: { Instance }?)
	local t = Layout.tire
	local step = (t.height + 0.3) * scale
	for k = 0, t.stack - 1 do
		local off =
			Vector3.new((k % 2 - 0.5) * 0.7 * scale, k * step, (1 - k % 2 * 2) * 0.25 * scale)
		local tire = can(
			parent,
			"Tire",
			t.diameter * scale,
			t.height * scale,
			pos + off,
			rgb(C.tire),
			solids ~= nil,
			solids,
			Enum.Material.Rubber
		)
		if solids then
			bouncy(tire)
		end
		if k == t.stack - 1 then
			can(
				parent,
				"TireRim",
				t.diameter * 0.55 * scale,
				0.3 * scale,
				pos + off + Vector3.new(0, t.height * scale - 0.1, 0),
				rgb(C.metalDark),
				false,
				nil,
				Enum.Material.Metal
			)
		end
	end
end

local function floor(folder: Folder, origin: Vector3, solids: { Instance })
	local hx, hz, r = Layout.halfX, Layout.halfZ, Layout.corner
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local asphalt = rgb(C.asphalt)
	part(
		folder,
		"Floor",
		Vector3.new(hx * 2, 2, (hz - r) * 2),
		at(0, -1, 0),
		asphalt,
		true,
		solids,
		Enum.Material.Asphalt
	)
	part(
		folder,
		"FloorX",
		Vector3.new((hx - r) * 2, 2, hz * 2),
		at(0, -1, 0),
		asphalt,
		true,
		solids,
		Enum.Material.Asphalt
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			can(
				folder,
				"FloorCorner",
				r * 2,
				2,
				origin + Vector3.new(sx * (hx - r), -2, sz * (hz - r)),
				asphalt,
				true,
				solids,
				Enum.Material.Asphalt
			)
		end
	end
	-- the ground around it, a touch lower than the floor
	part(
		folder,
		"Grass",
		Vector3.new(Layout.groundX, 2, Layout.groundZ),
		at(0, -1.7, 0),
		rgb(C.grass),
		true,
		solids,
		Enum.Material.Grass
	)
end

-- Look-only decoration of the grass: dirt paths and far hills.
local function ground(folder: Folder, origin: Vector3)
	local grp = group(folder, "Ground")
	for _, p in Layout.paths() do
		part(
			grp,
			"Path",
			Vector3.new(p.sx, 0.12, p.sz),
			CFrame.new(origin + Vector3.new(p.x, -0.64, p.z)) * yaw(p.yawDeg),
			rgb(C.dirt),
			false,
			nil,
			Enum.Material.Ground
		)
	end
	for _, h in Layout.hills() do
		ball(
			grp,
			"Hill",
			h.d,
			origin + Vector3.new(h.x, 24 - h.d / 2, h.z),
			rgb(C.hill),
			false,
			nil,
			Enum.Material.Grass
		)
	end
end

local function bar(
	parent: Instance,
	origin: Vector3,
	x: number,
	z: number,
	y: number,
	len: number,
	wid: number,
	yawDeg: number,
	color: Color3
)
	part(
		parent,
		"Mark",
		Vector3.new(len, 0.1, wid),
		CFrame.new(origin + Vector3.new(x, y, z)) * yaw(yawDeg),
		color,
		false
	)
end

-- Painted floor: dashed edge, lane lines, center circle, arrows, skid marks and the two start pads.
-- Returns the team-colored parts (the pads) of each side.
local function markings(folder: Folder, origin: Vector3, teamParts: { [string]: { Instance } })
	local marks = group(folder, "FloorMarks")
	local white = rgb(C.marking)
	for _, d in Layout.dashes() do
		bar(marks, origin, d.x, d.z, 0.06, d.length, 0.9, d.yawDeg, white)
	end
	for _, d in Layout.laneLines() do
		bar(marks, origin, d.x, d.z, 0.06, d.length, 0.8, d.yawDeg, white)
	end
	-- center circle: a white disc with a slightly smaller asphalt disc on top
	can(
		marks,
		"CircleRing",
		Layout.circle * 2,
		0.08,
		origin + Vector3.new(0, 0.02, 0),
		white,
		false
	)
	can(
		marks,
		"CircleFill",
		Layout.circle * 2 - 2,
		0.09,
		origin + Vector3.new(0, 0.03, 0),
		rgb(C.asphalt),
		false,
		nil,
		Enum.Material.Asphalt
	)
	for _, s in Layout.skids() do
		bar(marks, origin, s.x, s.z, 0.05, s.length, 0.7, s.yawDeg, rgb(C.skid))
	end
	for _, a in Layout.arrows() do
		local color = rgb(if a.team == "orange" then C.orange else C.blue)
		local base = CFrame.new(origin + Vector3.new(a.x, 0.07, a.z)) * yaw(-a.yawDeg)
		part(
			marks,
			"ArrowShaft",
			Vector3.new(12, 0.1, 3.2),
			base * CFrame.new(-3, 0, 0),
			color,
			false
		)
		for _, side in { -1, 1 } do
			part(
				marks,
				"ArrowHead",
				Vector3.new(9, 0.1, 3),
				base * CFrame.new(-0.3, 0, side * 3) * yaw(side * 42),
				color,
				false
			)
		end
	end
	-- start pads: look only, the fight code reads them as the start spots
	for side, _ in { a = true, b = true } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.05, z)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
		local pad = part(
			folder,
			"Spawn" .. string.upper(side),
			Vector3.new(Layout.pad.sx, 0.12, Layout.pad.sz),
			cf,
			rgb(C.red),
			false
		)
		table.insert(teamParts[side], pad)
		for _, e in { -1, 1 } do
			part(
				marks,
				"PadEdge",
				Vector3.new(Layout.pad.sx, 0.14, 0.7),
				cf * CFrame.new(0, 0, e * (Layout.pad.sz / 2 - 0.35)),
				white,
				false
			)
		end
	end
end

local function walls(folder: Folder, origin: Vector3, solids: { Instance })
	local t, h = Layout.wallThickness, Layout.wallHeight
	local wallGroup = group(folder, "Walls")
	local trim = group(folder, "WallTrim")
	for _, w in Layout.walls() do
		local center = origin + Vector3.new(w.x - w.nx * t / 2, h / 2, w.z - w.nz * t / 2)
		local cf = CFrame.new(center) * yaw(w.yawDeg)
		local team = rgb(if w.team == "orange" then C.orange else C.blue)
		local len = w.length * 1.12
		bouncy(
			part(
				wallGroup,
				w.name,
				Vector3.new(len, h, t),
				cf,
				team,
				true,
				solids,
				Enum.Material.Metal
			)
		)
		-- a metal base and cap, so the module reads as painted metal
		part(
			trim,
			"Base",
			Vector3.new(len, 1.4, t + 0.3),
			cf * CFrame.new(0, -h / 2 + 0.7, 0),
			rgb(C.metal),
			false,
			nil,
			Enum.Material.Metal
		)
		part(
			trim,
			"Cap",
			Vector3.new(len, 0.5, t + 0.3),
			cf * CFrame.new(0, h / 2 + 0.25, 0),
			rgb(C.metal),
			false,
			nil,
			Enum.Material.Metal
		)
		-- steady glowing lights on the inner face: two to a straight module, one on a corner piece
		local face = Vector3.new(w.nx * 0.15, 0, w.nz * 0.15)
		local spots = if w.arc then { 0 } else { -0.22, 0.22 }
		for _, s in spots do
			local along =
				Vector3.new(math.cos(math.rad(w.yawDeg)), 0, -math.sin(math.rad(w.yawDeg)))
			local p = origin + Vector3.new(w.x, 4.2, w.z) + face + along * (s * len)
			part(
				trim,
				"Light",
				Vector3.new(len * (if w.arc then 0.5 else 0.24), 1.3, 0.3),
				CFrame.new(p) * yaw(w.yawDeg),
				rgb(C.light),
				false,
				nil,
				Enum.Material.Neon
			)
		end
	end
	-- tire stacks where wall modules meet, standing against the inner wall face (solid and bouncy)
	local tireGroup = group(folder, "TireStacks")
	for _, s in Layout.tireStacks() do
		tires(tireGroup, origin + Vector3.new(s.x + s.nx * 2.9, 0, s.z + s.nz * 2.9), 1, solids)
	end
end

-- Cover barrier: a chunky grey block with orange and dark stripes and a glowing light on each end.
local function blocks(folder: Folder, origin: Vector3, solids: { Instance })
	local b = Layout.block
	local grp = group(folder, "Cover")
	for _, blk in Layout.blocks() do
		local cf = CFrame.new(origin + Vector3.new(blk.x, b.sy / 2, blk.z)) * yaw(blk.yawDeg)
		bouncy(
			part(
				grp,
				blk.name,
				Vector3.new(b.sx, b.sy, b.sz),
				cf,
				rgb(C.metal),
				true,
				solids,
				Enum.Material.Metal
			)
		)
		for i = 0, 3 do
			for _, side in { -1, 1 } do
				part(
					grp,
					"Stripe",
					Vector3.new(2.4, b.sy - 1.6, 0.2),
					cf * CFrame.new(-b.sx / 2 + 2.4 + i * 4.2, 0, side * (b.sz / 2 + 0.05)),
					rgb(if i % 2 == 0 then C.orange else C.tire),
					false
				)
			end
		end
		part(
			grp,
			"Top",
			Vector3.new(b.sx + 0.4, 0.5, b.sz + 0.4),
			cf * CFrame.new(0, b.sy / 2 + 0.25, 0),
			rgb(C.metalDark),
			false
		)
		for _, side in { -1, 1 } do
			part(
				grp,
				"EndLight",
				Vector3.new(0.3, 1.4, b.sz * 0.5),
				cf * CFrame.new(side * (b.sx / 2 + 0.1), 0.6, 0),
				rgb(C.light),
				false,
				nil,
				Enum.Material.Neon
			)
		end
	end
end

-- A flag that waves on the player's screen: five strips, MapFx sways them.
local function flag(
	parent: Instance,
	pos: Vector3,
	color: Color3,
	towardZ: number,
	team: { Instance }
)
	can(parent, "Pole", 0.7, 20, pos, rgb(C.metal), false)
	local model = Instance.new("Model")
	model.Name = "Flag"
	for i = 1, 5 do
		local strip = part(
			model,
			"Strip" .. i,
			Vector3.new(0.3, 5, 1.1),
			CFrame.new(pos + Vector3.new(0, 17, towardZ * (0.8 + (i - 0.5) * 1.1))),
			color,
			false
		)
		table.insert(team, strip)
	end
	model.Parent = parent
	CollectionService:AddTag(model, "MapWave")
end

local function garage(
	folder: Folder,
	origin: Vector3,
	g: { side: string, x: number, z: number, dir: number },
	solids: { Instance },
	teamParts: { [string]: { Instance } },
	doors: { Part },
	labels: { [string]: TextLabel }
)
	local gd = Layout.garage
	local depth = gd.d
	local dir = g.dir
	local team = teamParts[g.side]
	local grp = group(folder, if g.side == "a" then "GarageA" else "GarageB")
	-- depth u runs from the mouth (-d/2) to the back wall (+d/2); v is across (z)
	local function P(u: number, y: number, v: number): Vector3
		return origin + Vector3.new(g.x + dir * u, y, g.z + v)
	end
	local function box(
		name: string,
		du: number,
		sy: number,
		dv: number,
		u: number,
		y: number,
		v: number,
		color: Color3,
		material: Enum.Material?
	): Part
		return part(
			grp,
			name,
			Vector3.new(du, sy, dv),
			CFrame.new(P(u, y, v)),
			color,
			false,
			nil,
			material
		)
	end
	local dark = Color3.fromRGB(58, 62, 74)
	local mouthU = -depth / 2
	-- shell: floor, back and side walls, roof, header over the door
	box(
		"Floor",
		depth,
		0.3,
		depth + 4,
		0,
		0.1,
		0,
		Color3.fromRGB(96, 102, 114),
		Enum.Material.Concrete
	)
	box("Back", 1, gd.h, gd.w, depth / 2, gd.h / 2, 0, dark, Enum.Material.Metal)
	for _, sv in { -1, 1 } do
		box("Side", depth, gd.h, 1, 0, gd.h / 2, sv * (gd.w / 2), dark, Enum.Material.Metal)
		local post = box(
			"Post",
			2,
			gd.h + 1,
			2,
			mouthU,
			gd.h / 2,
			sv * (gd.mouth / 2 + 1),
			rgb(C.red),
			Enum.Material.Metal
		)
		table.insert(team, post)
		flag(grp, P(mouthU + 1, 0, sv * (gd.mouth / 2 + 1)), rgb(C.red), sv, team)
	end
	local roof =
		box("Roof", depth + 3, 1.4, gd.w + 3, 0, gd.h + 0.7, 0, rgb(C.red), Enum.Material.Metal)
	table.insert(team, roof)
	box(
		"Header",
		1.4,
		gd.h - gd.door,
		gd.mouth,
		mouthU,
		gd.door + (gd.h - gd.door) / 2,
		0,
		dark,
		Enum.Material.Metal
	)
	-- the invisible gate that keeps cars out (the door is only a look)
	local gate = part(
		grp,
		"Gate",
		Vector3.new(1.5, gd.h, gd.mouth),
		CFrame.new(P(mouthU - 0.2, gd.h / 2, 0)),
		dark,
		true,
		solids
	)
	gate.Transparency = 1
	bouncy(gate)
	-- the roller door: slats that slide up behind the header
	local slats = 6
	for i = 1, slats do
		local slat = box(
			"Slat",
			0.5,
			gd.door / slats - 0.15,
			gd.mouth - 0.4,
			mouthU + 0.6,
			(i - 0.5) * gd.door / slats,
			0,
			Color3.fromRGB(192, 198, 208),
			Enum.Material.Metal
		)
		table.insert(doors, slat)
	end
	-- inside: tool boxes, tire racks, crates, a bench and a ceiling light
	local ls = box(
		"CeilingLight",
		1.2,
		0.4,
		gd.mouth * 0.8,
		1,
		gd.h - 0.5,
		0,
		Color3.fromRGB(255, 240, 200),
		Enum.Material.Neon
	)
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 224, 170)
	lamp.Brightness = 1.4
	lamp.Range = 30
	lamp.Shadows = false
	lamp.Parent = ls
	for _, sv in { -1, 1 } do
		local v = sv * (gd.w / 2 - 3)
		box("ToolBox", 3.4, 3, 5, depth / 2 - 3, 1.6, v, rgb(C.red), Enum.Material.Metal)
		box(
			"ToolBoxTop",
			3.6,
			1.6,
			5.2,
			depth / 2 - 3,
			3.7,
			v,
			rgb(C.metalDark),
			Enum.Material.Metal
		)
		box(
			"Crate",
			3.6,
			3.6,
			3.6,
			depth / 2 - 3.5,
			1.9,
			sv * (gd.w / 2 - 8.5),
			rgb(C.crate),
			Enum.Material.WoodPlanks
		)
		box(
			"Crate",
			3.2,
			3.2,
			3.2,
			depth / 2 - 3.5,
			5.4,
			sv * (gd.w / 2 - 8.5),
			rgb(C.crate),
			Enum.Material.WoodPlanks
		)
		-- tire rack: a frame with three tires lying on it
		box("RackPost", 0.6, 7, 0.6, 2, 3.5, sv * (gd.w / 2 - 3), rgb(C.metal), Enum.Material.Metal)
		box(
			"RackPost",
			0.6,
			7,
			0.6,
			-4,
			3.5,
			sv * (gd.w / 2 - 3),
			rgb(C.metal),
			Enum.Material.Metal
		)
		for r = 1, 3 do
			local pos = P(-1, r * 2.1 - 0.4, sv * (gd.w / 2 - 3))
			can(
				grp,
				"RackTire",
				4.6,
				1.7,
				pos - Vector3.new(0, 0.85, 0),
				rgb(C.tire),
				false,
				nil,
				Enum.Material.Rubber
			)
		end
	end
	box(
		"Bench",
		2.4,
		0.5,
		9,
		depth / 2 - 2,
		3.4,
		0,
		Color3.fromRGB(140, 104, 66),
		Enum.Material.WoodPlanks
	)
	box("BenchLegA", 0.6, 3.2, 0.6, depth / 2 - 2, 1.6, -4, rgb(C.metal), Enum.Material.Metal)
	box("BenchLegB", 0.6, 3.2, 0.6, depth / 2 - 2, 1.6, 4, rgb(C.metal), Enum.Material.Metal)
	-- the glowing name sign on top of the roof, facing the arena
	local sign = box(
		"Sign",
		1.2,
		4.6,
		gd.mouth - 6,
		mouthU + 1,
		gd.h + 3.6,
		0,
		Color3.fromRGB(30, 33, 44),
		Enum.Material.Metal
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = if dir < 0 then Enum.NormalId.Right else Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	label.Text = if g.side == "a" then "PLAYER" else "BOT"
	label.Parent = gui
	labels[g.side] = label
	local glow = box(
		"SignGlow",
		0.4,
		0.7,
		gd.mouth - 5.4,
		mouthU + 0.5,
		gd.h + 1.5,
		0,
		rgb(C.red),
		Enum.Material.Neon
	)
	table.insert(team, glow)
end

local function towers(folder: Folder, origin: Vector3)
	local grp = group(folder, "Towers")
	for _, t in Layout.towers() do
		local base = origin + Vector3.new(t.x, -0.7, t.z)
		can(
			grp,
			"Pole",
			1.8,
			Layout.tower.height,
			base,
			rgb(C.metal),
			false,
			nil,
			Enum.Material.Metal
		)
		can(grp, "Foot", 4, 1.2, base, rgb(C.metalDark), false)
		local top = base + Vector3.new(0, Layout.tower.height, 0)
		local toward = Vector3.new(-math.sign(t.x), 0, -math.sign(t.z)).Unit
		local cf =
			CFrame.lookAt(top + Vector3.new(0, 2.2, 0), top + Vector3.new(0, 2.2, 0) + toward)
		part(
			grp,
			"Head",
			Vector3.new(11, 5.6, 1.4),
			cf,
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
		for row = 0, 1 do
			for col = 0, 2 do
				part(
					grp,
					"Lamp",
					Vector3.new(2.6, 2, 0.4),
					cf * CFrame.new(-3.4 + col * 3.4, -1.4 + row * 2.6 + 0.6, -0.8),
					Color3.fromRGB(255, 244, 200),
					false,
					nil,
					Enum.Material.Neon
				)
			end
		end
	end
end

local function carSign(folder: Folder, origin: Vector3)
	local s = Layout.sign
	local grp = group(folder, "CarSign")
	local board = part(
		grp,
		"Board",
		Vector3.new(s.width, s.height, 1.5),
		CFrame.new(origin + Vector3.new(0, s.y, s.z)),
		Color3.fromRGB(26, 40, 78),
		false,
		nil,
		Enum.Material.Metal
	)
	part(
		grp,
		"Border",
		Vector3.new(s.width + 2, s.height + 2, 1),
		CFrame.new(origin + Vector3.new(0, s.y, s.z - 0.3)),
		rgb(C.orange),
		false,
		nil,
		Enum.Material.Neon
	)
	for _, sx in { -1, 1 } do
		part(
			grp,
			"Post",
			Vector3.new(2.4, s.y, 2.4),
			CFrame.new(origin + Vector3.new(sx * (s.width / 2 - 4), s.y / 2 - 0.7, s.z)),
			rgb(C.metal),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the +z side looks into the arena
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "CAR VS CAR"
	label.TextColor3 = rgb(C.orange)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = rgb(C.blue)
	label.Parent = gui
end

local function scenery(folder: Folder, origin: Vector3)
	local near = group(folder, "Scenery")
	local far = group(folder, "FarScenery") -- cut this first if phones lag
	for _, s in Layout.scenery() do
		local grp = if s.far then far else near
		local base = origin + Vector3.new(s.x, -0.6, s.z)
		local k = s.scale
		if s.kind == "tree" then
			can(grp, "Trunk", 2.6 * k, 6 * k, base, rgb(C.trunk), false, nil, Enum.Material.Wood)
			ball(grp, "Leaves", 11 * k, base + Vector3.new(0, 9.5 * k, 0), rgb(C.leaf), false)
			ball(
				grp,
				"LeavesTop",
				7.5 * k,
				base + Vector3.new(0.8 * k, 14 * k, 0.5 * k),
				rgb(C.leafLight),
				false
			)
		elseif s.kind == "pine" then
			can(grp, "Trunk", 2 * k, 4 * k, base, rgb(C.trunk), false, nil, Enum.Material.Wood)
			for i = 0, 2 do
				can(
					grp,
					"Pine",
					(11 - i * 3.4) * k,
					5.2 * k,
					base + Vector3.new(0, (3 + i * 4.2) * k, 0),
					rgb(if i % 2 == 0 then C.pine else C.pineLight),
					false
				)
			end
		elseif s.kind == "rock" then
			part(
				grp,
				"Rock",
				Vector3.new(7 * k, 4.5 * k, 5.5 * k),
				CFrame.new(base + Vector3.new(0, 1.6 * k, 0))
					* yaw(s.yawDeg)
					* CFrame.Angles(0.12, 0, 0.1),
				rgb(C.rock),
				false,
				nil,
				Enum.Material.Slate
			)
			if k > 1.2 then
				part(
					grp,
					"RockSmall",
					Vector3.new(3.4, 2.4, 3),
					CFrame.new(base + Vector3.new(4.6 * k, 0.8, 1.6)) * yaw(s.yawDeg + 40),
					rgb(C.rockDark),
					false,
					nil,
					Enum.Material.Slate
				)
			end
		elseif s.kind == "bush" then
			ball(grp, "Bush", 4.6 * k, base + Vector3.new(0, 1.6 * k, 0), rgb(C.bush), false)
		else
			local f = C.flowers[s.pick]
			can(grp, "Stem", 0.3, 1.4, base, rgb(C.bush), false)
			ball(grp, "Flower", 1.6, base + Vector3.new(0, 1.6, 0), rgb(f), false)
		end
	end
end

-- Silent sound spots: the ids are blank until carter supplies them (docs/sounds-needed.md).
local function sounds(folder: Folder, origin: Vector3): { [string]: Sound }
	local grp = group(folder, "Sounds")
	local list: { [string]: Sound } = {}
	local function spot(name: string, pos: Vector3, looped: boolean, volume: number)
		local p = part(
			grp,
			"Spot_" .. name,
			Vector3.new(1, 1, 1),
			CFrame.new(origin + pos),
			Color3.new(1, 1, 1),
			false
		)
		p.Transparency = 1
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = ""
		s.Looped = looped
		s.Volume = volume
		s.RollOffMaxDistance = 220
		s.Parent = p
		list[name] = s
	end
	spot("Birds", Vector3.new(0, 30, -20), true, 0.35)
	spot("GarageDoorA", Vector3.new(-Layout.halfX - 6, 6, 0), false, 0.8)
	spot("GarageDoorB", Vector3.new(Layout.halfX + 6, 6, 0), false, 0.8)
	spot("GoHorn", Vector3.new(0, 20, 0), false, 1)
	return list
end

function DuelArena.build(folder: Folder, origin: Vector3, solids: { Instance }): Controls
	local teamParts: { [string]: { Instance } } = { a = {}, b = {} }
	local doors: { Part } = {}
	local labels: { [string]: TextLabel } = {}
	floor(folder, origin, solids)
	ground(folder, origin)
	markings(folder, origin, teamParts)
	walls(folder, origin, solids)
	blocks(folder, origin, solids)
	for _, g in Layout.garages() do
		garage(folder, origin, g, solids, teamParts, doors, labels)
	end
	towers(folder, origin)
	carSign(folder, origin)
	scenery(folder, origin)
	local snd = sounds(folder, origin)

	-- the sunny sky: puffy clouds, set once for the whole place
	local terrain = workspace.Terrain
	if terrain:FindFirstChildOfClass("Clouds") == nil then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end

	local closedAt: { [Part]: Vector3 } = {}
	for _, slat in doors do
		closedAt[slat] = slat.Position
	end
	local function slide(up: boolean)
		for i, slat in doors do
			-- open: the slats pile up behind the header over the doorway
			local goal = if up
				then Vector3.new(
					slat.Position.X,
					origin.Y + Layout.garage.door + 0.4 + ((i - 1) % 6) * 0.4,
					slat.Position.Z
				)
				else closedAt[slat] :: Vector3
			TweenService:Create(
				slat,
				TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = goal }
			):Play()
		end
		for _, name in { "GarageDoorA", "GarageDoorB" } do
			snd[name]:Play()
		end
	end
	local controls: Controls = {
		openDoors = function()
			slide(true)
			snd.GoHorn:Play()
		end,
		closeDoors = function()
			slide(false)
		end,
		setNames = function(a: string, b: string)
			if labels.a then
				labels.a.Text = string.upper(string.sub(a, 1, 14))
			end
			if labels.b then
				labels.b.Text = string.upper(string.sub(b, 1, 14))
			end
		end,
		setTeams = function(aIsRed: boolean)
			for side, list in teamParts do
				local red = (side == "a") == aIsRed
				local color = rgb(if red then C.red else C.blue)
				for _, p in list do
					if p:IsA("BasePart") then
						p.Color = color
					end
				end
			end
		end,
	}
	snd.Birds:Play()
	return controls
end

return DuelArena
