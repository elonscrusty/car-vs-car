--!strict
-- Pure rules for the aim-and-coast duel (no Roblox objects, so they can be unit tested).

local Logic = require("./Logic")

local Duel = {}

-- Angle (degrees, -180..180) of a flat direction. 0 = +Z. Same convention as Aim.direction.
function Duel.angleOf(dx: number, dz: number): number
	return math.deg(math.atan2(-dx, dz))
end

-- Slingshot: pull back on screen, car goes the other way. Screen y points down.
-- right/fwd are the camera's flat right and forward vectors as (x, z). Returns the flat world direction.
function Duel.dragToWorld(
	dragX: number,
	dragY: number,
	rightX: number,
	rightZ: number,
	fwdX: number,
	fwdZ: number
): (number, number)
	local sx, sy = -dragX, -dragY
	return rightX * sx + fwdX * -sy, rightZ * sx + fwdZ * -sy
end

-- Drag length in pixels -> power 0..1. Under minPx = 0 (counts as "no aim").
function Duel.dragPower(lengthPx: number, minPx: number, maxPx: number): number
	if lengthPx < minPx then
		return 0
	end
	return Logic.clamp((lengthPx - minPx) / (maxPx - minPx), 0, 1)
end

-- Settle timer: counts up while BOTH cars are slow, resets when either is fast.
function Duel.tickSettle(timer: number, fastestSpeed: number, dt: number, slowBelow: number): number
	if fastestSpeed >= slowBelow then
		return 0
	end
	return timer + dt
end

-- The fight phase is over when cars have been slow long enough, or the phase ran too long.
function Duel.fightOver(
	settleTimer: number,
	elapsed: number,
	settleTime: number,
	maxTime: number
): boolean
	return settleTimer >= settleTime or elapsed >= maxTime
end

-- Damage grows each round in a row where nobody got hit, so stalling cannot go on forever.
function Duel.escalation(quietRounds: number, step: number): number
	return 1 + math.max(0, quietRounds) * step
end

-- Match timer ran out? Returns winner 1 or 2 by HP, or 0 for an exact tie (sudden death).
function Duel.timeoutWinner(hp1: number, hp2: number): number
	if hp1 > hp2 then
		return 1
	elseif hp2 > hp1 then
		return 2
	end
	return 0
end

-- Bot aim: toward the target with a little error. noiseDeg is already random, in -x..x.
function Duel.botAim(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	noiseDeg: number
): number
	local a = Duel.angleOf(toX - fromX, toZ - fromZ) + noiseDeg
	if a > 180 then
		a -= 360
	elseif a < -180 then
		a += 360
	end
	return a
end

-- Slow horizontal speed a bit every frame so cars coast to a stop. Returns the new multiplier.
function Duel.dragFactor(dragPerSec: number, dt: number): number
	return math.max(0, 1 - dragPerSec * dt)
end

return Duel
