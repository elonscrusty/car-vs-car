--!strict
-- Coins and the short result line for a finished match (pure, unit tested).
-- Pay by what happened, not by "win or lose": a base for finishing plus goals / tags / place.
-- Multi-car modes (soccer, tag, race) never say "lose": the line says "3rd place", "Survived 1:10",
-- "2 goals". All numbers are PLACEHOLDERS in LobbyConfig.ResultRewards.
-- Every field except `won` is optional: nil = the match did not report it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local LobbyConfig = sibling("LobbyConfig")

export type Info = {
	mode: string?,
	won: boolean,
	place: number?, -- 1 = first
	goals: number?,
	survivedSeconds: number?,
	tags: number?,
}
export type Result = {
	coins: number,
	resultText: string, -- "" = no special line (the client keeps its normal win/lose text)
	kind: string, -- "win" | "place" | "survived" | "goals" | "tags" | "played" | "duel"
	mode: string?, -- the mode used (given or guessed from the fields)
}

local ResultRewards = {}

local GROUP_MODES = { soccer = true, tag = true, race = true } :: { [string]: boolean }

local function count(v: any, cap: number): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, cap)
end

-- nil when the match gave no usable number.
local function whole(v: any): number?
	if type(v) ~= "number" or v ~= v or v < 0 or v > 1e9 then
		return nil
	end
	return math.floor(v)
end

-- Is this one of the multi-car (group) modes?
function ResultRewards.isGroupMode(mode: any): boolean
	return type(mode) == "string" and GROUP_MODES[mode] == true
end

-- The mode to use: the reported one, else a guess from which fields were reported.
function ResultRewards.modeOf(info: Info): string?
	local m = info.mode
	if type(m) == "string" and m ~= "auto" then
		return m
	end
	if whole(info.place) ~= nil then
		return "race"
	elseif whole(info.goals) ~= nil then
		return "soccer"
	elseif whole(info.survivedSeconds) ~= nil or whole(info.tags) ~= nil then
		return "tag"
	end
	return nil
end

-- 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11 -> "11th".
function ResultRewards.ordinal(n: number): string
	local k = math.floor(n)
	local tens = k % 100
	local suffix = "th"
	if tens < 11 or tens > 13 then
		local last = k % 10
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return `{k}{suffix}`
end

-- 70 -> "1:10", 5 -> "0:05".
function ResultRewards.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function goalsText(goals: number): string
	return if goals == 1 then "1 goal" else `{goals} goals`
end

local function tagsText(tags: number): string
	return if tags == 1 then "1 tag" else `{tags} tags`
end

-- The coins and the result line. `cfg` = LobbyConfig.ResultRewards (or a test copy).
function ResultRewards.compute(info: Info, cfg: any?): Result
	local c = cfg or LobbyConfig.ResultRewards
	local mode = ResultRewards.modeOf(info)
	local won = info.won == true
	local base: number = if won then c.baseWin else c.baseOther

	if mode == "race" then
		local place = whole(info.place)
		if won and place == nil then
			place = 1
		end
		if place ~= nil then
			place = math.max(1, place)
			local byPlace: { number } = c.racePlaceCoins
			local coins = byPlace[math.min(place, #byPlace)] or c.baseOther
			return {
				coins = coins,
				resultText = `{ResultRewards.ordinal(place)} place`,
				kind = if place == 1 then "win" else "place",
				mode = mode,
			}
		end
		return { coins = base, resultText = "Good race", kind = "played", mode = mode }
	elseif mode == "soccer" then
		local goals = count(info.goals, c.maxGoalsPaid)
		local text: string
		if goals > 0 then
			text = if won then `Team win, {goalsText(goals)}` else goalsText(goals)
		else
			text = if won then "Team win" else "Good game"
		end
		return {
			coins = base + goals * c.perGoal,
			resultText = text,
			kind = if won then "win" elseif goals > 0 then "goals" else "played",
			mode = mode,
		}
	elseif mode == "tag" then
		local tags = count(info.tags, c.maxTagsPaid)
		local coins = base + tags * c.perTag
		local survived = whole(info.survivedSeconds)
		if won then
			return {
				coins = coins,
				resultText = if tags > 0 then `Last car, {tagsText(tags)}` else "Last car standing",
				kind = "win",
				mode = mode,
			}
		end
		local text = "Good game"
		local kind = "played"
		if survived ~= nil then
			local steps = survived // c.tagSurviveStep
			coins += math.min(steps * c.tagSurvivePerStep, c.tagSurviveMax)
			text = `Survived {ResultRewards.clock(survived)}`
			kind = "survived"
			if tags > 0 then
				text ..= `, {tagsText(tags)}`
			end
		elseif tags > 0 then
			text = tagsText(tags)
			kind = "tags"
		end
		return { coins = coins, resultText = text, kind = kind, mode = mode }
	end
	-- Duel, hill, ice and anything unknown: the old win / not-win coins, no special line.
	local duel = if won then c.duelWin or base else c.duelLose or base
	return { coins = duel, resultText = "", kind = "duel", mode = mode }
end

-- Does this finish keep the win streak alive without a win? Tag/race: top-half place (needs `place`).
function ResultRewards.keepsStreak(info: Info, cfg: any?): boolean
	local c = cfg or LobbyConfig.ResultRewards
	if info.won == true then
		return false -- a win already extends it
	end
	local mode = ResultRewards.modeOf(info)
	if mode ~= "tag" and mode ~= "race" then
		return false
	end
	local place = whole(info.place)
	return place ~= nil and place >= 1 and place <= c.topHalfPlace
end

-- Show the INVITE prompt after a goal, or after the 2nd+ finished match (not only wins).
-- `matchesFinished` counts this match.
function ResultRewards.invitePrompt(info: Info, matchesFinished: number, cfg: any?): boolean
	local c = cfg or LobbyConfig.ResultRewards
	if count(info.goals, 1000) > 0 then
		return true
	end
	return type(matchesFinished) == "number" and matchesFinished >= c.invitePromptMatches
end

return ResultRewards
