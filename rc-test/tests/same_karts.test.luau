--!nocheck
-- Car VS Car SMASH: karts have no stats (carter 23:25). In a round every kart drives the same:
-- two kids on different cars get the same kart body and the same health, and the screen's drive
-- never reads a car's race numbers (RaceStats), whatever the car or its old training.
local H = require("./harness")
local Fake = require("./fakeroblox")
local fs = require("@lune/fs")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: every kart drives the same")

local function body(S, id: number)
	local car = S.workspace:FindFirstChild("Car_" .. id)
	return car and car.PrimaryPart
end

test("two kids on different cars: same kart body, same health in a round", function()
	local S = Fake.server(Fake.store(), { jobId = "same-karts" })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local a, b = S.join(601), S.join(602)
	S.advance(3, 0.05)
	-- b drives another car, with lots of old training on it (the save keeps it, unused)
	local PlayerData = S.require("PlayerData")
	local Profile = S.require("Shared.Profile")
	local data = PlayerData.get(b)
	local car = Profile.addCar(data, "race_rocket")
	car.speed, car.turn, car.boost = 10, 10, 10
	data.racer = car.uid
	S.require("GarageServer").show(b, data)
	S.advance(1, 0.05)
	truthy(a:GetAttribute("RacerCar") ~= b:GetAttribute("RacerCar"), "different cars")
	MR.join(a)
	MR.join(b)
	for _ = 1, 40 do
		if
			a:GetAttribute("InMatch")
			and b:GetAttribute("InMatch")
			and body(S, 601)
			and body(S, 602)
		then
			break
		end
		S.advance(0.5, 0.05)
	end
	local pa, pb = body(S, 601), body(S, 602)
	truthy(pa and pb, "both karts in the arena")
	eq(tostring(pa.Size), tostring(pb.Size), "body size")
	eq(tostring(pa.CustomPhysicalProperties), tostring(pb.CustomPhysicalProperties), "physics")
	eq(pa.Massless, pb.Massless, "massless")
	eq(a:GetAttribute("MaxHealth"), b:GetAttribute("MaxHealth"), "health")
end)

test("the screen's drive never uses a car's race numbers", function()
	local src = fs.readFile("src/client/Main.client.luau")
	-- RaceStats is only there for its type; no call into it, and every drive resets the numbers
	eq(string.find(src, "RaceStats%.%a+%("), nil, "no RaceStats call")
	local drive = string.match(src, 'kind == "drive".-goTo%(index%)')
	truthy(drive and string.find(drive, "setStats%(nil%)", 1, false), "drive resets the numbers")
end)
