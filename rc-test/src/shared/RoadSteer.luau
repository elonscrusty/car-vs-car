--!strict
-- A first race's helping hand for a kid who only holds the gas (AUTO GAS, no steering): where on
-- the road to aim, a little way ahead along the map's centre line. Studio pr842: with no steering
-- the car hit a wall every 5-6 s and was put back 14 times in one lap. Only the steering input is
-- filled in, and only while the kid doesn't steer: the car drives exactly as it always does.

local RoadSteer = {}

RoadSteer.AHEAD = 35 -- big units along the road to aim at
RoadSteer.GAIN = 1.6 -- steer per radian off that aim (1 = full lock)
RoadSteer.WINDOW = 12 -- samples searched either side of the last one (whole loop when lost)

type Sample = { x: number, z: number }

-- the centre line sample nearest (x, z); `hint` = the last one, to look near it only
function RoadSteer.nearest(loop: { Sample }, x: number, z: number, hint: number?): number
	local n = #loop
	local best, at = math.huge, 1
	local function look(k: number)
		local s = loop[k]
		local d = (s.x - x) ^ 2 + (s.z - z) ^ 2
		if d < best then
			best, at = d, k
		end
	end
	if hint and n > RoadSteer.WINDOW * 2 then
		for i = -RoadSteer.WINDOW, RoadSteer.WINDOW do
			look((hint - 1 + i) % n + 1)
		end
		-- (far from the window's best: a put-back or a short cut; look everywhere)
		if best <= 60 * 60 then
			return at
		end
	end
	for k = 1, n do
		look(k)
	end
	return at
end

-- the point AHEAD along the road from sample `k` (driving order; the loop is closed)
function RoadSteer.aim(loop: { Sample }, k: number): (number, number)
	local n = #loop
	local left = RoadSteer.AHEAD
	local i = k
	for _ = 1, n do
		local a = loop[i]
		local j = i % n + 1
		local b = loop[j]
		local d = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if d >= left then
			local f = left / math.max(d, 1e-6)
			return a.x + (b.x - a.x) * f, a.z + (b.z - a.z) * f
		end
		left -= d
		i = j
	end
	return loop[k].x, loop[k].z
end

-- the steering for an angle (radians, right positive) between the nose and the aim
function RoadSteer.steer(angle: number): number
	return math.clamp(angle * RoadSteer.GAIN, -1, 1)
end

return RoadSteer
