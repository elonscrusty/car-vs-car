--!strict
-- Small part builders shared by the battle map and lobby files (BattleMap, MapDecor, Lobby*) and by
-- the client's practice yard (PracticeYard). server/MapParts.luau hands this same module out.

local MapParts = {}

function MapParts.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function MapParts.shade(c: { number }, k: number): Color3
	return Color3.fromRGB(
		math.clamp(math.floor(c[1] * k), 0, 255),
		math.clamp(math.floor(c[2] * k), 0, 255),
		math.clamp(math.floor(c[3] * k), 0, 255)
	)
end

-- One anchored part. `solid` pieces are hit by cars and stop shells (and go in `solids`); the rest
-- are looks only (no collision, no query, no touch, no shadow).
function MapParts.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean,
	solids: { Instance }?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
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

-- A cylinder standing up: height `h`, diameter `d`, bottom at `pos`.
function MapParts.can(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	pos: Vector3,
	color: Color3,
	solid: boolean,
	solids: { Instance }?,
	material: Enum.Material?
): Part
	local p = MapParts.part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		solid,
		solids,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function MapParts.ball(
	parent: Instance,
	name: string,
	d: number,
	pos: Vector3,
	color: Color3,
	solid: boolean,
	solids: { Instance }?,
	material: Enum.Material?
): Part
	local p = MapParts.part(
		parent,
		name,
		Vector3.new(d, d, d),
		CFrame.new(pos),
		color,
		solid,
		solids,
		material
	)
	p.Shape = Enum.PartType.Ball
	return p
end

function MapParts.group(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

return MapParts
