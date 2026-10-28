--!strict
-- XP and levels (Smash plan, REWARDS row): every match pays XP for playing, for each smash and for
-- a top 3 place; XP fills a level bar ("0 / 100" at level 1, a bit more each level). A level up
-- pays coins. Pure tables, so Lune can test it; XpServer saves it and sets the Level attribute
-- (the scoreboard badge by each name).

export type Save = { xp: number, coins: number }
export type Gain = {
	xp: number, -- XP added
	from: number, -- level before
	to: number, -- level after
	coins: number, -- coins paid for the new levels
}

local Xp = {}

Xp.MATCH = 20 -- for playing a whole match
Xp.SMASH = 10 -- each smash (bumps count too)
Xp.SMASH_CAP = 30 -- smashes counted per match, so one match can't pay a mountain
Xp.PLACE = { 50, 30, 15 } -- 1st, 2nd, 3rd
Xp.FIRST_NEED = 100 -- XP from level 1 to 2
Xp.MORE_NEED = 25 -- each level after needs this much more
Xp.MAX_LEVEL = 999
Xp.LEVEL_COINS = 50 -- coins for each new level
Xp.MAX_XP = 1e9
Xp.MAX_COINS = 1e12 -- the same as Profile.MAX_COINS

local function whole(v: any, lo: number, hi: number): number
	if type(v) ~= "number" or v ~= v then
		return lo
	end
	return math.clamp(math.floor(v), lo, hi)
end

-- XP to go from `level` to the next one.
function Xp.need(level: number): number
	return Xp.FIRST_NEED + Xp.MORE_NEED * (whole(level, 1, Xp.MAX_LEVEL) - 1)
end

-- The level `xp` reaches, how far into that level it is, and what that level needs.
function Xp.levelOf(xp: number): (number, number, number)
	local left = whole(xp, 0, Xp.MAX_XP)
	local level = 1
	while level < Xp.MAX_LEVEL and left >= Xp.need(level) do
		left -= Xp.need(level)
		level += 1
	end
	local need = Xp.need(level)
	return level, math.min(left, need), need -- the top level's bar stays full
end

-- XP for one match: `place` 1.., `smashes` 0.. (junk counts as 0 / no place).
function Xp.forMatch(place: any, smashes: any): number
	local p = whole(place, 0, 99)
	local bonus = Xp.PLACE[p] or 0
	return Xp.MATCH + Xp.SMASH * whole(smashes, 0, Xp.SMASH_CAP) + bonus
end

-- Add `amount` XP to the save; pays LEVEL_COINS for every new level.
function Xp.add(d: Save, amount: number): Gain
	local add = whole(amount, 0, Xp.MAX_XP)
	local from = Xp.levelOf(d.xp)
	d.xp = math.min(whole(d.xp, 0, Xp.MAX_XP) + add, Xp.MAX_XP)
	local to = Xp.levelOf(d.xp)
	local coins = (to - from) * Xp.LEVEL_COINS
	d.coins = math.min(d.coins + coins, Xp.MAX_COINS)
	return { xp = add, from = from, to = to, coins = coins }
end

return Xp
