--!strict
local H = require("./harness")
local BattleConfig = require("../src/shared/BattleConfig")
local Config = require("../src/shared/TutorialConfig")
local Layout = require("../src/shared/PracticeLayout")
local LobbyLayout = require("../src/shared/LobbyLayout")
local Rules = require("../src/shared/PracticeRules")
local Camera = require("../src/shared/PracticeCamera")

print("Practice yard")

-- Distance from a point to the edge of a (possibly turned) rectangle; 0 inside.
local function distToRect(r: Layout.Rect, x: number, z: number): number
	local c, s = math.cos(math.rad(r.yawDeg)), math.sin(math.rad(r.yawDeg))
	local dx, dz = x - r.x, z - r.z
	local u = math.abs(dx * c - dz * s) - r.w / 2
	local v = math.abs(dx * s + dz * c) - r.d / 2
	return math.sqrt(math.max(u, 0) ^ 2 + math.max(v, 0) ^ 2)
end

local function aabb(r: Layout.Rect): (number, number, number, number)
	local c, s = math.cos(math.rad(r.yawDeg)), math.sin(math.rad(r.yawDeg))
	local hx = math.abs(c) * r.w / 2 + math.abs(s) * r.d / 2
	local hz = math.abs(s) * r.w / 2 + math.abs(c) * r.d / 2
	return r.x - hx, r.x + hx, r.z - hz, r.z + hz
end

H.test("the yard is flat, medium, and the car starts inside it facing the boxes", function()
	H.truthy(Layout.half.x > 40 and Layout.half.z > 30)
	H.eq(Layout.spawn.yawDeg, 0)
	H.truthy(Layout.inside(Layout.spawn.x, Layout.spawn.z, 8))
	-- the car starts near the south wall and the first crate is ahead of it (toward -z)
	for _, crate in Layout.crates do
		H.truthy(crate.z < Layout.spawn.z)
	end
	-- no ramps (L56): nothing in the layout has a height above the floor except walls, blocks and decor
	for _, b in Layout.barriers do
		H.truthy(b.h <= 5)
	end
end)

H.test("there are enough boxes, all reachable and well apart", function()
	H.truthy(#Layout.crates >= Config.boxesNeeded + 3)
	for i, c in Layout.crates do
		H.truthy(
			Layout.inside(c.x, c.z, Layout.crateClearance + Layout.crateSize / 2),
			`crate {i} is too near a wall`
		)
		for j = i + 1, #Layout.crates do
			local o = Layout.crates[j]
			local d = math.sqrt((c.x - o.x) ^ 2 + (c.z - o.z) ^ 2)
			H.truthy(d >= 16, `crates {i} and {j} are too close`)
		end
		for k, b in Layout.barriers do
			H.truthy(
				distToRect(b, c.x, c.z) >= Layout.crateClearance + Layout.crateSize / 2,
				`crate {i} is too near barrier {k}`
			)
		end
		-- not on the car's start
		H.truthy(math.sqrt((c.x - Layout.spawn.x) ^ 2 + (c.z - Layout.spawn.z) ^ 2) > 20)
	end
end)

H.test("no box stands in the straight line ahead of the start: a player has to steer", function()
	for i, c in Layout.crates do
		H.truthy(not (math.abs(c.x - Layout.spawn.x) < 12 and c.z > 0), `crate {i}`)
	end
end)

H.test("barriers are inside the floor, apart from each other and from the start", function()
	for i, b in Layout.barriers do
		local lo, hi, zlo, zhi = aabb(b)
		H.truthy(lo > -Layout.half.x and hi < Layout.half.x, `barrier {i} x`)
		H.truthy(zlo > -Layout.half.z and zhi < Layout.half.z, `barrier {i} z`)
		H.truthy(distToRect(b, Layout.spawn.x, Layout.spawn.z) > 12, `barrier {i} is on the start`)
		for j = i + 1, #Layout.barriers do
			H.eq(LobbyLayout.overlaps(b, Layout.barriers[j]), false)
		end
	end
end)

H.test("the scrapyard stands behind the walls and nothing overlaps", function()
	local outer =
		{ x = Layout.half.x + Layout.wall.thickness, z = Layout.half.z + Layout.wall.thickness }
	local names: { string } = {}
	local rects: { Layout.Rect } = {}
	for name, r in Layout.footprints() do
		table.insert(names, name)
		table.insert(rects, r)
		if not (string.sub(name, 1, 5) == "crate" or string.sub(name, 1, 7) == "barrier") then
			local x0, x1, z0, z1 = aabb(r)
			local outside = x0 > outer.x or x1 < -outer.x or z0 > outer.z or z1 < -outer.z
			H.truthy(outside, name .. " stands inside the walls")
			-- and the ground plate reaches past it
			H.truthy(
				math.max(math.abs(x0), math.abs(x1)) + 10 < Layout.ground.half,
				name .. " is off the ground"
			)
			H.truthy(
				math.max(math.abs(z0), math.abs(z1)) + 10 < Layout.ground.half,
				name .. " is off the ground"
			)
		end
	end
	H.truthy(#rects > 60)
	for i = 1, #rects do
		for j = i + 1, #rects do
			H.eq(LobbyLayout.overlaps(rects[i], rects[j]), false, `{names[i]} overlaps {names[j]}`)
		end
	end
end)

H.test("the scrapyard is the same every time and uses real colors", function()
	local a, b = Layout.junkCars(), Layout.junkCars()
	H.eq(#a, #b)
	H.truthy(#a >= 20 and #a <= 40)
	for i, j in a do
		H.eq(j.x, b[i].x)
		H.eq(j.seed, b[i].seed)
		H.truthy(j.color >= 1 and j.color <= 8)
	end
	for _, j in Layout.drums() do
		H.truthy(j.color >= 1 and j.color <= 4)
	end
	H.truthy(#Layout.tireStacks() >= 8)
	H.eq(#Layout.heaps(), 4)
	H.truthy(#Layout.containers >= 4)
	H.truthy(#Layout.stains >= 3 and #Layout.skids >= 3)
end)

H.test("the yard is far from the lobby and from the battle arena", function()
	local o = Layout.origin
	local lobby = { x = 0, z = 500 }
	local arena = BattleConfig.Arena.origin
	local function far(x: number, z: number): boolean
		return math.sqrt((o.x - x) ^ 2 + (o.z - z) ^ 2) > 2000
	end
	H.truthy(far(lobby.x, lobby.z))
	H.truthy(far(arena.x, arena.z))
end)

H.test("a rolling car smashes a box it touches, a creeping one does not", function()
	local carL = 16
	local car: Rules.Car = { x = 0, z = 0, yawDeg = 0 } -- nose toward -z
	local ahead: Rules.Spot = { x = 0, z = -11 } -- the nose is at 8, the box is 3 beyond it
	local far: Rules.Spot = { x = 0, z = -30 }
	H.truthy(Rules.touches(ahead, car, carL))
	H.eq(Rules.touches(far, car, carL), false)
	local alive = { true, true }
	H.eq(#Rules.smashed({ ahead, far }, alive, car, carL, Rules.minSmashSpeed - 0.1), 0)
	local hit = Rules.smashed({ ahead, far }, alive, car, carL, Rules.minSmashSpeed)
	H.eq(#hit, 1)
	H.eq(hit[1], 1)
	-- dead boxes are skipped
	H.eq(#Rules.smashed({ ahead, far }, { false, true }, car, carL, 40), 0)
	-- two at once
	H.eq(#Rules.smashed({ ahead, { x = 5, z = -10 } }, alive, car, carL, 40), 2)
end)

H.test("the hit test follows the car's turn and its width", function()
	local carL = 16
	-- turned left 90 degrees: the nose points toward -x
	local car: Rules.Car = { x = 0, z = 0, yawDeg = 90 }
	H.truthy(Rules.touches({ x = -11, z = 0 }, car, carL))
	H.eq(Rules.touches({ x = 0, z = -11 }, car, carL), false)
	-- beside the car, outside its width + the box reach, is a miss; just inside is a hit
	local straight: Rules.Car = { x = 0, z = 0, yawDeg = 0 }
	local reach = Layout.crateSize / 2 * Rules.crateReach
	local half = carL * Rules.carWidthL / 2
	H.truthy(Rules.touches({ x = half + reach - 0.1, z = 0 }, straight, carL))
	H.eq(Rules.touches({ x = half + reach + 0.1, z = 0 }, straight, carL), false)
	-- the same distance behind the car counts the same as ahead (contact is contact)
	H.eq(
		Rules.touches({ x = 0, z = 11 }, straight, carL),
		Rules.touches({ x = 0, z = -11 }, straight, carL)
	)
end)

H.test("a yaw and its look vector agree", function()
	for _, deg in { 0, 30, 90, 135, -60, -90 } do
		local fx, fz = Rules.axes(deg)
		H.near(Rules.yawOf(fx, fz), deg, 1e-9)
	end
	H.near(Rules.yawOf(0, -1), 0)
	H.near(Rules.yawOf(-1, 0), 90)
	H.near(Rules.yawOf(1, 0), -90)
	H.near(math.abs(Rules.yawOf(0, 1)), 180)
	local fx, fz, rx, rz = Rules.axes(0)
	H.near(fx, 0)
	H.near(fz, -1)
	H.near(rx, 1)
	H.near(rz, 0)
end)

H.test("leaving the yard and running out of time", function()
	H.eq(Rules.outside(0, 1, 0), false)
	H.eq(Rules.outside(Layout.half.x, 3, 0), false)
	H.truthy(Rules.outside(Layout.half.x + Layout.wall.thickness + 3, 3, 0))
	H.truthy(Rules.outside(0, 3, -(Layout.half.z + Layout.wall.thickness + 3)))
	H.truthy(Rules.outside(0, -16, 0))
	H.eq(Rules.timeUp(Config.practiceMaxSeconds - 1), false)
	H.truthy(Rules.timeUp(Config.practiceMaxSeconds))
end)

H.test("the camera starts behind the car, above it, looking where it points", function()
	local state = Camera.new()
	local carL = 16
	-- the car looks toward -z: its yaw (atan2(look.X, look.Z)) is pi
	local car: Camera.Vec = { x = 0, y = 3, z = 0 }
	local eye, look = Camera.aim(state, car, math.pi, carL, 0.016)
	local h = BattleConfig.Human
	H.near(eye.x, 0, 1e-6)
	H.near(eye.z, h.camDistL * carL, 1e-6) -- behind = toward +z
	H.near(eye.y, 3 + 0.3 * carL + h.camHeightL * carL, 1e-6)
	H.near(look.x, 0, 1e-6)
	H.near(look.z, -h.camLookL * carL, 1e-6)
	H.near(look.y, 3, 1e-6)
end)

H.test("the camera stays inside the walls", function()
	local state = Camera.new()
	local car: Camera.Vec = { x = Layout.half.x - 2, y = 3, z = Layout.half.z - 2 }
	-- the car runs toward the east wall: the camera would be outside it, so it is pulled in
	local eye = Camera.aim(state, car, math.rad(-90), 16, 0.016)
	H.truthy(eye.x <= Layout.half.x - Camera.inset + 1e-6)
	H.truthy(eye.z <= Layout.half.z - Camera.inset + 1e-6)
	local eye2 =
		Camera.aim(Camera.new(), { x = -Layout.half.x, y = 3, z = -Layout.half.z }, 0, 16, 0.016)
	H.truthy(eye2.x >= -Layout.half.x + Camera.inset - 1e-6)
	H.truthy(eye2.z >= -Layout.half.z + Camera.inset - 1e-6)
end)

-- The angle (degrees) between the way the camera looks and the way to the car. The view is 70
-- degrees tall (35 to its edge) and much wider, so a car 30 degrees off the middle is still on screen.
local function offMiddle(eye: Camera.Vec, look: Camera.Vec, car: Camera.Vec): number
	local ax, ay, az = look.x - eye.x, look.y - eye.y, look.z - eye.z
	local bx, by, bz = car.x - eye.x, car.y - eye.y, car.z - eye.z
	local dot = ax * bx + ay * by + az * bz
	local len = math.sqrt(ax * ax + ay * ay + az * az) * math.sqrt(bx * bx + by * by + bz * bz)
	return math.deg(math.acos(math.clamp(dot / len, -1, 1)))
end

H.test("the car is on screen where it starts, with the wall pulling the camera in", function()
	local s = Layout.spawn
	local car: Camera.Vec = { x = s.x, y = 3, z = s.z }
	local carYaw = math.rad(180 - s.yawDeg) -- yawDeg 0 looks toward -z: atan2(look.X, look.Z) = pi
	local eye, look = Camera.aim(Camera.new(), car, carYaw, 16, 0.016)
	-- the start is so near the south wall that the camera is pulled in to a few studs behind the car
	H.truthy(math.abs(eye.z - car.z) < 0.5 * BattleConfig.Human.camDistL * 16)
	local off = offMiddle(eye, look, car)
	H.truthy(off < 30, `the car sits {off} degrees off the middle of the view at the start`)
end)

H.test("the car stays on screen wherever it is in the yard, whichever way it points", function()
	local worst, where = 0, ""
	for xi = -6, 6 do
		for zi = -5, 5 do
			for heading = 0, 7 do
				local car: Camera.Vec = { x = xi * 11, y = 3, z = zi * 10 }
				local yaw = math.rad(heading * 45)
				local eye, look = Camera.aim(Camera.new(), car, yaw, 16, 0.016)
				local off = offMiddle(eye, look, car)
				if off > worst then
					worst, where = off, `x {car.x} z {car.z} heading {heading * 45}`
				end
			end
		end
	end
	H.truthy(worst < 30, `the car sits {worst} degrees off the middle of the view at {where}`)
end)

H.test("the camera swings after the nose, never faster than the cap", function()
	local state = Camera.new()
	local car: Camera.Vec = { x = 0, y = 3, z = 0 }
	Camera.aim(state, car, 0, 16, 0.016)
	H.near(state.yaw :: number, 0)
	-- the car snaps round 90 degrees: the camera moves only a little in one frame
	Camera.aim(state, car, math.rad(90), 16, 0.016)
	local cap = math.rad(BattleConfig.Human.camSwingDegPerSec) * 0.016
	H.truthy((state.yaw :: number) > 0 and (state.yaw :: number) <= cap + 1e-9)
	-- a long hiccup counts as 0.1 s at most
	local slow = Camera.new()
	Camera.aim(slow, car, 0, 16, 0.016)
	Camera.aim(slow, car, math.rad(90), 16, 5)
	H.truthy((slow.yaw :: number) <= math.rad(BattleConfig.Human.camSwingDegPerSec) * 0.1 + 1e-9)
	-- and it gets there in the end
	for _ = 1, 400 do
		Camera.aim(state, car, math.rad(90), 16, 0.016)
	end
	H.near(state.yaw :: number, math.rad(90), 0.02)
end)
