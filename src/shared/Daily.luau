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

export type Daily = { lastDay: number, freePulls: number }

local Daily = {}

function Daily.default(): Daily
	return { lastDay = 0, freePulls = 0 }
end

function Daily.clean(raw: any): Daily
	local d = Daily.default()
	if type(raw) == "table" then
		local last, pulls = raw.lastDay, raw.freePulls
		if type(last) == "number" and last == last and last >= 0 and last < 1e9 then
			d.lastDay = math.floor(last)
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

-- Returns true when the gift was given (once per day).
function Daily.claim(d: Daily, now: number): boolean
	if not Daily.canClaim(d, now) then
		return false
	end
	d.lastDay = Daily.dayNumber(now)
	d.freePulls = math.min(d.freePulls + 1, QuestsConfig.Daily.maxFreePulls)
	return true
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
