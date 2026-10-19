--!strict
local Harness = require("./harness")
local SoccerField = require("../src/shared/SoccerField")
local Config = require("../src/shared/SoccerFieldConfig")

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
