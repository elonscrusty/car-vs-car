--!strict
-- Looks and physics props for the fight modes (server only): the hill circle, the ice bowl,
-- soccer goals and the giant ball. All numbers come from ModesConfig / GameConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Modes = require(ReplicatedStorage.Shared.Modes)
local ModesConfig = require(ReplicatedStorage.Shared.ModesConfig)
local LobbyDecor = require(script.Parent.LobbyDecor)

local ModeFx = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A thin glowing part you can drive through (no collision, not queried).
local function glow(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

export type Hill = { setHolder: (color: Color3?) -> () }

-- The glowing circle in the middle. `setHolder(color)` tints it to the car that holds it
-- (nil = white = nobody / contested).
function ModeFx.hill(parent: Instance, center: Vector3, radius: number): Hill
	local disc = glow(
		parent,
		"HillCircle",
		Vector3.new(0.2, radius * 2, radius * 2),
		CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.new(1, 1, 1)
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.55
	return {
		setHolder = function(color: Color3?)
			disc.Color = color or Color3.new(1, 1, 1)
		end,
	}
end

-- Make the bowl icy: pale blue paint and almost no friction. Cars keep their own friction low
-- through `ModeFx.iceCar`.
function ModeFx.iceBowl(arena: Model)
	local ice = ModesConfig.Ice
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Floor" or d.Name == "Slope") then
			d.Color = rgb(ice.tint)
			d.Material = Enum.Material.Ice
			d.CustomPhysicalProperties = PhysicalProperties.new(
				2,
				Modes.iceFriction(GameConfig.Drive.groundFriction, ice.floorFriction),
				0.1,
				100,
				1
			)
		end
	end
end

-- Slippery car body (keeps its density, so mass stays what the car config says).
function ModeFx.iceCar(body: BasePart)
	local p = body.CustomPhysicalProperties
	if p then
		body.CustomPhysicalProperties = PhysicalProperties.new(
			p.Density,
			Modes.iceFriction(p.Friction, ModesConfig.Ice.carFriction),
			p.Elasticity,
			100,
			1
		)
	end
end

-- Flat-ground height of the bowl `r` studs from the middle (a point on the slope).
local function surface(r: number): number
	local a = GameConfig.Arena
	return ArenaMath.surfaceHeight(r, a.flatRadius, a.rimRadius, a.tiltDeg)
end

-- Where on the bowl a flat spot (relative x, z) sits, a little above the surface.
function ModeFx.spotPosition(center: Vector3, x: number, z: number, lift: number): Vector3
	return center + Vector3.new(x, surface(math.sqrt(x * x + z * z)) + lift, z)
end

-- Goals: the Blender goal frames (ServerStorage.Models.Bowl) at each goal arc, with the field
-- lines on the floor and the score board outside the rim. Without the models, a row of glowing
-- strips across the slope at each goal (team colour).
local GOAL_MODELS = { "SoccerGoal_Blue", "SoccerGoal_Red" }

function ModeFx.goals(parent: Instance, center: Vector3)
	local cfg = ModesConfig.Soccer
	local steps = 9
	for team = 1, 2 do
		local base = Modes.goalAngle(team)
		local placed = false
		if LobbyDecor.has(GOAL_MODELS[team], "Bowl") then
			local x, z = math.cos(base) * cfg.goalRadius, math.sin(base) * cfg.goalRadius
			local pos = ModeFx.spotPosition(center, x, z, 0)
			local m = LobbyDecor.clone(GOAL_MODELS[team], parent, nil, "Bowl")
			if m then
				m:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
				placed = true
			end
		end
		if not placed then
			for k = 0, steps - 1 do
				local a = base + (k / (steps - 1) * 2 - 1) * cfg.goalHalfAngle
				local x, z = math.cos(a) * cfg.goalRadius, math.sin(a) * cfg.goalRadius
				local pos = ModeFx.spotPosition(center, x, z, 0.3)
				glow(
					parent,
					"GoalMark",
					Vector3.new(2, 0.5, 8),
					CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
					rgb(cfg.colors[team])
				)
			end
		end
	end

	local lines = LobbyDecor.clone("SoccerFieldLines", parent, nil, "Bowl")
	if lines then
		lines:PivotTo(CFrame.new(ModeFx.spotPosition(center, 0, 0, 0.15)))
	end
	-- The score board stands outside the rim, facing the middle (look only, no numbers yet).
	local board = LobbyDecor.clone("Board_SoccerScore", parent, nil, "Bowl")
	if board then
		local r = GameConfig.Arena.rimRadius + 38
		local pos = center + Vector3.new(0, surface(GameConfig.Arena.rimRadius), -r)
		board:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
	end
end

-- The giant ball (physics part, the server owns it).
function ModeFx.ball(parent: Instance, pos: Vector3): Part
	local cfg = ModesConfig.Soccer
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * cfg.ballSize
	ball.Color = Color3.fromRGB(245, 245, 245)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(cfg.ballDensity, 0.3, 0.6, 1, 1)
	ball.Position = pos
	ball.Anchored = false
	ball.Parent = parent
	-- The Blender ball rides on the physics sphere (welded, no weight, no collision of its own).
	local look = LobbyDecor.clone("SoccerBall", parent, nil, "Bowl")
	if look then
		look:PivotTo(CFrame.new(pos - Vector3.new(0, cfg.ballSize / 2, 0)))
		ball.Transparency = 1
		ball.CastShadow = false
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = ball
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	return ball
end

return ModeFx
