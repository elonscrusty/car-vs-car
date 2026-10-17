--!strict
-- Builds the bowl arena from plain parts: flat floor, 32 tilted slope slabs, low bumper walls,
-- and two launch pads. All anchored. Everything is positioned around `origin`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Arena = {
	model: Model,
	center: Vector3,
	frames: { CFrame }, -- [1] = player side, [2] = bot side (rotated around the middle)
}

local Arena = {}

local function makePart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function Arena.build(origin: Vector3): Arena
	local cfg = GameConfig.Arena
	local tilt = math.rad(cfg.tiltDeg)
	local model = Instance.new("Model")
	model.Name = "Arena"

	local function height(r: number): number
		return ArenaMath.surfaceHeight(r, cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg)
	end

	-- Flat floor (a cylinder standing on its side is a disc: axis X -> rotate to Y).
	local floorR = cfg.flatRadius + 4
	local floor = makePart(
		model,
		"Floor",
		Vector3.new(2, floorR * 2, floorR * 2),
		CFrame.new(origin + Vector3.new(0, -1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(110, 190, 95)
	)
	floor.Shape = Enum.PartType.Cylinder

	-- Slope slabs around the circle. Each slab sits in a frame turned by phi around Y.
	local thick = 2
	local midR = (cfg.flatRadius + cfg.rimRadius) / 2
	local slabSize = Vector3.new(
		ArenaMath.slabWidth(cfg.rimRadius, cfg.segments),
		thick,
		ArenaMath.slopeLength(cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg) + 2
	)
	local wallSize = Vector3.new(slabSize.X * 1.02, cfg.wallHeight, 3)
	for i = 0, cfg.segments - 1 do
		local phi = i / cfg.segments * math.pi * 2
		local base = CFrame.new(origin) * CFrame.Angles(0, phi, 0)
		local slabCf = base
			* CFrame.new(0, height(midR), -midR)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, -thick / 2, 0)
		local color = Color3.fromRGB(95, 175, 85)
		if i % 2 == 0 then
			color = Color3.fromRGB(120, 195, 100)
		end
		makePart(model, "Slope", slabSize, slabCf, color)

		local wallCf = base
			* CFrame.new(
				0,
				height(cfg.rimRadius) + cfg.wallHeight / 2 - 0.5,
				-(cfg.rimRadius + 0.5)
			)
		local wallColor = Color3.fromRGB(245, 245, 245)
		if i % 2 == 0 then
			wallColor = Color3.fromRGB(225, 60, 60)
		end
		makePart(model, "Wall", wallSize, wallCf, wallColor)
	end

	-- Two launch frames on opposite sides, plus a glowing pad on each.
	local frames: { CFrame } = {}
	for idx = 1, 2 do
		local base = CFrame.new(origin) * CFrame.Angles(0, if idx == 1 then 0 else math.pi, 0)
		frames[idx] = base
		local padCf = base
			* CFrame.new(0, height(cfg.spawnRadius), -cfg.spawnRadius)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, 0.15, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
		local pad = makePart(
			model,
			"LaunchPad",
			Vector3.new(0.3, 14, 14),
			padCf,
			if idx == 1 then Color3.fromRGB(80, 230, 120) else Color3.fromRGB(255, 160, 60)
		)
		pad.Shape = Enum.PartType.Cylinder
		pad.Material = Enum.Material.Neon
		pad.CanCollide = false
	end

	model.Parent = workspace
	return { model = model, center = origin, frames = frames }
end

-- Where to put car `idx` (1 or 2): on its launch pad, nose pointing at the middle (downhill).
function Arena.carCFrame(arena: Arena, idx: number, halfHeight: number): CFrame
	local cfg = GameConfig.Arena
	local h = ArenaMath.surfaceHeight(cfg.spawnRadius, cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg)
	return arena.frames[idx]
		* CFrame.new(0, h, -cfg.spawnRadius)
		* CFrame.Angles(math.rad(cfg.tiltDeg), 0, 0)
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.new(0, halfHeight + 0.6, 0)
end

-- Flat direction from car `idx`'s launch spot toward the middle.
function Arena.inwardDirection(arena: Arena, idx: number): Vector3
	return arena.frames[idx]:VectorToWorldSpace(Vector3.new(0, 0, 1))
end

return Arena
