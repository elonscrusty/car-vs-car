--!strict
-- Comeback rule (pure): under 25% HP, the first boost/ability press gives a short speed pop.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local DefaultConfig = sibling("ComebackConfig")

local Comeback = {}

-- Can the pop start now? `used` = it already fired once this fight.
function Comeback.canPop(hp: number, maxHp: number, used: boolean, cfg: any?): boolean
	local c = cfg or DefaultConfig
	if not c.enabled or used or maxHp <= 0 or hp <= 0 then
		return false
	end
	return hp / maxHp <= c.belowFrac
end

-- Top-speed multiplier `elapsed` seconds after the pop started (1 = no pop).
function Comeback.speedMult(elapsed: number, cfg: any?): number
	local c = cfg or DefaultConfig
	if not c.enabled or elapsed < 0 or elapsed >= c.seconds then
		return 1
	end
	return 1 + c.speedBonus * (1 - elapsed / c.seconds)
end

-- Biggest multiplier the pop can ever give (for the server's anti-cheat speed cap).
function Comeback.maxMult(cfg: any?): number
	local c = cfg or DefaultConfig
	return if c.enabled then 1 + c.speedBonus else 1
end

return Comeback
