--!strict
-- The Lucky Spin and kart hats (Smash plan, REWARDS row): odds, one free spin a day, fair rolls,
-- hats saved, the low-poly look rules.
local H = require("./harness")
local LuckySpin = require("../src/shared/LuckySpin")
local Hats = require("../src/shared/Hats")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lucky spin")

local DAY = 86400
local NOW = 20000 * DAY + 3600 -- 1 am on some day

test("spin: the odds add up to 100 and every prize can come up", function()
	local sum = 0
	for _, p in LuckySpin.PRIZES do
		truthy(p.chance > 0, p.label)
		truthy(p.label ~= "" and #p.label <= 16, p.label)
		truthy(p.kind == "coins" or p.kind == "hat")
		if p.kind == "hat" then
			truthy(Hats.get(p.hat), p.label)
		else
			truthy((p.coins or 0) > 0)
		end
		sum += p.chance
	end
	H.near(sum, 100, 1e-9)
	local seen: { [number]: number } = {}
	for k = 0, 9999 do
		local i = LuckySpin.pick((k + 0.5) / 10000)
		seen[i] = (seen[i] or 0) + 1
	end
	for i, p in LuckySpin.PRIZES do
		-- a fair roll lands each prize at its shown chance (to 0.1%)
		H.near((seen[i] or 0) / 100, p.chance, 0.1, p.label)
	end
end)

test("spin: junk rolls land on a real prize", function()
	local junk: { any } = { -1, 2, 0 / 0, math.huge, "x", nil }
	for _, r in junk do
		local i = LuckySpin.pick(r)
		truthy(i >= 1 and i <= #LuckySpin.PRIZES)
	end
end)

test("spin: one free spin a day, back at midnight", function()
	local d = Profile.new()
	eq(LuckySpin.wait(d, NOW), 0)
	local won = LuckySpin.spin(d, NOW, 0) -- the first prize: 50 coins
	truthy(won)
	eq((won :: any).coins, 50)
	eq(d.coins, 50)
	eq(LuckySpin.spin(d, NOW + 60, 0.5), nil)
	eq(d.coins, 50)
	eq(LuckySpin.wait(d, NOW), DAY - 3600)
	eq(LuckySpin.wait(d, 20001 * DAY), 0)
	truthy(LuckySpin.spin(d, 20001 * DAY + 5, 0))
end)

test("spin: a new hat is saved; a hat you have pays coins", function()
	local d = Profile.new()
	local hatRoll: number? = nil
	local sum = 0
	for _, p in LuckySpin.PRIZES do
		if p.hat == "crown" then
			hatRoll = (sum + p.chance / 2) / 100
		end
		sum += p.chance
	end
	local won = LuckySpin.spin(d, NOW, hatRoll :: number) :: any
	eq(won.hat, "crown")
	eq(won.coins, 0)
	eq(d.hats.crown, true)
	won = LuckySpin.spin(d, NOW + DAY, hatRoll :: number) :: any
	eq(won.hat, nil)
	eq(won.coins, LuckySpin.DUPE_COINS)
	eq(d.coins, LuckySpin.DUPE_COINS)
end)

test("spin: no Robux, no paid spins", function()
	for _, p in LuckySpin.PRIZES do
		eq((p :: any).robux, nil)
	end
	eq((LuckySpin :: any).buy, nil)
end)

test("hats: low-poly look (few parts, SmoothPlastic/Neon shapes, palette, no text)", function()
	local ids: { [string]: boolean } = {}
	local shapes = { Block = true, Ball = true, Cylinder = true, Wedge = true }
	for _, h in Hats.LIST do
		truthy(not ids[h.id], "dupe " .. h.id)
		ids[h.id] = true
		truthy(#h.bits >= 1 and #h.bits <= Hats.MAX_BITS, h.id)
		truthy(
			h.rarity == "common"
				or h.rarity == "rare"
				or h.rarity == "epic"
				or h.rarity == "legendary"
		)
		for _, b in h.bits do
			truthy(shapes[b.shape], h.id .. " " .. b.shape)
			eq(#b.size, 3)
			eq(#b.at, 3)
			eq(#b.rgb, 3)
			for k in b :: any do
				truthy(k ~= "text" and k ~= "decal" and k ~= "texture", h.id .. " has " .. k)
			end
			-- small enough to sit on a kart (body 3 studs wide)
			truthy(b.size[1] <= 3 and b.size[2] <= 3 and b.size[3] <= 3, h.id)
		end
	end
	-- every hat can be won
	for _, h in Hats.LIST do
		local found = false
		for _, p in LuckySpin.PRIZES do
			found = found or p.hat == h.id
		end
		truthy(found, h.id .. " is on the wheel")
	end
end)

test(
	"spin saves: old saves load clean, junk hats dropped, a late visit keeps its spin and hats",
	function()
		local d = Profile.new()
		eq(d.spinDay, 0)
		eq(d.hat, "")
		eq(next(d.hats), nil)
		local raw = Profile.new() :: any
		raw.spinDay, raw.hats, raw.hat = nil, nil, nil
		local m = Profile.migrate(raw)
		eq(m.spinDay, 0)
		eq(m.hat, "")
		raw = Profile.new() :: any
		raw.spinDay = 20000.7
		raw.hats = { crown = true, fake = true, cone = "yes" }
		raw.hat = "fake"
		m = Profile.migrate(raw)
		eq(m.spinDay, 20000)
		eq(m.hats.crown, true)
		eq(m.hats.fake, nil)
		eq(m.hats.cone, nil)
		eq(m.hat, "")
		raw.hat = "crown"
		eq(Profile.migrate(raw).hat, "crown")
		local stored = Profile.new()
		stored.hats.cone = true
		stored.hat = "cone"
		local base = Profile.new()
		local session = Profile.new()
		session.spinDay = 20001
		session.hats.star = true
		local out = Profile.mergeVisit(stored, session, base)
		eq(out.spinDay, 20001)
		eq(out.hats.cone, true)
		eq(out.hats.star, true)
		eq(out.hat, "cone") -- the visit didn't change hats: keep the saved one
	end
)

test(
	"spin: a day from a clock that runs ahead counts as used; a junk far day is cut back",
	function()
		local d = Profile.new()
		d.spinDay = LuckySpin.day(NOW) + 1
		eq(LuckySpin.spin(d, NOW, 0), nil)
		truthy(LuckySpin.wait(d, NOW) > 0)
		local raw = Profile.new() :: any
		raw.spinDay = 1e9
		eq(Profile.migrate(raw).spinDay, Profile.day(os.time()) + 1)
	end
)
