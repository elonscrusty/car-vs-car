--!strict
-- Phone speed for Car VS Car: the tiny training cars on all 8 plots, the race cars and the people
-- on the stand stay under a part budget, and plots far from the camera stop moving their cars.
-- (Meshy cars are fewer parts than these block stand-ins, so this is the most.)
local H = require("./harness")
local Garage = require("../src/shared/Garage")
local PlotTraining = require("../src/shared/PlotTraining")
local LobbyLayout = require("../src/shared/LobbyLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car part budget")

local PLOTS = #LobbyLayout.slots()
local RACERS = 8
local RACE_CAR = 20 -- server body ~10 parts + 4 wheels with a stripe each (OtherCars)
local AVATAR = 30 -- a person on the stand: R15 body plus hat and hair, at most
local BUDGET = 3200 -- everything the cars and people add on top of the lobby (cap, ~15% over)

-- the most parts one tiny car makes (any look)
local function carParts(): number
	local most = 0
	for _, style in { "", "rock", "drift" } do
		local pieces = {}
		Garage.toyCar(
			Garage.adder(pieces),
			"Car",
			{ x = 0, y = 0, z = 0 },
			0,
			{ 200, 40, 40 },
			PlotTraining.CAR,
			if style == "" then nil else style
		)
		most = math.max(most, #pieces)
	end
	return most
end

-- every pad and every stand full, on every plot
local function training(): number
	local perPlot = #PlotTraining.GRID + #PlotTraining.STANDS
	return PLOTS * perPlot * carParts()
end

test("a tiny car is a few parts", function()
	truthy(carParts() <= 20, `a tiny car is {carParts()} parts`)
end)

test("there are 8 plots and 8 racers", function()
	eq(PLOTS, 8)
end)

test("full plots, 8 race cars and 8 people on the stand stay under budget", function()
	local total = training() + RACERS * (RACE_CAR + AVATAR)
	print(`       {total} parts of {BUDGET}`)
	truthy(total <= BUDGET, `{total} parts, budget {BUDGET}`)
end)

test("a plot far from the camera stops moving its cars; a near one moves", function()
	truthy(PlotTraining.awake(0))
	truthy(PlotTraining.awake(PlotTraining.NEAR - 1))
	truthy(not PlotTraining.awake(PlotTraining.NEAR))
	truthy(not PlotTraining.awake(5000))
end)

test("an 8-car race: far shop crates don't spin, rival wheels move in one go each frame", function()
	local fs = require("@lune/fs")
	local crates = fs.readFile("src/client/CrateShop.client.luau")
	truthy(
		string.find(crates, "(s.base.Position - eye).Magnitude < SPIN_NEAR", 1, true),
		"far spin"
	)
	local others = fs.readFile("src/client/OtherCars.luau")
	local _, moves = string.gsub(others, "BulkMoveTo%(", "")
	eq(moves, 1) -- one per frame for every rival's wheels, stripes and shell
	truthy(
		not string.find(others, 'FindFirstChild("Stripe")', 1, true),
		"a find per wheel per frame"
	)
end)
