--!strict
-- The grass world round the Car Battle Lobby plaza: grass plate, far hills, dirt paths, round puffy
-- trees and rocks (no pines, bushes or flowers: L31, L32). Everything is look-only except the grass
-- plate (solid, so nothing falls). Nothing is built on the plaza. Local coords: plaza top is y = 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyScenery = {}

local rgb, part, can, ball, group =
	MapParts.rgb, MapParts.part, MapParts.can, MapParts.ball, MapParts.group
local C = Layout.colors

local GRASS_TOP = -0.3 -- just under the asphalt slab (top y = 0)
local PLATE_SIZE = 760
local PLATE_THICK = 4
local PATH_TOP = -0.15
local PATH_THICK = 0.1
local HILL_TOP = 22

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

local function grassPlate(folder: Folder, origin: Vector3)
	local p = part(
		folder,
		"GrassPlate",
		Vector3.new(PLATE_SIZE, PLATE_THICK, PLATE_SIZE),
		CFrame.new(origin + Vector3.new(0, GRASS_TOP - PLATE_THICK / 2, 0)),
		rgb(C.grass),
		true,
		nil,
		Enum.Material.Grass
	)
	p.CastShadow = false
end

local function hills(folder: Folder, origin: Vector3)
	local grp = group(folder, "Hills")
	for _, h in Layout.hills() do
		ball(
			grp,
			"Hill",
			h.d,
			origin + Vector3.new(h.x, HILL_TOP - h.d / 2, h.z),
			rgb(C.hill),
			false,
			nil,
			Enum.Material.Grass
		)
	end
end

local function dirtPaths(folder: Folder, origin: Vector3)
	local grp = group(folder, "DirtPaths")
	for _, p in Layout.outsidePaths() do
		part(
			grp,
			"DirtPath",
			Vector3.new(p.sx, PATH_THICK, p.sz),
			CFrame.new(origin + Vector3.new(p.x, PATH_TOP - PATH_THICK / 2, p.z)) * yaw(p.yawDeg),
			rgb(C.dirt),
			false,
			nil,
			Enum.Material.Ground
		)
	end
end

-- A round puffy cartoon tree (carter's L31): a short trunk and a crown of bright balls. The far
-- ones get a smaller crown, so they cost less.
local function tree(grp: Instance, base: Vector3, k: number, far: boolean)
	local puff = C.puff
	can(grp, "Trunk", 2.4 * k, 7 * k, base, rgb(C.trunk), false, nil, Enum.Material.Wood)
	ball(grp, "Crown", 13 * k, base + Vector3.new(0, 11 * k, 0), rgb(puff[1]), false)
	if not far then
		ball(grp, "Puff", 9.5 * k, base + Vector3.new(4 * k, 9.4 * k, 1.5 * k), rgb(puff[3]), false)
		ball(grp, "Puff", 9 * k, base + Vector3.new(-3.8 * k, 10 * k, -2 * k), rgb(puff[2]), false)
	end
	ball(grp, "CrownTop", 8 * k, base + Vector3.new(0.5 * k, 16.4 * k, 0), rgb(puff[2]), false)
end

local function scenery(folder: Folder, origin: Vector3)
	local near = group(folder, "Scenery")
	local far = group(folder, "FarScenery") -- cut this first if phones lag
	for _, s in Layout.scenery() do
		local grp = if s.far then far else near
		local base = origin + Vector3.new(s.x, GRASS_TOP - 0.05, s.z)
		local k = s.scale
		if s.kind == "tree" then
			tree(grp, base, k, s.far)
		else
			part(
				grp,
				"Rock",
				Vector3.new(7 * k, 4.5 * k, 5.5 * k),
				CFrame.new(base + Vector3.new(0, 1.6 * k, 0))
					* yaw(s.yawDeg)
					* CFrame.Angles(0.12, 0, 0.1),
				rgb(C.rock),
				false,
				nil,
				Enum.Material.Slate
			)
			if k > 1.2 then
				part(
					grp,
					"RockSmall",
					Vector3.new(3.4, 2.4, 3),
					CFrame.new(base + Vector3.new(4.6 * k, 0.8, 1.6)) * yaw(s.yawDeg + 40),
					rgb(C.rockDark),
					false,
					nil,
					Enum.Material.Slate
				)
			end
		end
	end
end

-- carter's L48 wants puffy cartoon clouds: LobbyProps builds them from balls. The old Terrain
-- clouds would sit on top of them, so any left from an older build is removed.
local function clouds()
	local old = workspace.Terrain:FindFirstChild("LobbyClouds")
	if old then
		old:Destroy()
	end
end

function LobbyScenery.build(folder: Folder, origin: Vector3)
	grassPlate(folder, origin)
	hills(folder, origin)
	dirtPaths(folder, origin)
	scenery(folder, origin)
	clouds()
end

return LobbyScenery
