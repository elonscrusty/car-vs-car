--!strict
-- The crate opening show's plan: your car's card is where the reel stops, the reel only shows
-- kinds the crate can give, near misses sit next to yours, and the show grows with the rarity.
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local Crates = require("../src/shared/Crates")
local CrateReel = require("../src/shared/CrateReel")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Crate reel")

local KINDS = { "free", "basic", "big", "mega" }

test("your car is on the winning card, for every crate and every kind of car", function()
	for _, kind in KINDS do
		local odds = Crates.odds(kind)
		for i, r in CarCatalog.RARITY_ORDER do
			if (odds[r] or 0) > 0 then
				for seed = 1, 5 do
					local p = CrateReel.plan(r, kind, seed)
					eq(p.cards[p.win], i, `{kind} {r} seed {seed}`)
					eq(p.rarity, i)
					eq(#p.cards, CrateReel.CARDS)
				end
			end
		end
	end
end)

test("the reel never shows a kind of car the crate can't give", function()
	for _, kind in KINDS do
		local odds = Crates.odds(kind)
		for i, r in CarCatalog.RARITY_ORDER do
			if (odds[r] or 0) > 0 then
				for seed = 1, 20 do
					for n, c in CrateReel.plan(r, kind, seed).cards do
						truthy(
							(odds[CarCatalog.RARITY_ORDER[c]] or 0) > 0,
							`{kind} card {n} is a {c}`
						)
					end
				end
			end
		end
	end
end)

test("the same seed gives the same strip; no seed still gives a full strip", function()
	local a = CrateReel.plan("epic", "big", 7)
	local b = CrateReel.plan("epic", "big", 7)
	for i = 1, #a.cards do
		eq(a.cards[i], b.cards[i])
	end
	eq(#CrateReel.plan("rare", "basic").cards, CrateReel.CARDS)
end)

test(
	"near misses: a step up sits next to a rare+ car, epic and up stop a card early then creep",
	function()
		for seed = 1, 10 do
			local p = CrateReel.plan("rare", "basic", seed)
			truthy(
				p.cards[p.win + 1] >= 3 or Crates.odds("basic").epic == 0,
				"a better car next door"
			)
			eq(p.stop, p.win)
			eq(p.creep, false)
			local e = CrateReel.plan("epic", "mega", seed)
			eq(e.stop, e.win - 1)
			eq(e.creep, true)
			truthy(e.cards[e.win - 1] <= 2, "the card before an epic is a lower one")
		end
	end
)

test("the show grows with the rarity", function()
	local last = CrateReel.plan("common", "free", 1)
	eq(last.word, "NICE!")
	eq(last.bolts, 0)
	eq(last.coins, 0)
	for _, r in { "rare", "epic", "legend" } do
		local p = CrateReel.plan(r, "mega", 1)
		truthy(p.spin > last.spin, `{r} spins longer`)
		truthy(p.shake > last.shake, `{r} shakes harder`)
		truthy(
			p.bolts >= last.bolts and p.rings >= last.rings and p.coins >= last.coins,
			`{r} bigger boom`
		)
		last = p
	end
	eq(last.word, "LEGENDARY!!!")
	eq(last.big, true)
	eq(last.coins, 44)
	eq(CrateReel.plan("legendary", "mega", 1).rarity, 4, "legendary = legend")
end)
