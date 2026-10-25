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
