--!strict
-- Frosty Yard, the second arena (shared/FrostYard): builds the snow props and the ICE PATCHES once,
-- then swaps the arena's look per round. All the snow stuff lives in one folder that sits in
-- ServerStorage (not in the world) while the sunny junkyard is on, and in the workspace while the
-- frost look is on. The Burning Yard folder (BurningYardServer) swaps the other way.
-- Ice is the one thing that plays differently: a flat part named "Ice" with the attribute Grip
-- (the wheels read it, like the soft sand). Everything else is looks only: not solid, no touch, no
-- query, no shadow. Nothing glows. The clients re-colour the arena by name (client/ArenaFrost).
--
--   local h = FrostYardServer.start({ at = function(x, y) return Vector3 end, unit = 0.375 })
--   h.setTheme("frost", burningYardFolder)
-- `at` turns a picture point into a world floor point; `unit` is world studs per picture unit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FrostYard = require(ReplicatedStorage.Shared.FrostYard)

local FrostYardServer = {}

export type Options = { at: (x: number, y: number) -> Vector3, unit: number }
export type Handle = {
	setTheme: (name: string, other: Instance?) -> (),
	theme: () -> string,
	folder: Folder,
	stop: () -> (),
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local SNOW, SNOW_2 = Color3.fromRGB(246, 250, 254), Color3.fromRGB(226, 238, 250)
local PINE, PINE_2 = Color3.fromRGB(44, 108, 78), Color3.fromRGB(58, 128, 92)
local LOG, LOG_2 = Color3.fromRGB(150, 104, 66), Color3.fromRGB(122, 84, 52)

local started: Handle? = nil

-- looks only: anchored, never solid, never touched, never hit by a ray or the chase cam
local function look(name: string, parent: Instance, color: Color3, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- one ice patch: a thin disc on the floor the wheels can read (the only part here that is queried)
local function icePatch(spot: Vector3, radius: number, rnd: Random, parent: Instance)
	local up = Vector3.new(0, 1, 0)
	local lay = CFrame.Angles(0, 0, math.rad(90)) -- a Roblox cylinder lies along X: lay it flat
	local rim = look(
		"IceRim",
		parent,
		rgb(FrostYard.ICE_RIM),
		Vector3.new(0.06, (radius + 0.35) * 2, (radius + 0.35) * 2),
		CFrame.new(spot + up * 0.01) * lay
	)
	rim.Shape = Enum.PartType.Cylinder
	local ice = look(
		"Ice",
		parent,
		rgb(FrostYard.ICE_COLOR),
		Vector3.new(0.08, radius * 2, radius * 2),
		CFrame.new(spot + up * 0.02) * lay
	)
	ice.Shape = Enum.PartType.Cylinder
	ice.Reflectance = 0.1
	ice.CanQuery = true -- the wheels' ray must hit it to read the grip
	ice:SetAttribute("Grip", FrostYard.ICE_GRIP)
	if FrostYard.ICE_DRAG > 0 then
		ice:SetAttribute("Drag", FrostYard.ICE_DRAG)
	end
	for _ = 1, 3 do
		local len = radius * rnd:NextNumber(0.9, 1.5)
		local at = Vector3.new(
			rnd:NextNumber(-0.3, 0.3) * radius,
			0.07,
			rnd:NextNumber(-0.3, 0.3) * radius
		)
		look(
			"IceCrack",
			parent,
			rgb(FrostYard.ICE_CRACK),
			Vector3.new(len, 0.03, 0.12),
			CFrame.new(spot + at) * CFrame.Angles(0, rnd:NextNumber(0, math.pi), 0)
		)
	end
end

-- a pine: a trunk and three turned square tiers with a snow cap on each (like the game's tree tops)
local function pine(spot: Vector3, k: number, yaw: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Pine"
	look(
		"Trunk",
		m,
		LOG_2,
		Vector3.new(0.7, 1.6, 0.7) * k,
		CFrame.new(spot + Vector3.new(0, 0.8 * k, 0))
	)
	for i = 1, 3 do
		local w = (4.6 - 1.3 * (i - 1)) * k
		local y = (1.6 + (i - 1) * 1.7 + 1.1) * k
		local turn = CFrame.Angles(0, yaw + (if i % 2 == 0 then math.pi / 4 else 0), 0)
		look(
			"Tier",
			m,
			if i % 2 == 0 then PINE_2 else PINE,
			Vector3.new(w, 2.2 * k, w),
			CFrame.new(spot + Vector3.new(0, y, 0)) * turn
		)
		look(
			"Cap",
			m,
			SNOW,
			Vector3.new(w * 0.86, 0.5 * k, w * 0.86),
			CFrame.new(spot + Vector3.new(0, y + 1.15 * k, 0)) * turn
		)
	end
	m.Parent = parent
end

local function cabin(spot: Vector3, yaw: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Cabin"
	local base = CFrame.new(spot) * CFrame.Angles(0, yaw, 0)
	for i = 0, 5 do
		look(
			"Log",
			m,
			if i % 2 == 0 then LOG else LOG_2,
			Vector3.new(9.2, 0.68, 6.2),
			base * CFrame.new(0, 0.34 + i * 0.68, 0)
		)
	end
	for _, side in { -1, 1 } do
		look(
			"Roof",
			m,
			SNOW,
			Vector3.new(10.4, 0.5, 3.9),
			base * CFrame.new(0, 4.5, side * 1.55) * CFrame.Angles(side * math.rad(-32), 0, 0)
		)
	end
	look("Door", m, LOG_2, Vector3.new(1.5, 2.5, 0.2), base * CFrame.new(-1.6, 1.25, 3.1))
	look(
		"Window",
		m,
		Color3.fromRGB(150, 196, 232),
		Vector3.new(1.4, 1.1, 0.2),
		base * CFrame.new(1.8, 2.2, 3.1)
	)
	look(
		"Chimney",
		m,
		Color3.fromRGB(150, 146, 150),
		Vector3.new(0.9, 2.2, 0.9),
		base * CFrame.new(2.6, 5.2, -0.6)
	)
	look("ChimneyCap", m, SNOW, Vector3.new(1.1, 0.25, 1.1), base * CFrame.new(2.6, 6.4, -0.6))
	m.Parent = parent
end

local function snowman(spot: Vector3, s: number, yaw: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Snowman"
	local base = CFrame.new(spot) * CFrame.Angles(0, yaw, 0)
	for i, d in { 1.6, 1.2, 0.85 } do
		local y = ({ 0.8, 2.1, 3.1 })[i] * s
		local ball = look("Ball", m, SNOW, Vector3.one * d * s, base * CFrame.new(0, y, 0))
		ball.Shape = Enum.PartType.Ball
	end
	look(
		"Nose",
		m,
		Color3.fromRGB(232, 128, 28),
		Vector3.new(0.18, 0.18, 0.7) * s,
		base * CFrame.new(0, 3.1 * s, 0.55 * s)
	)
	look(
		"Hat",
		m,
		Color3.fromRGB(32, 34, 44),
		Vector3.new(0.7, 0.55, 0.7) * s,
		base * CFrame.new(0, 3.75 * s, 0)
	)
	look(
		"Brim",
		m,
		Color3.fromRGB(32, 34, 44),
		Vector3.new(1.0, 0.1, 1.0) * s,
		base * CFrame.new(0, 3.47 * s, 0)
	)
	for _, side in { -1, 1 } do
		look(
			"Arm",
			m,
			LOG_2,
			Vector3.new(0.14, 0.14, 1.5) * s,
			base
				* CFrame.new(side * 0.85 * s, 2.3 * s, 0)
				* CFrame.Angles(0, side * math.rad(80), math.rad(side * 20))
		)
	end
	m.Parent = parent
end

-- a drift: a squashed snowball piled against the foot of the wall (a mesh part, so it can be flat)
local function drift(
	spot: Vector3,
	w: number,
	h: number,
	d: number,
	yaw: number,
	shade: Color3,
	parent: Instance
)
	local p = look(
		"Drift",
		parent,
		shade,
		Vector3.new(w, h, d),
		CFrame.new(spot + Vector3.new(0, h * 0.2, 0)) * CFrame.Angles(0, yaw, 0)
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

function FrostYardServer.start(opts: Options): Handle
	if started then
		started.stop()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FrostYard"
	folder.Parent = ServerStorage -- the sunny junkyard is the first look
	local rnd = Random.new(11)
	local at, u = opts.at, opts.unit

	for _, p in FrostYard.ICE do
		icePatch(at(p[1], p[2]), p[3] * u, rnd, folder)
	end
	for _, p in FrostYard.pines() do
		pine(at(p[1], p[2]), p[3], rnd:NextNumber(0, math.pi), folder)
	end
	local c = FrostYard.CABIN
	cabin(at(c.x, c.y), c.yaw, folder)
	local mid = at(120, 120)
	for _, p in FrostYard.SNOWMEN do
		-- face the middle of the yard
		local spot = at(p[1], p[2])
		snowman(spot, 1.5, math.atan2(mid.X - spot.X, mid.Z - spot.Z), folder)
	end
	local edge = 7 -- picture units in from the edge: just inside the wall
	local k = 0
	for x = FrostYard.DRIFT_FROM, FrostYard.DRIFT_TO, FrostYard.DRIFT_STEP do
		for _, p in
			{
				{ x, edge, 0 },
				{ x, 240 - edge, 0 },
				{ edge, x, math.pi / 2 },
				{ 240 - edge, x, math.pi / 2 },
			}
		do
			k += 1
			local w = FrostYard.DRIFT_STEP * u * rnd:NextNumber(0.95, 1.2)
			drift(
				at(p[1], p[2]),
				w,
				rnd:NextNumber(1.5, 2.1),
				rnd:NextNumber(2.2, 2.9),
				p[3],
				if k % 2 == 0 then SNOW else SNOW_2,
				folder
			)
		end
	end

	local current = FrostYard.YARD
	local handle: Handle
	handle = {
		setTheme = function(name: string, other: Instance?)
			if name ~= FrostYard.YARD and name ~= FrostYard.FROST then
				return
			end
			current = name
			local frost = name == FrostYard.FROST
			folder.Parent = if frost then workspace else ServerStorage
			if other then
				-- the junkyard's piles step out while the snow is in (and back)
				pcall(function()
					other.Parent = if frost then ServerStorage else workspace
				end)
			end
			workspace:SetAttribute(FrostYard.ATTR, name)
		end,
		theme = function()
			return current
		end,
		folder = folder,
		stop = function()
			folder:Destroy()
			if started == handle then
				started = nil
			end
		end,
	}
	started = handle
	workspace:SetAttribute(FrostYard.ATTR, current)
	return handle
end

return FrostYardServer
