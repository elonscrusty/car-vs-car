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

export type Data = { carXp: { [string]: number }, streak: number }
export type Result = { coinsBonus: number, leveledUp: boolean, newLevel: number, streak: number }

local Progress = {}

local MAX_NUMBER = 1e9

function Progress.default(): Data
	return { carXp = {}, streak = 0 }
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
	if type(raw.carXp) == "table" then
		for _, id in CarConfig.Order do
			local xp = cleanNumber(raw.carXp[id])
			if xp > 0 then
				data.carXp[id] = xp
			end
		end
	end
	return data
end

function Progress.copy(d: Data): Data
	return { carXp = table.clone(d.carXp), streak = d.streak }
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
		bonus = Progress.streakBonus(d.streak, c)
	else
		d.streak = 0
	end
	return { coinsBonus = bonus, leveledUp = after > before, newLevel = after, streak = d.streak }
end

return Progress
