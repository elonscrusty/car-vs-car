--!strict
-- The Lucky Spin (Smash plan, REWARDS row): one free spin a day, coins or a kart hat. The odds
-- are shown before you spin (the spin window lists every prize and its chance), they add up to
-- 100, and the server rolls. No Robux and no paid spins. A hat you already have pays DUPE_COINS.
-- Pure tables, so Lune can test it; SpinServer saves it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Hats = sibling("Hats")

export type Prize = {
	kind: string, -- "coins" | "hat"
	coins: number?, -- kind coins
	hat: string?, -- kind hat: a Hats id
	chance: number, -- in percent
	label: string, -- what the wheel and the odds list say
	rarity: string,
}
export type Save = {
	coins: number,
	spinDay: number, -- the day the free spin was last used (0 = never)
	hats: { [string]: boolean },
}
export type Won = {
	index: number, -- which prize (LuckySpin.PRIZES)
	coins: number, -- coins paid (a hat you had pays DUPE_COINS)
	hat: string?, -- the new hat, if you got one
}

local LuckySpin = {}

LuckySpin.DUPE_COINS = 150
LuckySpin.MAX_COINS = 1e12 -- the same as Profile.MAX_COINS

local function coins(n: number, chance: number, rarity: string): Prize
	return {
		kind = "coins",
		coins = n,
		chance = chance,
		label = tostring(n) .. " COINS",
		rarity = rarity,
	}
end
local function hat(id: string, chance: number): Prize
	local h = Hats.get(id)
	assert(h, "no hat " .. id)
	return {
		kind = "hat",
		hat = id,
		chance = chance,
		label = string.upper(h.name),
		rarity = h.rarity,
	}
end

-- the wheel, in order round it (coins and hats take turns so the wheel looks mixed)
LuckySpin.PRIZES = {
	coins(50, 30, "common"),
	hat("cherry", 10),
	coins(100, 22, "common"),
	hat("cone", 7),
	coins(200, 14, "rare"),
	hat("tophat", 6),
	coins(500, 5, "epic"),
	hat("propeller", 3),
	hat("crown", 2),
	hat("star", 1),
} :: { Prize }

-- The day number (a free spin each UTC day; the same as Profile.day).
function LuckySpin.day(now: number): number
	return math.floor(now / 86400)
end

-- Seconds until the next free spin (0 = ready now).
function LuckySpin.wait(d: Save, now: number): number
	-- (>=: a day from a server whose clock runs ahead still counts as used)
	if d.spinDay < LuckySpin.day(now) then
		return 0
	end
	return (LuckySpin.day(now) + 1) * 86400 - now
end

-- Which prize a roll in [0, 1) lands on (the chances in order).
function LuckySpin.pick(roll: number): number
	local r = if type(roll) == "number" and roll == roll then math.clamp(roll, 0, 0.999999) else 0
	local at = r * 100
	local sum = 0
	for i, p in LuckySpin.PRIZES do
		sum += p.chance
		if at < sum then
			return i
		end
	end
	return #LuckySpin.PRIZES
end

-- Use today's free spin with `roll` in [0, 1) (the server's Random). nil = already spun today.
function LuckySpin.spin(d: Save, now: number, roll: number): Won?
	local day = LuckySpin.day(now)
	if d.spinDay >= day then
		return nil
	end
	d.spinDay = day
	local i = LuckySpin.pick(roll)
	local p = LuckySpin.PRIZES[i]
	local won: Won = { index = i, coins = 0, hat = nil }
	if p.kind == "hat" and p.hat and not d.hats[p.hat] then
		d.hats[p.hat] = true
		won.hat = p.hat
	else
		won.coins = if p.kind == "hat" then LuckySpin.DUPE_COINS else p.coins or 0
	end
	d.coins = math.min(d.coins + won.coins, LuckySpin.MAX_COINS)
	return won
end

return LuckySpin
