--!strict
-- Why visit other plots (carter 10-25): each plot's sign as seen by one player.
local H = require("./harness")
local Visit = require("../src/shared/Visit")
local Profile = require("../src/shared/Profile")

local test, eq = H.test, H.eq

print("Visit")

local DAY = 20000
local SAM = { value = 21, name = "Sam", userId = 2 }

test("visit sign: stars to win first, then the record to beat, and the gift", function()
	local d = Profile.new()
	-- a fresh plot: all 3 stars and today's gift
	local s = Visit.sign(d, 1, 4, 2, "race", SAM, DAY, 1)
	eq(s.stars, 3)
	eq(s.beat, nil)
	eq(s.gift, Profile.VISIT_COINS)
	local lines = Visit.lines(s)
	eq(lines[1], "⭐ 3 HERE")
	eq(lines[2], `+{Profile.VISIT_COINS} VISIT GIFT`)
	-- bronze won: 2 left; gift taken today: no gift line
	Profile.award(d, 1, 2, "race", 1)
	Profile.visit(d, 1, 2, DAY, 1)
	s = Visit.sign(d, 1, 4, 2, "race", SAM, DAY, 1)
	eq(s.stars, 2)
	eq(s.gift, 0)
	eq(#Visit.lines(s), 1)
	-- tomorrow the gift is back
	eq(Visit.sign(d, 1, 4, 2, "race", SAM, DAY + 1, 1).gift, Profile.VISIT_COINS)
	-- gold won: no stars left, Sam's record to beat
	Profile.award(d, 1, 2, "race", 3)
	s = Visit.sign(d, 1, 4, 2, "race", SAM, DAY, 2)
	eq(s.stars, 0)
	eq(s.beat, "SAM 0:21.0")
	eq(Visit.lines(s)[1], `BEAT SAM 0:21.0 = {Profile.WIN_COINS * 2} COINS`)
	-- my own record there: nothing to beat
	s = Visit.sign(d, 1, 4, 2, "race", { value = 19, name = "Me", userId = 1 }, DAY, 1)
	eq(s.beat, nil)
	eq(#Visit.lines(s), 0)
	-- the drift side counts on its own
	eq(Visit.sign(d, 1, 4, 2, "drift", nil, DAY, 1).stars, 3)
	eq(
		Visit.lines(
			Visit.sign(d, 1, 4, 2, "drift", { value = 1500, name = "Sam", userId = 2 }, DAY, 1)
		)[1],
		"⭐ 3 HERE"
	)
end)

test("visit sign: my own plot says no stars, a nobody's plot says nothing", function()
	local d = Profile.new()
	local own = Visit.sign(d, 1, 3, 1, "race", SAM, DAY, 1)
	eq(own.own, true)
	eq(own.stars, 0)
	eq(own.gift, 0)
	eq(Visit.lines(own)[1], "NO ⭐ HERE")
	local nobody = Visit.sign(d, 1, 5, nil, "race", SAM, DAY, 1)
	eq(#Visit.lines(nobody), 0)
end)

test("visit: StarsAt lists the plots with stars, nearest first", function()
	local d = Profile.new()
	Profile.award(d, 1, 6, "race", 3) -- owner 6: all won
	local signs = {
		Visit.sign(d, 1, 1, 1, "race", nil, DAY, 1), -- mine
		Visit.sign(d, 1, 2, 5, "race", nil, DAY, 1),
		Visit.sign(d, 1, 3, 6, "race", nil, DAY, 1), -- none left
		Visit.sign(d, 1, 4, 7, "drift", nil, DAY, 1),
		Visit.sign(d, 1, 5, nil, "race", nil, DAY, 1), -- nobody's
	}
	eq(Visit.starsAt(signs, { [2] = 50, [4] = 10 }), "4,2")
	eq(Visit.starsAt(signs, {}), "2,4")
	eq(Visit.starsAt({}, {}), "")
end)
