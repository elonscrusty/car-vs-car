--!strict
-- Builds the bowl arena from plain parts: flat floor, 32 tilted slope slabs, low bumper walls,
-- two launch pads and the scenery around it (ArenaScenery). All anchored. Everything is positioned around `origin`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ArenaDecor = require(script.Parent.ArenaDecor)
local ArenaScenery = require(script.Parent.ArenaScenery)
local ArenaProps = require(script.Parent.ArenaProps)
local ArenaStadium = require(script.Parent.ArenaStadium)

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
	-- Slippery ground: cars slide and keep momentum (their own grip code handles steering).
	p.CustomPhysicalProperties =
		PhysicalProperties.new(0.7, GameConfig.Drive.groundFriction, 0.1, 1, 1)
	p.Parent = model
	return p
end

-- `arenaCfg` = another arena shape (the flat fight arena); nil = the normal bowl.
function Arena.build(origin: Vector3, arenaCfg: any?): Arena
	local cfg = arenaCfg or GameConfig.Arena
	local tilt = math.rad(cfg.tiltDeg)
	local model = Instance.new("Model")
	model.Name = "Arena"
	-- Always send the whole arena to clients (the camera has no avatar, so streaming would skip it).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

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
		if cfg.dirt then Color3.fromRGB(150, 98, 60) else Color3.fromRGB(88, 112, 150)
	)
	floor.Shape = Enum.PartType.Cylinder
	floor.Material = if cfg.dirt then Enum.Material.Ground else Enum.Material.Concrete

	if cfg.stadium and cfg.dirt then
		ArenaProps.floorArt(model, origin, cfg.flatRadius, Color3.fromRGB(150, 98, 60))
	end

	-- A faint darker ring line near the edge of the flat floor (looks only, nothing to bump into).
	local lineR = cfg.flatRadius - 1
	for idx, d in { { r = lineR + 0.5, c = 205 }, { r = lineR - 0.5, c = 88 } } do
		local disc = makePart(
			model,
			"FloorLine",
			Vector3.new(0.1, d.r * 2, d.r * 2),
			CFrame.new(origin + Vector3.new(0, 0.03 * idx, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			if d.c == 88
				then if cfg.dirt then Color3.fromRGB(150, 98, 60) else Color3.fromRGB(88, 112, 150)
				else Color3.fromRGB(d.c, d.c + 10, d.c + 30)
		)
		disc.Shape = Enum.PartType.Cylinder
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.CastShadow = false
	end

	-- Slope slabs around the circle. Each slab sits in a frame turned by phi around Y.
	local thick = 2
	local midR = (cfg.flatRadius + cfg.rimRadius) / 2
	local slabSize = Vector3.new(
		ArenaMath.slabWidth(cfg.rimRadius, cfg.segments),
		thick,
		ArenaMath.slopeLength(cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg) + 2
	)
	local wallSize = Vector3.new(slabSize.X * 1.02, cfg.wallHeight, 3)
	local flat = cfg.tiltDeg == 0
	for i = 0, cfg.segments - 1 do
		local phi = i / cfg.segments * math.pi * 2
		local base = CFrame.new(origin) * CFrame.Angles(0, phi, 0)
		local slabCf = base
			* CFrame.new(0, height(midR), -midR)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, -thick / 2, 0)
		local color = Color3.fromRGB(116, 140, 178) -- one plain tone: no sunburst stripes
		if not flat then
			local slab = makePart(model, "Slope", slabSize, slabCf, color)
			-- Very slippery: a car that stops on the slope slides back down to the middle.
			slab.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.1, 1, 1)
			slab.Material = Enum.Material.Concrete
		end

		local wallCf = base
			* CFrame.new(
				0,
				height(cfg.rimRadius) + cfg.wallHeight / 2 - 0.5,
				-(cfg.rimRadius + 0.5)
			)
		local wallColor = Color3.fromRGB(250, 205, 60)
		if i % 2 == 0 then
			wallColor = Color3.fromRGB(55, 95, 150)
		end
		local gap = cfg.gapEvery ~= nil and i % cfg.gapEvery < 2
		if not gap then
			local wall = makePart(model, "Wall", wallSize, wallCf, wallColor)
			if cfg.stadium then
				wall.Color = if i % 2 == 0
					then Color3.fromRGB(240, 242, 250)
					else Color3.fromRGB(235, 60, 55)
				ArenaProps.wallStrip(model, wall, Color3.fromRGB(120, 215, 255))
			end
		end
	end

	-- Obstacles (flat arena): boxes and round pillars standing on the floor.
	local spinnerBars: { Part } = {}
	for _, o in cfg.obstacles do
		local pos = origin + Vector3.new(o.x, (o.sy or 0) / 2, o.z)
		local color = Color3.fromRGB(150, 150, 165)
		if o.kind == "spinner" then
			-- A heavy bar driven round by a motor on an invisible hub, so it shoves cars properly.
			local hub = makePart(
				model,
				"SpinnerHub",
				Vector3.one,
				CFrame.new(origin + Vector3.new(o.x, 3, o.z)),
				color
			)
			hub.Transparency = 1
			hub.CanCollide = false
			hub.CanQuery = false
			local bar = makePart(
				model,
				"Obstacle",
				Vector3.new(o.sx, o.sy, 2.5),
				CFrame.new(origin + Vector3.new(o.x, 3, o.z)),
				Color3.fromRGB(235, 70, 60)
			)
			bar.Anchored = false
			bar.CustomPhysicalProperties = PhysicalProperties.new(60, 0.3, 0.2, 1, 1)
			local a0 = Instance.new("Attachment")
			a0.CFrame = CFrame.Angles(0, 0, math.pi / 2) -- turn the hinge axis to point up
			a0.Parent = hub
			local a1 = Instance.new("Attachment")
			a1.CFrame = CFrame.Angles(0, 0, math.pi / 2)
			a1.Parent = bar
			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = a0
			hinge.Attachment1 = a1
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.AngularVelocity = o.spin or 1
			hinge.MotorMaxTorque = 1e9
			hinge.Parent = bar
			table.insert(spinnerBars, bar)
			if cfg.stadium then
				ArenaProps.dressHammer(model, bar, origin + Vector3.new(o.x, 0, o.z), origin.Y)
			end
		elseif o.kind == "ramp" then
			local rampTilt = math.rad(18)
			local len = o.sz or o.sx
			local rise = len / 2 * math.sin(rampTilt)
			local ramp = makePart(
				model,
				"Obstacle",
				Vector3.new(o.sx, 1, len),
				CFrame.new(origin + Vector3.new(o.x, rise + 0.2, o.z))
					* CFrame.Angles(0, math.rad(o.yaw or 0), 0)
					* CFrame.Angles(rampTilt, 0, 0),
				Color3.fromRGB(240, 200, 40)
			)
			if cfg.stadium then
				ArenaProps.dressRamp(model, ramp)
			end
		elseif o.kind == "pillar" then
			local pillar = makePart(
				model,
				"Obstacle",
				Vector3.new(o.sy, o.sx, o.sx),
				CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
				color
			)
			pillar.Shape = Enum.PartType.Cylinder
			if cfg.stadium then
				ArenaProps.dressPillar(model, pillar)
			end
		else
			local block = makePart(
				model,
				"Obstacle",
				Vector3.new(o.sx, o.sy, o.sz or o.sx),
				CFrame.new(pos),
				color
			)
			if cfg.stadium then
				ArenaProps.dressBlock(model, block)
			end
		end
	end

	-- Two launch frames on opposite sides, plus a glowing pad on each.
	local frames: { CFrame } = {}
	for idx = 1, 2 do
		local base = CFrame.new(origin) * CFrame.Angles(0, if idx == 1 then 0 else math.pi, 0)
		frames[idx] = base
		if cfg.noPads then
			continue
		end
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

	if cfg.stadium then
		ArenaStadium.build(model, origin, cfg)
	else
		ArenaScenery.build(model, origin)
		ArenaDecor.build(model, origin)
	end

	model.Parent = workspace
	for _, bar in spinnerBars do
		bar:SetNetworkOwner(nil) -- the server turns the bar (needs to be in the workspace first)
	end
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
