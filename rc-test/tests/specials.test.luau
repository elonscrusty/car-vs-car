--!nocheck
-- One car, one special (shared/Specials): which special a car owns and how its button looks.

local H = require("./harness")
local Specials = require("../src/shared/Specials")
local FireSwarm = require("../src/shared/FireSwarm")
local Shockwave = require("../src/shared/Shockwave")

local test, eq, truthy = H.test, H.eq, H.truthy

test("the Ice Viper owns Shockwave", function()
	eq(Specials.forCar("ice_viper"), Shockwave.NAME)
end)

test("any other car (or a bad value) gets the default special", function()
	eq(Specials.forCar("race_bolt"), Specials.DEFAULT)
	eq(Specials.forCar(nil), Specials.DEFAULT)
	eq(Specials.forCar(42), Specials.DEFAULT)
	eq(Specials.DEFAULT, FireSwarm.NAME)
end)

test("every special has a look, and a bad name falls back to the default look", function()
	for name, look in Specials.LOOKS do
		truthy(#look.word > 0, name .. " word")
		eq(#look.on, 3)
		eq(#look.full, 3)
	end
	eq(Specials.look("nope").word, Specials.LOOKS[Specials.DEFAULT].word)
	eq(Specials.look(nil).word, Specials.LOOKS[Specials.DEFAULT].word)
end)

test("both specials refill in the same time, so one meter fits both", function()
	eq(Shockwave.REFILL, FireSwarm.REFILL)
end)
