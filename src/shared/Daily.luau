--!strict
-- Daily gift rules (pure): one free claw try per calendar day (UTC day number from os.time()).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local QuestsConfig = sibling("QuestsConfig")

export type Daily = { lastDay: number, freePulls: number, streak: number? } -- streak = days in a row

local Daily = {}

function Daily.default(): Daily
	return { lastDay = 0, freePulls = 0, streak = 0 }
end

function Daily.clean(raw: any): Daily
	local d = Daily.default()
	if type(raw) == "table" then
		local last, pulls = raw.lastDay, raw.freePulls
		if type(last) == "number" and last == last and last >= 0 and last < 1e9 then
			d.lastDay = math.floor(last)
		end
		local streak = raw.streak
		if type(streak) == "number" and streak == streak then
			d.streak = math.clamp(math.floor(streak), 0, 9999)
		end
		if type(pulls) == "number" and pulls == pulls then
			d.freePulls = math.clamp(math.floor(pulls), 0, QuestsConfig.Daily.maxFreePulls)
		end
	end
	return d
end

function Daily.dayNumber(now: number): number
	return math.floor(now / QuestsConfig.Daily.dayLength)
end

function Daily.canClaim(d: Daily, now: number): boolean
	return Daily.dayNumber(now) ~= d.lastDay
end

-- Seconds until the next gift can be claimed (0 = claim it now). The day rolls over at UTC midnight.
function Daily.secondsUntilNext(d: Daily, now: number): number
	if Daily.canClaim(d, now) then
		return 0
	end
	local len = QuestsConfig.Daily.dayLength
	return math.max(0, math.ceil(len - (now % len)))
end

-- Returns true when the gift was given (once per day).
function Daily.claim(d: Daily, now: number): boolean
	if not Daily.canClaim(d, now) then
		return false
	end
	local today = Daily.dayNumber(now)
	-- Came back the very next day = the streak grows; any longer gap starts again at 1.
	d.streak = if d.lastDay == today - 1 then (d.streak or 0) + 1 else 1
	d.lastDay = today
	d.freePulls = math.min(d.freePulls + 1, QuestsConfig.Daily.maxFreePulls)
	return true
end

-- Coins for the login streak the claim just made (day 1 pays the first number, day 7 and on the last).
function Daily.streakCoins(d: Daily): number
	local list = QuestsConfig.Daily.streakCoins
	return list[math.clamp(d.streak or 0, 1, #list)] or 0
end

-- Coins the next claim would pay (pure preview of `claim` + `streakCoins`; changes nothing).
function Daily.nextCoins(d: Daily, now: number): number
	local list = QuestsConfig.Daily.streakCoins
	local streak = if d.lastDay == Daily.dayNumber(now) - 1 then (d.streak or 0) + 1 else 1
	return list[math.clamp(streak, 1, #list)] or 0
end

-- Spends one gift try. Returns true if there was one.
function Daily.consume(d: Daily): boolean
	if d.freePulls > 0 then
		d.freePulls -= 1
		return true
	end
	return false
end

return Daily
