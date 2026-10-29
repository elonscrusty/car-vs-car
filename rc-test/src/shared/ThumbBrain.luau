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
-- backing up, like a kid (Lead R7-1; ArenaBrain.BACK_TIME): stuck, or the target far behind at
-- low speed (a turn on the spot it can't make), so it holds brake (= reverse) and turns the nose
ThumbBrain.BACK_TIME = 0.8 -- s of reverse
ThumbBrain.BACK_STUCK = 0.6 -- s slower than BACK_SLOW pressing the gas = stuck
ThumbBrain.BACK_SLOW = 2 -- studs/s
ThumbBrain.BEHIND = math.rad(120) -- the target this far off the nose...
ThumbBrain.BEHIND_SPEED = 4 -- ...while slower than this (studs/s) = back up and swing round
ThumbBrain.BACK_GAP = 1 -- s of driving before it may back up again
-- round and round a box or kart it's too close to turn onto (Lead R8: 3.5 studs/s, 3 boxes): a
-- kid lifts off the gas to turn tighter, then backs up
ThumbBrain.ORBIT_NEAR = 10 -- studs
ThumbBrain.ORBIT_ANGLE = math.rad(50) -- the target this far off the nose, this near...
ThumbBrain.ORBIT_EASE = 1 -- ...for this long (s): ease off the gas
ThumbBrain.ORBIT_GAS = 0.35
ThumbBrain.ORBIT_BACK = 3 -- ...for this long: back up
-- the same back-up again and again in one spot (a corner): drive off to the side and give up on
-- that target for a while
ThumbBrain.LOOP_NEAR = 5 -- studs between back-ups that count as the same spot
ThumbBrain.LOOP_TIME = 5 -- s between them
ThumbBrain.LOOPS = 3 -- this many = a loop
ThumbBrain.DETOUR_TIME = 1.8 -- s driving at a point off to the side
ThumbBrain.DETOUR_DIST = 12 -- studs
ThumbBrain.AVOID_TIME = 6 -- s it skips the target it couldn't reach

export type Point = { x: number, z: number }
-- where, the nose, and (optional) the flat speed in studs/s (no speed = never backs up)
export type Me = { x: number, z: number, fx: number, fz: number, speed: number? }
-- mode: "drive", "ease" (off the gas to turn tighter), "back" (reverse) or "detour"
export type Out = {
	steer: number,
	throttle: number,
	brake: number,
	fire: boolean,
	target: Point?,
	mode: string,
}
export type Rng = { NextNumber: (any) -> number }
export type State = {
	rng: Rng,
	seenAt: number, -- when it last looked
	aimAt: Point?, -- the box it saw then
	karts: { Point }, -- the karts it saw then
	coneSince: number?, -- since when a kart has been in the cone
	noise: number,
	slowFor: number, -- s slow while pressing the gas
	lastAt: number?, -- the last step's time
	backUntil: number, -- reversing until then
	orbitFor: number, -- s with the target near and off to the side
	backAt: Point?, -- where it last started backing up...
	backT: number, -- ...when
	loops: number, -- back-ups in a row in one spot
	detour: Point?, -- driving at this point instead...
	detourUntil: number, -- ...until then
	detourSide: number, -- which side the next detour goes (+1 right, -1 left)
	avoid: Point?, -- the target it gave up on...
	avoidUntil: number, -- ...until then
}

-- On only in Studio, and only with the workspace attribute set to true (off by default).
function ThumbBrain.allowed(isStudio: boolean, attr: unknown): boolean
	return isStudio == true and attr == true
end

function ThumbBrain.new(rng: Rng): State
	return {
		rng = rng,
		seenAt = -math.huge,
		aimAt = nil,
		karts = {},
		coneSince = nil,
		noise = 0,
		slowFor = 0,
		lastAt = nil,
		backUntil = -math.huge,
		orbitFor = 0,
		backAt = nil,
		backT = -math.huge,
		loops = 0,
		detour = nil,
		detourUntil = -math.huge,
		detourSide = 1,
		avoid = nil,
		avoidUntil = -math.huge,
	}
end

-- The angle (radians, + = to the right) from the nose to `p`, and how far it is.
local function angleTo(me: Me, p: Point): (number, number)
	local dx, dz = p.x - me.x, p.z - me.z
	local fwd = dx * me.fx + dz * me.fz
	-- right of the nose (Roblox: the right of look (fx, fz) is (-fz, fx))
	local right = dx * -me.fz + dz * me.fx
	return math.atan2(right, fwd), math.sqrt(dx * dx + dz * dz)
end

-- (near the target it gave up on: skip it)
local function skipped(avoid: Point?, p: Point): boolean
	return avoid ~= nil and (p.x - avoid.x) ^ 2 + (p.z - avoid.z) ^ 2 < 9
end

-- The kart to chase: the nearest one within CHASE of the nose, else the nearest of all.
local function chase(me: Me, karts: { Point }, avoid: Point?): Point?
	local ahead, aheadD, any, anyD = nil, math.huge, nil, math.huge
	for _, k in karts do
		if skipped(avoid, k) then
			continue
		end
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
		local avoid = if now < s.avoidUntil then s.avoid else nil
		local best = if armed then chase(me, karts, avoid) else nil
		if not best then
			local bestD = math.huge
			for _, b in boxes do
				local d = math.sqrt((b.x - me.x) ^ 2 + (b.z - me.z) ^ 2)
				if d < bestD and not skipped(avoid, b) then
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
	local detouring = s.detour ~= nil and now < s.detourUntil
	if detouring then
		aim = s.detour
	end
	if aim then
		local a = angleTo(me, aim)
		steer = math.clamp(a / ThumbBrain.FULL_TURN, -1, 1) + s.noise
	end
	steer = math.clamp(steer + math.sin(now * 2.3) * ThumbBrain.WOBBLE * 0.5, -1, 1)
	-- back up: stuck, or a target far behind it can't turn to at this speed
	local dt = if s.lastAt then math.clamp(now - s.lastAt, 0, 0.5) else 0
	s.lastAt = now
	local throttle, brake = 1, 0
	local mode = if detouring then "detour" else "drive"
	local speed = me.speed
	if now < s.backUntil then
		throttle, brake, mode = 0, 1, "back"
		-- (in reverse the nose swings the other way: steer away to point it at the target)
		steer = -(if aim and angleTo(me, aim) < 0 then -1 else 1)
	elseif speed then
		s.slowFor = if speed < ThumbBrain.BACK_SLOW then s.slowFor + dt else 0
		local a, d = 0, math.huge
		if aim then
			a, d = angleTo(me, aim)
		end
		local behind = aim ~= nil and math.abs(a) > ThumbBrain.BEHIND
		local orbiting = not detouring
			and d < ThumbBrain.ORBIT_NEAR
			and math.abs(a) > ThumbBrain.ORBIT_ANGLE
		s.orbitFor = if orbiting then s.orbitFor + dt else 0
		local free = now >= s.backUntil + ThumbBrain.BACK_GAP
		if
			free
			and (
				s.slowFor >= ThumbBrain.BACK_STUCK
				or (behind and speed < ThumbBrain.BEHIND_SPEED)
				or s.orbitFor >= ThumbBrain.ORBIT_BACK
			)
		then
			-- the same spot again and again: a loop (a corner it can't turn out of)
			local again = s.backAt ~= nil
				and now - s.backT < ThumbBrain.LOOP_TIME
				and (me.x - s.backAt.x) ^ 2 + (me.z - s.backAt.z) ^ 2 < ThumbBrain.LOOP_NEAR ^ 2
			s.loops = if again then s.loops + 1 else 1
			s.backAt, s.backT = { x = me.x, z = me.z }, now
			s.backUntil = now + ThumbBrain.BACK_TIME
			s.slowFor, s.orbitFor = 0, 0
			throttle, brake, mode = 0, 1, "back"
			steer = -(if aim and a < 0 then -1 else 1)
			if s.loops >= ThumbBrain.LOOPS then
				-- give up on that target for a while; once backed out, drive off to one side
				s.loops = 0
				if s.aimAt then
					s.avoid, s.avoidUntil = s.aimAt, now + ThumbBrain.AVOID_TIME
					s.seenAt = -math.huge -- (look again for another one)
				end
				local side = s.detourSide
				s.detourSide = -side
				s.detour = {
					x = me.x - me.fz * side * ThumbBrain.DETOUR_DIST,
					z = me.z + me.fx * side * ThumbBrain.DETOUR_DIST,
				}
				s.detourUntil = s.backUntil + ThumbBrain.DETOUR_TIME
			end
		elseif s.orbitFor >= ThumbBrain.ORBIT_EASE then
			throttle, mode = ThumbBrain.ORBIT_GAS, "ease"
		end
	end
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
	return {
		steer = steer,
		throttle = throttle,
		brake = brake,
		fire = fire,
		target = aim,
		mode = mode,
	}
end

-- ===== the round report (Studio copies it; Lead R7-1: why 1 smash in Studio, 2+ in the sim) =====
ThumbBrain.STUCK_SPEED = 2 -- studs/s: slower than this while alive = stuck or wedged
ThumbBrain.FLIPPED_UP = 0.5 -- the kart's up this far off the sky = on its side or roof
ThumbBrain.JUMP = 8 -- studs in one frame while alive = put back (OOPS) or a respawn
ThumbBrain.SIM_SPEED = "11-17" -- the sim kid's speed (tests/new_kid_pass), studs/s
ThumbBrain.STUCK_LOG = 1 -- s slow in a row = a stuck moment (logged with where and what)
ThumbBrain.FLIP_LOG = 0.5 -- s on its side in a row = a flip moment
ThumbBrain.STRAIGHT = math.rad(20) -- stuck with the target this close to the nose = the arena's
-- doing (it was driving straight at it); more = it was turning (its wobble or turning circle)
ThumbBrain.CELL = 6 -- studs: catch spots this close together are one spot

export type Spot = { kind: string, x: number, z: number, what: string, straight: boolean }

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
	stuckRun: number, -- s slow in a row right now
	flipRun: number, -- s on its side in a row right now
	spots: { Spot }, -- each stuck or flip moment
	backs: number, -- back-ups started
	detours: number, -- loops it drove out of
	eased: number, -- s off the gas to turn tighter
	pinned: number, -- moments it got under NET_MIN studs in NET_TIME s, slowly (pinned, sliding)
	circling: number, -- ... or quickly (round and round)
	modeWas: string, -- last frame's mode
	trail: { { t: number, x: number, z: number, d: number } }, -- recent spots, and dist so far
	netAt: number, -- when the last pinned/circling moment was logged
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
		stuckRun = 0,
		flipRun = 0,
		spots = {},
		backs = 0,
		detours = 0,
		eased = 0,
		pinned = 0,
		circling = 0,
		modeWas = "drive",
		trail = {},
		netAt = -math.huge,
	}
end

ThumbBrain.NET_TIME = 3 -- s: got under NET_MIN studs from where it was this long ago...
ThumbBrain.NET_MIN = 4 -- ...= a pinned or circling moment (catches what STUCK_LOG misses:
-- sliding along a wall with the gas on, a back-up loop, round and round a box)
ThumbBrain.CIRCLE_SPEED = 2.5 -- studs/s along its path: faster than this = circling, else pinned

-- The thumb's mode this frame (from ThumbBrain.step): counts back-ups, detours and ease time.
function ThumbBrain.mode(t: Tally, dt: number, mode: string)
	if mode ~= t.modeWas then
		if mode == "back" then
			t.backs += 1
		elseif mode == "detour" then
			t.detours += 1
		end
		t.modeWas = mode
	end
	if mode == "ease" and dt > 0 and dt <= 0.5 then
		t.eased += dt
	end
end

-- Where it is now (call every frame alive, after sample). Returns "pinned" or "circling" when it
-- has got under NET_MIN studs from where it was NET_TIME s ago (once per NET_TIME s), else nil.
function ThumbBrain.net(t: Tally, now: number, x: number, z: number): string?
	local trail = t.trail
	local last = trail[#trail]
	if last and now - last.t < 0.25 then
		return nil -- (a spot every 0.25 s is plenty)
	end
	local d = if last then last.d + math.sqrt((x - last.x) ^ 2 + (z - last.z) ^ 2) else 0
	table.insert(trail, { t = now, x = x, z = z, d = d })
	while #trail > 1 and now - trail[2].t >= ThumbBrain.NET_TIME do
		table.remove(trail, 1)
	end
	local first = trail[1]
	if now - first.t < ThumbBrain.NET_TIME or now - t.netAt < ThumbBrain.NET_TIME then
		return nil
	end
	if (x - first.x) ^ 2 + (z - first.z) ^ 2 >= ThumbBrain.NET_MIN ^ 2 then
		return nil
	end
	t.netAt = now
	local pathSpeed = (d - first.d) / (now - first.t)
	if pathSpeed > ThumbBrain.CIRCLE_SPEED then
		t.circling += 1
		return "circling"
	end
	t.pinned += 1
	return "pinned"
end

-- (a jump, a death or a respawn: the trail starts again)
function ThumbBrain.netReset(t: Tally)
	table.clear(t.trail)
end

-- Forget being slow or backing up (smashed, or frozen at a spawn).
function ThumbBrain.calm(s: State)
	s.slowFor, s.lastAt, s.backUntil = 0, nil, -math.huge
	s.orbitFor, s.loops, s.backAt, s.detour, s.detourUntil = 0, 0, nil, nil, -math.huge
	s.avoid, s.avoidUntil = nil, -math.huge
end

-- The angle (radians, + = right) from the nose to `p`.
function ThumbBrain.angle(me: Me, p: Point): number
	return (angleTo(me, p))
end

-- One frame alive: moved `moved` studs (flat) in `dt` s, the kart's up has `upY`. Returns the
-- moments that start this frame ({"stuck"}, {"flip"} or both; the caller logs where), else nil.
function ThumbBrain.sample(t: Tally, dt: number, moved: number, upY: number): { string }?
	if dt <= 0 or dt > 0.5 then
		return nil -- (a hitch or a pause: not driving)
	end
	if moved > ThumbBrain.JUMP then
		t.putBack += 1
		t.stuckRun, t.flipRun = 0, 0
		table.clear(t.trail)
		return nil
	end
	t.alive += dt
	t.dist += moved
	local events: { string }? = nil
	if moved / dt < ThumbBrain.STUCK_SPEED then
		t.stuck += dt
		local was = t.stuckRun
		t.stuckRun += dt
		if was < ThumbBrain.STUCK_LOG and t.stuckRun >= ThumbBrain.STUCK_LOG then
			events = { "stuck" }
		end
	else
		t.stuckRun = 0
	end
	if upY < ThumbBrain.FLIPPED_UP then
		t.flipped += dt
		local was = t.flipRun
		t.flipRun += dt
		if was < ThumbBrain.FLIP_LOG and t.flipRun >= ThumbBrain.FLIP_LOG then
			events = events or {}
			table.insert(events, "flip")
		end
	else
		t.flipRun = 0
	end
	return events
end

-- A stuck or flip moment at (x, z), touching `what`; `straight` = its target was near the nose.
function ThumbBrain.spot(
	t: Tally,
	kind: string,
	x: number,
	z: number,
	what: string,
	straight: boolean
)
	table.insert(t.spots, { kind = kind, x = x, z = z, what = what, straight = straight })
end

-- The catch spots, most hit first: "(x, z) N stuck M flip on <what>", grouped by CELL.
function ThumbBrain.spotList(spots: { Spot }, most: number): { string }
	local cells: { [string]: { x: number, z: number, stuck: number, flip: number, what: { [string]: number } } } =
		{}
	local order = {}
	for _, sp in spots do
		local key = math.floor(sp.x / ThumbBrain.CELL) .. "," .. math.floor(sp.z / ThumbBrain.CELL)
		local c = cells[key]
		if not c then
			c = { x = sp.x, z = sp.z, stuck = 0, flip = 0, what = {} }
			cells[key] = c
			table.insert(order, c)
		end
		if sp.kind == "flip" then
			c.flip += 1
		else
			c.stuck += 1
		end
		c.what[sp.what] = (c.what[sp.what] or 0) + 1
	end
	table.sort(order, function(a, b)
		return a.stuck + a.flip > b.stuck + b.flip
	end)
	local out = {}
	for i, c in order do
		if i > most then
			break
		end
		local best, n = "?", 0
		for w, k in c.what do
			if k > n or (k == n and w < best) then
				best, n = w, k
			end
		end
		table.insert(
			out,
			string.format(
				"(%d, %d) %d stuck %d flip on %s",
				math.floor(c.x + 0.5),
				math.floor(c.z + 0.5),
				c.stuck,
				c.flip,
				best
			)
		)
	end
	return out
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
			"  boxes %d (%s), shots %d, locked on %d (nose %d), hits landed %d (each gun bullet counts)",
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
		(function(): string
			local straight, turning, flips = 0, 0, 0
			for _, sp in t.spots do
				if sp.kind == "flip" then
					flips += 1
				elseif sp.kind ~= "stuck" then
					continue -- (pinned / circling: their own counts)
				elseif sp.straight then
					straight += 1
				else
					turning += 1
				end
			end
			return string.format(
				"  stuck moments %d (%d driving straight at its target = the arena, %d turning = the thumb), flips %d, pinned %d, circling %d, back-ups %d, detours %d, eased %.0f s",
				straight + turning,
				straight,
				turning,
				flips,
				t.pinned,
				t.circling,
				t.backs,
				t.detours,
				t.eased
			)
		end)(),
		"  catch spots: "
			.. (if #t.spots > 0 then table.concat(ThumbBrain.spotList(t.spots, 8), "; ") else "-"),
	}
end

return ThumbBrain
