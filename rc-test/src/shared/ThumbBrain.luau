--!strict
-- The Studio-only "test thumb" (Lead 10-29, auditor R6-6: "a real driver gets 2+ smashes in
-- 60 s"; Studio's remote keys lag ~7 s). The no-skill kid of tests/new_kid_pass.test.luau on the
-- real stick and FIRE: it steers at the nearest "?" box that's up and taps FIRE whenever a kart
-- is within 30 deg ahead and in reach. Like a kid, it wobbles and sees things ~0.3 s late.
-- Pure maths (no Instances): client/TestThumb feeds it, Lune tests it. NEVER on in a live game:
-- ThumbBrain.allowed needs Studio AND workspace attribute TestThumb = true.

local ThumbBrain = {}

ThumbBrain.ATTR = "TestThumb" -- workspace attribute that turns it on (Studio only)
ThumbBrain.REACT = 0.3 -- seconds late it sees where things are
ThumbBrain.WOBBLE = 0.18 -- steer wobble, a thumb that isn't steady
ThumbBrain.FULL_TURN = 0.6 -- radians off the nose for full steer
ThumbBrain.CONE = math.rad(30) -- FIRE when a kart is this close to straight ahead...
ThumbBrain.RANGE = 35 -- ...and this near (studs), as new_kid_pass's kid

export type Point = { x: number, z: number }
export type Me = { x: number, z: number, fx: number, fz: number } -- where, and the nose
export type Out = { steer: number, throttle: number, fire: boolean, target: Point? }
export type Rng = { NextNumber: (any) -> number }
export type State = {
	rng: Rng,
	seenAt: number, -- when it last looked
	aimAt: Point?, -- the box it saw then
	karts: { Point }, -- the karts it saw then
	coneSince: number?, -- since when a kart has been in the cone
	noise: number,
}

-- On only in Studio, and only with the workspace attribute set to true (off by default).
function ThumbBrain.allowed(isStudio: boolean, attr: unknown): boolean
	return isStudio == true and attr == true
end

function ThumbBrain.new(rng: Rng): State
	return { rng = rng, seenAt = -math.huge, aimAt = nil, karts = {}, coneSince = nil, noise = 0 }
end

-- The angle (radians, + = to the right) from the nose to `p`, and how far it is.
local function angleTo(me: Me, p: Point): (number, number)
	local dx, dz = p.x - me.x, p.z - me.z
	local fwd = dx * me.fx + dz * me.fz
	-- right of the nose (Roblox: the right of look (fx, fz) is (-fz, fx))
	local right = dx * -me.fz + dz * me.fx
	return math.atan2(right, fwd), math.sqrt(dx * dx + dz * dz)
end

-- One frame. `boxes`: the "?" boxes that are up; `karts`: the live enemy karts; `armed`: holding
-- a weapon with ammo. Returns the stick (steer -1..1, throttle 0..1) and whether to tap FIRE.
function ThumbBrain.step(
	s: State,
	now: number,
	me: Me,
	boxes: { Point },
	karts: { Point },
	armed: boolean
): Out
	-- it looks again every REACT seconds: in between it acts on what it saw (a late thumb)
	if now - s.seenAt >= ThumbBrain.REACT then
		s.seenAt = now
		local best, bestD = nil, math.huge
		for _, b in boxes do
			local d = math.sqrt((b.x - me.x) ^ 2 + (b.z - me.z) ^ 2)
			if d < bestD then
				best, bestD = b, d
			end
		end
		s.aimAt = if best then { x = best.x, z = best.z } else nil
		s.karts = table.clone(karts)
		s.noise = (s.rng:NextNumber() * 2 - 1) * ThumbBrain.WOBBLE
	end
	local steer = s.noise
	local aim = s.aimAt
	if aim then
		local a = angleTo(me, aim)
		steer = math.clamp(a / ThumbBrain.FULL_TURN, -1, 1) + s.noise
	end
	steer = math.clamp(steer + math.sin(now * 2.3) * ThumbBrain.WOBBLE * 0.5, -1, 1)
	local fire = false
	local inCone = false
	if armed then
		for _, k in s.karts do
			local a, d = angleTo(me, k)
			if d > 0.1 and d <= ThumbBrain.RANGE and math.abs(a) <= ThumbBrain.CONE then
				inCone = true
				break
			end
		end
	end
	if inCone then
		s.coneSince = s.coneSince or now
		-- a kid presses FIRE a moment after a kart lines up
		fire = now - s.coneSince >= ThumbBrain.REACT
	else
		s.coneSince = nil
	end
	return { steer = steer, throttle = 1, fire = fire, target = aim }
end

return ThumbBrain
