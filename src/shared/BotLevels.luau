--!strict
-- Bot difficulty. Pure: no Roblox types, unit tested.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("BotLevelsConfig")

export type Level = {
	name: string,
	noiseDeg: number,
	powerMin: number,
	powerMax: number,
	turnGainMult: number,
	speedMult: number,
	wanderEvery: number,
	wanderDeg: number,
	wanderFade: number,
	runUpMult: number,
	rewardMult: number,
}

local BotLevels = {}

local cache: { [string]: Level } = {}

-- Unknown / bad input -> medium.
function BotLevels.get(level: any): Level
	local name: string = Config.Default
	if type(level) == "string" and Config.Levels[level] ~= nil then
		name = level
	end
	local hit = cache[name]
	if hit then
		return hit
	end
	local made = table.clone(Config.Levels[name]) :: any
	made.name = name
	cache[name] = made :: Level
	return made :: Level
end

function BotLevels.isValid(level: any): boolean
	return type(level) == "string" and Config.Levels[level] ~= nil
end

function BotLevels.names(): { string }
	return table.clone(Config.Names :: { string })
end

-- Next level in the cycle easy -> medium -> hard -> easy.
function BotLevels.next(level: any): string
	local cur = BotLevels.get(level).name
	for i, n in Config.Names :: { string } do
		if n == cur then
			return (Config.Names :: { string })[i % #Config.Names + 1]
		end
	end
	return Config.Default
end

-- Coin reward multiplier for beating this level. Pure: nothing applies it yet.
function BotLevels.rewardMultiplier(level: any): number
	return BotLevels.get(level).rewardMult
end

-- Launch power from a 0..1 random roll.
function BotLevels.launchPower(level: Level, roll: number): number
	local r = math.clamp(roll, 0, 1)
	return level.powerMin + (level.powerMax - level.powerMin) * r
end

-- Cheap deterministic 0..1 hash of two numbers.
local function hash01(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- Aim offset in degrees at time t (seconds): a random sign/size kick at the start of every
-- wanderEvery period, fading out. Stateless; `seed` keeps two bots from kicking together.
function BotLevels.wanderOffsetDeg(level: Level, t: number, seed: number): number
	if level.wanderEvery <= 0 or level.wanderDeg <= 0 then
		return 0
	end
	local k = math.floor(t / level.wanderEvery)
	local phase = t - k * level.wanderEvery
	local fade = math.max(0, 1 - phase / math.max(level.wanderFade, 0.01))
	local size = 0.4 + 0.6 * hash01(k, seed)
	local sign = if hash01(k, seed + 1) < 0.5 then -1 else 1
	return sign * size * level.wanderDeg * fade
end

-- Seconds of standing still before a run-up (base / runUpMult).
function BotLevels.stuckLimit(level: Level, base: number): number
	return base / math.max(level.runUpMult, 0.05)
end

return BotLevels
