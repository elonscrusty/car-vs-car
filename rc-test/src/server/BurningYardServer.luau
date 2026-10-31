--!strict
-- Builds the Burning Yard look (shared/BurningYard): smouldering wreck piles + barrier rows and
-- plain floodlight masts past the corners. A calm DAY look, nothing glows. Looks only: every part
-- is anchored, not solid, not touchable, not queryable, so karts, shots and the chase cam ignore
-- all of it. Made once (it replicates like the fire pits). Light for phones: a heap and one smoke
-- emitter per pile, a few parts per mast.
--
--   local h = BurningYardServer.start({ at = function(x, y) return Vector3 end })
--   h.stop()
-- `at` turns a picture point into a world floor point (TrackData.toWorld, as the pits do).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BurningYard = require(ReplicatedStorage.Shared.BurningYard)
local GemKit = require(ReplicatedStorage.Shared.GemKit)

local BurningYardServer = {}

export type Options = { at: (x: number, y: number) -> Vector3, parent: Instance? }
export type Handle = { stop: () -> (), folder: Folder }

local RUST = Color3.fromRGB(122, 58, 34)
local SOOT = Color3.fromRGB(46, 42, 44)
local STEEL = Color3.fromRGB(58, 60, 70)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local started: Handle? = nil

local function solid(name: string, parent: Instance, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- smoke: slow dark puffs that climb and fade (one light emitter, made once)
local function smoke(parent: Instance, rate: number, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = SMOKE
	e.Rate = rate
	e.Color = ColorSequence.new(Color3.fromRGB(52, 50, 56))
	e.LightInfluence = 0.5
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(1.2, 2.4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0.6, 0.8, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(1, size * 1.8),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
end

-- A burning pile: the dead-car heap (mesh, or three rusty boxes if this server can't make one),
-- three tall flames on top, a scorch patch, an ember glow and smoke.
local function pile(i: number, spot: Vector3, yaw: number, parent: Folder)
	local m = Instance.new("Model")
	m.Name = "Pile" .. i
	local heap = GemKit.build(m, "junkCars", spot, 6.55 * BurningYard.PILE_SCALE, yaw, false)
	local top = 6.55 * BurningYard.PILE_SCALE
	if heap == nil then
		top = 2.2
		for n = 1, 3 do
			local b = solid("Wreck" .. n, m, if n == 2 then SOOT else RUST, Enum.Material.Metal)
			b.Size = Vector3.new(4.2 - n * 0.6, 0.7, 2.2 - n * 0.2)
			b.CFrame = CFrame.new(spot + Vector3.new(0, 0.35 + (n - 1) * 0.7, 0))
				* CFrame.Angles(0, yaw + n * 0.5, 0)
		end
	end
	local scorch = solid("Scorch", m, SOOT, Enum.Material.Slate)
	scorch.Shape = Enum.PartType.Cylinder
	scorch.Size = Vector3.new(0.1, 9 * BurningYard.PILE_SCALE * 2, 9 * BurningYard.PILE_SCALE * 2)
	scorch.CFrame = CFrame.new(spot + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local holder = solid("SmokeHolder", m, SOOT, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = spot + Vector3.new(0, top + 1.4, 0)
	smoke(holder, 5, 2.2)
	m.Parent = parent
end

-- a short row of concrete barriers along the wall (the mesh if there is one)
local function barriers(spot: Vector3, along: { number }, parent: Folder)
	for n = 0, 1 do
		local at = spot + Vector3.new(along[1], 0, along[2]) * n * 6
		local m = GemKit.build(
			parent,
			"junkBarrier",
			at,
			4.29 * BurningYard.BARRIER_SCALE,
			math.atan2(along[1], along[2]) + math.pi / 2,
			false
		)
		if m == nil then
			local b =
				solid("Barrier", parent, Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
			b.Size = Vector3.new(1.3, 1.0, 5)
			b.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
				* CFrame.Angles(0, math.atan2(along[1], along[2]), 0)
		end
	end
end

-- a floodlight mast past a corner: a steel pole and a dark lamp head turned toward the yard
local function tower(i: number, base: Vector3, mid: Vector3, parent: Folder)
	local h = BurningYard.TOWER_H
	local m = Instance.new("Model")
	m.Name = "Tower" .. i
	local mast = solid("Mast", m, STEEL, Enum.Material.Metal)
	mast.Size = Vector3.new(0.7, h, 0.7)
	mast.Position = base + Vector3.new(0, h / 2, 0)
	local head = solid("Head", m, Color3.fromRGB(32, 34, 44), Enum.Material.Metal)
	head.Size = Vector3.new(3.6, 2, 0.5)
	local headAt = base + Vector3.new(0, h + 1, 0)
	head.CFrame = CFrame.lookAt(headAt, Vector3.new(mid.X, headAt.Y - 6, mid.Z))
	m.Parent = parent
end

function BurningYardServer.start(opts: Options): Handle
	if started then
		started.stop()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BurningYard"
	folder.Parent = opts.parent or workspace
	for i, p in BurningYard.PILES do
		local spot = opts.at(p.x, p.y)
		pile(i, spot, p.yaw, folder)
		local off = opts.at(
			p.x + p.along[1] * BurningYard.BARRIER_GAP,
			p.y + p.along[2] * BurningYard.BARRIER_GAP
		)
		barriers(off, p.along, folder)
	end
	local mid = opts.at(120, 120)
	for i, t in BurningYard.TOWERS do
		tower(i, opts.at(t[1], t[2]), mid, folder)
	end
	local handle: Handle
	handle = {
		stop = function()
			folder:Destroy()
			if started == handle then
				started = nil
			end
		end,
		folder = folder,
	}
	started = handle
	return handle
end

return BurningYardServer
