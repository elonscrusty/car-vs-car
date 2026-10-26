--!strict
-- Joining one thing at a time (carter 10-25): the saved stage and what each stage shows.
local H = require("./harness")
local JoinStage = require("../src/shared/JoinStage")
local Profile = require("../src/shared/Profile")

local test, eq = H.test, H.eq

print("JoinStage")

test("join stage: a new player sees GO, coins and the race, then a bit more each step", function()
	eq(JoinStage.shows(0, "go"), true)
	eq(JoinStage.shows(0, "coins"), true) -- (tycoon: the free car earns from the start)
	eq(JoinStage.shows(0, "race"), true)
	eq(JoinStage.shows(0, "build"), false)
	eq(JoinStage.shows(0, "gift"), false)
	eq(JoinStage.shows(1, "coins"), true)
	eq(JoinStage.shows(1, "build"), true)
	eq(JoinStage.shows(1, "shop"), false)
	eq(JoinStage.shows(2, "shop"), true)
	eq(JoinStage.shows(2, "jobs"), false)
	eq(JoinStage.shows(3, "jobs"), true)
	eq(JoinStage.shows(3, "visit"), true)
	-- not loaded yet = new; junk is clamped; unknown names always show
	eq(JoinStage.shows(nil, "shop"), false)
	eq(JoinStage.of(0 / 0), 0)
	eq(JoinStage.of(9), 3)
	eq(JoinStage.shows(0, "somethingNew"), true)
	-- the two stage lists agree
	eq(JoinStage.LAPPED, Profile.STAGE.LAPPED)
	eq(JoinStage.RACED, Profile.STAGE.RACED)
	eq(JoinStage.SHOPPED, Profile.STAGE.SHOPPED)
end)

test("join stage: saved, only goes up, old saves that played skip ahead", function()
	local d = Profile.new()
	eq(d.stage, 0)
	eq(Profile.raiseStage(d, 1), true)
	eq(Profile.raiseStage(d, 1), false)
	eq(Profile.raiseStage(d, 0), false)
	eq(d.stage, 1)
	eq(Profile.raiseStage(d, 9), true)
	eq(d.stage, 3)
	eq(Profile.raiseStage(d, 0 / 0), false)
	-- a round trip keeps it
	eq(Profile.migrate({ version = Profile.VERSION, stage = 2, coins = 50 }).stage, 2)
	eq(Profile.migrate({ version = Profile.VERSION, stage = 99 }).stage, 3)
	-- before stages: played (coins, stars or a car) = seen it all; never played = new
	eq(Profile.migrate({ version = 13, coins = 10 }).stage, 3)
	eq(Profile.migrate({ version = 13, cars = { blue = true } }).stage, 3)
	eq(Profile.migrate({ version = 13 }).stage, 0)
	eq(Profile.migrate(nil).stage, 0)
end)
