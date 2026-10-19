--!strict
local Harness = require("./harness")
local GarageLikes = require("../src/shared/GarageLikes")
local Inventory = require("../src/shared/Inventory")

local test, truthy, eq = Harness.test, Harness.truthy, Harness.eq

print("GarageLikes")

test("a like counts once and is remembered", function()
	local giver, owner = GarageLikes.default(), GarageLikes.default()
	local ok = GarageLikes.like(giver, owner, 1, 2)
	truthy(ok)
	eq(owner.received, 1)
	local ok2, why = GarageLikes.like(giver, owner, 1, 2)
	truthy(not ok2)
	eq(why, "already")
	eq(owner.received, 1)
end)

test("you cannot like your own garage", function()
	local d = GarageLikes.default()
	local ok, why = GarageLikes.like(d, d, 5, 5)
	truthy(not ok)
	eq(why, "self")
	eq(d.received, 0)
end)

test("bad owner ids are refused", function()
	local giver, owner = GarageLikes.default(), GarageLikes.default()
	local ok, why = GarageLikes.like(giver, owner, 1, -3)
	truthy(not ok)
	eq(why, "unknown")
	local ok2 = GarageLikes.like(giver, owner, 1, 0 / 0)
	truthy(not ok2)
end)

test("the give list has a cap", function()
	local giver, owner = GarageLikes.default(), GarageLikes.default()
	for id = 2, GarageLikes.MaxGiven + 1 do
		truthy(GarageLikes.like(giver, owner, 1, id))
	end
	local ok, why = GarageLikes.like(giver, owner, 1, 99999)
	truthy(not ok)
	eq(why, "full")
end)

test("clean fixes junk and never errors", function()
	eq(GarageLikes.clean(nil).received, 0)
	eq(GarageLikes.clean("x").received, 0)
	local d = GarageLikes.clean({
		received = -5,
		given = { ["12"] = true, abc = true, ["13"] = "yes", [7] = true },
	})
	eq(d.received, 0)
	truthy(d.given["12"])
	truthy(d.given["abc"] == nil)
	truthy(d.given["13"] == nil)
	eq(GarageLikes.clean({ received = 3.9 }).received, 3)
	eq(GarageLikes.clean({ received = 0 / 0 }).received, 0)
end)

test("clean trims an over-long give list", function()
	local given: { [string]: boolean } = {}
	for i = 1, GarageLikes.MaxGiven + 50 do
		given[tostring(i)] = true
	end
	local n = 0
	for _ in GarageLikes.clean({ given = given }).given do
		n += 1
	end
	eq(n, GarageLikes.MaxGiven)
end)

test("sign text", function()
	eq(GarageLikes.label(0), "0 LIKES")
	eq(GarageLikes.label(1), "1 LIKE")
	eq(GarageLikes.label(12), "12 LIKES")
	eq(GarageLikes.label(1250), "1.2K LIKES")
	eq(GarageLikes.label(-4), "0 LIKES")
end)

test("profiles keep likes through default and migrate", function()
	local p = Inventory.default()
	eq(p.garage.received, 0)
	p.garage.received = 4
	p.garage.given["9"] = true
	local back = Inventory.migrate(p)
	eq(back.garage.received, 4)
	truthy(back.garage.given["9"])
	eq(Inventory.migrate({}).garage.received, 0) -- old saves have no garage data
end)
