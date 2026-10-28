--!strict
-- CvcGoal: the Car VS Car guide arrow points at one thing at a time.
local H = require("./harness")
local CvcGoal = require("../src/shared/CvcGoal")
local Crates = require("../src/shared/Crates")
local Profile = require("../src/shared/Profile")

local test, eq = H.test, H.eq

print("CvcGoal")

local function state(over: { [string]: any }): any
	local s: any =
		{ picked = true, stage = Profile.STAGE.RACED, crates = 0, coins = 0, shopSeen = false }
	for k, v in over do
		s[k] = v
	end
	return s
end

local function target(over: { [string]: any }): string?
	local g = CvcGoal.pick(state(over))
	return if g then g.target else nil
end

test("no arrow before you pick a car", function()
	eq(target({ picked = false, stage = Profile.STAGE.NEW, crates = 1, coins = 9999 }), nil)
end)

test("never raced: join the race first", function()
	eq(target({ stage = Profile.STAGE.NEW }), "join")
	eq(target({ stage = Profile.STAGE.LAPPED, crates = 1 }), "join")
	local unsaved = state({})
	unsaved.stage = nil -- the save is still loading
	local g = CvcGoal.pick(unsaved)
	eq(g and g.target, "join")
end)

test("a crate to open beats the shop", function()
	eq(target({ crates = 1, coins = 9999 }), "crate")
end)

test("coins for the cheapest crate: to the crate shop, till you get there", function()
	local cheap = CvcGoal.cheapest()
	eq(cheap, Crates.price("basic"))
	eq(target({ coins = cheap - 1 }), nil)
	eq(target({ coins = cheap }), "crateshop")
	eq(target({ coins = cheap, shopSeen = true }), nil)
end)
