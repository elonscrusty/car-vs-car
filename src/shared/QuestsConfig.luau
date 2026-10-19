--!strict
-- Quest catalog and daily gift numbers. All coin amounts are placeholders: change them here.
-- Owned by the quests worker.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local FeatureFlags = sibling("FeatureFlags")

export type Def = {
	id: string,
	-- "win" | "play" | "beatBot" | "goal" (goals you score) | "tag" (cars you tag / pass IT on to)
	-- | "raceDone" (finish a race)
	kind: string,
	carId: string?, -- only counts matches played with this car
	mode: string?, -- only counts matches in this mode
	target: number,
	reward: number, -- coins
	title: string,
}

local QuestsConfig = {}

QuestsConfig.Slots = 3 -- active quests per player

QuestsConfig.Daily = {
	maxFreePulls = 3, -- unclaimed free claw tries stop stacking here
	dayLength = 86400, -- seconds; the day number is floor(os.time() / dayLength) (UTC)
}

-- Starter quests: win3 and play5 plus mode-learning ones that teach each mode (small coin rewards,
-- PLACEHOLDERS). A mode quest only exists while that mode is in the rotation. "Beat the bot 2
-- times" is gone: in soccer / tag / race you do not duel a bot. The per-car ones only join with the
-- perCarQuests flag.
local function catalogFor(flags: { [string]: boolean }?): { Def }
	local out: { Def } = {
		{ id = "win3", kind = "win", target = 3, reward = 60, title = "Win 3 matches" },
		{ id = "play5", kind = "play", target = 5, reward = 40, title = "Play 5 matches" },
	}
	if FeatureFlags.enabled("soccerMode", flags) then
		table.insert(out, {
			id = "goal1",
			kind = "goal",
			mode = "soccer",
			target = 1,
			reward = 30,
			title = "Score a goal",
		})
		table.insert(out, {
			id = "soccer3",
			kind = "play",
			mode = "soccer",
			target = 3,
			reward = 40,
			title = "Play 3 soccer matches",
		})
	end
	if FeatureFlags.enabled("tagMode", flags) then
		table.insert(out, {
			id = "tag2",
			kind = "tag",
			mode = "tag",
			target = 2,
			reward = 30,
			title = "Pass IT on 2 times",
		})
	end
	if FeatureFlags.enabled("raceMode", flags) then
		table.insert(out, {
			id = "race1",
			kind = "raceDone",
			mode = "race",
			target = 1,
			reward = 30,
			title = "Finish a race",
		})
	end
	if FeatureFlags.enabled("lastStandingMode", flags) then
		table.insert(out, {
			id = "fight3",
			kind = "play",
			mode = "lastStanding",
			target = 3,
			reward = 40,
			title = "Play 3 fights",
		})
		table.insert(out, {
			id = "fightwin1",
			kind = "win",
			mode = "lastStanding",
			target = 1,
			reward = 30,
			title = "Win a fight",
		})
		table.insert(out, {
			id = "fightwin2",
			kind = "win",
			mode = "lastStanding",
			target = 2,
			reward = 50,
			title = "Win 2 fights",
		})
		table.insert(out, {
			id = "fight6",
			kind = "play",
			mode = "lastStanding",
			target = 6,
			reward = 50,
			title = "Play 6 fights",
		})
	end
	if FeatureFlags.enabled("perCarQuests", flags) then
		for _, carId in CarConfig.Order do
			table.insert(out, {
				id = "win3_" .. carId,
				kind = "win",
				carId = carId,
				target = 3,
				reward = 80,
				title = `Win 3 with {carId}`,
			})
		end
	end
	return out
end

QuestsConfig.catalogFor = catalogFor
local list = catalogFor(nil)
QuestsConfig.Catalog = list

local byId: { [string]: Def } = {}
for _, def in list do
	byId[def.id] = def
end

-- Every quest of every mode, hidden or not: progress rules can still read an old one.
local byIdAll: { [string]: Def } = {}
for _, def in catalogFor({
	soccerMode = true,
	tagMode = true,
	raceMode = true,
	lastStandingMode = true,
}) do
	byIdAll[def.id] = def
end
for _, def in list do
	byIdAll[def.id] = def
end

function QuestsConfig.get(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return byIdAll[id]
end

-- Is this quest in today's catalog (its mode is in the rotation)? A saved quest of a hidden mode is not.
function QuestsConfig.isActive(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return QuestsConfig
