--!strict
-- Claw machine motion (pure math, so Lune can test it). All numbers are studs in the machine's own
-- space, relative to where the claw rests. dy is 0 when raised and negative when lowered.

export type Pose = { dx: number, dz: number, dy: number, closed: boolean }
export type Spot = { x: number, z: number }

local ClawPath = {}

-- Seconds spent on each step, in order.
ClawPath.Steps = {
	{ name = "move", seconds = 1.1 },
	{ name = "drop", seconds = 0.8 },
	{ name = "grab", seconds = 0.4 },
	{ name = "lift", seconds = 0.8 },
	{ name = "carry", seconds = 1.2 },
	{ name = "release", seconds = 0.5 },
	{ name = "home", seconds = 1.0 },
}

function ClawPath.total(): number
	local t = 0
	for _, s in ClawPath.Steps do
		t += s.seconds
	end
	return t
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Where the claw is `t` seconds after the start.
-- `target`: where it goes down. `chute`: where the prize is dropped. `depth`: how far it lowers.
function ClawPath.pose(t: number, target: Spot, chute: Spot, depth: number): Pose
	local x, z, y = 0, 0, 0
	local closed = false
	local left = math.max(0, t)
	for _, step in ClawPath.Steps do
		local k = smooth(left / step.seconds)
		local done = left >= step.seconds
		if step.name == "move" then
			x, z = lerp(0, target.x, k), lerp(0, target.z, k)
		elseif step.name == "drop" then
			x, z, y = target.x, target.z, lerp(0, -depth, k)
		elseif step.name == "grab" then
			x, z, y = target.x, target.z, -depth
			closed = k >= 0.5
		elseif step.name == "lift" then
			x, z, y = target.x, target.z, lerp(-depth, 0, k)
			closed = true
		elseif step.name == "carry" then
			x, z, y = lerp(target.x, chute.x, k), lerp(target.z, chute.z, k), 0
			closed = true
		elseif step.name == "release" then
			x, z, y = chute.x, chute.z, 0
			closed = k < 0.5
		else -- home
			x, z, y = lerp(chute.x, 0, k), lerp(chute.z, 0, k), 0
		end
		if not done then
			return { dx = x, dz = z, dy = y, closed = closed }
		end
		left -= step.seconds
	end
	return { dx = 0, dz = 0, dy = 0, closed = false }
end

return ClawPath
