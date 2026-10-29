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
ThumbBrain.CHASE = math.rad(60) -- armed: chases the nearest kart this close to ahead, else the nearest

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

-- The kart to chase: the nearest one within CHASE of the nose, else the nearest of all.
local function chase(me: Me, karts: { Point }): Point?
	local ahead, aheadD, any, anyD = nil, math.huge, nil, math.huge
	for _, k in karts do
		local a, d = angleTo(me, k)
		if d < anyD then
			any, anyD = k, d
		end
		if math.abs(a) <= ThumbBrain.CHASE and d < aheadD then
			ahead, aheadD = k, d
		end
	end
	return ahead or any
end

-- One frame. `boxes`: the "?" boxes that are up; `karts`: the live enemy karts; `armed`: holding
-- a weapon with ammo. Unarmed it drives at the nearest box; armed it chases a kart (Lead R7-1: a
-- kid with a weapon goes after karts). Returns the stick (steer -1..1, throttle 0..1) and whether
-- to tap FIRE.
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
		local best = if armed then chase(me, karts) else nil
		if not best then
			local bestD = math.huge
			for _, b in boxes do
				local d = math.sqrt((b.x - me.x) ^ 2 + (b.z - me.z) ^ 2)
				if d < bestD then
					best, bestD = b, d
				end
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

-- ===== the round report (Studio copies it; Lead R7-1: why 1 smash in Studio, 2+ in the sim) =====
ThumbBrain.STUCK_SPEED = 2 -- studs/s: slower than this while alive = stuck or wedged
ThumbBrain.FLIPPED_UP = 0.5 -- the kart's up this far off the sky = on its side or roof
ThumbBrain.JUMP = 8 -- studs in one frame while alive = put back (OOPS) or a respawn
ThumbBrain.SIM_SPEED = "11-17" -- the sim kid's speed (tests/new_kid_pass), studs/s

export type Tally = {
	boxes: number, -- weapons picked up
	weapons: { string }, -- their names, in order
	shots: number, -- shots the server took (ammo went down)
	locked: number, -- of those, with a kart in the weapon's lock cone (the HUD's aim)
	lockedNose: number, -- ... with the cone along the nose instead (the sim kid's aim)
	hits: number, -- the server said a shot of ours hit (WeaponFx)
	hitsTaken: number,
	alive: number, -- seconds alive in the round
	stuck: number, -- of those, seconds slower than STUCK_SPEED
	flipped: number, -- seconds on its side or roof
	putBack: number, -- jumps while alive (OOPS / back to start)
	dist: number, -- studs driven while alive
}

function ThumbBrain.tally(): Tally
	return {
		boxes = 0,
		weapons = {},
		shots = 0,
		locked = 0,
		lockedNose = 0,
		hits = 0,
		hitsTaken = 0,
		alive = 0,
		stuck = 0,
		flipped = 0,
		putBack = 0,
		dist = 0,
	}
end

-- One frame alive: moved `moved` studs (flat) in `dt` s, the kart's up has `upY`.
function ThumbBrain.sample(t: Tally, dt: number, moved: number, upY: number)
	if dt <= 0 or dt > 0.5 then
		return -- (a hitch or a pause: not driving)
	end
	if moved > ThumbBrain.JUMP then
		t.putBack += 1
		return
	end
	t.alive += dt
	t.dist += moved
	if moved / dt < ThumbBrain.STUCK_SPEED then
		t.stuck += dt
	end
	if upY < ThumbBrain.FLIPPED_UP then
		t.flipped += dt
	end
end

-- Is this WeaponFx (kind, data) a shot of kart `myId` that hit someone?
function ThumbBrain.isHit(kind: unknown, data: unknown, myId: number): boolean
	if type(data) ~= "table" then
		return false
	end
	local d = data :: { [string]: unknown }
	if d.owner ~= myId then
		return false
	end
	if kind == "GunShot" or kind == "FreezeShot" then
		return d.hit == true
	elseif kind == "RocketBoom" then
		return d.hit ~= nil and d.quiet ~= true
	elseif kind == "MineBoom" then
		return true
	end
	return false
end

local function pct(part: number, whole: number): string
	return if whole > 0 then string.format("%d%%", math.floor(part / whole * 100 + 0.5)) else "-"
end

-- The lines printed at ROUND OVER.
function ThumbBrain.report(
	t: Tally,
	smashes: number,
	place: number,
	total: number,
	firstAt: number?
): { string }
	local speed = if t.alive > 0 then t.dist / t.alive else 0
	return {
		string.format(
			"round over: smashes %d, place %d/%d, hits taken %d, first smash %s",
			smashes,
			place,
			total,
			t.hitsTaken,
			if firstAt then string.format("%.1f s", firstAt) else "none"
		),
		string.format(
			"  boxes %d (%s), shots %d, locked on %d (nose %d), hits landed %d",
			t.boxes,
			if #t.weapons > 0 then table.concat(t.weapons, " ") else "-",
			t.shots,
			t.locked,
			t.lockedNose,
			t.hits
		),
		string.format(
			"  alive %.0f s, avg speed %.1f studs/s (sim kid %s), stuck %.0f s (%s), flipped %.0f s, put back %d",
			t.alive,
			speed,
			ThumbBrain.SIM_SPEED,
			t.stuck,
			pct(t.stuck, t.alive),
			t.flipped,
			t.putBack
		),
	}
end

return ThumbBrain
