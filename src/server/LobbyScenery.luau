--!strict
-- The junkyard round the Car Battle Lobby plaza (sunset look, 2026-10-20): a dirt plate, dirt
-- mounds, dirt paths, piles of crushed cars and containers (dusty scrub until carter's models are
-- imported), rocks, light towers, a claw crane and a blocky city on the horizon. Everything is look-only except the grass
-- plate (solid, so nothing falls). Nothing is built on the plaza. Local coords: plaza top is y = 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)
local MeshProps = require(script.Parent.MeshProps)

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
		Enum.Material.Ground
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
			Enum.Material.Ground
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
	for i, s in Layout.scenery() do
		local grp = if s.far then far else near
		local base = origin + Vector3.new(s.x, GRASS_TOP - 0.05, s.z)
		local k = s.scale
		if s.kind == "tree" then
			-- carter's crushed-car piles, every third spot a container (scrub until imported)
			local spot = CFrame.new(base) * yaw(s.yawDeg)
			local placed = if i % 3 == 0
				then MeshProps.place("Container", grp, spot, 8.5)
				else MeshProps.place("ScrapPile", grp, spot, 5 + 3 * k)
			if placed == nil then
				tree(grp, base, k, s.far)
			end
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
-- Light towers at the plaza corners, a claw crane at the back, and a blocky city on the horizon
-- (dark against the sunset, some lit windows). The towers and crane need carter's models.
local function junkyard(folder: Folder, origin: Vector3)
	local far = folder:FindFirstChild("FarScenery") :: Folder
	local p = Layout.plaza
	local out = Layout.fenceGap + 8
	for _, c in { { -1, p.backZ }, { 1, p.backZ }, { -1, p.frontZ }, { 1, p.frontZ } } do
		local z = c[2] + (if c[2] < 0 then -out else out)
		local pos = origin + Vector3.new(c[1] * (p.halfX + out), GRASS_TOP, z)
		MeshProps.place(
			"LightTower",
			far,
			CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)),
			40
		)
	end
	local cranePos = origin + Vector3.new(-120, GRASS_TOP, p.backZ - 50)
	MeshProps.place(
		"Crane",
		far,
		CFrame.lookAt(cranePos, Vector3.new(origin.X, cranePos.Y, origin.Z)) * yaw(90),
		26
	)
	local count = 24
	for i = 1, count do
		local a = (i - 0.5) / count * 2 * math.pi + math.sin(i * 5.1) * 0.08
		local r = 400 + (i * 37 % 5) * 12
		local w = 30 + (i * 13 % 4) * 8
		local top = 34 + (i * 29 % 7) * 9
		local h = top + 40
		local pos = origin + Vector3.new(math.cos(a) * r, GRASS_TOP + top - h / 2, math.sin(a) * r)
		local cf = CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z))
		local block =
			part(far, "City", Vector3.new(w, h, w * 0.8), cf, rgb(C.city[i % #C.city + 1]), false)
		block.CastShadow = false
		if i % 2 == 0 then
			local lit = part(
				far,
				"Windows",
				Vector3.new(w * 0.7, 1.6, 0.2),
				cf * CFrame.new(0, h / 2 - top * 0.35, -w * 0.4 - 0.1),
				rgb(C.window),
				false,
				nil,
				Enum.Material.Neon
			)
			lit.CastShadow = false
		end
	end
end

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
	junkyard(folder, origin)
	clouds()
end

return LobbyScenery
