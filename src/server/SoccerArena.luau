--!strict
-- Builds the small car soccer field from plain anchored parts: striped grass, white lines,
-- tall walls with angled corners, goal frames + nets, an invisible lid and the ball. Empty
-- Folders "BallSpawn", "GoalA", "GoalB" and "ScoreBoardAnchor" mark spots where Studio models
-- can be placed later (no models are imported here). Layout comes from shared/SoccerField,
-- numbers from shared/SoccerFieldConfig. Same return shape as Arena.build so GroupMatch can use it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoccerBoost = require(ReplicatedStorage.Shared.SoccerBoost)
local SoccerField = require(ReplicatedStorage.Shared.SoccerField)
local SoccerFieldConfig = require(ReplicatedStorage.Shared.SoccerFieldConfig)

local Arena = require(script.Parent.Arena)
local LobbyDecor = require(script.Parent.LobbyDecor)
local ModeDecor = require(script.Parent.ModeDecor)

local SoccerArena = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- One anchored part. `solid` false = looks only (nothing to bump into or query).
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

local function folder(parent: Instance, name: string, at: Vector3)
	local f = Instance.new("Folder")
	f.Name = name
	f:SetAttribute("Position", at)
	f.Parent = parent
end

-- A goal at one short end. team = the team that DEFENDS it. Frame (posts + bar), back and side
-- nets (nets are see-through but solid so the ball stays in), and a coloured strip on the floor.
local function buildGoal(model: Model, origin: Vector3, team: number)
	local c = SoccerFieldConfig
	local box = SoccerField.goalBox(team)
	local sx = if team == 1 then -1 else 1
	local depth, gw, gh = c.goalDepth, c.goalWidth, c.goalHeight
	local lineX = sx * c.length / 2
	local backX = sx * (c.length / 2 + depth)
	local midX = sx * (c.length / 2 + depth / 2)
	local post = rgb(c.postColor)
	local net = rgb(c.netColor)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local name = if team == 1 then "GoalA" else "GoalB"
	-- Posts at the mouth and a crossbar.
	for _, z in { -gw / 2, gw / 2 } do
		part(model, name .. "Post", Vector3.new(1.2, gh, 1.2), at(lineX, gh / 2, z), post, false)
	end
	part(model, name .. "Bar", Vector3.new(1.2, 1.2, gw + 1.2), at(lineX, gh, 0), post, false)
	-- Nets: back, two sides, roof. Solid so the ball cannot leave; see-through.
	local function netPart(label: string, size: Vector3, cf: CFrame)
		local n = part(model, name .. label, size, cf, net, true)
		n.Transparency = c.netTransparency
		n.Material = Enum.Material.SmoothPlastic
		-- Slippery and bouncy-free so a ball in the net just drops.
		n.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.1, 1, 1)
	end
	netPart("NetBack", Vector3.new(1, gh, gw + 2), at(backX, gh / 2, 0))
	netPart("NetSideL", Vector3.new(depth, gh, 1), at(midX, gh / 2, -gw / 2 - 0.5))
	netPart("NetSideR", Vector3.new(depth, gh, 1), at(midX, gh / 2, gw / 2 + 0.5))
	netPart("NetRoof", Vector3.new(depth, 1, gw + 2), at(midX, gh + 0.5, 0))
	-- Floor strip in the team colour inside the goal mouth.
	part(
		model,
		name .. "Strip",
		Vector3.new(depth, 0.15, gw),
		at(midX, 0.08, (box.minZ + box.maxZ) / 2),
		rgb(c.goalZone[team]),
		false
	)
	-- Empty folder for a Studio goal model.
	folder(model, name, origin + Vector3.new(lineX, 0, 0))
end

-- Glowing boost pads (audit #20): flat neon discs named BoostPad1..n, nothing to bump into.
-- GroupMatch dims a pad (Transparency) while it is taken.
local function buildBoostPads(model: Model, origin: Vector3)
	local c = SoccerFieldConfig
	for i = 1, SoccerBoost.count() do
		local x, z = SoccerBoost.spot(i)
		local disc = part(
			model,
			"BoostPad" .. i,
			Vector3.new(0.3, c.boostPadRadius * 2, c.boostPadRadius * 2),
			CFrame.new(origin + Vector3.new(x, 0.25, z)) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(c.boostPadColor),
			false
		)
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.Neon
		disc.Transparency = 0.15
	end
end

-- `pads`: draw the boost pads (car soccer yes, tag no).
function SoccerArena.build(origin: Vector3, pads: boolean?): Arena.Arena
	local c = SoccerFieldConfig
	local model = Instance.new("Model")
	model.Name = "Arena"
	-- Always send the whole field to clients (the camera has no avatar, so streaming would skip it).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end

	-- Grass: a base slab (floor top at y = 0) with alternating stripes that look only. The base
	-- also runs under the goals. Flat slippery ground like the bowl so cars slide a bit.
	local tag = pads ~= true -- tag plays on the same field with a steel floor, so it does not look like soccer
	local grass = if tag then ModeDecor.TagFloor else rgb(c.grass)
	local grassAlt = if tag then ModeDecor.TagFloorAlt else rgb(c.grassAlt)
	local totalLen = c.length + 2 * c.goalDepth
	local base = part(model, "Floor", Vector3.new(totalLen, 2, c.width), at(0, -1, 0), grass, true)
	base.Material = if tag then Enum.Material.DiamondPlate else Enum.Material.Grass
	base.CustomPhysicalProperties =
		PhysicalProperties.new(0.7, GameConfig.Drive.groundFriction, 0.1, 1, 1)
	local stripeLen = c.length / c.stripes
	for i = 0, c.stripes - 1 do
		if i % 2 == 1 then
			local s = part(
				model,
				"Stripe",
				Vector3.new(stripeLen, 0.1, c.width),
				at(-c.length / 2 + stripeLen * (i + 0.5), 0.03, 0),
				grassAlt,
				false
			)
			s.Material = if tag then Enum.Material.DiamondPlate else Enum.Material.Grass
		end
	end

	-- White lines: boundary, halfway line, centre circle.
	local lc, lt = rgb(c.lineColor), c.lineThick
	local function line(sx: number, sz: number, x: number, z: number)
		part(model, "Line", Vector3.new(sx, 0.1, sz), at(x, 0.1, z), lc, false)
	end
	line(lt, c.width, 0, 0) -- halfway
	line(c.length, lt, 0, -c.width / 2 + lt / 2)
	line(c.length, lt, 0, c.width / 2 - lt / 2)
	local gz = c.goalWidth / 2
	local endLen = c.width / 2 - gz
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			line(lt, endLen, sx * (c.length / 2 - lt / 2), sz * (gz + endLen / 2))
		end
		line(lt, c.goalWidth, sx * (c.length / 2 - lt / 2), 0) -- goal line across the mouth
	end
	local ring = part(
		model,
		"CenterCircle",
		Vector3.new(0.1, c.centerCircleRadius * 2, c.centerCircleRadius * 2),
		at(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		lc,
		false
	)
	ring.Shape = Enum.PartType.Cylinder
	local inner = part(
		model,
		"CenterCircleInner",
		Vector3.new(0.12, c.centerCircleRadius * 2 - lt * 2, c.centerCircleRadius * 2 - lt * 2),
		at(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2),
		grass,
		false
	)
	inner.Shape = Enum.PartType.Cylinder

	-- Walls: the layout comes from the pure rules; the slab is pushed outward by half its
	-- thickness so the inside face sits on the edge line.
	local wallColor = rgb(c.wallColor)
	for _, w in SoccerField.walls() do
		local outward = Vector3.new(w.x, 0, w.z)
		-- Push along the slab's own normal, pointing away from the middle.
		local dir = Vector3.new(math.cos(w.yaw), 0, -math.sin(w.yaw))
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		if normal:Dot(outward) < 0 then
			normal = -normal
		end
		local push = normal * (c.wallThick / 2)
		-- Slabs overlap at the corners; the short-end pieces must not reach into the goal mouth.
		local extra, shift = c.wallThick, Vector3.zero
		if math.abs(math.abs(w.yaw) - math.pi / 2) < 1e-6 then
			extra = c.wallThick / 2
			shift = Vector3.new(0, 0, math.sign(w.z) * c.wallThick / 4)
		end
		local wall = part(
			model,
			"Wall",
			Vector3.new(w.length + extra, c.wallHeight, c.wallThick),
			CFrame.new(origin + Vector3.new(w.x, c.wallHeight / 2, w.z) + push + shift)
				* CFrame.Angles(0, w.yaw, 0),
			wallColor,
			true
		)
		-- Smooth and bouncy-ish: the ball and cars slide off instead of sticking.
		wall.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0.3, 1, 1)
		-- Yellow trim along the top (look only).
		part(
			model,
			"WallTrim",
			Vector3.new(wall.Size.X, 0.6, wall.Size.Z + 0.2),
			wall.CFrame * CFrame.new(0, c.wallHeight / 2 - 0.3, 0),
			Color3.fromRGB(255, 205, 40),
			false
		)
	end

	-- Goal frames and nets.
	buildGoal(model, origin, 1)
	buildGoal(model, origin, 2)

	if pads == true then
		buildBoostPads(model, origin)
	end

	-- Invisible lid: nothing can fly out over the walls.
	if c.ceilingHeight > 0 then
		local lid = part(
			model,
			"Lid",
			Vector3.new(totalLen + 2 * c.wallThick, 1, c.width + 2 * c.wallThick),
			at(0, c.ceilingHeight + 0.5, 0),
			Color3.new(1, 1, 1),
			true
		)
		lid.Transparency = 1
		lid.CanQuery = false
	end

	ModeDecor.field(model, origin, tag)

	-- Spots for Studio models (empty on purpose).
	folder(model, "BallSpawn", origin + Vector3.new(0, c.kickoffLift + c.ballDiameter / 2, 0))
	folder(model, "ScoreBoardAnchor", origin + Vector3.new(0, c.wallHeight + 6, -c.width / 2 - 4))

	-- Score board model on top of the back wall, facing the field (model front is -Z).
	local board = LobbyDecor.clone("Board_SoccerScore", model, nil, "Bowl")
	if board then
		board:PivotTo(
			CFrame.new(origin + Vector3.new(0, c.wallHeight + 1, -c.width / 2 - 1))
				* CFrame.Angles(0, math.pi, 0)
		)
	end

	model.Parent = workspace
	return { model = model, center = origin, frames = { CFrame.new(origin) } }
end

-- The ball: a physics part the server owns. Sits at BallSpawn (the middle) on the floor.
function SoccerArena.ball(parent: Instance, origin: Vector3): Part
	local c = SoccerFieldConfig
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * c.ballDiameter
	ball.Color = Color3.fromRGB(245, 245, 245)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties =
		PhysicalProperties.new(c.ballDensity, c.ballFriction, c.ballElasticity, 1, 1)
	ball.Position = SoccerArena.ballPosition(origin)
	ball.Anchored = false
	ball.Parent = parent
	-- The Studio ball look rides on the physics ball (which turns invisible).
	local look = LobbyDecor.clone("SoccerBall", ball, nil, "Bowl")
	if look then
		look:ScaleTo(c.ballDiameter / 16)
		look:PivotTo(ball.CFrame * CFrame.new(0, -c.ballDiameter / 2, 0))
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = ball
				w.Part1 = d
				w.Parent = d
			end
		end
		ball.Transparency = 1
	end
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	return ball
end

-- Where the ball goes at kickoff (world position).
function SoccerArena.ballPosition(origin: Vector3): Vector3
	local c = SoccerFieldConfig
	local x, z = SoccerField.ballSpawn()
	return origin + Vector3.new(x, c.ballDiameter / 2 + c.kickoffLift, z)
end

-- Where a car start spot (relative x, z) sits in the world; `lift` above the floor.
function SoccerArena.spotPosition(origin: Vector3, x: number, z: number, lift: number): Vector3
	return origin + Vector3.new(x, lift, z)
end

return SoccerArena
