--!strict
-- Fair-play rule (pure): in a match with 2+ humans, ignore the car level bonus and use
-- Common-strength abilities. Versus bots nothing changes. Numbers: FairnessConfig.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local DefaultConfig = sibling("FairnessConfig")

local Fairness = {}

-- True when this match should ignore level + rarity bonuses.
function Fairness.neutral(humanCount: number, cfg: any?): boolean
	local c = cfg or DefaultConfig
	return c.neutralizeHumanMatches == true and humanCount >= c.humansNeeded
end

-- The car level that counts (the real one, or the neutral one in a fair match).
function Fairness.level(level: number?, neutral: boolean, cfg: any?): number?
	if neutral then
		return (cfg or DefaultConfig).neutralLevel
	end
	return level
end

-- The ability rarity that counts (the real one, or Common in a fair match).
function Fairness.rarity(rarity: string?, neutral: boolean, cfg: any?): string?
	if neutral then
		return (cfg or DefaultConfig).neutralRarity
	end
	return rarity
end

-- The car stats that count: the base car with the garage build applied, or the plain base car in a
-- fair match (parts and part levels ignored, audit #51). Returns a new table; `base` is unchanged.
-- `buildStats` is Build.stats (passed in so this file stays free of the Build dependency).
function Fairness.stats(
	base: any,
	build: any?,
	neutral: boolean,
	buildStats: (any, any) -> any,
	cfg: any?
): any
	local c = cfg or DefaultConfig
	if build == nil or (neutral and c.neutralBuild ~= false) then
		return table.clone(base)
	end
	return buildStats(base, build)
end

return Fairness
