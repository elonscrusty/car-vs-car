--!strict
-- Car levels, win streak and rank badges (pure, unit tested).
-- Saved as profile.progress = { carXp = {[carId] = xp}, streak = n }. Wins stay in profile.wins
-- (LobbyService counts them); rank is derived from that counter.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local DefaultConfig = sibling("ProgressConfig")

export type Data = { carXp: { [string]: number }, streak: number, bestStreak: number }
export type Result = {
	coinsBonus: number,
	leveledUp: boolean,
	newLevel: number,
	streak: number,
	levelCoins: number, -- part of coinsBonus paid for the new level(s)
}

local Progress = {}

local MAX_NUMBER = 1e9

function Progress.default(): Data
	return { carXp = {}, streak = 0, bestStreak = 0 }
end

local function cleanNumber(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, MAX_NUMBER)
end

-- Never errors. Accepts anything (old saves have no `progress`), returns clean Data.
function Progress.clean(raw: any): Data
	local data = Progress.default()
	if type(raw) ~= "table" then
		return data
	end
	data.streak = cleanNumber(raw.streak)
	data.bestStreak = math.max(cleanNumber(raw.bestStreak), data.streak)
	if type(raw.carXp) == "table" then
		for _, id in CarConfig.FullOrder do
			local xp = cleanNumber(raw.carXp[id])
			if xp > 0 then
				data.carXp[id] = xp
			end
		end
	end
	return data
end

function Progress.copy(d: Data): Data
	return { carXp = table.clone(d.carXp), streak = d.streak, bestStreak = d.bestStreak }
end

function Progress.maxLevel(): number
	return #DefaultConfig.LevelXp
end

function Progress.levelForXp(xp: number): number
	local level = 1
	for i, need in DefaultConfig.LevelXp do
		if xp >= need then
			level = i
		end
	end
	return level
end

function Progress.levelOf(d: Data, carId: string): number
	return Progress.levelForXp(d.carXp[carId] or 0)
end

-- Level of every car that has gained XP: {[carId] = level}.
function Progress.levels(d: Data): { [string]: number }
	local out: { [string]: number } = {}
	for id, xp in d.carXp do
		out[id] = Progress.levelForXp(xp)
	end
	return out
end

-- HP and hit damage multiplier for a car level (level 1 = x1).
function Progress.statMult(level: number, cfg: any?): number
	local c = cfg or DefaultConfig
	return 1 + c.LevelStatBonus * (math.clamp(math.floor(level), 1, Progress.maxLevel()) - 1)
end

-- Stats with the level bonus on hp and damageMult. Returns a new table (the input stays unchanged).
function Progress.applyLevel(stats: any, level: number?, cfg: any?): any
	local out = table.clone(stats)
	local m = Progress.statMult(level or 1, cfg)
	out.hp = math.max(1, math.floor(stats.hp * m + 0.5))
	out.damageMult = stats.damageMult * m
	return out
end

-- Coins for every level between `before` (exclusive) and `after` (inclusive).
function Progress.levelCoins(before: number, after: number, cfg: any?): number
	local c = cfg or DefaultConfig
	local total = 0
	for lv = before + 1, after do
		total += c.LevelUpCoins[lv] or 0
	end
	return total
end

function Progress.rankFor(wins: number): string
	for _, r in DefaultConfig.Ranks do
		if wins >= r.minWins then
			return r.name
		end
	end
	return "Bronze"
end

function Progress.streakBonus(streak: number, cfg: any?): number
	local c = cfg or DefaultConfig
	if streak >= c.StreakBonusFrom then
		return c.StreakBonusMax
	end
	return c.StreakBonus[streak] or 0
end

-- Call once per finished real match. `profile` only needs a `progress` field (Data).
-- `cfg` is ProgressConfig (or a test copy). The caller pays `coinsBonus` and counts profile.wins.
function Progress.applyMatchResult(profile: any, carId: string, won: boolean, cfg: any?): Result
	local c = cfg or DefaultConfig
	local d: Data = profile.progress
	local before = Progress.levelOf(d, carId)
	if CarConfig.get(carId) then
		local gain = if won then c.XpWin else c.XpLoss
		d.carXp[carId] = math.clamp((d.carXp[carId] or 0) + gain, 0, MAX_NUMBER)
	end
	local after = Progress.levelOf(d, carId)
	local bonus = 0
	if won then
		d.streak = math.clamp(d.streak + 1, 0, MAX_NUMBER)
		d.bestStreak = math.max(d.bestStreak, d.streak)
		bonus = Progress.streakBonus(d.streak, c)
	else
		d.streak = 0
	end
	local levelCoins = Progress.levelCoins(before, after, c)
	return {
		coinsBonus = bonus + levelCoins,
		leveledUp = after > before,
		newLevel = after,
		streak = d.streak,
		levelCoins = levelCoins,
	}
end

return Progress
