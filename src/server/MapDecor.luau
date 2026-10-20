--!strict
-- The room around the battle arena: the furniture walls (a bed, a bookshelf, a toy chest and a
-- window wall), pennants, giant toys standing outside, soft lights, a sunbeam and floating dust.
-- Also the toy details on the solid pieces (toy-brick studs, alphabet letters, toy soldiers).
-- Everything here is looks only except the four solid walls and the soldiers; no collision, no
-- query, no shadows on the small stuff, so it costs phones very little.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.BattleMapLayout)
local MapParts = require(script.Parent.MapParts)

local MapDecor = {}

local rgb, shade, part, can, ball, group =
	MapParts.rgb, MapParts.shade, MapParts.part, MapParts.can, MapParts.ball, MapParts.group

-- Toy-brick studs in a grid on top of a block.
function MapDecor.studs(
	parent: Instance,
	b: Layout.Box,
	at: (number, number, number) -> CFrame,
	nx: number,
	nz: number
)
	local st = Layout.studSize
	for i = 1, nx do
		for j = 1, nz do
			local lx = (i - 0.5) / nx * b.sx - b.sx / 2
			local lz = (j - 0.5) / nz * b.sz - b.sz / 2
			local cf = at(b.x, b.sy, b.z)
				* CFrame.Angles(0, math.rad(b.yawDeg), 0)
				* CFrame.new(lx, st.height / 2, lz)
			local s = part(
				parent,
				"Stud",
				Vector3.new(st.height, st.diameter, st.diameter),
				cf * CFrame.Angles(0, 0, math.pi / 2),
				shade(b.color, 1.12),
				false
			)
			s.Shape = Enum.PartType.Cylinder
		end
	end
end

-- A letter on the side and top of an alphabet block.
function MapDecor.letter(p: Part, text: string)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Parent = g
		g.Parent = p
	end
end

-- A chunky toy soldier standing on a base plate. Its footprint is the layout box; the front looks
-- along the box's yaw.
function MapDecor.soldier(
	parent: Instance,
	b: Layout.Box,
	at: (number, number, number) -> CFrame,
	solids: { Instance }
)
	local c = Layout.colors
	local m = Instance.new("Model")
	m.Name = b.name
	local base = CFrame.new(at(b.x, 0, b.z).Position) * CFrame.Angles(0, math.rad(b.yawDeg), 0)
	local function piece(
		name: string,
		size: Vector3,
		off: Vector3,
		color: Color3,
		solid: boolean
	): Part
		return part(m, name, size, base * CFrame.new(off), color, solid, solids)
	end
	local coat = rgb(b.color)
	piece("Plate", Vector3.new(b.sx, 2, b.sz), Vector3.new(0, 1, 0), rgb(c.blocks[2]), true)
	piece("LegL", Vector3.new(3.4, 9, 4), Vector3.new(-2.1, 6.5, 0), shade(c.hat, 1.4), true)
	piece("LegR", Vector3.new(3.4, 9, 4), Vector3.new(2.1, 6.5, 0), shade(c.hat, 1.4), true)
	piece("Torso", Vector3.new(8.4, 8.5, 5), Vector3.new(0, 15.2, 0), coat, true)
	piece("Belt", Vector3.new(8.8, 1.2, 5.4), Vector3.new(0, 11.4, 0), rgb(c.white), true)
	piece("ArmL", Vector3.new(2, 7, 2.6), Vector3.new(-5.3, 15.6, 0), coat, true)
	piece("ArmR", Vector3.new(2, 7, 2.6), Vector3.new(5.3, 15.6, 0), coat, true)
	ball(m, "Head", 6.4, (base * CFrame.new(0, 22, 0)).Position, rgb(c.skin), true, solids)
	local hat =
		can(m, "Hat", 5.6, 4.6, (base * CFrame.new(0, 22.6, 0)).Position, rgb(c.hat), true, solids)
	hat.CFrame = base * CFrame.new(0, 25, 0) * CFrame.Angles(0, 0, math.pi / 2)
	piece("HatBrim", Vector3.new(6.6, 0.6, 6.6), Vector3.new(0, 22.4, 0), rgb(c.hat), false)
	piece("Badge", Vector3.new(2.2, 2.2, 0.3), Vector3.new(0, 15.6, -2.6), rgb(c.stripes[2]), false)
	local rifle =
		piece("Rifle", Vector3.new(1, 1, 15), Vector3.new(4.2, 15.5, -5.5), rgb(c.brown), false)
	rifle.CFrame = base * CFrame.new(4.2, 15.5, -4.5) * CFrame.Angles(math.rad(-8), 0, 0)
	m.Parent = parent
end

local function crayonColor(i: number): Color3
	local list = Layout.colors.crayons
	return rgb(list[(i - 1) % #list + 1])
end

-- The four furniture walls. The solid wall parts go in `solids`; everything on them is looks only.
local function walls(folder: Folder, origin: Vector3, solids: { Instance })
	local halfX, halfZ, h, t = Layout.halfX, Layout.halfZ, Layout.wallHeight, Layout.wallThickness
	local c = Layout.colors
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local wood = rgb(c.brown)
	local list: { { name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material } } =
		{
			{
				name = "WallN",
				size = Vector3.new(halfX * 2 + t * 2, h, t),
				cf = at(0, h / 2, -(halfZ + t / 2)),
				color = wood,
				material = Enum.Material.Wood,
			},
			{
				name = "WallS",
				size = Vector3.new(halfX * 2 + t * 2, h, t),
				cf = at(0, h / 2, halfZ + t / 2),
				color = wood,
				material = Enum.Material.Wood,
			},
			{
				name = "WallW",
				size = Vector3.new(t, h, halfZ * 2),
				cf = at(-(halfX + t / 2), h / 2, 0),
				color = wood,
				material = Enum.Material.Wood,
			},
			{
				name = "WallE",
				size = Vector3.new(t, h, halfZ * 2),
				cf = at(halfX + t / 2, h / 2, 0),
				color = rgb({ 255, 226, 236 }),
				material = Enum.Material.SmoothPlastic,
			},
		}
	local trim = group(folder, "WallTrim")
	for _, w in list do
		part(folder, w.name, w.size, w.cf, w.color, true, solids, w.material)
		local lengthways = w.size.X > w.size.Z
		part(
			trim,
			"WallCap",
			Vector3.new(
				w.size.X + (if lengthways then 0 else 1.6),
				1.2,
				w.size.Z + (if lengthways then 1.6 else 0)
			),
			w.cf * CFrame.new(0, h / 2 + 0.6, 0),
			rgb(c.white),
			false
		)
	end

	-- NORTH: a bed. Patchwork quilt, a white sheet fold and two pillows peeking over the top.
	local quilt = group(folder, "Bed")
	for i = 0, 11 do
		for j = 0, 1 do
			part(
				quilt,
				"Quilt",
				Vector3.new(18.4, 7.6, 0.5),
				at(-110 + i * 20, 5 + j * 8, -halfZ + 0.25),
				crayonColor(i + j * 3 + 1),
				false,
				nil,
				Enum.Material.Fabric
			)
		end
	end
	part(
		quilt,
		"SheetFold",
		Vector3.new(halfX * 2, 2.4, 0.9),
		at(0, 16.6, -halfZ + 0.45),
		rgb(c.white),
		false,
		nil,
		Enum.Material.Fabric
	)
	for _, px in { -70, 52 } do
		local pillow = part(
			quilt,
			"Pillow",
			Vector3.new(40, 9, 22),
			at(px, h + 5.5, -halfZ - 12) * CFrame.Angles(0, math.rad(px / 8), math.rad(2)),
			rgb(c.white),
			false,
			nil,
			Enum.Material.Fabric
		)
		part(
			quilt,
			"PillowStripe",
			Vector3.new(40.4, 2, 22.4),
			pillow.CFrame * CFrame.new(0, 0, 0),
			rgb(c.stripes[3]),
			false,
			nil,
			Enum.Material.Fabric
		)
	end

	-- SOUTH: a bookshelf. A plank at the foot and a row of colorful books.
	local shelf = group(folder, "Bookshelf")
	part(
		shelf,
		"ShelfPlank",
		Vector3.new(halfX * 2, 1.6, 2.4),
		at(0, 0.8, halfZ - 1.2),
		rgb(c.skirt),
		false,
		nil,
		Enum.Material.Wood
	)
	local i = 0
	local x = -halfX + 3
	while x < halfX - 3 do
		i += 1
		local bookH = 9 + (i * 7) % 6
		local bookW = 3.6 + (i * 3) % 3
		part(
			shelf,
			"Book",
			Vector3.new(bookW, bookH, 1.6),
			at(x, 1.6 + bookH / 2, halfZ - 1.4)
				* CFrame.Angles(0, 0, math.rad(if i % 11 == 0 then 8 else 0)),
			crayonColor(i * 5 + 2),
			false
		)
		x += bookW + 0.5
	end
	part(
		shelf,
		"ShelfTop",
		Vector3.new(halfX * 2, 1, 3),
		at(0, 15.4, halfZ - 1.4),
		rgb(c.skirt),
		false,
		nil,
		Enum.Material.Wood
	)

	-- WEST: a toy chest. Painted planks, two iron straps, a gold lock and yellow stars.
	local chest = group(folder, "ToyChest")
	for k = 0, 7 do
		part(
			chest,
			"Plank",
			Vector3.new(0.5, 15.4, 19),
			at(-halfX + 0.25, 8.8, -70 + k * 20),
			if k % 2 == 0 then rgb({ 200, 140, 80 }) else rgb(c.brown),
			false,
			nil,
			Enum.Material.WoodPlanks
		)
	end
	for _, sz in { -46, 46 } do
		part(
			chest,
			"Strap",
			Vector3.new(0.9, 17.6, 5),
			at(-halfX + 0.45, 9, sz),
			rgb({ 84, 90, 110 }),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	part(
		chest,
		"Lock",
		Vector3.new(1.2, 6, 5.6),
		at(-halfX + 0.6, 9, 0),
		rgb(c.stripes[2]),
		false,
		nil,
		Enum.Material.Metal
	)
	part(chest, "Keyhole", Vector3.new(1.4, 2.4, 1.2), at(-halfX + 0.7, 9, 0), rgb(c.hat), false)
	for _, sz in { -68, -22, 22, 68 } do
		for turn = 0, 1 do
			part(
				chest,
				"Star",
				Vector3.new(0.4, 4.6, 4.6),
				at(-halfX + 0.9, 9, sz) * CFrame.Angles(math.rad(turn * 45), 0, 0),
				rgb(c.stripes[2]),
				false
			)
		end
	end

	-- EAST: the window wall. Striped wallpaper, a big window, curtains and two sunbeams.
	local win = group(folder, "Window")
	for k = 0, 11 do
		if k % 2 == 0 then
			part(
				win,
				"Wallpaper",
				Vector3.new(0.4, 17, 9),
				at(halfX - 0.2, 8.6, -halfZ + 6 + k * 13),
				rgb({ 236, 150, 186 }),
				false
			)
		end
	end
	local frame = rgb(c.white)
	part(
		win,
		"Sky",
		Vector3.new(0.5, 10.6, 46),
		at(halfX - 0.3, 10, 0),
		rgb({ 150, 214, 255 }),
		false
	)
	part(win, "FrameTop", Vector3.new(1, 1.4, 49), at(halfX - 0.5, 15.6, 0), frame, false)
	part(win, "FrameBottom", Vector3.new(1, 1.4, 49), at(halfX - 0.5, 4.4, 0), frame, false)
	part(win, "FrameLeft", Vector3.new(1, 12, 1.4), at(halfX - 0.5, 10, -24), frame, false)
	part(win, "FrameRight", Vector3.new(1, 12, 1.4), at(halfX - 0.5, 10, 24), frame, false)
	part(win, "CrossV", Vector3.new(0.9, 10.6, 1.2), at(halfX - 0.5, 10, 0), frame, false)
	part(win, "CrossH", Vector3.new(0.9, 1.2, 46), at(halfX - 0.5, 10, 0), frame, false)
	part(win, "Sill", Vector3.new(4, 1.2, 54), at(halfX - 2, 3.4, 0), frame, false)
	for _, side in { -1, 1 } do
		for fold = 0, 2 do
			part(
				win,
				"Curtain",
				Vector3.new(1.2 + (fold % 2) * 0.6, 15.2, 3.2),
				at(halfX - 0.9, 9.8, side * (29 + fold * 2.8)),
				if fold % 2 == 0 then rgb(c.stripes[1]) else shade(c.stripes[1], 0.85),
				false,
				nil,
				Enum.Material.Fabric
			)
		end
	end
	local beam = group(folder, "Sunbeams")
	for _, sz in { -13, 13 } do
		local from = origin + Vector3.new(halfX - 2, 10, sz)
		local to = origin + Vector3.new(halfX - 62, 0.3, sz * 1.8)
		local mid = from:Lerp(to, 0.5)
		local b = part(
			beam,
			"Sunbeam",
			Vector3.new(16, 1.2, (to - from).Magnitude),
			CFrame.lookAt(mid, to),
			Color3.fromRGB(255, 240, 170),
			false,
			nil,
			Enum.Material.Neon
		)
		b.Transparency = 0.9
	end
end

-- Pennants strung along both long walls.
local function bunting(folder: Folder, origin: Vector3)
	local halfZ = Layout.halfZ
	local c = Layout.colors
	local g = group(folder, "Bunting")
	for _, side in { -1, 1 } do
		local z = side * (halfZ - 1.4)
		part(
			g,
			"String",
			Vector3.new(Layout.halfX * 2, 0.25, 0.25),
			CFrame.new(origin + Vector3.new(0, 15.2, z)),
			rgb(c.white),
			false
		)
		for _, b in Layout.bunting() do
			part(
				g,
				"Pennant",
				Vector3.new(4.2, 4.2, 0.25),
				CFrame.new(origin + Vector3.new(b.x, 13, z)) * CFrame.Angles(0, 0, math.pi / 4),
				crayonColor(b.i + 1),
				false
			)
		end
	end
end

-- Giant toys standing outside the walls.
local function teddy(parent: Instance, base: CFrame, s: number)
	local fur = rgb(Layout.colors.brown)
	local tan = rgb({ 240, 200, 150 })
	local dark = rgb(Layout.colors.hat)
	local function b(name: string, d: number, off: Vector3, color: Color3)
		ball(
			parent,
			name,
			d,
			(base * CFrame.new(off)).Position,
			color,
			false,
			nil,
			Enum.Material.Fabric
		)
	end
	b("Body", s, Vector3.new(0, s * 0.5, 0), fur)
	b("Belly", s * 0.66, Vector3.new(0, s * 0.46, -s * 0.34), tan)
	b("Head", s * 0.68, Vector3.new(0, s * 1.14, -s * 0.06), fur)
	b("EarL", s * 0.26, Vector3.new(-s * 0.26, s * 1.42, -s * 0.04), fur)
	b("EarR", s * 0.26, Vector3.new(s * 0.26, s * 1.42, -s * 0.04), fur)
	b("Muzzle", s * 0.3, Vector3.new(0, s * 1.06, -s * 0.34), tan)
	b("Nose", s * 0.1, Vector3.new(0, s * 1.1, -s * 0.48), dark)
	b("EyeL", s * 0.08, Vector3.new(-s * 0.13, s * 1.24, -s * 0.37), dark)
	b("EyeR", s * 0.08, Vector3.new(s * 0.13, s * 1.24, -s * 0.37), dark)
	b("ArmL", s * 0.3, Vector3.new(-s * 0.46, s * 0.62, -s * 0.2), fur)
	b("ArmR", s * 0.3, Vector3.new(s * 0.46, s * 0.62, -s * 0.2), fur)
	b("LegL", s * 0.36, Vector3.new(-s * 0.26, s * 0.14, -s * 0.34), fur)
	b("LegR", s * 0.36, Vector3.new(s * 0.26, s * 0.14, -s * 0.34), fur)
	local bow = Layout.colors.stripes[1]
	b("BowL", s * 0.12, Vector3.new(-s * 0.1, s * 0.84, -s * 0.34), rgb(bow))
	b("BowR", s * 0.12, Vector3.new(s * 0.1, s * 0.84, -s * 0.34), rgb(bow))
end

local function duck(parent: Instance, base: CFrame, s: number)
	local yellow = rgb(Layout.colors.stripes[2])
	local function b(name: string, d: number, off: Vector3, color: Color3)
		ball(parent, name, d, (base * CFrame.new(off)).Position, color, false)
	end
	b("Body", s, Vector3.new(0, s * 0.5, 0), yellow)
	b("Tail", s * 0.3, Vector3.new(0, s * 0.62, s * 0.46), yellow)
	b("Head", s * 0.56, Vector3.new(0, s * 1.08, -s * 0.2), yellow)
	b("EyeL", s * 0.09, Vector3.new(-s * 0.15, s * 1.18, -s * 0.42), rgb(Layout.colors.hat))
	b("EyeR", s * 0.09, Vector3.new(s * 0.15, s * 1.18, -s * 0.42), rgb(Layout.colors.hat))
	b(
		"WingL",
		s * 0.4,
		Vector3.new(-s * 0.46, s * 0.54, s * 0.04),
		shade(Layout.colors.stripes[2], 0.9)
	)
	b(
		"WingR",
		s * 0.4,
		Vector3.new(s * 0.46, s * 0.54, s * 0.04),
		shade(Layout.colors.stripes[2], 0.9)
	)
	part(
		parent,
		"Beak",
		Vector3.new(s * 0.32, s * 0.1, s * 0.22),
		base * CFrame.new(0, s * 1.02, -s * 0.5),
		rgb(Layout.colors.blocks[1]),
		false
	)
end

local function rocket(parent: Instance, pos: Vector3, s: number)
	local c = Layout.colors
	local white, red = rgb(c.white), rgb(c.stripes[1])
	can(parent, "Body", 16, s * 0.6, pos + Vector3.new(0, 4, 0), white, false)
	can(parent, "BandLow", 16.6, 5, pos + Vector3.new(0, 4 + s * 0.12, 0), red, false)
	can(parent, "BandHigh", 16.6, 5, pos + Vector3.new(0, 4 + s * 0.42, 0), red, false)
	can(parent, "NoseA", 12, 7, pos + Vector3.new(0, 4 + s * 0.6, 0), red, false)
	can(parent, "NoseB", 7, 6, pos + Vector3.new(0, 11 + s * 0.6, 0), red, false)
	can(parent, "NoseC", 3, 5, pos + Vector3.new(0, 17 + s * 0.6, 0), red, false)
	can(parent, "Engine", 9, 4, pos, rgb({ 84, 90, 110 }), false)
	ball(
		parent,
		"WindowA",
		6.4,
		pos + Vector3.new(0, 4 + s * 0.34, -7.6),
		rgb({ 150, 214, 255 }),
		false
	)
	ball(
		parent,
		"WindowB",
		6.4,
		pos + Vector3.new(7.6, 4 + s * 0.34, 0),
		rgb({ 150, 214, 255 }),
		false
	)
	for k = 0, 2 do
		part(
			parent,
			"Fin",
			Vector3.new(1.4, 14, 10),
			CFrame.new(pos + Vector3.new(0, 11, 0))
				* CFrame.Angles(0, math.rad(k * 120), 0)
				* CFrame.new(0, 0, 11),
			red,
			false
		)
	end
end

-- A big wheel: the Ferris model carries tags the player's own screen turns (no network cost).
local function ferris(parent: Instance, pos: Vector3, s: number)
	local c = Layout.colors
	local m = Instance.new("Model")
	m.Name = "FerrisWheel"
	local center = pos + Vector3.new(0, s / 2 + 8, 0)
	local hub = ball(m, "Hub", 7, center, rgb(c.stripes[1]), false)
	for k = 0, 7 do
		part(
			m,
			"Spoke",
			Vector3.new(0.9, s, 1.1),
			CFrame.new(center) * CFrame.Angles(math.rad(k * 22.5), 0, 0),
			rgb(c.white),
			false
		)
	end
	local segs = 20
	local r = s / 2
	local segLen = 2 * math.pi * r / segs + 0.4
	for k = 0, segs - 1 do
		local a = k / segs * 2 * math.pi
		part(
			m,
			"Rim",
			Vector3.new(1.4, 1.4, segLen),
			CFrame.new(center)
				* CFrame.Angles(a, 0, 0)
				* CFrame.new(0, r, 0)
				* CFrame.Angles(math.pi / 2, 0, 0)
				* CFrame.Angles(0, 0, 0),
			rgb(c.stripes[3]),
			false
		)
	end
	for k = 0, 9 do
		local a = k / 10 * 2 * math.pi
		part(
			m,
			"Gondola",
			Vector3.new(5, 5, 5.6),
			CFrame.new(center) * CFrame.Angles(a, 0, 0) * CFrame.new(0, r + 1, 0),
			crayonColor(k + 1),
			false
		)
	end
	m.PrimaryPart = hub
	m:SetAttribute("SpinSpeed", 0.22)
	m.Parent = parent
	CollectionService:AddTag(m, "MapSpin")
	-- two legs and a base (static)
	for _, side in { -1, 1 } do
		part(
			parent,
			"FerrisLeg",
			Vector3.new(1.8, s * 0.62, 1.8),
			CFrame.new(pos + Vector3.new(0, s * 0.31 + 3, side * 9))
				* CFrame.Angles(math.rad(side * -12), 0, 0),
			rgb(c.wall),
			false
		)
	end
	part(
		parent,
		"FerrisBase",
		Vector3.new(12, 2, 26),
		CFrame.new(pos + Vector3.new(0, 1, 0)),
		rgb(c.wall),
		false
	)
end

local function lamp(parent: Instance, pos: Vector3, s: number, target: Vector3)
	local c = Layout.colors
	can(parent, "LampBase", 18, 3, pos, rgb(c.stripes[3]), false)
	can(parent, "LampPole", 2.4, s * 0.8, pos + Vector3.new(0, 3, 0), rgb(c.white), false)
	local top = pos + Vector3.new(0, 3 + s * 0.8, 0)
	can(parent, "ShadeA", 12, 3, top, rgb(c.stripes[2]), false)
	can(parent, "ShadeB", 17, 4, top - Vector3.new(0, 4, 0), rgb(c.stripes[2]), false)
	can(parent, "ShadeC", 23, 4, top - Vector3.new(0, 8, 0), rgb(c.stripes[2]), false)
	local bulb = ball(
		parent,
		"Bulb",
		9,
		top - Vector3.new(0, 8, 0),
		Color3.fromRGB(255, 244, 200),
		false,
		nil,
		Enum.Material.Neon
	)
	local spot = Instance.new("SpotLight")
	spot.Angle = 70
	spot.Brightness = 1.4
	spot.Range = 260
	spot.Color = Color3.fromRGB(255, 236, 190)
	spot.Shadows = false
	spot.Face = Enum.NormalId.Front
	spot.Parent = bulb
	bulb.CFrame = CFrame.lookAt(bulb.Position, target)
end

local function props(folder: Folder, origin: Vector3)
	local c = Layout.colors
	local scenery = group(folder, "Scenery")
	for _, pr in Layout.scenery() do
		local pos = origin + Vector3.new(pr.x, 0, pr.z)
		local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(pr.yawDeg), 0)
		local color = crayonColor(pr.i)
		if pr.kind == "teddy" then
			teddy(scenery, base, pr.size)
		elseif pr.kind == "duck" then
			duck(scenery, base, pr.size)
		elseif pr.kind == "rocket" then
			rocket(scenery, pos, pr.size)
		elseif pr.kind == "ferris" then
			ferris(scenery, pos, pr.size)
		elseif pr.kind == "lamp" then
			lamp(scenery, pos, pr.size, origin + Vector3.new(0, 4, 0))
		elseif pr.kind == "crayon" then
			can(scenery, "Crayon", 8, pr.size, pos, color, false)
			can(
				scenery,
				"CrayonLabel",
				8.6,
				pr.size * 0.3,
				pos + Vector3.new(0, pr.size * 0.3, 0),
				rgb(c.white),
				false
			)
			can(scenery, "CrayonTip1", 5.4, 4, pos + Vector3.new(0, pr.size, 0), color, false)
			can(scenery, "CrayonTip2", 2.6, 3, pos + Vector3.new(0, pr.size + 4, 0), color, false)
		elseif pr.kind == "tower" then
			for k = 0, 2 do
				local s = pr.size - k * 3
				part(
					scenery,
					"ToyBlock",
					Vector3.new(s, s, s),
					CFrame.new(pos + Vector3.new(0, pr.size * k * 0.95 + s / 2, 0))
						* CFrame.Angles(0, math.rad(pr.yawDeg + k * 31), 0),
					crayonColor(pr.i + k),
					false
				)
			end
		elseif pr.kind == "ball" then
			ball(scenery, "BeachBall", pr.size, pos + Vector3.new(0, pr.size / 2, 0), color, false)
			can(
				scenery,
				"BallBand",
				pr.size * 0.55,
				pr.size * 0.9,
				pos + Vector3.new(0, pr.size * 0.05, 0),
				rgb(c.white),
				false
			)
		else -- corner flag pole
			can(scenery, "Pole", 1, pr.size, pos, rgb(c.wall), false)
			part(
				scenery,
				"Flag",
				Vector3.new(0.4, 6, 10),
				CFrame.new(pos + Vector3.new(0, pr.size - 4, -math.sign(pr.z) * 5)),
				color,
				false
			)
		end
	end
end

-- Soft lights and floating dust: three emitters and three lights per arena, all cheap.
local function effects(folder: Folder, origin: Vector3)
	local fx = group(folder, "Effects")
	local function anchor(name: string, size: Vector3, pos: Vector3): Part
		local p = part(fx, name, size, CFrame.new(origin + pos), Color3.new(1, 1, 1), false)
		p.Transparency = 1
		return p
	end
	local sparkle = "rbxasset://textures/particles/sparkles_main.dds"

	local dust = anchor(
		"Dust",
		Vector3.new(Layout.halfX * 1.8, 2, Layout.halfZ * 1.7),
		Vector3.new(0, 22, 0)
	)
	local e = Instance.new("ParticleEmitter")
	e.Texture = sparkle
	e.Rate = 9
	e.Lifetime = NumberRange.new(8, 12)
	e.Speed = NumberRange.new(0.4, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 0.15, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1.1),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 244, 200))
	e.LightEmission = 0.6
	e.RotSpeed = NumberRange.new(-20, 20)
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = dust

	-- a fountain of gold sparkles over the red ring
	local top = anchor(
		"PlateauSparkle",
		Vector3.new(14, 1, 14),
		Vector3.new(0, Layout.plateau.height + 1, 0)
	)
	local s = Instance.new("ParticleEmitter")
	s.Texture = sparkle
	s.Rate = 7
	s.Lifetime = NumberRange.new(1.6, 2.4)
	s.Speed = NumberRange.new(5, 9)
	s.SpreadAngle = Vector2.new(25, 25)
	s.EmissionDirection = Enum.NormalId.Top
	s.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	s.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	s.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	s.LightEmission = 0.9
	s.Acceleration = Vector3.new(0, -4, 0)
	s.Parent = top
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 90)
	glow.Brightness = 1.6
	glow.Range = 34
	glow.Shadows = false
	glow.Parent = top

	-- warm light from the window and a soft fill from the lamp side
	local sun = anchor("SunLight", Vector3.new(2, 2, 2), Vector3.new(Layout.halfX - 55, 16, 0))
	local sl = Instance.new("PointLight")
	sl.Color = Color3.fromRGB(255, 232, 170)
	sl.Brightness = 0.8
	sl.Range = 70
	sl.Shadows = false
	sl.Parent = sun
	-- dust drifting in the sunbeam
	local motes = anchor("BeamDust", Vector3.new(50, 10, 30), Vector3.new(Layout.halfX - 40, 6, 0))
	local m = e:Clone()
	m.Rate = 6
	m.Lifetime = NumberRange.new(5, 8)
	m.Parent = motes
end

-- Builds the walls, pennants, giant toys, lights and dust. The solid walls go in `solids`.
function MapDecor.room(folder: Folder, origin: Vector3, solids: { Instance })
	walls(folder, origin, solids)
	bunting(folder, origin)
	props(folder, origin)
	effects(folder, origin)
end

return MapDecor
