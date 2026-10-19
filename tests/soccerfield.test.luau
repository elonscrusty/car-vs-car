--!strict
local Harness = require("./harness")
local SoccerField = require("../src/shared/SoccerField")
local Config = require("../src/shared/SoccerFieldConfig")
local Flow = require("../src/shared/SoccerFieldFlow")
local ModesConfig = require("../src/shared/ModesConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("SoccerField")

test("field is small and the numbers make sense", function()
	truthy(Config.length >= 100 and Config.length <= 140)
	truthy(Config.width >= 60 and Config.width <= 80)
	truthy(Config.goalWidth < Config.width / 2)
	truthy(Config.wallHeight > Config.ballDiameter * 2)
	truthy(Config.cornerCut * 2 < Config.width - Config.goalWidth)
	truthy(Config.ballMaxSpeed > 0)
end)

test("goal boxes sit behind each goal line, centred on the short ends", function()
	local a, b = SoccerField.goalBox(1), SoccerField.goalBox(2)
	near(a.maxX, -Config.length / 2)
	near(a.minX, -Config.length / 2 - Config.goalDepth)
	near(b.minX, Config.length / 2)
	near(b.maxX, Config.length / 2 + Config.goalDepth)
	near(a.maxZ - a.minZ, Config.goalWidth)
	near(a.minZ, -a.maxZ)
	near(b.minZ, -b.maxZ)
end)

test("goal detection: inside a box scores for the other team, elsewhere nothing", function()
	eq(SoccerField.goalConceded(0, 0), 0)
	eq(SoccerField.goalConceded(-Config.length / 2 + 1, 0), 0) -- still on the field
	eq(SoccerField.goalConceded(-Config.length / 2 - 1, 0), 1) -- team 1 conceded
	eq(SoccerField.goalConceded(Config.length / 2 + 1, 5), 2)
	eq(SoccerField.goalConceded(Config.length / 2 + 1, Config.goalWidth / 2 + 1), 0) -- wide of the post
	eq(SoccerField.goalConceded(-Config.length / 2 - 1, -Config.goalWidth / 2 - 1), 0)
	eq(SoccerField.goalConceded(0, Config.width / 2 - 1), 0)
	eq(SoccerField.goalConceded(-Config.length / 2 - Config.goalDepth - 3, 0), 0) -- past the net
end)

test("spawn spots: teams on their own halves, facing the middle", function()
	local spots = SoccerField.spawnSpots(2)
	eq(#spots, 4)
	for i, s in spots do
		local team = if i <= 2 then 1 else 2
		truthy(if team == 1 then s.x < 0 else s.x > 0)
		-- Car faces -Z turned by yaw: direction (-sin, -cos). It must point at x = 0.
		local fx = -math.sin(s.yaw)
		truthy(if s.x < 0 then fx > 0.99 else fx < -0.99)
		truthy(SoccerField.inBounds(s.x, s.z, 0))
		eq(SoccerField.goalConceded(s.x, s.z), 0)
	end
	truthy(spots[1].z ~= spots[2].z)
	eq(#SoccerField.spawnSpots(3), 6)
end)

test("ball spawns in the middle", function()
	local x, z = SoccerField.ballSpawn()
	eq(x, 0)
	eq(z, 0)
end)

test("bot target is behind the ball on the line to the goal it attacks", function()
	local tx, tz = SoccerField.botTarget(0, 0, 1, 10) -- team 1 attacks +X
	near(tx, -10)
	near(tz, 0)
	tx, tz = SoccerField.botTarget(0, 0, 2, 10)
	near(tx, 10)
	tx, tz = SoccerField.botTarget(20, 10, 1, 10)
	truthy(tx < 20)
	local gx = Config.length / 2
	-- ball, aim point and goal middle are on one line
	local cross = (tx - 20) * (0 - 10) - (tz - 10) * (gx - 20)
	near(cross, 0, 1e-6)
end)

test("out of bounds and ball stuck", function()
	truthy(not SoccerField.outOfBounds(0, 1, 0))
	truthy(not SoccerField.outOfBounds(-Config.length / 2 - 3, 2, 0)) -- inside a goal
	truthy(SoccerField.outOfBounds(Config.length, 1, 0))
	truthy(SoccerField.outOfBounds(0, -Config.lostMargin - 1, 0))
	truthy(SoccerField.outOfBounds(0, Config.ceilingHeight + 1, 0))
	truthy(SoccerField.outOfBounds(0, 1, Config.width))
	local idle, stuck = 0, false
	for _ = 1, 11 do
		idle, stuck = SoccerField.stuckStep(idle, 0.1, Config.stuckSeconds / 10)
	end
	truthy(stuck)
	idle, stuck = SoccerField.stuckStep(idle, Config.stuckSpeed + 1, 0.1)
	eq(idle, 0)
	truthy(not stuck)
end)

test("ball speed cap keeps direction", function()
	local x, y, z = SoccerField.capVelocity(300, 0, 400, 100)
	near(math.sqrt(x * x + y * y + z * z), 100, 1e-6)
	near(x / z, 0.75, 1e-9)
	x, y, z = SoccerField.capVelocity(3, 4, 0, 100)
	eq(x, 3)
	eq(y, 4)
	x, y, z = SoccerField.capVelocity(0, 0, 0, 100)
	eq(z, 0)
end)

test("walls: closed outline with angled corners, only the goal mouths open", function()
	local walls = SoccerField.walls()
	eq(#walls, 10)
	-- Collect end points; each end must meet another wall end (closed) except at the goal mouths.
	local ends: { { number } } = {}
	for _, w in walls do
		local x1, z1, x2, z2 = SoccerField.wallEnds(w)
		table.insert(ends, { x1, z1 })
		table.insert(ends, { x2, z2 })
	end
	local open = 0
	for i, e in ends do
		local matched = false
		for j, o in ends do
			if i ~= j and math.abs(e[1] - o[1]) < 1e-6 and math.abs(e[2] - o[2]) < 1e-6 then
				matched = true
			end
		end
		if not matched then
			open += 1
			-- unmatched ends are exactly the four goal post spots
			near(math.abs(e[1]), Config.length / 2, 1e-6)
			near(math.abs(e[2]), Config.goalWidth / 2, 1e-6)
		end
	end
	eq(open, 4)
	-- No wall end pokes outside the field box; corners are cut so no 90 degree corner exists.
	for _, e in ends do
		truthy(math.abs(e[1]) <= Config.length / 2 + 1e-6)
		truthy(math.abs(e[2]) <= Config.width / 2 + 1e-6)
		truthy(
			not (
					math.abs(math.abs(e[1]) - Config.length / 2) < 1e-6
					and math.abs(math.abs(e[2]) - Config.width / 2) < 1e-6
				)
		)
	end
end)

test("kickoff countdown text: 3, 2, 1, GO", function()
	eq(Flow.countdownText(3), "3")
	eq(Flow.countdownText(2.2), "3")
	eq(Flow.countdownText(1.5), "2")
	eq(Flow.countdownText(0.1), "1")
	eq(Flow.countdownText(0), "GO!")
	eq(Flow.countdownText(-1), "GO!")
end)

test("match clock text and golden goal", function()
	eq(Flow.clockText(150, false), "2:30")
	eq(Flow.clockText(65.2, false), "1:06")
	eq(Flow.clockText(0, false), "0:00")
	eq(Flow.clockText(-3, false), "0:00")
	eq(Flow.clockText(0, true), "GOLDEN GOAL")
	truthy(ModesConfig.Soccer.maxSeconds > 0)
end)

test("kickoff and goal-restart numbers are set in ModesConfig", function()
	local s = ModesConfig.Soccer
	truthy(s.kickoffSeconds >= 1 and s.restartSeconds >= 1 and s.goalPause > 0)
	truthy(s.goSeconds > 0 and s.hudSeconds > 0 and s.readySeconds >= 0)
end)

test("stuck warning shows only in the last seconds before the reset", function()
	truthy(not Flow.stuckWarning(0))
	truthy(not Flow.stuckWarning(Config.stuckSeconds - Config.stuckWarnSeconds - 0.1))
	truthy(Flow.stuckWarning(Config.stuckSeconds - Config.stuckWarnSeconds))
	truthy(not Flow.stuckWarning(Config.stuckSeconds))
	truthy(Config.stuckWarnSeconds < Config.stuckSeconds)
end)

test("the ball cannot leave: lid above the walls, high or far balls are put back", function()
	truthy(Config.ceilingHeight >= Config.wallHeight + Config.ballDiameter)
	for _, p in
		{
			{ 0, Config.ceilingHeight + 0.5, 0 },
			{ Config.length / 2 + Config.goalDepth + Config.lostMargin + 1, 3, 0 },
			{ 0, 3, Config.width / 2 + Config.lostMargin + 1 },
			{ 0, -Config.lostMargin - 0.5, 0 },
		}
	do
		truthy(SoccerField.outOfBounds(p[1], p[2], p[3]))
	end
	-- the corners of the field itself are in play
	truthy(not SoccerField.outOfBounds(Config.length / 2 - 1, 1, Config.width / 2 - 1))
end)

test("keeper slot: first bot of a team with two or more cars", function()
	eq(Flow.keeperSlot({ true, true }), 1)
	eq(Flow.keeperSlot({ false, true }), 2)
	eq(Flow.keeperSlot({ true, false }), 1)
	eq(Flow.keeperSlot({ false, false }), 0)
	eq(Flow.keeperSlot({ true }), 0) -- a lone car must attack
end)

test("keeper waits in front of its own goal and follows the ball sideways", function()
	local x, z = Flow.keeperTarget(1, 3)
	truthy(x < 0 and x > -Config.length / 2)
	near(x, -(Config.length / 2 - Config.keeperDepth))
	eq(z, 3)
	x, z = Flow.keeperTarget(2, 50)
	truthy(x > 0)
	eq(z, Config.keeperRange)
	truthy(Config.keeperRange < Config.goalWidth / 2)
	_, z = Flow.keeperTarget(1, -50)
	eq(z, -Config.keeperRange)
end)

test("bots: keeper stays home until the ball is near its goal, chasers attack", function()
	-- ball in the middle: keeper stays at its post
	local tx, tz = Flow.botAim(true, 1, 0, 0, -30, 0)
	near(tx, -(Config.length / 2 - Config.keeperDepth))
	eq(tz, 0)
	-- ball close to team 1's goal: keeper drives out to clear it (aim behind the ball, toward +X goal)
	local bx = -Config.length / 2 + 10
	tx = Flow.botAim(true, 1, bx, 0, -45, 0)
	truthy(tx < bx)
	-- a chaser of team 1 aims behind the ball, on the side away from the +X goal it attacks
	tx, tz = Flow.botAim(false, 1, 10, 5, -20, 0)
	truthy(tx < 10)
	-- once lined up it drives straight into the ball
	tx, tz = Flow.botAim(false, 1, 10, 0, 10 - Config.botOffset, 0)
	eq(tx, 10)
	eq(tz, 0)
	-- team 2 chaser is mirrored
	tx = Flow.botAim(false, 2, 10, 5, 40, 0)
	truthy(tx > 10)
end)

test("camera: behind your car, high, ball and car both in a narrow view", function()
	local fov = math.rad(70) / 2 -- generous: real vertical half angle is 35 degrees
	local cases = {
		{ -40, 0, 0, 0, 1, 0 },
		{ -50, -25, 50, 25, 1, 0 },
		{ 50, 25, -50, -25, -1, 0 },
		{ 0, 30, 0, -30, 0, -1 },
		{ -55, 0, 55, 0, 1, 0 },
		{ 10, 10, 10.2, 10, 1, 0 }, -- ball right at the car
	}
	for i, c in cases do
		local f = Flow.cameraFrame(c[1], c[2], c[3], c[4], c[5], c[6])
		truthy(f.camY >= Config.camUp and f.camY <= Config.camMaxUp)
		local vx, vy, vz = f.lookX - f.camX, f.lookY - f.camY, f.lookZ - f.camZ
		local vl = math.sqrt(vx * vx + vy * vy + vz * vz)
		for _, t in { { c[3], c[4] }, { c[1], c[2] } } do
			local dx, dy, dz = t[1] - f.camX, 0 - f.camY, t[2] - f.camZ
			local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
			local cosA = (vx * dx + vy * dy + vz * dz) / (vl * dl)
			truthy(math.acos(math.clamp(cosA, -1, 1)) < fov, "case " .. i .. " target out of frame")
		end
	end
end)

test("camera: sits on the far side of the car from the ball, rises with distance", function()
	local near1 = Flow.cameraFrame(-10, 0, 0, 0, 1, 0)
	local far1 = Flow.cameraFrame(-50, 0, 40, 0, 1, 0)
	truthy(far1.camY > near1.camY)
	truthy(far1.camX < -50 + 1) -- behind: further from the ball than the car
	truthy(math.abs(far1.camX) <= Config.length / 2 + Config.goalDepth + Config.camMargin)
	-- no jitter: with the ball on the car the camera falls back to behind the car's nose
	local f = Flow.cameraFrame(0, 0, 0, 0, 1, 0)
	truthy(f.camX < 0)
	-- never inside-out numbers
	local g = Flow.cameraFrame(5, 5, 5, 5, 0, 0)
	truthy(g.camX == g.camX and g.camZ == g.camZ)
end)
