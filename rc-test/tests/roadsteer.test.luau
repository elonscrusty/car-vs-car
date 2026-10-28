--!strict
-- RoadSteer: a first race's helping hand for a kid who only holds the gas (Studio pr842: hit a
-- wall every 5-6 s, put back 14 times in one lap).
local H = require("./harness")
local RaceMaps = require("../src/shared/RaceMaps")
local RoadSteer = require("../src/shared/RoadSteer")

local test, eq, truthy = H.test, H.eq, H.truthy

test("RoadSteer: aims ahead along the road and steers toward it", function()
	local line = {
		{ x = 0, z = 0 },
		{ x = 10, z = 0 },
		{ x = 20, z = 0 },
		{ x = 30, z = 0 },
		{ x = 40, z = 0 },
	}
	eq(RoadSteer.nearest(line, 11, 3), 2)
	eq(RoadSteer.nearest(line, 29, -2, 2), 4)
	local ax, az = RoadSteer.aim(line, 1)
	truthy(ax > 0 and math.abs(az) < 1e-6, "aims the way the road goes")
	eq(RoadSteer.steer(0), 0)
	eq(RoadSteer.steer(5), 1)
	eq(RoadSteer.steer(-5), -1)
	truthy(RoadSteer.steer(0.2) > 0 and RoadSteer.steer(-0.2) < 0, "turns toward the aim")
end)

test("RoadSteer: a car with gas and no steering goes round every map on the road", function()
	-- a plain car: its nose turns toward the aim at up to TURN rad/s at full lock
	local SPEED, TURN, DT = 45, 1.6, 1 / 30
	for _, m in RaceMaps.list() do
		local loop = m.loop()
		local half = (m.ROAD or 30) / 2
		local a, b = loop[1], loop[2]
		local x, z = a.x, a.z
		local yaw = math.atan2(b.z - a.z, b.x - a.x)
		local at: number? = nil
		local worst, went = 0, 0
		local laps = 0
		local last = 1
		for _ = 1, 30 * 120 do
			local k = RoadSteer.nearest(loop, x, z, at)
			if at and k < last - #loop / 2 then
				laps += 1
			end
			last = k
			at = k
			local s = loop[k]
			worst = math.max(worst, math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2))
			local ax, az = RoadSteer.aim(loop, k)
			local want = math.atan2(az - z, ax - x)
			local off = (want - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw += RoadSteer.steer(off) * TURN * DT
			x += math.cos(yaw) * SPEED * DT
			z += math.sin(yaw) * SPEED * DT
			went += SPEED * DT
			if laps >= 1 then
				break
			end
		end
		truthy(laps >= 1, `{m.id}: didn't get round ({went} driven)`)
		truthy(worst < half, `{m.id}: left the road ({worst} from the middle, road half {half})`)
		print(
			`  {m.id}: round in {math.floor(went)} big units, at most {math.floor(worst)} from the middle`
		)
	end
	local fs = require("@lune/fs")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(string.find(main, "steer = RoadSteer.steer(angle)", 1, true), "not wired")
	truthy(
		string.find(main, "and math.abs(input.steer) < 0.05", 1, true),
		"the kid's steering must win"
	)
	truthy(
		string.find(main, 'and player:GetAttribute("EasyRace") == true\n\tthen', 1, true),
		"first race only"
	)
end)
