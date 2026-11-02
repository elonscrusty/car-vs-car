--!strict
-- The crate opening show (carter picked B "spinning reel", all out, 10-29; plans in
-- crate-open/crate-all-out.html): the crate crashes in, its lid blasts off, a reel of cars blurs
-- past, slows, freezes for a beat on your car, then a boom that grows with the rarity. The server
-- already rolled the car; this only plans the SHOW (which cards are on the reel, where it stops,
-- how long each beat lasts), so Lune can test it. The look is client/Ui/Screens/CrateReel.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end
local CarCatalog = sibling("CarCatalog")
local Crates = sibling("Crates")

local CrateReel = {}

CrateReel.CARDS = 46 -- cards on the strip
CrateReel.WIN = 36 -- the card your car is on (0 based: the 37th)
CrateReel.WORDS = { "NICE!", "RARE!", "EPIC!!", "LEGENDARY!!!" } -- the big word, by rarity 1..4

export type Plan = {
	rarity: number, -- 1 common .. 4 legend
	cards: { number }, -- rarity 1..4 of each card on the strip, left to right (1 based)
	win: number, -- index in `cards` (1 based) of your car
	stop: number, -- where the spin slows to a stop (epic and up stop one card early, then creep on)
	creep: boolean,
	spin: number, -- seconds the spin lasts
	creepSecs: number,
	hold: number, -- the freeze before the boom
	bolts: number, -- lightning bolts in the boom
	rings: number, -- shock rings in the boom
	coins: number, -- gold coins that rain
	shake: number, -- screen shake strength (design px)
	big: boolean, -- legend: a second flash and the confetti rain
	word: string,
}

-- rarity number 1..4 from "common" / "rare" / "epic" / "legend" (also "legendary")
function CrateReel.rarityNumber(rarity: any): number
	if rarity == "legendary" then
		rarity = "legend"
	end
	return table.find(CarCatalog.RARITY_ORDER, rarity) or 1
end

-- The show for a crate of `kind` that gave a car of `rarity`. `seed` makes the same strip every
-- time (tests); nil = random. Cards only ever show kinds of car the crate can really give (a
-- kind with 0% never turns up on the reel), and the cards next to yours are a step up or down
-- so a near miss builds the wait.
function CrateReel.plan(rarity: any, kind: any, seed: number?): Plan
	local t = CrateReel.rarityNumber(rarity)
	-- (a seed: our own little generator, the same in Lune and Roblox; no seed: Roblox's Random)
	local state = seed or 0
	local rng = {
		NextNumber = function(): number
			if not seed then
				return math.random()
			end
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
	local odds = Crates.odds(kind)
	local chance: { number } = {}
	for i, r in CarCatalog.RARITY_ORDER do
		chance[i] = odds[r] or 0
	end
	chance[t] = math.max(chance[t], 0.001) -- (the car it gave is always a real kind)
	local total = 0
	for _, c in chance do
		total += c
	end
	local function pick(): number
		local r = rng.NextNumber() * total
		local s = 0
		for i, c in chance do
			s += c
			if r < s then
				return i
			end
		end
		return t
	end
	-- the nearest kind the crate can give, going up (down if there is none above)
	local function real(want: number): number
		for i = math.min(want, 4), 4 do
			if chance[i] > 0 then
				return i
			end
		end
		for i = math.min(want, 4), 1, -1 do
			if chance[i] > 0 then
				return i
			end
		end
		return t
	end
	local win = CrateReel.WIN + 1
	local cards: { number } = {}
	for i = 1, CrateReel.CARDS do
		cards[i] = pick()
	end
	cards[win] = t
	cards[win + 1] = real(math.max(t + 1, 3))
	cards[win + 2] = real(t + 1)
	if t >= 3 then
		cards[win - 1] = real(math.max(1, t - 2))
	end
	local big = t >= 4
	return {
		rarity = t,
		cards = cards,
		win = win,
		stop = if t >= 3 then win - 1 else win,
		creep = t >= 3,
		spin = 3.9 + 0.5 * (t - 1),
		creepSecs = 1.1,
		hold = if t >= 3 then 0.42 else 0.24,
		bolts = if t >= 2 then 3 + 2 * (t - 1) else 0,
		rings = math.min(3, t),
		coins = if t >= 4 then 44 elseif t >= 3 then 22 else 0,
		shake = 10 + 3 * (t - 1),
		big = big,
		word = CrateReel.WORDS[t],
	}
end

return CrateReel
