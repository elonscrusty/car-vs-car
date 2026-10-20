--!strict
-- The enclosed 1v1 battle arena, one per match slot: "Duel Car Arena" (see DuelArena and
-- DuelArenaLayout). Walls all round, nothing to fall out of; HP decides. The old toy bedroom map
-- (BattleMap, BattleMapLayout, MapDecor) is kept: set THEME to "toy" to bring it back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleMapLayout = require(ReplicatedStorage.Shared.BattleMapLayout)
local DuelArenaLayout = require(ReplicatedStorage.Shared.DuelArenaLayout)
local BattleMap = require(script.Parent.BattleMap)
local DuelArena = require(script.Parent.DuelArena)
local ChaseMapLayout = require(ReplicatedStorage.Shared.ChaseMapLayout)
local ChaseMap = require(script.Parent.ChaseMap)

local THEME = "chase" -- "chase" = Wreck City, "duel" = Duel Car Arena, "toy" = the toy bedroom
local Layout: any = if THEME == "toy"
	then BattleMapLayout
	elseif THEME == "duel" then DuelArenaLayout
	else ChaseMapLayout

export type Arena = {
	folder: Folder,
	origin: Vector3, -- middle of the floor surface
	solids: { Instance }, -- walls and blocks (what a shell stops at)
	halfX: number,
	halfZ: number,
	toWorld: (x: number, z: number) -> Vector3,
	toLocal: (p: Vector3) -> (number, number),
	spawnPoint: (side: string) -> (Vector3, Vector3), -- world position and facing direction
	-- Duel arena dressing (no-ops on the toy map). Side a is the west garage, side b the east one.
	setNames: (a: string, b: string) -> (), -- the glowing name signs
	setTeams: (aIsRed: boolean) -> (), -- which side is red and which blue
	openDoors: () -> (), -- the garage roller doors roll up (at GO)
	closeDoors: () -> (),
	-- Wreck City live parts (no-ops on the other maps): once per fight frame, with each side's car
	-- body. Smashes props and returns the cars the crane hit.
	tick: (dt: number, bodies: { [string]: BasePart }) -> { ChaseMap.Hit },
	-- where to put a stuck or fallen car back (world position, facing)
	rescuePoint: (pos: Vector3) -> (Vector3, Vector3),
	resetBreakables: () -> (), -- smashed props come back (new round)
	destroy: () -> (),
}

local BattleArena = {}

local SLOT_SPACING = 520 -- studs between match slots, so matches never see each other

function BattleArena.build(slot: number): Arena
	local cfg = BattleConfig.Arena
	local o = cfg.origin
	local origin = Vector3.new(o.x + slot * SLOT_SPACING, o.y, o.z)
	local halfX, halfZ = Layout.halfX, Layout.halfZ
	local folder = Instance.new("Folder")
	folder.Name = "BattleArena_" .. slot
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginY", origin.Y)
	folder:SetAttribute("OriginZ", origin.Z)
	folder:SetAttribute("HalfX", halfX)
	folder:SetAttribute("HalfZ", halfZ)
	folder:SetAttribute("WallHeight", Layout.wallHeight)
	local solids: { Instance } = {}

	local controls: any = nil
	if THEME == "toy" then
		local wedges, ramps = BattleMap.build(folder, origin, solids)
		folder.Parent = workspace
		BattleMap.verify(origin, wedges, ramps)
		BattleMap.animate(folder)
	elseif THEME == "duel" then
		controls = DuelArena.build(folder, origin, solids)
		folder.Parent = workspace
	else
		controls = ChaseMap.build(folder, origin, solids)
		folder.Parent = workspace
		controls.verify()
	end

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
			local x, z, fx, fz = Layout.spawn(side)
			return origin + Vector3.new(x, 0, z), Vector3.new(fx, 0, fz)
		end,
		setNames = function(a: string, b: string)
			if controls then
				controls.setNames(a, b)
			end
		end,
		setTeams = function(aIsRed: boolean)
			if controls then
				controls.setTeams(aIsRed)
			end
		end,
		openDoors = function()
			if controls then
				controls.openDoors()
			end
		end,
		closeDoors = function()
			if controls then
				controls.closeDoors()
			end
		end,
		tick = function(dt: number, bodies: { [string]: BasePart }): { ChaseMap.Hit }
			if controls and controls.tick then
				return controls.tick(dt, bodies)
			end
			return {}
		end,
		rescuePoint = function(pos: Vector3): (Vector3, Vector3)
			if controls and controls.rescuePoint then
				return controls.rescuePoint(pos)
			end
			return origin + Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)
		end,
		resetBreakables = function()
			if controls and controls.resetBreakables then
				controls.resetBreakables()
			end
		end,
		destroy = function()
			folder:Destroy()
		end,
	}
	return arena
end

return BattleArena
