--!strict
-- Builds the 1v1 battle map "Toy Box Showdown" from `BattleMapLayout` (all numbers live there).
-- Bright toy look: flat colors, chunky pieces, toy-brick studs, alphabet blocks, toy soldiers, a
-- spinner hazard over the center plateau and giant toys outside the walls. The decoration has no
-- collision and no query, so it costs the physics nothing; around 330 parts, built once per match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.BattleMapLayout)

local BattleMap = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function shade(c: { number }, k: number): Color3
	return Color3.fromRGB(
		math.clamp(math.floor(c[1] * k), 0, 255),
		math.clamp(math.floor(c[2] * k), 0, 255),
		math.clamp(math.floor(c[3] * k), 0, 255)
	)
end

-- One anchored part. `solid` pieces are hit by cars and stop shells (and go in `solids`); the rest
-- are looks only.
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean,
	solids: { Instance }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if solid then
		if solids then
			table.insert(solids, p)
		end
	else
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- A cylinder standing up: height `h`, diameter `d`, bottom at y0.
local function can(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	pos: Vector3,
	color: Color3,
	solid: boolean,
	solids: { Instance }?
): Part
	local p = part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		solid,
		solids
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(
	parent: Instance,
	name: string,
	d: number,
	pos: Vector3,
	color: Color3,
	solid: boolean,
	solids: { Instance }?
): Part
	local p = part(parent, name, Vector3.new(d, d, d), CFrame.new(pos), color, solid, solids)
	p.Shape = Enum.PartType.Ball
	return p
end

-- One wedge ramp. Rises toward (dx, dz). The wedge's tall face is believed to be its back (+Z); the
-- caller checks that with `checkRamp` right after the map is in the workspace, so a wrong guess
-- cannot ship a ramp that drops instead of rises.
local function ramp(
	parent: Instance,
	origin: Vector3,
	r: Layout.Ramp,
	solids: { Instance }
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = r.name
	w.Anchored = true
	w.Size = Vector3.new(r.width, r.height, r.length)
	local center = origin + Vector3.new(r.x, r.height / 2, r.z)
	local rise = Vector3.new(r.dx, 0, r.dz)
	w.CFrame = CFrame.lookAt(center, center - rise)
	w.Color = rgb(r.color)
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w:SetAttribute("RiseX", r.dx)
	w:SetAttribute("RiseZ", r.dz)
	w.Parent = parent
	table.insert(solids, w)
	return w
end

-- Casts a ray down at the low end and the high end of the ramp; flips the ramp if it drops.
local function checkRamp(w: WedgePart, r: Layout.Ramp, origin: Vector3)
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

-- Toy-brick studs in a grid on top of a block.
local function studs(
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
local function letter(p: Part, text: string)
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
local function soldier(
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
		piece("Rifle", Vector3.new(1, 1, 15), Vector3.new(4.2, 15.5, -5.5), rgb(c.wood), false)
	rifle.CFrame = base * CFrame.new(4.2, 15.5, -4.5) * CFrame.Angles(math.rad(-8), 0, 0)
	m.Parent = parent
end

function BattleMap.build(folder: Folder, origin: Vector3, solids: { Instance })
	local halfX, halfZ, h, t = Layout.halfX, Layout.halfZ, Layout.wallHeight, Layout.wallThickness
	local c = Layout.colors
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local function group(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
		return f
	end

	-- floor: a base slab and every other checker tile on top (tiles are looks only)
	local floor = part(
		folder,
		"Floor",
		Vector3.new(halfX * 2 + t * 2, 2, halfZ * 2 + t * 2),
		at(0, -1, 0),
		rgb(c.tileA),
		true,
		solids
	)
	floor.Material = Enum.Material.Concrete
	local tiles = group("Tiles")
	for _, tile in Layout.tiles() do
		part(
			tiles,
			"Tile",
			Vector3.new(Layout.tileSize, 0.1, Layout.tileSize),
			at(tile.x, 0.05, tile.z),
			rgb(c.tileB),
			false
		)
	end

	-- start pads (looks only): red for side A, blue for side B. The fight code reads them as the
	-- start spots (parts SpawnA / SpawnB); the front of the part is the driving direction.
	local marks = group("FloorMarks")
	for side, color in { a = c.padA, b = c.padB } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.07, z)
		part(
			folder,
			"Spawn" .. string.upper(side),
			Vector3.new(26, 0.14, 18),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz)),
			rgb(color),
			false
		)
		-- white start line in front of the pad
		local lx = if side == "a" then -Layout.startLineX else Layout.startLineX
		part(marks, "StartLine", Vector3.new(1.6, 0.12, 26), at(lx, 0.11, 0), rgb(c.white), false)
	end

	-- chevrons on the floor pointing up the plateau ramps (two thin bars make an arrow)
	for _, cv in Layout.chevrons() do
		for _, side in { -1, 1 } do
			local cf = at(cv.x, 0.12, cv.z + side * 3.2)
				* CFrame.Angles(0, math.rad(side * 38 * cv.dir), 0)
			local bar =
				part(marks, "Chevron", Vector3.new(8.5, 0.12, 1.7), cf, rgb(c.chevron), false)
			bar.Material = Enum.Material.Neon
		end
	end

	-- walls: dark body, white cap, white base trim and a colored stripe on every 20-stud panel
	local wallColor = rgb(c.wall)
	local capColor = rgb(c.white)
	local walls: { { name: string, size: Vector3, cf: CFrame } } = {
		{
			name = "WallN",
			size = Vector3.new(halfX * 2 + t * 2, h, t),
			cf = at(0, h / 2, -(halfZ + t / 2)),
		},
		{
			name = "WallS",
			size = Vector3.new(halfX * 2 + t * 2, h, t),
			cf = at(0, h / 2, halfZ + t / 2),
		},
		{
			name = "WallW",
			size = Vector3.new(t, h, halfZ * 2),
			cf = at(-(halfX + t / 2), h / 2, 0),
		},
		{ name = "WallE", size = Vector3.new(t, h, halfZ * 2), cf = at(halfX + t / 2, h / 2, 0) },
	}
	for _, w in walls do
		part(folder, w.name, w.size, w.cf, wallColor, true, solids)
		local lengthways = w.size.X > w.size.Z
		part(
			marks,
			"WallCap",
			Vector3.new(
				w.size.X + (if lengthways then 0 else 1.6),
				1.2,
				w.size.Z + (if lengthways then 1.6 else 0)
			),
			w.cf * CFrame.new(0, h / 2 + 0.6, 0),
			capColor,
			false
		)
	end
	local stripes = group("WallStripes")
	local pw = Layout.panelWidth
	for i = 0, halfX * 2 // pw - 1 do
		local x = -halfX + (i + 0.5) * pw
		local color = rgb(c.stripes[i % #c.stripes + 1])
		part(stripes, "StripeN", Vector3.new(pw - 2, 5, 0.4), at(x, 4, -halfZ + 0.2), color, false)
		part(stripes, "StripeS", Vector3.new(pw - 2, 5, 0.4), at(x, 4, halfZ - 0.2), color, false)
	end
	for i = 0, halfZ * 2 // pw - 1 do
		local z = -halfZ + (i + 0.5) * pw
		local color = rgb(c.stripes[(i + 1) % #c.stripes + 1])
		part(stripes, "StripeW", Vector3.new(0.4, 5, pw - 2), at(-halfX + 0.2, 4, z), color, false)
		part(stripes, "StripeE", Vector3.new(0.4, 5, pw - 2), at(halfX - 0.2, 4, z), color, false)
	end

	-- pennants strung along both long walls
	local bunting = group("Bunting")
	for _, side in { -1, 1 } do
		part(
			bunting,
			"String",
			Vector3.new(halfX * 2, 0.25, 0.25),
			at(0, 13.4, side * (halfZ - 0.6)),
			rgb(c.white),
			false
		)
		for _, b in Layout.bunting() do
			local color = rgb(c.crayons[b.i % #c.crayons + 1])
			part(
				bunting,
				"Pennant",
				Vector3.new(4.2, 4.2, 0.25),
				at(b.x, 11.2, side * (halfZ - 0.6)) * CFrame.Angles(0, 0, math.pi / 4),
				color,
				false
			)
		end
	end

	-- chunky solid pieces: plateau, bunkers, cover blocks, corner bumpers, toy soldiers
	local deco = group("Details")
	for _, b in Layout.boxes() do
		if b.kind == "soldier" then
			soldier(folder, b, at, solids)
		else
			local cf = at(b.x, b.sy / 2, b.z) * CFrame.Angles(0, math.rad(b.yawDeg), 0)
			local p =
				part(folder, b.name, Vector3.new(b.sx, b.sy, b.sz), cf, rgb(b.color), true, solids)
			if b.kind == "plateau" then
				-- lighter lip on top, darker skirt at the foot, and a glowing red ring in the middle
				part(
					deco,
					"PlateauCap",
					Vector3.new(b.sx + 1.2, 0.8, b.sz + 1.2),
					at(0, b.sy - 0.2, 0),
					rgb(c.cap),
					false
				)
				part(
					deco,
					"PlateauSkirt",
					Vector3.new(b.sx + 2, 1.6, b.sz + 2),
					at(0, 0.8, 0),
					rgb(c.skirt),
					false
				)
				local d = b.sx - 6
				local ring = part(
					deco,
					"PlateauRing",
					Vector3.new(0.2, d, d),
					at(0, b.sy + 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(c.ring),
					false
				)
				ring.Shape = Enum.PartType.Cylinder
				ring.Material = Enum.Material.Neon
				p:SetAttribute("TopY", b.sy)
			elseif b.kind == "block" then
				studs(deco, b, at, 2, 2)
				if b.letter then
					letter(p, b.letter)
				end
			elseif b.kind == "bunker" then
				studs(deco, b, at, 1, 3)
				part(
					deco,
					"BunkerBand",
					Vector3.new(b.sx + 0.4, 2, b.sz + 0.4),
					at(b.x, 2.2, b.z),
					rgb(c.white),
					false
				)
			elseif b.kind == "bumper" then
				for k = -1, 1, 2 do
					part(
						deco,
						"BumperBand",
						Vector3.new(2.4, b.sy + 0.2, b.sz + 0.3),
						cf * CFrame.new(k * 7, 0, 0),
						rgb(c.white),
						false
					)
				end
			end
		end
	end

	-- ramps
	local ramps = Layout.ramps()
	local wedges: { WedgePart } = {}
	for _, r in ramps do
		table.insert(wedges, ramp(folder, origin, r, solids))
	end

	-- the hazard: a spinner arm over the plateau (turned every frame by `BattleMap.animate`)
	local sp = Layout.spinner
	local topY = Layout.plateau.height + sp.clearance
	local spinner = Instance.new("Model")
	spinner.Name = "Spinner"
	local hub = can(
		spinner,
		"Hub",
		sp.hubRadius * 2,
		sp.height + 2,
		origin + Vector3.new(0, Layout.plateau.height, 0),
		rgb(c.stripes[1]),
		true,
		solids
	)
	local arm = part(
		spinner,
		"Arm",
		Vector3.new(sp.radius * 2, sp.height, sp.width),
		at(0, topY + sp.height / 2, 0),
		rgb(c.stripes[2]),
		true,
		solids
	)
	for k = -1, 1, 2 do
		ball(
			spinner,
			"Tip",
			sp.height + 2,
			origin + Vector3.new(k * sp.radius, topY + sp.height / 2, 0),
			rgb(c.stripes[1]),
			true,
			solids
		)
	end
	spinner.PrimaryPart = hub
	spinner.Parent = folder
	arm:SetAttribute("Hazard", true)

	-- toy scenery outside the walls (looks only, no collision): crayons, block towers, beach balls
	local scenery = group("Scenery")
	for _, pr in Layout.scenery() do
		local color = rgb(c.crayons[pr.i % #c.crayons + 1])
		local pos = origin + Vector3.new(pr.x, 0, pr.z)
		if pr.kind == "crayon" then
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
					rgb(c.crayons[(pr.i + k) % #c.crayons + 1]),
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
				pos + Vector3.new(0, pr.size - 4, -math.sign(pr.z) * 5),
				color,
				false
			)
		end
	end

	return wedges, ramps
end

-- Run once the folder is in the workspace.
function BattleMap.verify(origin: Vector3, wedges: { WedgePart }, ramps: { Layout.Ramp })
	for i, w in wedges do
		checkRamp(w, ramps[i], origin)
	end
end

-- Turns the spinner until the arena folder is destroyed.
function BattleMap.animate(folder: Folder)
	local spinner = folder:FindFirstChild("Spinner")
	if not spinner or not spinner:IsA("Model") then
		return
	end
	local pivot = spinner:GetPivot()
	local center = pivot.Position
	local angle = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		angle += dt * Layout.spinner.speed
		spinner:PivotTo(
			CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(-center) * pivot
		)
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

return BattleMap
