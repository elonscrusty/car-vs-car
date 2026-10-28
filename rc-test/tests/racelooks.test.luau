--!strict
-- Race looks: sparks only on a real hit, never on braking or a bump.
local H = require("./harness")
local RaceLooks = require("../src/shared/RaceLooks")

local test, truthy = H.test, H.truthy

print("Race looks")

test("sparks: a wall stops the car in a frame; brakes and bumps don't", function()
	local s = 0.25 -- RC size
	truthy(RaceLooks.slammed(40, 8, s), "into a wall at speed")
	truthy(not RaceLooks.slammed(40, 39, s), "braking hard: about 1 stud/s a frame")
	truthy(not RaceLooks.slammed(4, 0, s), "a slow nudge is too small")
	truthy(not RaceLooks.slammed(40, 45, s), "speeding up")
end)

test("Car VS Car (playtest u01): the race car is your racer's toy car, not the grey box", function()
	local fs = require("@lune/fs")
	local Garage = require("../src/shared/Garage")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(string.find(main, "skin.update(car, skinName())", 1, true), "skin not used")
	truthy(string.find(main, "CarSkin.TOY .. id", 1, true), "no toy car for the racer")
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(string.find(skin, "Garage.toyCar(", 1, true), "not the plot's toy car")
	-- the toy car's four wheels sit one at each corner, so each gets its own name
	local pieces = {}
	Garage.toyCar(Garage.adder(pieces), "Car", { x = 0, y = 0, z = 0 }, 180, { 1, 2, 3 }, 1, "race")
	local corners: { [string]: number } = {}
	for _, p in pieces :: { any } do
		if p.name == "Wheel" then
			local k = (if p.pos.z > 0 then "F" else "R") .. (if p.pos.x < 0 then "R" else "L")
			corners[k] = (corners[k] or 0) + 1
		end
	end
	for _, k in { "FL", "FR", "RL", "RR" } do
		truthy(corners[k] == 1, `wheel {k}`)
	end
end)

test("skid marks (playtest u30, u12): one smooth fading ribbon, none on water", function()
	local fs = require("@lune/fs")
	local fx = fs.readFile("src/client/Effects.luau")
	truthy(string.find(fx, 'Instance.new("Trail")', 1, true), "marks are not a ribbon")
	truthy(not string.find(fx, 'p.Name = "Skid"', 1, true), "the old box marks are back")
	truthy(string.find(fx, "[Enum.Material.Water] = true", 1, true), "marks on water")
	truthy(string.find(fx, "[Enum.Material.Glass] = true", 1, true), "marks on puddles")
	local car = fs.readFile("src/client/RCCar.luau")
	truthy(
		string.find(car, "w.info.material = hit.Material", 1, true),
		"no material under the tyre"
	)
end)

test("boost pads (playtest u02): no glowing yellow pad that hides the car", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/RaceMapBuilder.luau")
	truthy(
		string.find(
			src,
			"boost = { color = rgb(225, 150, 40), mat = Enum.Material.SmoothPlastic }",
			1,
			true
		),
		"the pad glows again"
	)
end)

test("Car VS Car (phone 10-28 t096-t100): over the line, the car brakes to a stop", function()
	local fs = require("@lune/fs")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(
		string.find(main, "elseif grid and (raceDone ~= nil or raceOver) then", 1, true),
		"drives on"
	)
	truthy(
		string.find(main, "local rolling = car.telemetry.vLong > 3", 1, true),
		"backs up at a stop"
	)
end)
