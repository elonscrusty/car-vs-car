--!strict
-- The driving and weapon "brain" of one auto-battle fighter (pure, unit tested).
-- Each step it is told where both cars are and what touched what, and it answers with how to
-- steer and drive, whether to fire, and how much damage a ram or saw contact deals.
-- The server turns the answer into movement; tests run it on a flat 2D copy of the arena.
--
-- Space: arena-local x and z in studs. A body has a position and a unit forward vector.
-- turn: +1 = full turn to the left (counterclockwise seen from above), -1 = right.
-- drive: speed as a multiple of the car's cruise speed (negative = reverse).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

export type Body = { x: number, z: number, fx: number, fz: number }
export type Arena = {
	halfX: number,
	halfZ: number,
	obstacles: { { x: number, z: number, hx: number, hz: number } },
}
export type Contact = {
	ram: boolean,
	saw: boolean,
	speedFrac: number?, -- how fast the car is going, 0..1 of its full charge speed (ram damage scales with it)
	tempo: number?, -- weapon cooldowns run this many times faster (the final phase); default 1
}
export type Output = {
	turn: number,
	drive: number,
	fire: boolean, -- Cannon: launch the shell now (the car is holding still, aimed)
	damage: number, -- Ram / Saw: damage to deal to the foe this step
	event: string?, -- a short message for the HUD, nil most steps
	hold: boolean, -- true while telegraphing: the car stands still on purpose
	state: string,
	ready: number, -- 0..1 how ready the weapon is
	boost: number?, -- player cars: 1 while the boost burns
	boostReady: number?, -- player cars: 0..1 how ready the boost is
}
export type Brain = {
	fighterId: string,
	step: (dt: number, me: Body, foe: Body, contact: Contact) -> Output,
	shellResolved: (hit: boolean) -> string?,
	resetStuck: () -> (),
}

local BattleBrain = {}

local DEG = math.pi / 180

local function clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

-- Signed angle from direction f to direction d. Positive = d is to the left.
local function signedAngle(fx: number, fz: number, dx: number, dz: number): number
	return math.atan2(fz * dx - fx * dz, fx * dx + fz * dz)
end
BattleBrain.signedAngle = signedAngle

local function normalize(x: number, z: number): (number, number, number)
	local len = math.sqrt(x * x + z * z)
	if len < 1e-6 then
		return 0, 0, 0
	end
	return x / len, z / len, len
end

-- A push away from walls and blocks when a car is close to them (0,0 when far).
local function avoidance(me: Body, arena: Arena, L: number): (number, number)
	local margin = BattleConfig.Move.wallMarginL * L
	local obMargin = BattleConfig.Move.blockMarginL * L
	local ax, az = 0, 0
	local dx = arena.halfX - math.abs(me.x)
	if dx < margin then
		ax -= (if me.x >= 0 then 1 else -1) * (1 - dx / margin) * 2
	end
	local dz = arena.halfZ - math.abs(me.z)
	if dz < margin then
		az -= (if me.z >= 0 then 1 else -1) * (1 - dz / margin) * 2
	end
	for _, ob in arena.obstacles do
		-- nearest point of the block to the car
		local nx = clamp(me.x, ob.x - ob.hx, ob.x + ob.hx)
		local nz = clamp(me.z, ob.z - ob.hz, ob.z + ob.hz)
		local vx, vz = me.x - nx, me.z - nz
		local d = math.sqrt(vx * vx + vz * vz)
		if d < obMargin then
			if d < 1e-3 then
				vx, vz = normalize(me.x - ob.x, me.z - ob.z)
				d = 0
			else
				vx, vz = vx / d, vz / d
			end
			local s = (1 - d / obMargin) * 2
			ax += vx * s
			az += vz * s
		end
	end
	return ax, az
end

-- Blends the wanted direction with the push away from walls and blocks.
local function steerDirection(
	me: Body,
	gx: number,
	gz: number,
	arena: Arena,
	L: number
): (number, number)
	local ax, az = avoidance(me, arena, L)
	if ax == 0 and az == 0 then
		return gx, gz
	end
	local x, z, len = normalize(gx + ax * 1.6, gz + az * 1.6)
	if len == 0 then
		return gx, gz
	end
	return x, z
end

local function turnFor(angle: number): number
	return clamp(angle / 0.6, -1, 1)
end

-- True when the straight line between two points passes through a block (a shell would stop).
local function lineBlocked(
	arena: Arena,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	pad: number
): boolean
	local dx, dz = bx - ax, bz - az
	for _, ob in arena.obstacles do
		local tmin, tmax = 0, 1
		local hit = true
		for axis = 1, 2 do
			local o = if axis == 1 then ax else az
			local d = if axis == 1 then dx else dz
			local lo = (if axis == 1 then ob.x - ob.hx else ob.z - ob.hz) - pad
			local hi = (if axis == 1 then ob.x + ob.hx else ob.z + ob.hz) + pad
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then
					hit = false
					break
				end
			else
				local t1, t2 = (lo - o) / d, (hi - o) / d
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then
					hit = false
					break
				end
			end
		end
		if hit then
			return true
		end
	end
	return false
end
BattleBrain.lineBlocked = lineBlocked

-- Slow down when the nose points far from where the car wants to go.
local function driveForAngle(base: number, angle: number): number
	local a = math.abs(angle)
	return base * clamp(1 - (a - 0.5) / 1.6, 0.25, 1)
end

function BattleBrain.new(fighterId: string, L: number, arena: Arena, momentum: boolean?): Brain
	local move = BattleConfig.Move
	local mom = BattleConfig.Momentum
	local isMomentum = momentum == true
	local ram = BattleConfig.Ram
	local cannon = BattleConfig.Cannon
	local saw = BattleConfig.Saw

	-- shared
	local anchorX, anchorZ, anchorT, driveSum = 0, 0, 0, 0
	local anchorSet = false
	local recoverT = 0 -- > 0 while recovering
	local recoverSide = 1
	local recoverTotal = move.recoverReverse + move.recoverTurn
	local resetStuck: () -> ()

	-- weapon state
	local state = "approach"
	local stateT = 0
	local cooldown = 0
	local downtime = 0
	local chargeHit = false
	local sawCooldown = 0
	local sawEventCooldown = 0
	local peelSide = 1 -- which side the ram veers to while it recharges (flips every attack)
	local flip = 1 -- alternates the side a recovery turns to
	local tempo = 1 -- set every step from the contact info
	local sawContactT, sawGapT = 0, 0 -- steady saw contact builds damage
	local sawHeat, sawStallT = 0, 0 -- bounce fight: the saw overheats and stalls after long contact
	local fleeT, standT = 0, 0 -- cannon: time spent running, and time left standing to fight

	function resetStuck()
		anchorSet = false
		driveSum = 0
		anchorT = 0
	end

	local function stuckCheck(dt: number, me: Body, foeDist: number, drive: number): boolean
		if not anchorSet then
			anchorX, anchorZ, anchorT, driveSum, anchorSet = me.x, me.z, 0, 0, true
		end
		anchorT += dt
		driveSum += math.abs(drive) * dt
		if anchorT < move.stuckWindow then
			return false
		end
		local moved = math.sqrt((me.x - anchorX) ^ 2 + (me.z - anchorZ) ^ 2)
		local wantedToMove = driveSum / anchorT > 0.3
		anchorX, anchorZ, anchorT, driveSum = me.x, me.z, 0, 0
		return wantedToMove and moved < move.stuckDistL * L and foeDist > 1.6 * L
	end

	local function recoverStep(dt: number, me: Body): Output
		recoverT -= dt
		local elapsed = recoverTotal - recoverT
		local turn, drive = recoverSide, -0.7
		if elapsed >= move.recoverReverse then
			-- turn toward the middle of the arena and go
			local ax, az = normalize(-me.x, -me.z)
			local angle = signedAngle(me.fx, me.fz, ax, az)
			turn, drive = turnFor(angle), 0.6
		end
		if recoverT <= 0 then
			recoverT = 0
			resetStuck()
		end
		local out: Output = {
			turn = turn,
			drive = drive,
			fire = false,
			damage = 0,
			hold = false,
			state = "recover",
			ready = 0,
		}
		return out
	end

	local function startRecover()
		recoverT = recoverTotal
		flip = -flip
		recoverSide = flip
	end

	local brain: Brain = {
		fighterId = fighterId,
		step = nil :: any,
		shellResolved = nil :: any,
		resetStuck = resetStuck,
	}

	local function out(turn: number, drive: number, ready: number): Output
		local o: Output = {
			turn = turn,
			drive = drive,
			fire = false,
			damage = 0,
			hold = false,
			state = state,
			ready = ready,
		}
		return o
	end

	-- RAM TRUCK ----------------------------------------------------------------------------
	local function stepRam(dt: number, me: Body, foe: Body, contact: Contact): Output
		cooldown = math.max(0, cooldown - dt * tempo)
		stateT += dt
		local dx, dz, dist = normalize(foe.x - me.x, foe.z - me.z)
		local angle = signedAngle(me.fx, me.fz, dx, dz)
		local readyFrac = if cooldown <= 0 then 1 else 1 - cooldown / ram.cooldownSeconds

		if state == "telegraph" then
			-- momentum: the wind-up is a short surge, the truck keeps rolling instead of stopping
			local o = out(0, if isMomentum then 0.5 else 0, readyFrac)
			o.hold = not isMomentum
			if
				stateT >= (if isMomentum then 0.5 * ram.telegraphSeconds else ram.telegraphSeconds)
			then
				state, stateT, chargeHit = "charge", 0, false
			end
			return o
		elseif state == "charge" then
			-- No steering: the direction is committed, so a miss is possible.
			local o = out(0, ram.chargeMult, 0)
			local inFront = math.abs(angle) <= ram.frontConeDeg * DEG
			if contact.ram and inFront and not chargeHit then
				chargeHit = true
				-- a faster charge hits harder
				local fracSpeed = clamp(contact.speedFrac or 1, 0, 1)
				o.damage =
					math.floor(ram.damageMin + (ram.damage - ram.damageMin) * fracSpeed + 0.5)
				o.event = "Ram hit"
				state, stateT, cooldown = "recoil", 0, ram.cooldownSeconds
				o.state = state
			elseif stateT >= ram.chargeSeconds then
				o.event = "Ram missed"
				state, stateT = "skid", 0
				cooldown = ram.cooldownSeconds
				downtime = ram.missDowntimeSeconds
				o.state = state
			end
			return o
		elseif state == "recoil" then
			-- a hit bounces the truck back so the cars separate
			local o = out(0.3 * peelSide, ram.recoilDrive, readyFrac)
			if stateT >= ram.recoilSeconds then
				state, stateT = "approach", 0
				peelSide = -peelSide
			end
			return o
		elseif state == "skid" then
			-- a miss: the truck rolls on past the foe, sliding (the server brakes gently)
			local o = out(0.15 * peelSide, 0, readyFrac)
			if stateT >= ram.skidSeconds then
				state, stateT = "approach", 0
				peelSide = -peelSide
			end
			return o
		end

		downtime = math.max(0, downtime - dt)
		local gx, gz = steerDirection(me, dx, dz, arena, L)
		if cooldown > 0 and dist < ram.peelRangeL * L and not isMomentum then
			-- recharging: veer off to the side instead of pushing on the foe, then come back
			local a = peelSide * ram.peelAngleDeg * DEG
			local ax, az = -dx, -dz -- directly away
			local rx = ax * math.cos(a) - az * math.sin(a)
			local rz = ax * math.sin(a) + az * math.cos(a)
			gx, gz = steerDirection(me, rx, rz, arena, L)
		end
		local gangle = signedAngle(me.fx, me.fz, gx, gz)
		local drive = driveForAngle(1, gangle)
		if downtime > 0 then
			drive = ram.missDowntimeDrive
		end
		local o = out(turnFor(gangle), drive, readyFrac)
		-- turning slowly after a miss is part of the weakness
		if downtime > 0 then
			o.turn *= 0.5
		end
		if
			cooldown <= 0
			and downtime <= 0
			and dist <= ram.startRangeL * (if isMomentum then 2.2 else 1) * L
			and math.abs(angle) <= ram.startAngleDeg * (if isMomentum then 2.5 else 1) * DEG
		then
			state, stateT = "telegraph", 0
			o.state = state
			o.hold = not isMomentum
			if not isMomentum then
				o.drive, o.turn = 0, 0
			end
		end
		return o
	end

	-- CANNON VAN ---------------------------------------------------------------------------
	local function stepCannon(dt: number, me: Body, foe: Body, _contact: Contact): Output
		cooldown = math.max(0, cooldown - dt * tempo)
		stateT += dt
		local dx, dz, dist = normalize(foe.x - me.x, foe.z - me.z)
		local angle = signedAngle(me.fx, me.fz, dx, dz)
		local readyFrac = if cooldown <= 0 then 1 else 1 - cooldown / cannon.cooldownSeconds

		if state == "telegraph" then
			-- The direction is locked for the whole telegraph (still in the steering fight; rolling on
			-- in the momentum fight).
			local o = out(0, if isMomentum then 1 else 0, readyFrac)
			o.hold = not isMomentum
			if stateT >= cannon.telegraphSeconds then
				o.fire = true
				o.hold = false
				state, stateT, cooldown = "approach", 0, cannon.cooldownSeconds
				o.state = state
				o.ready = 0
			end
			return o
		end

		-- Running for too long means the foe is faster or a wall is behind us: turn and fight instead.
		if standT > 0 then
			standT -= dt
		elseif fleeT > cannon.fleeGiveUpSeconds then
			fleeT, standT = 0, cannon.standSeconds
		end

		local o: Output
		if isMomentum then
			-- keep rolling and swinging toward the foe; shoot whenever the gun happens to point at it
			o = out(turnFor(angle), 0.7, readyFrac)
			if cooldown <= 0 and dist <= mom.rangeL * L and math.abs(angle) <= mom.aimDeg * DEG then
				state, stateT = "telegraph", 0
				o.state = state
				o.turn = 0
			end
			return o
		elseif standT > 0 and not isMomentum then
			-- stand and fight: face the foe, shoot as soon as the gun points at it
			o = out(turnFor(angle), 0, readyFrac)
			if cooldown <= 0 and math.abs(angle) <= 3 * cannon.aimToleranceDeg * DEG then
				state, stateT = "telegraph", 0
				o.state = state
				o.hold = true
				o.turn = 0
			end
		elseif
			dist < 2.2 * L
			and cooldown <= 0
			and math.abs(angle) <= 3 * cannon.aimToleranceDeg * DEG
		then
			-- cornered by a fast foe with the gun ready and pointed at it: shoot, do not run
			state, stateT = "telegraph", 0
			o = out(0, 0, readyFrac)
			o.hold = true
		elseif dist < cannon.minRangeL * L then
			-- too close: run away (turn tail, then full speed), steering round walls and blocks
			local gx, gz = steerDirection(me, -dx, -dz, arena, L)
			local gangle = signedAngle(me.fx, me.fz, gx, gz)
			o = out(turnFor(gangle), driveForAngle(cannon.fleeDrive, gangle), readyFrac)
			o.state = "flee"
		elseif
			dist > cannon.maxRangeL * L or lineBlocked(arena, me.x, me.z, foe.x, foe.z, 0.2 * L)
		then
			-- too far, or a block is in the way: move to get a clear shot
			local gx, gz = steerDirection(me, dx, dz, arena, L)
			local gangle = signedAngle(me.fx, me.fz, gx, gz)
			o = out(turnFor(gangle), driveForAngle(cannon.repositionDrive, gangle), readyFrac)
		elseif cooldown > 0 and dist < cannon.maxRangeL * 0.75 * L then
			-- reloading with the foe still near: keep backing away so the next shot has room
			local gx, gz = steerDirection(me, -dx, -dz, arena, L)
			local gangle = signedAngle(me.fx, me.fz, gx, gz)
			o = out(turnFor(gangle), driveForAngle(0.9, gangle), readyFrac)
			o.state = "flee"
		else
			-- in the sweet spot: line up the shot. A small angle still gets a real turn command and
			-- a creep forward, so a slow car never freezes just short of lining up.
			local tol = cannon.aimToleranceDeg * DEG
			local tn = turnFor(angle)
			local creep = 0
			if math.abs(angle) > tol then
				tn = (if angle >= 0 then 1 else -1) * math.max(math.abs(tn), 0.5)
				creep = 0.3
			end
			o = out(tn, creep, readyFrac)
			if cooldown <= 0 and math.abs(angle) <= tol then
				state, stateT = "telegraph", 0
				o.state = state
				o.hold = true
				o.turn = 0
			end
		end
		fleeT = if o.state == "flee" and standT <= 0 then fleeT + dt else math.max(0, fleeT - dt)
		return o
	end

	-- SAW BUGGY ----------------------------------------------------------------------------
	local function stepSaw(dt: number, me: Body, foe: Body, contact: Contact): Output
		sawCooldown = math.max(0, sawCooldown - dt * tempo)
		sawEventCooldown = math.max(0, sawEventCooldown - dt)
		local dx, dz = normalize(foe.x - me.x, foe.z - me.z)
		local angle = signedAngle(me.fx, me.fz, dx, dz)
		local gx, gz = steerDirection(me, dx, dz, arena, L)
		local gangle = signedAngle(me.fx, me.fz, gx, gz)
		local o = out(
			turnFor(angle * 1.2 + (gangle - angle)),
			driveForAngle(saw.approachDrive, gangle),
			if sawCooldown <= 0 then 1 else 1 - sawCooldown / saw.tickSeconds
		)
		state = if contact.saw then "grind" else "approach"
		o.state = state
		local touching = contact.saw and math.abs(angle) <= saw.frontConeDeg * DEG
		if touching then
			sawContactT += dt
			sawGapT = 0
			if isMomentum then
				sawHeat += dt
				if sawHeat >= saw.heatSeconds then
					sawHeat, sawStallT, sawContactT = 0, saw.stallSeconds, 0
				end
			end
		else
			sawGapT += dt
			if sawGapT >= saw.loseContactSeconds then
				sawContactT = 0 -- contact lost: the build-up starts over
			end
		end
		if sawStallT > 0 then
			sawStallT -= dt
			touching = false
			sawHeat = 0
		end
		if touching and sawCooldown <= 0 then
			local build = clamp(sawContactT / saw.buildSeconds, 0, 1)
			o.damage = math.floor(saw.damage * (1 + (saw.maxMult - 1) * build) + 0.5)
			sawCooldown = saw.tickSeconds
			if sawEventCooldown <= 0 then
				o.event = "Saw contact"
				sawEventCooldown = saw.eventSeconds
			end
		end
		return o
	end

	function brain.step(dt: number, me: Body, foe: Body, contact: Contact): Output
		local inAttack = state == "telegraph" or state == "charge"
		local foeDist = math.sqrt((foe.x - me.x) ^ 2 + (foe.z - me.z) ^ 2)
		if recoverT > 0 and not isMomentum then
			-- timers keep running while backing out; the weapon stays idle
			cooldown = math.max(0, cooldown - dt * (contact.tempo or 1))
			sawCooldown = math.max(0, sawCooldown - dt * (contact.tempo or 1))
			return recoverStep(dt, me)
		end
		tempo = contact.tempo or 1
		local o: Output
		if fighterId == "RamTruck" then
			o = stepRam(dt, me, foe, contact)
		elseif fighterId == "CannonVan" then
			o = stepCannon(dt, me, foe, contact)
		else
			o = stepSaw(dt, me, foe, contact)
		end
		if not isMomentum and not inAttack and not o.hold and o.state ~= "charge" then
			if stuckCheck(dt, me, foeDist, o.drive) then
				startRecover()
			end
		else
			resetStuck()
		end
		return o
	end

	-- The server tells the brain how a shell ended so the HUD can say hit or missed.
	function brain.shellResolved(hit: boolean): string?
		return if hit then "Cannon hit" else "Cannon missed"
	end

	return brain
end

return BattleBrain
