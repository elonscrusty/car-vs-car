--!strict
-- The compact enclosed arena for the 1v1 auto-battle: a flat floor, four walls and a few broad
-- blocks. Built in code, one per match slot. No falling off, no hazards: HP decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleSetup = require(ReplicatedStorage.Shared.BattleSetup)

export type Arena = {
	folder: Folder,
	origin: Vector3, -- middle of the floor surface
	solids: { Instance }, -- walls and blocks (what a shell stops at)
	halfX: number,
	halfZ: number,
	toWorld: (x: number, z: number) -> Vector3,
	toLocal: (p: Vector3) -> (number, number),
	spawnPoint: (side: string) -> (Vector3, Vector3), -- world position and facing direction
	destroy: () -> (),
}

local BattleArena = {}

local SLOT_SPACING = 400 -- studs between match slots, so matches never see each other

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	solids: { Instance }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	if solids then
		table.insert(solids, p)
	end
	return p
end

function BattleArena.build(slot: number): Arena
	local cfg = BattleConfig.Arena
	local o = cfg.origin
	local origin = Vector3.new(o.x + slot * SLOT_SPACING, o.y, o.z)
	local halfX, halfZ = cfg.halfX, cfg.halfZ
	local folder = Instance.new("Folder")
	folder.Name = "BattleArena_" .. slot
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginY", origin.Y)
	folder:SetAttribute("OriginZ", origin.Z)
	folder:SetAttribute("HalfX", halfX)
	folder:SetAttribute("HalfZ", halfZ)
	folder:SetAttribute("WallHeight", cfg.wallHeight)
	local solids: { Instance } = {}

	local floor = part(
		folder,
		"Floor",
		Vector3.new(halfX * 2 + cfg.wallThickness * 2, 2, halfZ * 2 + cfg.wallThickness * 2),
		origin - Vector3.new(0, 1, 0),
		rgb(cfg.floorColor),
		solids
	)
	floor.Material = Enum.Material.Concrete

	local t, h = cfg.wallThickness, cfg.wallHeight
	local wallColor = rgb(cfg.wallColor)
	part(
		folder,
		"WallN",
		Vector3.new(halfX * 2 + t * 2, h, t),
		origin + Vector3.new(0, h / 2, -(halfZ + t / 2)),
		wallColor,
		solids
	)
	part(
		folder,
		"WallS",
		Vector3.new(halfX * 2 + t * 2, h, t),
		origin + Vector3.new(0, h / 2, halfZ + t / 2),
		wallColor,
		solids
	)
	part(
		folder,
		"WallW",
		Vector3.new(t, h, halfZ * 2),
		origin + Vector3.new(-(halfX + t / 2), h / 2, 0),
		wallColor,
		solids
	)
	part(
		folder,
		"WallE",
		Vector3.new(t, h, halfZ * 2),
		origin + Vector3.new(halfX + t / 2, h / 2, 0),
		wallColor,
		solids
	)
	for i, ob in cfg.obstacles do
		local b = part(
			folder,
			"Block" .. i,
			Vector3.new(ob.hx * 2, 6, ob.hz * 2),
			origin + Vector3.new(ob.x, 3, ob.z),
			rgb(cfg.obstacleColor),
			solids
		)
		b.Material = Enum.Material.Concrete
	end
	folder.Parent = workspace

	local arena: Arena
	arena = {
		folder = folder,
		origin = origin,
		solids = solids,
		halfX = halfX,
		halfZ = halfZ,
		toWorld = function(x: number, z: number): Vector3
			return origin + Vector3.new(x, 0, z)
		end,
		toLocal = function(p: Vector3): (number, number)
			return p.X - origin.X, p.Z - origin.Z
		end,
		spawnPoint = function(side: string): (Vector3, Vector3)
			-- A map can place its own start spots: parts named SpawnA / SpawnB inside the arena
			-- folder (the car faces the way the part's front looks).
			local marker = folder:FindFirstChild("Spawn" .. string.upper(side))
			if marker and marker:IsA("BasePart") then
				local look = marker.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
				return Vector3.new(marker.Position.X, origin.Y, marker.Position.Z), facing
			end
			local x, z, fx, fz = BattleSetup.place(side, halfX, halfZ, cfg.spawnInset, 0, 0)
			return origin + Vector3.new(x, 0, z), Vector3.new(fx, 0, fz)
		end,
		destroy = function()
			folder:Destroy()
		end,
	}
	return arena
end

return BattleArena
