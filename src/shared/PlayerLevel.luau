--!strict
-- Player level (all cars together): XP from fights fills it, each new level pays a reward that
-- is a mix of coins, spin box tries and paint colors (carter's pick). Pure, unit tested.
-- All numbers are PLACEHOLDERS; change them in the Config table below.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local PaintConfig = sibling("PaintConfig")
local QuestsConfig = sibling("QuestsConfig")

export type Reward = { coins: number, spins: number, paint: string? }
export type Paid = { coins: number, spins: number, paints: { string } }
export type View = { level: number, into: number, needed: number, maxed: boolean }

local PlayerLevel = {}

PlayerLevel.MaxLevel = 30

-- Total XP needed to reach level i: 0, 35, 106, 204 ... (a gentle curve, a level every few fights).
local function need(level: number): number
	return math.floor(35 * (level - 1) ^ 1.6 + 0.5)
end

-- Reward for reaching `level` (level 1 pays nothing). Spin tries every 3rd level, a paint color on
-- chosen levels, coins on all the rest.
local PAINT_LEVELS: { [number]: string } = {
	[3] = "blue",
	[5] = "green",
	[8] = "orange",
	[11] = "purple",
	[14] = "pink",
	[18] = "cyan",
	[25] = "gold",
}

function PlayerLevel.reward(level: number): Reward
	if level <= 1 then
		return { coins = 0, spins = 0, paint = nil }
	end
	local paint = PAINT_LEVELS[level]
	return {
		coins = if paint then 0 else 20 + 5 * level,
		spins = if level % 3 == 0 then 1 else 0,
		paint = paint,
	}
end

function PlayerLevel.totalXp(progress: { carXp: { [string]: number } }): number
	local sum = 0
	for _, xp in progress.carXp do
		sum += xp
	end
	return sum
end

function PlayerLevel.levelForXp(xp: number): number
	local level = 1
	while level < PlayerLevel.MaxLevel and xp >= need(level + 1) do
		level += 1
	end
	return level
end

function PlayerLevel.view(xp: number): View
	local level = PlayerLevel.levelForXp(xp)
	if level >= PlayerLevel.MaxLevel then
		return { level = level, into = 0, needed = 0, maxed = true }
	end
	return {
		level = level,
		into = xp - need(level),
		needed = need(level + 1) - need(level),
		maxed = false,
	}
end

-- Pays the rewards for every level between `beforeXp` and `afterXp`. `profile` needs coins, paint
-- ({owned}) and daily ({freePulls}). A paint the player already owns pays coins instead.
function PlayerLevel.pay(profile: any, beforeXp: number, afterXp: number): Paid
	local paid: Paid = { coins = 0, spins = 0, paints = {} }
	local from = PlayerLevel.levelForXp(beforeXp)
	local to = PlayerLevel.levelForXp(afterXp)
	for level = from + 1, to do
		local r = PlayerLevel.reward(level)
		paid.coins += r.coins
		paid.spins += r.spins
		if r.paint then
			if PaintConfig.color(r.paint) and not profile.paint.owned[r.paint] then
				profile.paint.owned[r.paint] = true
				table.insert(paid.paints, r.paint)
			else
				paid.coins += 60
			end
		end
	end
	profile.coins = math.clamp(profile.coins + paid.coins, 0, 1e9)
	profile.daily.freePulls =
		math.min(profile.daily.freePulls + paid.spins, QuestsConfig.Daily.maxFreePulls)
	return paid
end

return PlayerLevel
