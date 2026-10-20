--!strict
-- Cheat checks for a car the player's device drives. The server still owns hits, HP and weapons, but
-- the device moves the car, so the server watches how fast it really moves (plain numbers, tested).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local BattleGuard = {}

-- True when the car moved further in one step than any legitimate drive, knock or charge could:
-- a teleport. `dx`, `dz` = flat studs moved since the last step.
function BattleGuard.teleported(dx: number, dz: number, dt: number, topSpeed: number): boolean
	local G = BattleConfig.Guard
	local limit = topSpeed * G.teleportSpeedMult * math.max(dt, 1 / 120) + G.slackStuds
	return math.sqrt(dx * dx + dz * dz) > limit
end

-- True when the flat speed is above the most a car can ever reach (a speed hack). The server also
-- clamps it; a car that keeps hitting this is taken back under server control.
function BattleGuard.tooFast(speed: number, topSpeed: number): boolean
	local G = BattleConfig.Guard
	return speed > topSpeed * math.max(1, BattleConfig.Ram.chargeMult) * G.speedSlack
end

return BattleGuard
