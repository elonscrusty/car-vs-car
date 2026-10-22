--!strict
-- SHOW CAR plot (picture: rc-plot/plot-show.png). A spinning stage with a car on it at the
-- back, two rows of 4 parked cars in the middle, and a cruise loop round the edge.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Kit = sibling("Kit")
local C = Kit.COLORS

local ROAD = 30
-- Cruise loop: front straight runs +x (left to right), up the right side, back along the top.
local POINTS = {
	{ x = -100, z = 120 },
	{ x = 100, z = 120 },
	{ x = 130, z = 90 },
	{ x = 130, z = -160 },
	{ x = 100, z = -190 },
	{ x = -100, z = -190 },
	{ x = -130, z = -160 },
	{ x = -130, z = 90 },
}

local Plot = {}
Plot.id = "show"
Plot.label = "SHOW"
Plot.mode = "free"
Plot.grip = 1
Plot.ROAD = ROAD

-- Spinning stage (plot-local centre, radius) and how fast it turns.
Plot.STAGE = { x = 0, z = -90, radius = 16 }
Plot.SPIN_SECONDS = 16 -- one full turn
Plot.STAGE_TOP = 1.6

-- Parked car spots: 2 rows of 4, either side of the middle, cars facing the front.
Plot.SPOT = { w = 10, d = 14 }
Plot.spots = {} :: { { x: number, z: number } }
for _, x in { -36, 36 } do
	for i = 0, 3 do
		table.insert(Plot.spots, { x = x, z = -50 + i * 18 })
	end
end

function Plot.loop()
	return Kit.loop(POINTS, 8)
end

-- Start on the front straight, in the middle, right in front of the player.
Plot.spawn = Kit.spawnAt(Plot.loop()[5], 0)
Plot.gates = {}

-- ===== Building (Roblox only) =====

local TAG = "ShowTurntable"
local spinning = false

-- One loop turns every stage (the big plot and its small copy both carry the tag).
local function startSpin()
	if spinning then
		return
	end
	spinning = true
	local CollectionService = game:GetService("CollectionService")
	local rate = 2 * math.pi / Plot.SPIN_SECONDS
	game:GetService("RunService").Heartbeat:Connect(function(dt: number)
		local turn = CFrame.Angles(0, rate * dt, 0)
		for _, m in CollectionService:GetTagged(TAG) do
			if m:IsA("Model") and m.PrimaryPart then
				m:PivotTo(m:GetPivot() * turn)
			end
		end
	end)
end

-- A thin painted strip on the floor, size sx by sz, that cars drive over.
local function paint(parent: Instance, origin: CFrame, x: number, z: number, sx: number, sz: number)
	local p =
		Kit.part(parent, "Paint", origin, Vector3.new(sx, 0.1, sz), CFrame.new(x, 0.06, z), C.white)
	p.CanCollide = false
end

-- A grey-block car (5.5 long, like the real one) standing on y, facing +z.
local function showCar(
	parent: Instance,
	origin: CFrame,
	x: number,
	y: number,
	z: number,
	color: Color3
)
	local car = Instance.new("Model")
	car.Name = "ShowCar"
	local at = CFrame.new(x, y, z)
	Kit.part(car, "Body", origin, Vector3.new(3, 1.2, 5.5), at * CFrame.new(0, 1.2, 0), color)
	Kit.part(
		car,
		"Cabin",
		origin,
		Vector3.new(2.4, 0.9, 2.6),
		at * CFrame.new(0, 2.25, -0.4),
		color
	)
	for _, sx in { -1.6, 1.6 } do
		for _, sz in { -1.8, 1.8 } do
			local w = Kit.part(
				car,
				"Wheel",
				origin,
				Vector3.new(0.6, 1.4, 1.4),
				at * CFrame.new(sx, 0.7, sz),
				C.road
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	car.Parent = parent
	return car
end

function Plot.build(parent: Instance, origin: CFrame)
	-- Cruise loop with a dashed middle line.
	local ring = Plot.loop()
	Kit.ribbon(parent, origin, ring, ROAD)
	for i = 1, #ring, 3 do
		local s = ring[i]
		Kit.line(parent, origin, s.x, 0, s.z, -s.tz, s.tx, 6, C.white)
	end

	-- Stage: a fixed base and a turning top with a car on it.
	local st = Plot.STAGE
	Kit.disc(parent, "StageBase", origin, st.x, 0.6, st.z, st.radius + 2, 1.2, C.wall)
	local table_ = Instance.new("Model")
	table_.Name = "Turntable"
	local hub = Kit.part(
		table_,
		"Hub",
		origin,
		Vector3.new(1, 1, 1),
		CFrame.new(st.x, Plot.STAGE_TOP, st.z),
		C.pad
	)
	hub.Transparency = 1
	hub.CanCollide = false
	Kit.disc(table_, "Top", origin, st.x, 1.4, st.z, st.radius, 0.4, C.pad)
	showCar(table_, origin, st.x, Plot.STAGE_TOP, st.z, C.orange)
	table_.PrimaryPart = hub
	table_:AddTag(TAG)
	table_.Parent = parent

	-- Parked cars, each in a painted box (open at the front).
	local w, d = Plot.SPOT.w, Plot.SPOT.d
	for _, p in Plot.spots do
		paint(parent, origin, p.x - w / 2, p.z, 0.6, d)
		paint(parent, origin, p.x + w / 2, p.z, 0.6, d)
		paint(parent, origin, p.x, p.z - d / 2, w + 0.6, 0.6)
		showCar(parent, origin, p.x, 0, p.z, C.blue)
	end

	startSpin()
end

return Plot
