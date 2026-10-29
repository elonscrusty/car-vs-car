--!strict
-- Phone speed for Car VS Car: the karts in all 8 garages (PlotShowroom), the race cars and the
-- people on the stand stay under a part budget, and garages far from the camera stop turning.
-- (Meshy cars are fewer parts than these block stand-ins, so this is the most.)
local H = require("./harness")
local Garage = require("../src/shared/Garage")
local ToyCars = require("../src/shared/ToyCars")
local PlotShowroom = require("../src/shared/PlotShowroom")
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
	local styles = { "" }
	for _, shape in ToyCars.SHAPES do
		table.insert(styles, shape .. "/dark/glow")
	end
	for _, style in styles do
		local pieces = {}
		Garage.toyCar(
			Garage.adder(pieces),
			"Car",
			{ x = 0, y = 0, z = 0 },
			0,
			{ 200, 40, 40 },
			PlotShowroom.TURNTABLE.car,
			if style == "" then nil else style
		)
		most = math.max(most, #pieces)
	end
	return most
end

-- every stand and the turntable full, in every garage
local function garages(): number
	local perPlot = #PlotShowroom.SPOTS + 1
	return PLOTS * perPlot * carParts()
end

test("a tiny car is a few parts", function()
	truthy(carParts() <= 20, `a tiny car is {carParts()} parts`)
end)

test("there are 8 plots and 8 racers", function()
	eq(PLOTS, 8)
end)

test("full plots, 8 race cars and 8 people on the stand stay under budget", function()
	local total = garages() + RACERS * (RACE_CAR + AVATAR)
	print(`       {total} parts of {BUDGET}`)
	truthy(total <= BUDGET, `{total} parts, budget {BUDGET}`)
end)

test("a garage far from the camera stops turning its kart; a near one turns", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/client/PlotShowroom.client.luau")
	truthy(string.find(src, "Magnitude < PlotShowroom.NEAR then", 1, true), "far garages wait")
	truthy(PlotShowroom.NEAR > 0 and PlotShowroom.NEAR <= 300)
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
