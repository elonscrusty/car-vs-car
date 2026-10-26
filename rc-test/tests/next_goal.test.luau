--!strict
-- NextGoal: one thing to do next for a player on foot (carter's pick #2).
local H = require("./harness")
local NextGoal = require("../src/shared/NextGoal")

local test, eq = H.test, H.eq

local function state(over: { [string]: any }): any
	local s: any = {
		hasPlot = true,
		driven = true,
		nearPad = false,
		inShops = false,
		inBreak = false,
		canBuy = false,
	}
	for k, v in over do
		s[k] = v
	end
	return s
end

test("next goal: drive your own track first, before anything else", function()
	local g = NextGoal.pick(state({ driven = false, canBuy = true, inBreak = true })) :: any
	eq(g.text, "FOLLOW THE ARROWS")
	eq(g.target, "pad")
	g = NextGoal.pick(state({ driven = false, nearPad = true })) :: any
	eq(g.text, "TAP DRIVE!")
	eq(g.target, nil)
end)

test("next goal: coins for the next unlock send you to the shops", function()
	local g = NextGoal.pick(state({ canBuy = true, inBreak = true })) :: any
	eq(g.text, "GO SHOP!")
	eq(g.target, "shop")
	g = NextGoal.pick(state({ canBuy = true, inShops = true })) :: any
	eq(g.text, "BUY IT!")
	eq(g.target, nil)
end)

test("next goal: build in the break, else drive your track", function()
	eq((NextGoal.pick(state({ inBreak = true })) :: any).text, "TAP BUILD!")
	local g = NextGoal.pick(state({})) :: any
	eq(g.text, "DRIVE YOUR TRACK")
	eq(g.target, "pad")
	eq((NextGoal.pick(state({ nearPad = true })) :: any).text, "TAP DRIVE!")
end)

test("next goal: built in this break, so count down to the race", function()
	eq(
		(NextGoal.pick(state({ inBreak = true, built = true, raceIn = 99.2 })) :: any).text,
		"RACE IN 1:40"
	)
	eq(
		(NextGoal.pick(state({ inBreak = true, built = true, raceIn = -3 })) :: any).text,
		"RACE IN 0:00"
	)
	eq(
		(NextGoal.pick(state({ inBreak = true, built = false, raceIn = 50 })) :: any).text,
		"TAP BUILD!"
	)
	-- the shop still wins: coins to spend
	eq(
		(NextGoal.pick(state({ inBreak = true, built = true, raceIn = 50, canBuy = true })) :: any).text,
		"GO SHOP!"
	)
end)

test("next goal: no plot, only the shop (or nothing)", function()
	eq(NextGoal.pick(state({ hasPlot = false })), nil)
	eq((NextGoal.pick(state({ hasPlot = false, canBuy = true })) :: any).target, "shop")
end)

test("next goal: always 1-3 words", function()
	for _, over in
		{
			{ driven = false },
			{ driven = false, nearPad = true },
			{ canBuy = true },
			{ canBuy = true, inShops = true },
			{ inBreak = true },
			{},
			{ nearPad = true },
		}
	do
		local g = NextGoal.pick(state(over)) :: any
		H.truthy(#string.split(g.text, " ") <= 3, g.text)
	end
end)

test("next goal: after the first car, win stars on someone else's plot", function()
	local g = NextGoal.pick(state({ visit = "Sam" }))
	eq(g and g.text, "WIN ⭐ AT SAM'S")
	eq(g and g.target, "visit")
	-- the shop and BUILD still come first; once built, the visit beats the countdown
	eq((NextGoal.pick(state({ visit = "Sam", canBuy = true })) :: any).target, "shop")
	eq((NextGoal.pick(state({ visit = "Sam", inBreak = true })) :: any).text, "TAP BUILD!")
	eq(
		(NextGoal.pick(state({ visit = "Sam", inBreak = true, built = true, raceIn = 60 })) :: any).target,
		"visit"
	)
	eq(
		(NextGoal.pick(state({ visit = "superlongname_2014" })) :: any).text,
		"WIN ⭐ AT SUPERLONGN'S"
	)
end)

test("next goal (tycoon): garage first, then race, shop, collect", function()
	local function t(over: { [string]: any }): any
		local s = state(over)
		s.tycoon = true
		return NextGoal.pick(s)
	end
	eq(t({ seenGarage = false }).text, "YOUR GARAGE")
	eq(t({ seenGarage = false }).target, "pad")
	eq(t({ seenGarage = false, nearPad = true }), nil)
	eq(t({ seenGarage = true, joinOpen = true }).text, "JOIN THE RACE")
	eq(t({ seenGarage = true, joinOpen = true }).target, "shop")
	eq(t({ seenGarage = true, joinOpen = true, joined = true }).text, "RACE SOON!")
	eq(t({ seenGarage = true, joinOpen = true, canBuy = true }).text, "GO SHOP!")
	eq(t({ seenGarage = true, joinOpen = true, pile = NextGoal.COLLECT_AT }).text, "COLLECT COINS")
	eq(t({ seenGarage = true, nearPad = true, pile = 99 }).text, "TAP TO COLLECT")
	eq(t({ seenGarage = true }), nil)
	-- no build or drive-your-track goals in the tycoon
	eq(t({ seenGarage = true, inBreak = true }), nil)
end)
