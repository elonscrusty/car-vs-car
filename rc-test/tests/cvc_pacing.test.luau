--!strict
-- Car VS Car pacing (carter 10-28): a kid who loses every race still gets something new on the
-- plot often. The kid is the Studio bored-kid run (rc-game/cvc/studio/critic/REPORT-1.md): no
-- race coins (never finished), cars from crates at 2:30 and 3:10, the "train 5 min" job's 30
-- coins at 5:22 and the daily gift's 10 at 5:44. Coins come only from training
-- (CvcRules.COINS_PER_MIN for each car on a station). Each second the kid buys the cheapest thing
-- they can: the next plot level (a new station) or a level on a station that has a car.
local H = require("./harness")
local CvcRules = require("../src/shared/CvcRules")
local Training = require("../src/shared/Training")

local test, truthy = H.test, H.truthy

print("Car VS Car pacing")

type Buy = { at: number, what: string }

local function play(minutes: number): { Buy }
	local coins = 0
	local plotLevel = 0
	local levels = { 1 } -- each station's level
	local buys: { Buy } = {}
	for s = 0, minutes * 60 do
		local cars = if s < 150 then 1 elseif s < 190 then 2 else 3
		coins += math.min(cars, #levels) * CvcRules.COINS_PER_MIN / 60
		if s == 322 then
			coins += 30
		elseif s == 344 then
			coins += 10
		end
		while true do
			local cost, what, which = math.huge, "", 0
			local plot = Training.plotCost(plotLevel)
			if plot then
				cost, what = plot, "station"
			end
			for i, lv in levels do
				local up = Training.upgradeCost(lv)
				if i <= cars and up and up < cost then
					cost, what, which = up, "upgrade", i
				end
			end
			if coins < cost then
				break
			end
			coins -= cost
			if what == "station" then
				plotLevel += 1
				table.insert(levels, 1)
			else
				levels[which] += 1
			end
			table.insert(buys, { at = s / 60, what = what })
		end
	end
	return buys
end

local buys = play(15)

test("a kid who loses every race opens the 2nd station within 5 minutes", function()
	local first = math.huge
	for _, b in buys do
		if b.what == "station" then
			first = math.min(first, b.at)
		end
	end
	print(string.format("       2nd station at %.1f min", first))
	truthy(first <= 5, "2nd station by 5 min")
end)

test("in the first 15 minutes, never more than 4 minutes without something new", function()
	local last, worst = 0, 0
	for _, b in buys do
		worst = math.max(worst, b.at - last)
		last = b.at
	end
	worst = math.max(worst, 15 - last)
	-- (carter's goal is 2 min; training coins alone can't get there: it needs coins for racing
	-- even when you lose, which is the race side's job)
	print(string.format("       %d new things, longest wait %.1f min", #buys, worst))
	truthy(worst <= 4, "no wait over 4 min")
end)
