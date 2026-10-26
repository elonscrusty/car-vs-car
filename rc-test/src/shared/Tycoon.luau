--!strict
-- The tycoon half of carter's loop (10-26, rc-game/tycoon/PLAN.md): race -> coins -> buy cars ->
-- your parked cars make coins -> better cars. Each car parked in your plot (the garage) makes
-- coins every minute by its rarity; the coins pile up in the plot until you tap to collect. A
-- race win doubles the plot's income for a while. The pile keeps filling while you're away, up
-- to a cap, so coming back pays. Pure, so Lune can test it; TycoonServer runs it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")

local Tycoon = {}

Tycoon.BASE_SLOTS = 3 -- cars that park and earn at plot level 0
Tycoon.MAX_LEVEL = 5 -- one more slot each level: 8 at the top
Tycoon.LEVEL_COST = { 500, 1200, 2500, 5000, 9000 } -- coins to reach level 1, 2, ...
Tycoon.WIN_BOOST = 2 -- a race win doubles the plot's income...
Tycoon.BOOST_SECS = 600 -- ...for 10 minutes
Tycoon.PILE_CAP_MIN = 120 -- the pile stops at this many minutes of income (online or away)

-- Coins a minute this car makes parked (0 for an unknown id): its rarity's (CarCatalog.RARITY).
function Tycoon.perMin(id: string): number
	if CarCatalog.get(id) == nil then
		return 0
	end
	return CarCatalog.rarity(id).perMin
end

function Tycoon.slots(level: number): number
	return Tycoon.BASE_SLOTS + math.clamp(math.floor(level), 0, Tycoon.MAX_LEVEL)
end

-- Coins to go from this level to the next (nil at the top).
function Tycoon.levelCost(level: number): number?
	return Tycoon.LEVEL_COST[math.floor(level) + 1]
end

-- Coins a minute from these parked cars (boost included when it's on at `now`).
function Tycoon.income(parked: { string }, boostUntil: number, now: number): number
	local sum = 0
	for _, id in parked do
		sum += Tycoon.perMin(id)
	end
	return if boostUntil > now then sum * Tycoon.WIN_BOOST else sum
end

-- The pile after `seconds` at `perMin`: it grows to the cap and stops there (a pile already over
-- the cap, from a bigger income before, is never cut).
function Tycoon.accrue(pile: number, perMin: number, seconds: number): number
	local cap = perMin * Tycoon.PILE_CAP_MIN
	if seconds <= 0 or pile >= cap then
		return pile
	end
	return math.min(pile + perMin * seconds / 60, cap)
end

-- The garage for someone who never had one: their best owned cars, up to the slots (the free
-- starter at least). `owns` says whether they have a car.
function Tycoon.firstParked(level: number, owns: (string) -> boolean): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: string)
		if not seen[id] and owns(id) then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, mode in CarCatalog.MODES do
		for _, c in CarCatalog.SHOP[mode] do
			add(c.id)
		end
	end
	for _, g in CarCatalog.GUMBALL do
		add(g.car.id)
	end
	table.sort(list, function(a, b)
		local pa, pb = Tycoon.perMin(a), Tycoon.perMin(b)
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)
	-- the race starter first among equals: Bolt is the car a new kid sees parked
	local starter = CarCatalog.starter("race").id
	local at = table.find(list, starter)
	if at and Tycoon.perMin(list[1]) <= Tycoon.perMin(starter) then
		table.remove(list, at)
		table.insert(list, 1, starter)
	end
	while #list > Tycoon.slots(level) do
		table.remove(list)
	end
	return list
end

-- Park a car (on) or take it out. False when it can't: not owned, already there / not there,
-- or the garage is full.
function Tycoon.park(
	parked: { string },
	level: number,
	id: string,
	on: boolean,
	owns: (string) -> boolean
): boolean
	local at = table.find(parked, id)
	if not on then
		if at == nil then
			return false
		end
		table.remove(parked, at)
		return true
	end
	if at or not owns(id) or #parked >= Tycoon.slots(level) then
		return false
	end
	table.insert(parked, id)
	return true
end

return Tycoon
