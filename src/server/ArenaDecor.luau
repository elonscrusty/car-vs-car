--!strict
-- Blender dressing for the bowl (ServerStorage.Models.Bowl): the plain scenery props are swapped
-- for models at the same spots (barriers, tires, cones, light towers, hills, trees, rocks), and
-- a striped rim, grandstands and flags are added. Look only. A missing model keeps the plain prop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local ArenaLookConfig = require(ReplicatedStorage.Shared.ArenaLookConfig)
local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyDecor = require(script.Parent.LobbyDecor)

local ArenaDecor = {}

local TREES = { "Tree_Round" }
local ROCKS = { { "Rock_A", 6.6 }, { "Rock_B", 4.5 } }

-- Plain props that a model replaces (parts of the same prop go together).
local SWAP: { [string]: { string } } = {
	Barrier = { "Barrier", "BarrierBar" },
	TireStack = { "Tire" },
	Cone = { "Cone", "ConeBase" },
	LightTower = { "TowerPost", "TowerLamp", "TowerPanel" },
	Hill = { "Hill" },
	Tree = { "Trunk", "Leaves" },
	Rock = { "Rock" },
	Cloud = { "Cloud" },
}

function ArenaDecor.build(model: Model, origin: Vector3)
	local scenery = model:FindFirstChild("Scenery")
	if scenery == nil then
		return
	end
	local cfg = GameConfig.Arena
	local look = ArenaLookConfig
	local ground = origin.Y
		+ ArenaMath.surfaceHeight(cfg.rimRadius, cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg)
	local group = Instance.new("Folder")
	group.Name = "BowlDecor"
	group.Parent = model

	local function has(name: string): boolean
		return LobbyDecor.has(name, "Bowl")
	end

	-- Take away the plain parts of a prop (only when its model exists).
	local function clearPlain(prop: string)
		local names: { [string]: boolean } = {}
		for _, n in SWAP[prop] do
			names[n] = true
		end
		for _, d in scenery:GetChildren() do
			if names[d.Name] then
				d:Destroy()
			end
		end
	end

	local function put(name: string, cf: CFrame, scale: number)
		local m = LobbyDecor.clone(name, group, nil, "Bowl")
		if m then
			m:ScaleTo(m:GetScale() * scale)
			m:PivotTo(cf)
		end
	end
	local function at(s: ArenaLayout.Spot, up: number): CFrame
		return CFrame.new(origin.X + s.x, ground + up, origin.Z + s.z)
			* CFrame.Angles(0, math.rad(s.yawDeg), 0)
	end
	if has("Barrier") then
		clearPlain("Barrier")
		for _, s in ArenaLayout.barrierSpots() do
			put("Barrier", at(s, 0), look.barriers.length / 8)
		end
	end
	if has("TireStack") then
		clearPlain("TireStack")
		for _, s in ArenaLayout.tireStacks() do
			put("TireStack", at(s, 0), if s.n >= 3 then 1 else 0.75)
		end
	end
	if has("Cone") then
		clearPlain("Cone")
		for _, s in ArenaLayout.coneSpots() do
			put("Cone", at(s, 0), 1)
		end
	end
	if has("LightTower") then
		clearPlain("LightTower")
		for _, s in ArenaLayout.towerSpots() do
			put("LightTower", at(s, 0) * CFrame.Angles(0, math.pi, 0), look.towers.height / 32.9)
		end
	end
	if has("Hill") then
		clearPlain("Hill")
		for _, s in ArenaLayout.hillSpots() do
			put("Hill", at(s, -1), s.scale * 2 / 52)
		end
	end
	if has("Tree_Round") and has("Tree_Palm") and has("Tree_Pine") then
		clearPlain("Tree")
		for i, s in ArenaLayout.treeSpots() do
			put(TREES[i % #TREES + 1], at(s, 0), 0.8 + 0.25 * s.scale)
		end
	end
	if has("Rock_A") and has("Rock_B") then
		clearPlain("Rock")
		for i, s in ArenaLayout.rockSpots() do
			local r = ROCKS[i % #ROCKS + 1]
			put(r[1] :: string, at(s, 0), s.scale * 1.2 / (r[2] :: number))
		end
	end

	-- Soft Blender clouds at the same sky spots as the plain white puffs.
	local CLOUDS = { "Cloud_A", "Cloud_B", "Cloud_C" }
	if has("Cloud_A") and has("Cloud_B") and has("Cloud_C") then
		clearPlain("Cloud")
		for i, s in ArenaLayout.cloudSpots() do
			put(CLOUDS[i % #CLOUDS + 1], at(s, s.y), s.scale * 1.6)
		end
	end

	-- No grandstands, flags, finish arch, pit walls, boards or towers: the ring is a plain steel band.
end

return ArenaDecor
