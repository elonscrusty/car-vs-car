--!strict
-- Pure rules for the fight moves: cooldown math, boost timeline, drift grip.
-- No requires (so Lune tests can load it): callers pass the MovesConfig tables in.
-- The server applies the results (src/server/Moves).

export type DriftState = {
	held: number, -- seconds of full steer in one direction
	side: number, -- -1, 0 or 1: the direction being held
	linger: number, -- seconds of slide left after the steer stopped
}

export type BoostConfig = { duration: number, fade: number, speedBonus: number, accelBonus: number }
export type DriftConfig = {
	fullSteer: number,
	startSeconds: number,
	minSpeed: number,
	lingerSeconds: number,
	gripFactor: number,
	turnBonus: number,
}

local Moves = {}

-- True when `name` is a move the client may ask for.
function Moves.isMove(name: any, names: { string }): boolean
	if type(name) ~= "string" then
		return false
	end
	return table.find(names, name) ~= nil
end

-- Seconds until a move used at `lastUsed` is ready again (0 = ready).
function Moves.cooldownLeft(lastUsed: number, cooldown: number, now: number): number
	return math.max(0, lastUsed + cooldown - now)
end

function Moves.ready(lastUsed: number, cooldown: number, now: number): boolean
	return Moves.cooldownLeft(lastUsed, cooldown, now) <= 0
end

-- 0..1 strength of the boost `elapsed` seconds after it started: full, then a linear fade.
function Moves.boostStrength(elapsed: number, b: BoostConfig): number
	if elapsed < 0 or elapsed >= b.duration then
		return 0
	end
	local fadeStart = b.duration - b.fade
	if elapsed <= fadeStart or b.fade <= 0 then
		return 1
	end
	return (b.duration - elapsed) / b.fade
end

-- Top speed multiplier during a boost (1 = no boost).
function Moves.boostSpeedMult(elapsed: number, b: BoostConfig): number
	return 1 + b.speedBonus * Moves.boostStrength(elapsed, b)
end

-- Push (acceleration) multiplier during a boost.
function Moves.boostAccelMult(elapsed: number, b: BoostConfig): number
	return 1 + b.accelBonus * Moves.boostStrength(elapsed, b)
end

function Moves.newDrift(): DriftState
	return { held = 0, side = 0, linger = 0 }
end

-- Advances the drift one frame. `steer` is the eased steer input, `speed` the flat speed.
-- Returns (gripScale, turnScale): 1, 1 when driving normally.
function Moves.driftStep(
	state: DriftState,
	steer: number,
	speed: number,
	dt: number,
	d: DriftConfig
): (number, number)
	local side = if steer >= d.fullSteer then 1 elseif steer <= -d.fullSteer then -1 else 0
	if side ~= 0 and speed >= d.minSpeed then
		if side ~= state.side then
			state.side = side
			state.held = 0
		end
		state.held += dt
		if state.held >= d.startSeconds then
			state.linger = d.lingerSeconds
		end
	else
		state.held = 0
		state.side = 0
		state.linger = math.max(0, state.linger - dt)
	end
	if state.linger > 0 then
		return d.gripFactor, d.turnBonus
	end
	return 1, 1
end

function Moves.resetDrift(state: DriftState)
	state.held, state.side, state.linger = 0, 0, 0
end

return Moves
