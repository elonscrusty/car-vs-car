--!strict
-- One special move per car (Tank smash, Rocket dash, Ramp flip, ...). Owned by the specials worker.
-- Match calls `use` when a human presses SPECIAL during the fight. Server decides everything.

local CarBuilder = require(script.Parent.CarBuilder)

local Specials = {}

-- Tries to fire `car`'s special at `enemy`. `now` is os.clock(). Returns true if it fired
-- (so the caller can start the cooldown UI). Cooldown handling lives in here.
function Specials.use(_car: CarBuilder.Car, _enemy: CarBuilder.Car, _now: number): boolean
	return false -- stub
end

-- Seconds until `car` can use its special again (0 = ready). For the HUD.
function Specials.cooldownLeft(_car: CarBuilder.Car, _now: number): number
	return 0 -- stub
end

return Specials
