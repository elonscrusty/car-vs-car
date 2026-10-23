--!strict
-- The plot looks shop (PlotShop.luau): buying spends coins once, stars give the themes free,
-- looks turn on and off, and every shop item is a look PlotLooks can build.
local H = require("./harness")
local S = require("../src/shared/PlotShop")
local L = require("../src/shared/PlotLooks")
local Profile = require("../src/shared/Profile")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Plot shop")

local function wallet(coins: number, stars: number): any
	return { coins = coins, stars = stars, looks = {}, lookOff = {} }
end

test("every item is a look, with a price; themes match the star tiers", function()
	for _, it in S.ITEMS do
		truthy(table.find(L.IDS, it.id) ~= nil, it.id)
		truthy(it.price > 0, it.id)
	end
	for i, id in L.STAR_LOOKS do
		eq((S.item(id) :: any).stars, L.TIERS[i])
	end
end)

test("buy: spends the coins once, never below zero", function()
	local w = wallet(250, 0)
	eq(S.buy(w, "balloons"), true)
	eq(w.coins, 150)
	local ok, why = S.buy(w, "balloons")
	eq(ok, false)
	eq(why, "have")
	ok, why = S.buy(w, "snow")
	eq(why, "coins")
	eq(w.coins, 150)
	ok, why = S.buy(w, "rocket")
	eq(why, "unknown")
	eq(S.encode(S.shown(w)), "balloons")
end)

test("stars give the themes free (and they can't be bought again)", function()
	local w = wallet(1000, 25)
	eq(S.encode(S.shown(w)), "night,snow")
	local _, why = S.buy(w, "night")
	eq(why, "have")
	eq(w.coins, 1000)
	eq(S.buy(w, "party"), true)
	eq(S.encode(S.shown(w)), "night,snow,party")
end)

test("toggle: off and on again, only looks you have", function()
	local w = wallet(0, 10)
	eq(S.toggle(w, "night"), false)
	eq(S.encode(S.shown(w)), "")
	eq(S.toggle(w, "night"), true)
	eq(S.encode(S.shown(w)), "night")
	eq(S.toggle(w, "confetti"), nil)
end)

test("decode drops junk; the save keeps looks across a reload", function()
	eq(table.concat(S.decode("night,,rocket,neon"), ","), "night,neon")
	eq(#S.decode(nil), 0)
	local d = Profile.new()
	d.coins = 500
	S.buy(d, "neon")
	S.toggle(d, "neon")
	local back = Profile.migrate(d)
	eq(back.looks.neon, true)
	eq(back.lookOff.neon, true)
	eq(back.coins, 300)
	eq(Profile.migrate({ looks = { neon = "yes", [1] = true } }).looks.neon, nil)
end)
