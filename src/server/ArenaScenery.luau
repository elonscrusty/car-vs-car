--!strict
-- The toy world around the bowl: curb and steel skirt, ring road, props, towers, trees, hills,
-- ocean and clouds. All anchored plain parts in a "Scenery" folder inside the arena model. The
-- ground outside the bowl is as high as the rim, so the bowl looks sunk into the ground. Only the
-- curb, skirt and ring road are solid (a car knocked out lands on them); the rest is decoration.
-- About 380 parts. Where things go comes from ArenaLayout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local ArenaLookConfig = require(ReplicatedStorage.Shared.ArenaLookConfig)
local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local ArenaThemes = require(ReplicatedStorage.Shared.ArenaThemes)
local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ArenaScenery = {}

local ASPHALT = Color3.fromRGB(70, 72, 82)
local YELLOW = Color3.fromRGB(255, 205, 40)
local BLACK = Color3.fromRGB(30, 30, 36)
local WHITE = Color3.fromRGB(245, 245, 245)
local RED = Color3.fromRGB(230, 55, 55)
local STEEL = Color3.fromRGB(55, 60, 72)
local GREEN = Color3.fromRGB(110, 200, 90)
local GREEN_DARK = Color3.fromRGB(80, 175, 75)

function ArenaScenery.build(model: Model, origin: Vector3)
	local cfg = GameConfig.Arena
	local look = ArenaLookConfig
	-- Weekly look: only colors change (rim wall stripes, grass tint), never sizes.
	local theme = ArenaThemes.forWeek(Leaderboard.weekIndex(os.time()))
	local wallIdx = 0
	for _, w in model:GetChildren() do
		if w.Name == "Wall" and w:IsA("BasePart") then
			local c = if wallIdx % 2 == 0 then theme.rimA else theme.rimB
			w.Color = Color3.fromRGB(c[1], c[2], c[3])
			wallIdx += 1
		end
	end
	-- Ground level outside the bowl = rim height.
	local ground = origin.Y
		+ ArenaMath.surfaceHeight(cfg.rimRadius, cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg)

	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = model

	local function part(
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
		p.CanCollide = solid
		p.CanTouch = solid
		p.CanQuery = solid
		p.CastShadow = false
		p.Parent = folder
		return p
	end

	-- A spot from the layout, `up` studs above the ground, turned by its yaw.
	local function at(s: ArenaLayout.Spot, up: number): CFrame
		return CFrame.new(origin.X + s.x, ground + up, origin.Z + s.z)
			* CFrame.Angles(0, math.rad(s.yawDeg), 0)
	end

	-- A flat ring made of boxes (top at `top`, `thick` deep), turned so each box's Z is the radius.
	local function ring(
		name: string,
		count: number,
		rIn: number,
		rOut: number,
		top: number,
		thick: number,
		color: Color3,
		solid: boolean
	)
		local mid = (rIn + rOut) / 2
		local width = 2 * math.pi * rOut / count * 1.06
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			part(
				name,
				Vector3.new(width, thick, rOut - rIn),
				CFrame.new(
					origin.X + mid * math.sin(a),
					top - thick / 2,
					origin.Z - mid * math.cos(a)
				) * CFrame.Angles(0, -a, 0),
				color,
				solid
			)
		end
	end

	-- Ocean far below, then the grass, road, curb and steel skirt at rim height.
	part(
		"Ocean",
		Vector3.new(look.oceanSize, 2, look.oceanSize),
		CFrame.new(origin.X, origin.Y - look.oceanDrop - 1, origin.Z),
		Color3.fromRGB(70, 160, 235),
		false
	)
	ring(
		"Grass",
		look.grassSegments,
		look.roadOuter - 1,
		look.grassOuter,
		ground - 0.1,
		6,
		Color3.fromRGB(theme.ground[1], theme.ground[2], theme.ground[3]),
		false
	)
	ring("Road", look.roadSegments, look.roadInner, look.roadOuter, ground, 3, ASPHALT, true)
	ring("Curb", 16, look.curbInner, look.curbInner + 2, ground, 8, WHITE, true)
	ring("Skirt", 16, look.curbInner + 2, look.roadInner, ground, 8, STEEL, true)
	-- Yellow hazard stripes on the skirt (a few long ones, not one per segment).
	local skirtMid = look.curbInner + 2 + (look.roadInner - look.curbInner - 2) / 2
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		part(
			"SkirtStripe",
			Vector3.new(8, 0.2, (look.roadInner - look.curbInner - 2) * 0.8),
			CFrame.new(
				origin.X + skirtMid * math.sin(a),
				ground + 0.1,
				origin.Z - skirtMid * math.cos(a)
			) * CFrame.Angles(0, -a, 0),
			YELLOW,
			false
		)
	end

	-- Hazard pads on the road: yellow plate with three black bars.
	local padSize = Vector3.new(look.hazardPads.sizeX, 0.2, look.hazardPads.sizeZ)
	for _, s in ArenaLayout.hazardPadSpots() do
		part("HazardPad", padSize, at(s, 0.1), YELLOW, false)
		for k = -1, 1 do
			part(
				"HazardBar",
				Vector3.new(look.hazardPads.sizeX * 0.9, 0.25, 1.6),
				at(s, 0.12) * CFrame.new(0, 0, k * 3.4),
				BLACK,
				false
			)
		end
	end

	-- Tire stacks: black upright cylinders (axis Y), 2 or 3 high.
	local tireR = look.tires.radius
	for _, s in ArenaLayout.tireStacks() do
		for k = 1, s.n do
			local tire = part(
				"Tire",
				Vector3.new(1.6, tireR * 2, tireR * 2),
				at(s, (k - 0.5) * 1.6) * CFrame.Angles(0, 0, math.pi / 2),
				if k % 2 == 0 then BLACK else Color3.fromRGB(48, 48, 56),
				false
			)
			tire.Shape = Enum.PartType.Cylinder
		end
	end

	-- Orange cones with a dark base plate.
	for _, s in ArenaLayout.coneSpots() do
		part("ConeBase", Vector3.new(2.2, 0.3, 2.2), at(s, 0.15), BLACK, false)
		part("Cone", Vector3.new(1.3, 2.4, 1.3), at(s, 1.5), Color3.fromRGB(255, 130, 30), false)
	end

	-- Red/white barriers: red block with two white bars.
	local barLen = look.barriers.length
	for _, s in ArenaLayout.barrierSpots() do
		part("Barrier", Vector3.new(barLen, 2.2, 1.4), at(s, 1.1), RED, false)
		for k = -1, 1, 2 do
			part(
				"BarrierBar",
				Vector3.new(barLen * 0.22, 2.25, 1.45),
				at(s, 1.1) * CFrame.new(k * barLen * 0.25, 0, 0),
				WHITE,
				false
			)
		end
	end

	-- Floodlight towers: dark post, a lamp box and two glowing panels facing the bowl (local +Z).
	local towerH = look.towers.height
	for _, s in ArenaLayout.towerSpots() do
		part("TowerPost", Vector3.new(1.4, towerH, 1.4), at(s, towerH / 2), STEEL, false)
		local head = at(s, towerH + 1.5)
		part("TowerLamp", Vector3.new(8, 3.6, 2), head, BLACK, false)
		for k = -1, 1, 2 do
			local panel = part(
				"TowerPanel",
				Vector3.new(3.4, 2.6, 0.2),
				head * CFrame.new(k * 2, 0, 1.05),
				WHITE,
				false
			)
			panel.Material = Enum.Material.Neon
		end
	end

	-- Hills: big flat green balls, half buried.
	for i, s in ArenaLayout.hillSpots() do
		local hill = part(
			"Hill",
			Vector3.new(s.scale * 2, s.scale * 0.7, s.scale * 2),
			at(s, -s.scale * 0.15),
			if i % 2 == 0 then GREEN else GREEN_DARK,
			false
		)
		hill.Shape = Enum.PartType.Ball
	end

	-- Trees: brown trunk with one or two green blocks on top.
	for _, s in ArenaLayout.treeSpots() do
		local k = s.scale
		part(
			"Trunk",
			Vector3.new(1.6 * k, 4 * k, 1.6 * k),
			at(s, 2 * k),
			Color3.fromRGB(125, 85, 50),
			false
		)
		part("Leaves", Vector3.new(7 * k, 5 * k, 7 * k), at(s, 6.5 * k), GREEN_DARK, false)
		if s.n >= 2 then
			part("Leaves", Vector3.new(4.6 * k, 4 * k, 4.6 * k), at(s, 10.5 * k), GREEN, false)
		end
	end

	-- Rocks: grey blocks.
	for _, s in ArenaLayout.rockSpots() do
		part(
			"Rock",
			Vector3.new(s.scale * 1.2, s.scale * 0.8, s.scale),
			at(s, s.scale * 0.3),
			Color3.fromRGB(150, 155, 168),
			false
		)
	end

	-- Clouds: three white puffs each.
	for _, s in ArenaLayout.cloudSpots() do
		for k = -1, 1 do
			local size = (if k == 0 then 22 else 15) * s.scale
			local puff = part(
				"Cloud",
				Vector3.new(size, size * 0.55, size),
				at(s, s.y) * CFrame.new(k * 14 * s.scale, 0, 0),
				WHITE,
				false
			)
			puff.Shape = Enum.PartType.Ball
		end
	end
end

return ArenaScenery
