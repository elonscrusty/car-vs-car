--!strict
-- Night weeds for the junkyard floor (carter picked "A Night weeds", 2026-10-30): small tufts of thin
-- low-poly grass blades and a few pale flower dots, in clusters along the wall foot and out on the floor.
-- Looks only: anchored, no touch, no collide, no query, no shadows. Data: GrassBitsData (generated).
--
-- Each blade is one thin WedgePart. A part is cheap but not free, so `keep` (0 to 1, default 0.4) thins the
-- tufts: every tenth tuft is kept or dropped in a fixed pattern (the same tufts every time).

local GrassKit = {}

local DEFAULT_KEEP = 0.4
local BLADE_THICK = 0.1 -- big units

export type Data = {
	kinds: { [string]: { { x: number, z: number, yaw: number, lean: number, h: number, w: number, c: { number } } } },
	tufts: { { k: string, x: number, z: number, yaw: number, s: number } },
	dots: { { x: number, y: number, z: number, r: number, yaw: number, c: { number } } },
}

local function colour(c: { number }): Color3
	return Color3.fromRGB(c[1] :: number, c[2] :: number, c[3] :: number)
end

local function looksOnly(p: BasePart, color: Color3, material: Enum.Material)
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- how many parts build() makes for this `keep`
function GrassKit.count(data: Data, keep: number?): number
	local k = math.clamp(keep or DEFAULT_KEEP, 0, 1)
	local n = #data.dots
	for i, t in data.tufts do
		if (i - 1) % 10 < math.floor(k * 10 + 0.5) then
			n += #data.kinds[t.k]
		end
	end
	return n
end

-- Builds the weeds in a "GrassBits" folder under `parent`. `centre` is the arena centre, `unit` the stud size
-- of one big unit.
function GrassKit.build(parent: Instance, data: Data, centre: Vector3, unit: number, keep: number?): Folder
	local k = math.clamp(keep or DEFAULT_KEEP, 0, 1)
	local folder = Instance.new("Folder")
	folder.Name = "GrassBits"
	for i, t in data.tufts do
		if (i - 1) % 10 >= math.floor(k * 10 + 0.5) then
			continue
		end
		local base = CFrame.new(centre + Vector3.new(t.x, 0, t.z) * unit) * CFrame.Angles(0, t.yaw, 0)
		for _, b in data.kinds[t.k] do
			local h, w = b.h * t.s * unit, b.w * t.s * unit
			local cf = base
				* CFrame.new(b.x * t.s * unit, 0, b.z * t.s * unit)
				* CFrame.Angles(0, b.yaw, 0)
				* CFrame.Angles(b.lean, 0, 0)
				* CFrame.new(0, h / 2, 0)
			local p = Instance.new("WedgePart")
			p.Name = "Blade"
			p.Size = Vector3.new(BLADE_THICK * unit, h, w)
			p.CFrame = cf
			looksOnly(p, colour(b.c), Enum.Material.SmoothPlastic)
			p.Parent = folder
		end
	end
	for _, d in data.dots do
		local s = d.r * 1.5 * unit
		local p = Instance.new("Part")
		p.Name = "FlowerDot"
		p.Size = Vector3.new(s, s, s)
		p.CFrame = CFrame.new(centre + Vector3.new(d.x, d.y, d.z) * unit) * CFrame.Angles(0.6, d.yaw, 0.5)
		looksOnly(p, colour(d.c), Enum.Material.Neon)
		p.Parent = folder
	end
	folder.Parent = parent
	return folder
end

return GrassKit
