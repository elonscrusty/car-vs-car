--!strict
-- The enclosed 1v1 battle arena, one per match slot: "Toy Box Showdown" (see BattleMap and
-- BattleMapLayout). Four walls, nothing to fall out of; HP decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleMapLayout = require(ReplicatedStorage.Shared.BattleMapLayout)
local BattleMap = require(script.Parent.BattleMap)

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

local SLOT_SPACING = 520 -- studs between match slots, so matches never see each other

function BattleArena.build(slot: number): Arena
	local cfg = BattleConfig.Arena
	local o = cfg.origin
	local origin = Vector3.new(o.x + slot * SLOT_SPACING, o.y, o.z)
	local halfX, halfZ = BattleMapLayout.halfX, BattleMapLayout.halfZ
	local folder = Instance.new("Folder")
	folder.Name = "BattleArena_" .. slot
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginY", origin.Y)
	folder:SetAttribute("OriginZ", origin.Z)
	folder:SetAttribute("HalfX", halfX)
	folder:SetAttribute("HalfZ", halfZ)
	folder:SetAttribute("WallHeight", cfg.wallHeight)
	local solids: { Instance } = {}

	local wedges, ramps = BattleMap.build(folder, origin, solids)
	folder.Parent = workspace
	BattleMap.verify(origin, wedges, ramps)
	BattleMap.animate(folder)

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
			-- the map's own start pads: parts SpawnA / SpawnB in the arena folder (front = driving direction)
			local marker = folder:FindFirstChild("Spawn" .. string.upper(side))
			if marker and marker:IsA("BasePart") then
				local look = marker.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
				return Vector3.new(marker.Position.X, origin.Y, marker.Position.Z), facing
			end
			local x, z, fx, fz = BattleMapLayout.spawn(side)
			return origin + Vector3.new(x, 0, z), Vector3.new(fx, 0, fz)
		end,
		destroy = function()
			folder:Destroy()
		end,
	}
	return arena
end

return BattleArena
