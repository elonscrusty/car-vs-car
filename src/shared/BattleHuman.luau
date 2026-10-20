--!strict
-- The "brain" of a car that a PLAYER drives (pure, unit tested). It has the same shape as
-- BattleBrain, so the server runs both the same way: each step it is told where both cars are
-- and what touched what, and it answers with how to steer and drive, whether to fire, and how
-- much damage a ram or saw contact deals. The difference: steering and gas come from the player's
-- stick or keys, and the weapon fires when the player presses ATTACK.
--   Ram Truck:  ATTACK = a straight charge (no steering while it lasts). Faster hits harder.
--   Cannon Van: ATTACK = fire a shell along the nose (the server nudges it onto a foe it nearly faces).
--   Saw Buggy:  HOLD ATTACK to grind while its front touches the foe (up to a few seconds), then it waits.
-- Every weapon has the same long wait (6 s); the HUD button fills up like a clock during it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")
local BattleBrain = sibling("BattleBrain")
local BattleAim = sibling("BattleAim")

export type Body = { x: number, z: number, fx: number, fz: number }
export type Contact = { ram: boolean, saw: boolean, speedFrac: number?, tempo: number? }
export type Output = {
	turn: number,
	drive: number,
	fire: boolean,
	damage: number,
	event: string?,
	hold: boolean,
	state: string,
	ready: number,
}
export type Human = {
	fighterId: string,
	step: (dt: number, me: Body, foe: Body, contact: Contact) -> Output,
	shellResolved: (hit: boolean) -> string?,
	resetStuck: () -> (),
	setInput: (steer: number, gas: number, attackHeld: boolean) -> (),
	human: boolean,
}

local BattleHuman = {}

local DEG = math.pi / 180

local function clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

function BattleHuman.new(fighterId: string): Human
	local ram = BattleConfig.Ram
	local cannon = BattleConfig.Cannon
	local saw = BattleConfig.Saw
	local H = BattleConfig.Human

	local steer, gas = 0, 0
	local attackHeld = false -- ATTACK is down right now
	local attackPressed = false -- ATTACK went down since the last step (kept until a step uses it)

	local state = "drive"
	local stateT = 0
	local cooldown = 0
	local chargeHit = false
	local sawCooldown = 0
	local sawEventCooldown = 0
	local sawContactT, sawGapT = 0, 0
	local grindCooldown = 0 -- the saw's wait after a grind
	local grindT = 0
	local grinding = false

	local function cooldownTotal(): number
		if fighterId == "RamTruck" then
			return ram.cooldownSeconds
		elseif fighterId == "CannonVan" then
			return cannon.cooldownSeconds
		end
		return H.sawCooldownSeconds
	end

	-- 1 = ready (the HUD button is full and glows); during the wait it fills up
	local function readyFrac(): number
		if fighterId == "SawBuggy" and grinding then
			return 1 - grindT / H.sawGrindSeconds -- the grind time left drains
		end
		local c = if fighterId == "SawBuggy" then grindCooldown else cooldown
		return if c <= 0 then 1 else 1 - c / cooldownTotal()
	end

	local function out(turn: number, drive: number): Output
		return {
			turn = turn,
			drive = drive,
			fire = false,
			damage = 0,
			hold = false,
			state = state,
			ready = readyFrac(),
		}
	end

	local brain: Human = {
		fighterId = fighterId,
		human = true,
		setInput = function(s: number, g: number, held: boolean)
			steer = clamp(s, -1, 1)
			gas = clamp(g, -1, 1)
			if held and not attackHeld then
				attackPressed = true -- a new press: stays set until a step can use it
			end
			attackHeld = held
		end,
		step = function(dt: number, me: Body, foe: Body, contact: Contact): Output
			local tempo = contact.tempo or 1
			cooldown = math.max(0, cooldown - dt * tempo)
			sawCooldown = math.max(0, sawCooldown - dt * tempo)
			sawEventCooldown = math.max(0, sawEventCooldown - dt)
			stateT += dt
			local attack = attackPressed
			attackPressed = false
			-- the stick's turn: steer +1 is RIGHT, the brain's turn +1 is LEFT
			local turn = -steer
			local drive = gas
			local dx, dz = foe.x - me.x, foe.z - me.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist > 1e-6 then
				dx, dz = dx / dist, dz / dist
			end
			local angle = BattleBrain.signedAngle(me.fx, me.fz, dx, dz)

			if fighterId == "RamTruck" then
				if state == "charge" then
					-- direction committed; only auto-aim nudges it toward a foe that is nearly ahead
					local o = out(
						BattleAim.chargeTurn(angle, ram.homingConeDeg * DEG, ram.homingTurn),
						ram.chargeMult
					)
					local inFront = math.abs(angle) <= ram.frontConeDeg * DEG
					if contact.ram and inFront and not chargeHit then
						chargeHit = true
						local fracSpeed = clamp(contact.speedFrac or 1, 0, 1)
						o.damage = math.floor(
							ram.damageMin + (ram.damage - ram.damageMin) * fracSpeed + 0.5
						)
						o.event = "Ram hit"
						state, stateT, cooldown = "recoil", 0, ram.cooldownSeconds
						o.state = state
					elseif stateT >= ram.chargeSeconds then
						o.event = "Ram missed"
						state, stateT, cooldown = "skid", 0, ram.cooldownSeconds
						o.state = state
					end
					return o
				elseif state == "recoil" then
					local o = out(0, ram.recoilDrive)
					if stateT >= ram.recoilSeconds then
						state, stateT = "drive", 0
					end
					return o
				elseif state == "skid" then
					-- a miss: the truck rolls on, sliding, and cannot be steered for a moment
					local o = out(0, 0)
					if stateT >= ram.skidSeconds then
						state, stateT = "drive", 0
					end
					return o
				end
				local o = out(turn, drive)
				if attack and cooldown <= 0 then
					state, stateT, chargeHit = "charge", 0, false
					o.state = state
					o.event = "Charge!"
				end
				return o
			elseif fighterId == "CannonVan" then
				local o = out(turn, drive)
				-- a held button fires again as soon as the cannon is ready
				if (attack or attackHeld) and cooldown <= 0 then
					o.fire = true
					cooldown = cannon.cooldownSeconds
					o.ready = 0
				end
				return o
			end

			-- Saw Buggy: hold ATTACK to grind (the saw only hurts while it is spinning)
			grindCooldown = math.max(0, grindCooldown - dt * tempo)
			if grinding then
				grindT += dt
				if not attackHeld or grindT >= H.sawGrindSeconds then
					grinding = false
					grindT = 0
					grindCooldown = H.sawCooldownSeconds
					state = "drive"
				end
			elseif attackHeld and grindCooldown <= 0 then
				grinding, grindT = true, 0
				state = "grind"
			end
			local o = out(turn, drive)
			local touching = grinding and contact.saw and math.abs(angle) <= saw.frontConeDeg * DEG
			if touching then
				sawContactT += dt
				sawGapT = 0
			else
				sawGapT += dt
				if sawGapT >= saw.loseContactSeconds then
					sawContactT = 0
				end
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
			o.ready = readyFrac()
			return o
		end,
		shellResolved = function(hit: boolean): string?
			return if hit then "Cannon hit" else "Cannon missed"
		end,
		resetStuck = function() end,
	}
	return brain
end

return BattleHuman
