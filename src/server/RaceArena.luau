--!strict
-- Builds the Crazy Race track from plain anchored parts: a big grass slab, the road (one box per
-- stretch plus a disc at every corner), a checkered start/finish line, checkpoint posts, orange
-- jump ramps and a low fence around the grass. Layout: shared/RaceTrack, numbers:
-- shared/RaceTrackConfig. Same return shape as Arena.build so GroupMatch can use it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RaceTrack = require(ReplicatedStorage.Shared.RaceTrack)
local RaceTrackConfig = require(ReplicatedStorage.Shared.RaceTrackConfig)

local Arena = require(script.Parent.Arena)

local RaceArena = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean
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
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

function RaceArena.build(origin: Vector3): Arena.Arena
	local c = RaceTrackConfig
	local model = Instance.new("Model")
	model.Name = "Arena"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	-- Grass slab, top at y = 0 (same slippery feel as the other flat arenas).
	local x0, x1, z0, z1 = RaceTrack.bounds()
	local w, d = x1 - x0, z1 - z0
	local floor = part(
		model,
		"Floor",
		Vector3.new(w, 2, d),
		CFrame.new(at((x0 + x1) / 2, -1, (z0 + z1) / 2)),
		rgb(c.colors.grass),
		true
	)
	floor.Material = Enum.Material.Grass
	floor.CustomPhysicalProperties =
		PhysicalProperties.new(0.7, GameConfig.Drive.groundFriction, 0.1, 1, 1)

	-- Fence: low walls so nobody leaves the grass.
	local fenceColor = Color3.fromRGB(70, 76, 92)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	part(model, "FenceN", Vector3.new(w, 12, 3), CFrame.new(at(cx, 6, z0)), fenceColor, true)
	part(model, "FenceS", Vector3.new(w, 12, 3), CFrame.new(at(cx, 6, z1)), fenceColor, true)
	part(model, "FenceW", Vector3.new(3, 12, d), CFrame.new(at(x0, 6, cz)), fenceColor, true)
	part(model, "FenceE", Vector3.new(3, 12, d), CFrame.new(at(x1, 6, cz)), fenceColor, true)

	-- Road: looks only (the grass slab is the floor), so jumps and driving feel the same everywhere.
	local n = RaceTrack.count()
	local road = rgb(c.colors.road)
	for i = 1, n do
		local a, b = RaceTrack.point(i), RaceTrack.point(i + 1)
		local len = RaceTrack.segmentLength(i)
		local mid = at((a.x + b.x) / 2, 0.05, (a.z + b.z) / 2)
		local dx, dz = RaceTrack.direction(i)
		local cf = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
		part(model, "Road", Vector3.new(c.roadWidth, 0.1, len), cf, road, false)
		-- yellow edge lines
		for _, side in { -1, 1 } do
			local off = cf * CFrame.new(side * (c.roadWidth / 2 - 1), 0.03, 0)
			part(model, "Edge", Vector3.new(1, 0.1, len), off, rgb(c.colors.edge), false)
		end
		-- round corner patch
		local disc = part(
			model,
			"Corner",
			Vector3.new(0.1, c.roadWidth, c.roadWidth),
			CFrame.new(at(a.x, 0.06, a.z)) * CFrame.Angles(0, 0, math.pi / 2),
			road,
			false
		)
		disc.Shape = Enum.PartType.Cylinder
		-- checkpoint posts (looks only)
		local sx, sz = -dz, dx
		for _, side in { -1, 1 } do
			part(
				model,
				"Post" .. i,
				Vector3.new(2, 16, 2),
				CFrame.new(
					at(
						a.x + sx * side * (c.roadWidth / 2 + 3),
						8,
						a.z + sz * side * (c.roadWidth / 2 + 3)
					)
				),
				if i == 1 then rgb(c.colors.line) else rgb(c.colors.edge),
				false
			)
		end
	end

	-- Start / finish line: checkered strip across the road at waypoint 1.
	local start = RaceTrack.point(1)
	local dx, dz = RaceTrack.direction(1)
	local base = CFrame.lookAt(at(start.x, 0.12, start.z), at(start.x + dx, 0.12, start.z + dz))
	local tiles = 8
	local tile = c.roadWidth / tiles
	for row = 0, 1 do
		for k = 0, tiles - 1 do
			local white = (row + k) % 2 == 0
			part(
				model,
				"FinishTile",
				Vector3.new(tile, 0.1, tile),
				base * CFrame.new(-c.roadWidth / 2 + tile * (k + 0.5), 0, (row - 0.5) * tile),
				if white then rgb(c.colors.line) else Color3.fromRGB(20, 20, 24),
				false
			)
		end
	end

	-- Jump ramps: solid wedges in the middle of a stretch, nose pointing the way the cars go.
	for _, r in c.ramps do
		local a, b = RaceTrack.point(r.seg), RaceTrack.point(r.seg + 1)
		local px, pz = a.x + (b.x - a.x) * r.t, a.z + (b.z - a.z) * r.t
		local rdx, rdz = RaceTrack.direction(r.seg)
		-- Two wedges back to back make a hill: up (high end ahead, verified in Studio), then down.
		for half = 1, 2 do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Ramp"
			wedge.Anchored = true
			wedge.Size = Vector3.new(r.width, r.height, r.length)
			local shift = (half - 1.5) * r.length -- half 1 sits before the middle, half 2 after it
			local pos = at(px + rdx * shift, r.height / 2, pz + rdz * shift)
			local face = if half == 1 then -1 else 1 -- the down slope is the up slope turned round
			wedge.CFrame = CFrame.lookAt(pos, pos + Vector3.new(rdx, 0, rdz) * face)
			wedge.Color = rgb(c.colors.ramp)
			wedge.Material = Enum.Material.SmoothPlastic
			wedge.TopSurface = Enum.SurfaceType.Smooth
			wedge.BottomSurface = Enum.SurfaceType.Smooth
			wedge.Parent = model
		end
	end

	model.Parent = workspace
	local center = at(start.x, 0, start.z)
	return { model = model, center = center, frames = { CFrame.new(center) } }
end

return RaceArena
