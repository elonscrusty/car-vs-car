--!strict
-- Temporary power-up effects on cars (shield, big hit, speed). Owned by the power-ups worker.
-- Other code only READS buffs through these functions, so it stays simple:
--   Autopilot multiplies max speed by speedMult; resolveHit multiplies damage by damageMult
--   and passes incoming damage through absorb.

local CarBuilder = require(script.Parent.CarBuilder)

local Buffs = {}

function Buffs.speedMult(_car: CarBuilder.Car): number
	return 1 -- stub
end

-- Multiplier on damage this car deals right now (big hit).
function Buffs.damageMult(_car: CarBuilder.Car): number
	return 1 -- stub
end

-- Damage the car takes after its shield; may consume the shield.
function Buffs.absorb(_car: CarBuilder.Car, damage: number): number
	return damage -- stub
end

-- Called every Heartbeat with dt so timed buffs run out.
function Buffs.tick(_car: CarBuilder.Car, _dt: number) end

-- Removes all buffs from a car (new match / car destroyed).
function Buffs.clear(_car: CarBuilder.Car) end

return Buffs
