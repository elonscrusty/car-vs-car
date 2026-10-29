--!strict
-- carter's kit v41 windows (WINDOWS): the shop sells only the crates you can buy, at Crates'
-- prices, each crate's odds add up to 100 and show before OPEN, and the layouts keep to the canvas.
local H = require("./harness")
local Crates = require("../src/shared/Crates")
local Profile = require("../src/shared/Profile")
local SmashScreens = require("../src/shared/SmashScreens")
local UiScreens = require("../src/shared/UiScreens")
local fs = require("@lune/fs")

local test, eq, truthy = H.test, H.eq, H.truthy

print("KitWindows")

test("shop: only real crates, a free one only while you have one", function()
	local none = SmashScreens.crateTiles(0)
	eq(#none, #Crates.SHOP)
	for i, t in none do
		eq(t.kind, Crates.SHOP[i])
		local price = Crates.price(t.kind)
		truthy(price ~= nil and price > 0, t.kind .. " has no coin price")
		eq(t.word, string.upper(t.word))
	end
	local some = SmashScreens.crateTiles(2)
	eq(#some, #Crates.SHOP + 1)
	eq(some[1].kind, "free")
	truthy(Crates.get("free") ~= nil, "no free crate kind")
end)

test("odds: every crate's rows add up to 100, rarest last, no 0% rows", function()
	for _, t in SmashScreens.CRATE_TILES do
		local rows = SmashScreens.oddsRows(Crates.odds(t.kind))
		local sum = 0
		for _, r in rows do
			truthy(r.chance > 0, t.kind .. " shows a 0% row")
			sum += r.chance
		end
		truthy(math.abs(sum - 100) < 1e-6, `{t.kind} odds add to {sum}`)
	end
	local mega = SmashScreens.oddsRows(Crates.odds("mega"))
	eq(mega[1].rarity, "rare")
	eq(mega[#mega].rarity, "legendary")
end)

test("shop tiles fit the panel, side by side, big enough to tap", function()
	local panel = SmashScreens.piece("kitShop", "Panel")
	for n = 1, 4 do
		local boxes = SmashScreens.shopTiles(n, panel.w)
		eq(#boxes, n)
		for i, b in boxes do
			truthy(b.x >= 0 and b.x + b.w <= panel.w, `tile {i}/{n} runs out`)
			truthy(b.y + b.h <= panel.h - 54, `tile {i}/{n} covers the note`)
			truthy(b.w >= 44 and b.h >= 44, `tile {i}/{n} too small`)
			if i > 1 then
				truthy(b.x >= boxes[i - 1].x + boxes[i - 1].w, `tile {i}/{n} covers the one before`)
			end
		end
	end
end)

test("kit layouts: nothing covers anything else", function()
	for _, id in { "kitShop", "kitOdds", "kitReveal", "kitDaily", "kitQuests" } do
		local ps = SmashScreens.get(id).pieces
		for i = 1, #ps do
			for j = i + 1, #ps do
				truthy(not UiScreens.overlap(ps[i], ps[j]), `{id}.{ps[i].name} covers {ps[j].name}`)
			end
		end
	end
end)

test("the looks-only lines stay, and the shop has no SOON or Robux", function()
	truthy(
		SmashScreens.KIT_WORDS.oddsNote:find("skins only", 1, true) ~= nil,
		"skins only line gone"
	)
	truthy(SmashScreens.KIT_WORDS.shopNote:find("look only", 1, true) ~= nil, "look only line gone")
	local src = fs.readFile("src/client/Ui/Screens/KitWindows.luau")
	for _, bad in { "SOON", "Robux", "R%$", 'COINS"', "BOOSTS" } do
		truthy(not src:find(bad), "KitWindows says " .. bad)
	end
	-- the odds window is the only way to OPEN a crate from the shop
	local cvc = fs.readFile("src/client/CvcScreens.client.luau")
	truthy(cvc:find("pick = openKitOdds", 1, true) ~= nil, "a shop tile doesn't open the odds")
end)

test("daily: the 7 real days, today's coins as paid, a crate only when one came", function()
	local days = SmashScreens.dailyDays(Profile.DAILY, 3, 40, false)
	eq(#days, #Profile.DAILY)
	eq(days[1].state, "got")
	eq(days[3].state, "today")
	eq(days[3].coins, 40) -- (a 2X boost day: what the server paid)
	eq(days[4].state, "later")
	eq(days[7].coins, Profile.DAILY[7])
	for _, d in days do
		eq(d.crate, false)
	end
	eq(SmashScreens.dailyDays(Profile.DAILY, 1, nil, true)[1].crate, true)
	eq(SmashScreens.dailyDays(Profile.DAILY, 99, nil, false)[7].state, "today")
	local stars = fs.readFile("src/client/Stars.client.luau")
	truthy(stars:find("SmashScreens.dailyDays(DAILY", 1, true) ~= nil, "Smash daily not from DAILY")
end)

test("jobs: each Smash job line gets its icon", function()
	eq(SmashScreens.jobIcon("Smash 10 karts"), "nuke")
	eq(SmashScreens.jobIcon("Open a crate"), "crate")
	eq(SmashScreens.jobIcon("Play 3 matches"), "trophy")
	eq(SmashScreens.jobIcon("Get top 3 in a match"), "trophy")
	eq(SmashScreens.jobIcon("Something new"), "coin")
end)
