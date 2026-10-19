--!strict
-- Car handling traits (pure, unit tested): resolve + clamp, the driving curves CarDrive uses,
-- stat bar fractions and the short "Fast, slippery" description. Numbers: CarTraitsConfig.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("CarTraitsConfig")

export type Traits = {
	grip: number,
	drift: number,
	punch: number,
	highTurn: number,
	sizeScale: number,
}

local CarTraits = {}

local function clampTo(key: string, v: any, fallback: number): number
	local n = if type(v) == "number" and v == v then v else fallback
	local lim = Config.Limits[key]
	return math.clamp(n, lim[1], lim[2])
end

-- Defaults + the car's row, every value clamped. `size` (optional {x,y,z}) sets sizeScale for
-- cars whose size is written out by hand.
function CarTraits.resolve(row: { [string]: number }?, size: { number }?): Traits
	local d = Config.Defaults
	local r = row or {}
	local scale = r.sizeScale
	if scale == nil and size ~= nil then
		scale = size[3] / Config.neutralLength
	end
	return {
		grip = clampTo("grip", r.grip, d.grip),
		drift = clampTo("drift", r.drift, d.drift),
		punch = clampTo("punch", r.punch, d.punch),
		highTurn = clampTo("highTurn", r.highTurn, d.highTurn),
		sizeScale = clampTo("sizeScale", scale, d.sizeScale),
	}
end

-- Traits of a stats table (defaults when it has none).
function CarTraits.of(stats: any): Traits
	local t = if stats then stats.traits else nil
	if t then
		return t :: Traits
	end
	return Config.Defaults
end

-- speed / maxSpeed, clamped 0..1.
function CarTraits.speedFrac(speed: number, maxSpeed: number): number
	if maxSpeed <= 0 then
		return 0
	end
	return math.clamp(math.abs(speed) / maxSpeed, 0, 1)
end

-- Acceleration multiplier: 1 + punch at a standstill, 1 - punch at top speed.
function CarTraits.accelFactor(t: Traits, frac: number): number
	local r = Config.accelRange
	return math.clamp(1 + t.punch * (1 - 2 * frac), r[1], r[2])
end

-- Side-grip multiplier. Hard steering at speed loosens it by `drift`.
function CarTraits.gripFactor(t: Traits, steerAbs: number, frac: number): number
	local loose = t.drift * math.clamp(steerAbs, 0, 1) * frac * Config.driftSlip
	return math.max(Config.minGrip, t.grip * (1 - loose))
end

-- Turn-rate multiplier: 1 standing still, `highTurn` at top speed.
function CarTraits.turnFactor(t: Traits, frac: number): number
	return 1 + (t.highTurn - 1) * frac
end

local function fraction(range: { number }, v: number): number
	return math.clamp((v - range[1]) / (range[2] - range[1]), 0, 1)
end

-- Bar fill 0..1 for the car list: speed, weight, turn, hp.
function CarTraits.bars(stats: any): { speed: number, weight: number, turn: number, hp: number }
	local r = Config.BarRanges
	return {
		speed = fraction(r.speed, stats.maxSpeed),
		weight = fraction(r.weight, stats.mass),
		turn = fraction(r.turn, stats.turnRate),
		hp = fraction(r.hp, stats.hp),
	}
end

local function statValue(key: string, stats: any): number?
	if key == "grip" then
		return CarTraits.of(stats).grip
	elseif key == "turn" then
		return stats.turnRate
	end
	return stats[key]
end

-- Short text like "Fast, slippery": the two most extreme words ("Balanced" when none fire).
function CarTraits.describe(stats: any): string
	local found: { { word: string, score: number } } = {}
	for _, rule in Config.Words do
		local v = statValue(rule.key, stats)
		if v ~= nil then
			if v >= rule.high.at then
				table.insert(found, {
					word = rule.high.word,
					score = rule.weight * (v - rule.high.at) / rule.high.at,
				})
			elseif v <= rule.low.at then
				table.insert(
					found,
					{ word = rule.low.word, score = rule.weight * (rule.low.at - v) / rule.low.at }
				)
			end
		end
	end
	if #found == 0 then
		return "Balanced"
	end
	-- Most extreme first; rule order breaks ties (table.sort is not stable).
	local order: { number } = {}
	for i = 1, #found do
		order[i] = i
	end
	table.sort(order, function(a, b)
		if found[a].score ~= found[b].score then
			return found[a].score > found[b].score
		end
		return a < b
	end)
	local first = found[order[1]].word
	local text = string.upper(string.sub(first, 1, 1)) .. string.sub(first, 2)
	if #order >= 2 then
		text ..= ", " .. found[order[2]].word
	end
	return text
end

-- How many traits differ between two cars (see CarTraitsConfig.differBy).
function CarTraits.differences(a: Traits, b: Traits): number
	local n = 0
	for key in Config.Defaults do
		if math.abs((a :: any)[key] - (b :: any)[key]) >= Config.differBy then
			n += 1
		end
	end
	return n
end

return CarTraits
