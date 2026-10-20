--!strict
-- Builds the 1v1 battle map "Toy Box Showdown" from `BattleMapLayout` (all numbers live there).
-- Bright toy-car look: flat colors, chunky pieces, a checker floor. About 130 parts, cheap on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.BattleMapLayout)

local BattleMap = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

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

function BattleMap.build(folder: Folder, origin: Vector3, solids: { Instance })
	local halfX, halfZ, h, t = Layout.halfX, Layout.halfZ, Layout.wallHeight, Layout.wallThickness
	local c = Layout.colors
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
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
	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
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
	tiles.Parent = folder

	-- start pads (looks only): red for side A, blue for side B
	for side, color in { a = c.padA, b = c.padB } do
		local x, z = Layout.spawn(side)
		part(folder, "Pad_" .. side, Vector3.new(18, 0.14, 26), at(x, 0.07, z), rgb(color), false)
	end

	-- walls, with a colored stripe on each 20-stud panel of the inside face
	local wallColor = rgb(c.wall)
	part(
		folder,
		"WallN",
		Vector3.new(halfX * 2 + t * 2, h, t),
		at(0, h / 2, -(halfZ + t / 2)),
		wallColor,
		true,
		solids
	)
	part(
		folder,
		"WallS",
		Vector3.new(halfX * 2 + t * 2, h, t),
		at(0, h / 2, halfZ + t / 2),
		wallColor,
		true,
		solids
	)
	part(
		folder,
		"WallW",
		Vector3.new(t, h, halfZ * 2),
		at(-(halfX + t / 2), h / 2, 0),
		wallColor,
		true,
		solids
	)
	part(
		folder,
		"WallE",
		Vector3.new(t, h, halfZ * 2),
		at(halfX + t / 2, h / 2, 0),
		wallColor,
		true,
		solids
	)
	local stripes = Instance.new("Folder")
	stripes.Name = "WallStripes"
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
	stripes.Parent = folder

	-- chunky solid pieces: plateau, bunkers, cover blocks, corner bumpers
	for _, b in Layout.boxes() do
		local cf = at(b.x, b.sy / 2, b.z) * CFrame.Angles(0, math.rad(b.yawDeg), 0)
		local p =
			part(folder, b.name, Vector3.new(b.sx, b.sy, b.sz), cf, rgb(b.color), true, solids)
		if b.name == "Plateau" then
			-- a red ring on top marks the middle of the fight
			local ring = part(
				folder,
				"PlateauRing",
				Vector3.new(0.2, b.sx - 8, b.sx - 8),
				at(0, b.sy + 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(c.ring),
				false
			)
			ring.Shape = Enum.PartType.Cylinder
			p:SetAttribute("TopY", b.sy)
		end
	end

	-- ramps
	local ramps = Layout.ramps()
	local wedges: { WedgePart } = {}
	for _, r in ramps do
		table.insert(wedges, ramp(folder, origin, r, solids))
	end

	-- toy scenery outside the walls (looks only, no collision)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	local palette = { c.stripes[1], c.stripes[2], c.stripes[3], c.blocks[1], c.blocks[2], c.bunker }
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for k = 1, 3 do
				n += 1
				local size = 14 + (n * 7) % 12
				local x = sx * (halfX + 16 + (k - 1) * 18 + (n % 3) * 4)
				local z = sz * (halfZ - 6 + (k - 1) * 24)
				part(
					scenery,
					"ToyBlock",
					Vector3.new(size, size, size),
					at(x, size / 2, z) * CFrame.Angles(0, math.rad(n * 23), 0),
					rgb(palette[n % #palette + 1]),
					false
				)
			end
			-- corner flag pole
			local px, pz = sx * (halfX + 4), sz * (halfZ + 4)
			local pole =
				part(scenery, "Pole", Vector3.new(1, 34, 1), at(px, 17, pz), rgb(c.wall), false)
			pole.Shape = Enum.PartType.Cylinder
			pole.CFrame = at(px, 17, pz) * CFrame.Angles(0, 0, math.pi / 2)
			pole.Size = Vector3.new(34, 1, 1)
			part(
				scenery,
				"Flag",
				Vector3.new(0.4, 6, 10),
				at(px, 30, pz - sz * 5),
				rgb(palette[(n + 2) % #palette + 1]),
				false
			)
		end
	end
	scenery.Parent = folder

	-- spawn markers the fight code can read: Part "SpawnA" / "SpawnB" (look = driving direction)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for side, name in { a = "SpawnA", b = "SpawnB" } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0, z)
		local m = part(
			spawns,
			name,
			Vector3.new(4, 0.2, 4),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz)),
			rgb(c.padA),
			false
		)
		m.Transparency = 1
	end
	spawns.Parent = folder

	return wedges, ramps
end

-- Run once the folder is in the workspace.
function BattleMap.verify(origin: Vector3, wedges: { WedgePart }, ramps: { Layout.Ramp })
	for i, w in wedges do
		checkRamp(w, ramps[i], origin)
	end
end

return BattleMap
