--!strict
-- Crates: odds always add up, a roll always gives a car of the right kind.

local H = require("./harness")
local Cat = require("../src/shared/CarCatalog")
local Crates = require("../src/shared/Crates")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Crates")

-- a fake Random that hands out the numbers given, in turn
local function rng(...: number)
	local list = { ... }
	local i = 0
	return {
		NextNumber = function(_self: any): number
			i += 1
			return list[(i - 1) % #list + 1]
		end,
	}
end

test("every crate's odds add up to 100, cover every kind, and the free one isn't sold", function()
	for _, k in Crates.KINDS do
		local sum = 0
		local odds = Crates.odds(k.id)
		for _, r in Cat.RARITY_ORDER do
			truthy(type(odds[r]) == "number", k.id .. " has odds for " .. r)
			sum += odds[r]
		end
		truthy(math.abs(sum - 100) < 1e-9, k.id .. " odds add to 100")
		eq(k.robux, nil)
	end
	eq(Crates.price("free"), nil)
	eq(Crates.price("nope"), nil)
	for _, id in Crates.SHOP do
		truthy((Crates.price(id) or 0) > 0, id .. " has a coin price")
	end
end)

test("a pricier crate gives better odds", function()
	local last = -1
	for _, id in Crates.SHOP do
		local o = Crates.odds(id)
		local good = o.epic + o.legend
		truthy(good > last, id .. " beats the crate before it")
		last = good
	end
end)

test("the pool has every catalog car once, sorted, by its kind", function()
	local pool = Crates.pool()
	local seen = {}
	local Stats = require("../src/shared/CarStats")
	for tier, list in pool do
		for i, id in list do
			truthy(not seen[id], id .. " once")
			seen[id] = true
			eq(Cat.rarity(id).id, tier)
			if i > 1 then
				truthy(list[i - 1] < id, "sorted")
			end
		end
	end
	truthy(#pool.common > 0 and #pool.legend > 0, "commons and legends to give")
	-- never a low starter: a crate car always starts above the car a new kid picked
	for _, id in Stats.STARTERS do
		truthy(not seen[id], id .. " is a starter, not a crate car")
	end
	for _, id in Stats.ids() do
		truthy(seen[id] or table.find(Stats.STARTERS, id) ~= nil, id .. " is in a crate")
	end
	local low = Stats.total({ uid = "u", id = pool.common[1], speed = 0, turn = 0, boost = 0 })
	for _, id in Stats.STARTERS do
		truthy(low > Stats.total({ uid = "u", id = id, speed = 0, turn = 0, boost = 0 }))
	end
end)

test("a roll lands on the kind its odds say, and picks evenly within it", function()
	local pool = Crates.pool()
	-- basic: common below 70, rare 70..95, epic 95..99.5, legend above
	local id, tier = Crates.roll("basic", rng(0.1, 0), pool)
	eq(tier, "common")
	eq(id, pool.common[1])
	id, tier = Crates.roll("basic", rng(0.8, 0.999), pool)
	eq(tier, "rare")
	eq(id, pool.rare[#pool.rare])
	_, tier = Crates.roll("basic", rng(0.97, 0.5), pool)
	eq(tier, "epic")
	_, tier = Crates.roll("basic", rng(0.999, 0.5), pool)
	eq(tier, "legend")
	-- mega never gives a common, even at the very bottom
	_, tier = Crates.roll("mega", rng(0, 0), pool)
	eq(tier, "rare")
	-- the free crate never gives a legend, even at the very top
	_, tier = Crates.roll("free", rng(0.99999, 0), pool)
	eq(tier, "epic")
end)

test("an empty kind falls back to the kind below; unknown crates give nothing", function()
	local pool = { common = { "race_bolt" }, rare = {}, epic = {}, legend = {} }
	local id, tier = Crates.roll("mega", rng(0.99, 0.5), pool)
	eq(id, "race_bolt")
	eq(tier, "common")
	eq(Crates.roll("nope", rng(0.5), pool), nil)
	eq(Crates.roll("basic", rng(0.5), { common = {}, rare = {}, epic = {}, legend = {} }), nil)
end)

test("many real rolls stay close to the odds shown", function()
	-- a small seeded stand-in for Random (Lune has none)
	local seed = 7
	local r = {
		NextNumber = function(_self: any): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
	local counts = { common = 0, rare = 0, epic = 0, legend = 0 }
	local n = 20000
	for _ = 1, n do
		local id, tier = Crates.roll("big", r)
		truthy(id ~= nil and Cat.get(id) ~= nil, "a real car")
		counts[tier :: string] += 1
	end
	local odds = Crates.odds("big")
	for tier, c in counts do
		truthy(math.abs(c / n * 100 - odds[tier]) < 1.5, tier .. " near its odds")
	end
end)
