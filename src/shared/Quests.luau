--!strict
-- Quests ("win 3 with Tank"). Pure rules so Lune can test them. Owned by the quests worker.
-- LobbyService calls `onMatchEnd` once per finished match, right where it pays the coin reward.
-- profile.quests is a list of {id, progress}; ids come from QuestsConfig.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local QuestsConfig = sibling("QuestsConfig")

local Quests = {}

export type Def = {
	id: string,
	kind: string,
	carId: string?,
	mode: string?,
	target: number,
	reward: number,
	title: string,
}
-- mode / goals / tags / place come from the match result; nil = not reported.
export type MatchInfo = {
	won: boolean,
	carId: string,
	opponentIsBot: boolean,
	mode: string?,
	goals: number?,
	tags: number?,
	place: number?,
}
export type Quest = { id: string, progress: number }
export type View = { title: string, progress: number, target: number, reward: number, done: boolean }

-- Drops unknown/duplicate quests and bad numbers (used when loading a save).
function Quests.clean(raw: any): { Quest }
	local out: { Quest } = {}
	if type(raw) ~= "table" then
		return out
	end
	local seen: { [string]: boolean } = {}
	for _, q in raw do
		if #out >= QuestsConfig.Slots then
			break
		end
		if type(q) == "table" then
			local def = QuestsConfig.get(q.id)
			if def and not seen[def.id] then
				seen[def.id] = true
				local pr = q.progress
				if type(pr) ~= "number" or pr ~= pr then
					pr = 0
				end
				table.insert(
					out,
					{ id = def.id, progress = math.clamp(math.floor(pr), 0, def.target) }
				)
			end
		end
	end
	return out
end

-- Picks a catalog quest not already active, deterministic for a given seed.
local function pick(quests: { Quest }, seed: number): string?
	local active: { [string]: boolean } = {}
	for _, q in quests do
		active[q.id] = true
	end
	local free: { string } = {}
	for _, def in QuestsConfig.Catalog do
		if not active[def.id] then
			table.insert(free, def.id)
		end
	end
	if #free == 0 then
		return nil
	end
	local index = (math.floor(math.abs(seed)) % #free) + 1
	return free[index]
end

-- Fills empty slots (a fresh profile gets its starters here). Returns true if anything changed.
function Quests.ensure(profile: any, seed: number): boolean
	if type(profile.quests) ~= "table" then
		profile.quests = {}
	end
	local quests: { Quest } = profile.quests
	local changed = false
	while #quests < QuestsConfig.Slots do
		local id = pick(quests, seed + #quests * 7919)
		if id == nil then
			break
		end
		table.insert(quests, { id = id, progress = 0 })
		changed = true
	end
	return changed
end

local function amount(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, 100)
end

-- How much progress this match gives the quest (0 = none).
local function counts(def: Def, info: MatchInfo): number
	if def.carId ~= nil and def.carId ~= info.carId then
		return 0
	end
	if def.mode ~= nil and def.mode ~= info.mode then
		return 0
	end
	if def.kind == "play" then
		return 1
	elseif def.kind == "win" then
		return if info.won then 1 else 0
	elseif def.kind == "beatBot" then
		-- Only a 1v1 bot fight: group modes have several cars, so it never counts there.
		local group = info.mode == "soccer" or info.mode == "tag" or info.mode == "race"
		return if info.won and info.opponentIsBot and not group then 1 else 0
	elseif def.kind == "goal" then
		return amount(info.goals)
	elseif def.kind == "tag" then
		return amount(info.tags)
	elseif def.kind == "raceDone" then
		return if info.mode == "race" and (info.place ~= nil or info.won) then 1 else 0
	end
	return 0
end

-- Updates quest progress inside `profile` (a Profile table). Returns true if anything changed.
function Quests.onMatchEnd(profile: any, info: MatchInfo): boolean
	local quests = profile.quests
	if type(quests) ~= "table" then
		return false
	end
	local changed = false
	for _, q in quests do
		local def = QuestsConfig.get(q.id)
		if def and q.progress < def.target then
			local add = counts(def, info)
			if add > 0 then
				q.progress = math.min(q.progress + add, def.target)
				changed = true
			end
		end
	end
	return changed
end

function Quests.isDone(q: Quest): boolean
	local def = QuestsConfig.get(q.id)
	return def ~= nil and q.progress >= def.target
end

function Quests.anyClaimable(profile: any): boolean
	for _, q in profile.quests or {} do
		if Quests.isDone(q) then
			return true
		end
	end
	return false
end

-- Pays the quest at `index` once and replaces it with a new one. Returns coins paid (0 = nothing).
function Quests.claim(profile: any, index: any, seed: number, addCoins: (number) -> ()): number
	local quests = profile.quests
	if type(quests) ~= "table" or type(index) ~= "number" or index ~= math.floor(index) then
		return 0
	end
	local q = quests[index]
	if q == nil or not Quests.isDone(q) then
		return 0
	end
	local def = QuestsConfig.get(q.id) :: Def
	table.remove(quests, index) -- gone before paying, so a repeat claim finds nothing
	addCoins(def.reward)
	Quests.ensure(profile, seed + def.reward)
	return def.reward
end

function Quests.views(profile: any): { View }
	local out: { View } = {}
	for _, q in profile.quests or {} do
		local def = QuestsConfig.get(q.id)
		if def then
			table.insert(out, {
				title = def.title,
				progress = q.progress,
				target = def.target,
				reward = def.reward,
				done = q.progress >= def.target,
			})
		end
	end
	return out
end

return Quests
