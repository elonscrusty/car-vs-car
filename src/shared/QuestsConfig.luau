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

export type Def = {
	id: string,
	kind: string, -- "win" | "play" | "beatBot"
	carId: string?, -- only counts matches played with this car
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

local list: { Def } = {
	{ id = "win3", kind = "win", target = 3, reward = 60, title = "Win 3 matches" },
	{ id = "play5", kind = "play", target = 5, reward = 40, title = "Play 5 matches" },
	{ id = "bot2", kind = "beatBot", target = 2, reward = 50, title = "Beat the bot 2 times" },
}
for _, carId in CarConfig.Order do
	table.insert(list, {
		id = "win3_" .. carId,
		kind = "win",
		carId = carId,
		target = 3,
		reward = 80,
		title = `Win 3 with {carId}`,
	})
end

QuestsConfig.Catalog = list

local byId: { [string]: Def } = {}
for _, def in list do
	byId[def.id] = def
end

function QuestsConfig.get(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

return QuestsConfig
