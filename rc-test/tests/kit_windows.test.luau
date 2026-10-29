--!strict
-- carter's kit v41 windows (WINDOWS): the shop sells only the crates you can buy, at Crates'
-- prices, each crate's odds add up to 100 and show before OPEN, and the layouts keep to the canvas.
local H = require("./harness")
local Crates = require("../src/shared/Crates")
local Profile = require("../src/shared/Profile")
local Lb = require("../src/shared/Leaderboards")
local GameSettings = require("../src/shared/GameSettings")
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
	for _, id in
		{
			"kitShop",
			"kitOdds",
			"kitReveal",
			"kitDaily",
			"kitQuests",
			"kitBoard",
			"kitLeagueUp",
			"kitGarage",
			"kitSettings",
		}
	do
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

test("global board: what the server sends is checked and cut", function()
	local rows = {
		{ uid = 1, name = "Pepper", score = 12450.7 },
		{ uid = -3, name = "bad id", score = 5 },
		{ uid = 2.5, name = "half id", score = 5 },
		{ uid = 3, name = string.rep("é", 30), score = 9 },
		{ uid = 4, name = "\255\254", score = 0 / 0 },
		{ uid = 5, name = 42, score = -10 },
		"junk",
		{ uid = 6, name = "Six", score = 1e12 },
		{ uid = 7, name = "Seven", score = 1 },
		{ uid = 8, name = "Eight", score = 1 },
	}
	local out = Lb.wire(rows)
	eq(#out, Lb.SHOWN)
	eq(out[1].userId, 1)
	eq(out[1].score, 12450)
	eq(out[2].userId, 3)
	eq(utf8.len(out[2].name), Lb.MAX_NAME)
	eq(out[3].userId, 5)
	eq(out[3].name, "PLAYER")
	eq(out[3].score, 0)
	eq(out[4].score, Lb.MAX_TROPHIES)
	eq(#Lb.wire(nil), 0)
	eq(#Lb.wire("x"), 0)
end)

test("global board: one ask each ASK_GAP s, answered from the server's last read", function()
	truthy(Lb.mayAsk(nil, 0), "a first ask is refused")
	truthy(not Lb.mayAsk(10, 10 + Lb.ASK_GAP - 0.1), "a fast ask goes through")
	truthy(Lb.mayAsk(10, 10 + Lb.ASK_GAP), "a later ask is refused")
	local src = fs.readFile("src/server/Leaderboards.luau")
	local at = src:find("OnServerInvoke", 1, true)
	truthy(at ~= nil, "no TopTrophies handler")
	local body = src:sub(at :: number, (src:find("\n\t\tend\n", at, true) or #src) :: number)
	truthy(body:find("Lb.mayAsk", 1, true) ~= nil, "the ask isn't rate-limited")
	truthy(body:find("Lb.wire", 1, true) ~= nil, "the answer isn't checked")
	truthy(body:find("Async", 1, true) == nil, "an ask calls the store")
end)

test("friends tab: most trophies first, you first on a tie, cut to 5", function()
	local list = {
		{ userId = 1, name = "Zed", score = 5 },
		{ userId = 2, name = "Me", score = 5, me = true },
		{ userId = 3, name = "Amy", score = 9 },
		{ userId = 4, name = "Bo", score = 5 },
		{ userId = 5, name = "Cy", score = 1 },
		{ userId = 6, name = "Di", score = 0 },
	}
	local out = SmashScreens.friendRows(list, 5)
	eq(#out, 5)
	eq(out[1].name, "Amy")
	eq(out[2].name, "Me")
	eq(out[3].name, "Bo")
	eq(out[4].name, "Zed")
	eq(#list, 6) -- (the list given is left as it was)
end)

test("league up under Smash: the kit screen, and matches (not races) pay", function()
	local src = fs.readFile("src/client/LeagueUp.luau")
	truthy(src:find("KitWindows.leagueUp", 1, true) ~= nil, "no kit league up")
	truthy(src:find('"^Races", "Matches"', 1, true) ~= nil, "Smash league up says races")
end)

test("garage: 4 cards a row with rarity dots, karts are looks (no stat bars)", function()
	eq(SmashScreens.rarityDots("common"), 1)
	eq(SmashScreens.rarityDots("legend"), 4)
	eq(SmashScreens.rarityDots("legendary"), 4)
	eq(SmashScreens.rarityDots(nil), 1)
	local grid = SmashScreens.piece("kitGarage", "Grid")
	local boxes = SmashScreens.garageCards(9, grid.w - 32)
	eq(boxes[5].y, boxes[1].y + boxes[1].h + 10)
	eq(boxes[5].x, 0)
	for i = 1, 8 do
		local b = boxes[i]
		truthy(b.x + b.w <= grid.w - 32 + 1e-6, `card {i} runs out`)
		truthy(b.y + b.h <= grid.h - 24, `card {i} of the first 8 needs a scroll`)
		truthy(b.w >= 44 and b.h >= 44, `card {i} too small`)
	end
	local src = fs.readFile("src/client/Ui/Screens/KitWindows.luau")
	for _, bad in { "statBar", "CardStats", "stats" } do
		truthy(not src:find(bad, 1, true), "the kit windows show " .. bad)
	end
	local glue = fs.readFile("src/client/SmashCustomize.client.luau")
	truthy(glue:find("KitWindows.garage(", 1, true) ~= nil, "CUSTOMIZE isn't the kit garage")
end)

test("settings: anything sent is cleaned, defaults on junk, one save each 2 s", function()
	local d = GameSettings.clean(nil)
	eq(d.music, 1)
	eq(d.names, true)
	local s =
		GameSettings.clean({ music = 0.333, sfx = -4, shadows = "no", names = false, evil = 1 })
	eq(s.music, 0.35)
	eq(s.sfx, 0)
	eq(s.shadows, true)
	eq(s.names, false)
	eq((s :: any).evil, nil)
	eq(GameSettings.clean({ music = 0 / 0 }).music, 1)
	eq(GameSettings.clean({ music = math.huge }).music, 1)
	truthy(GameSettings.same(d, GameSettings.clean({})), "defaults differ")
	local src = fs.readFile("src/server/SettingsServer.luau")
	truthy(src:find("GameSettings.clean(sent)", 1, true) ~= nil, "a sent table isn't cleaned")
	truthy(src:find("MIN_GAP", 1, true) ~= nil, "asks aren't rate-limited")
	truthy(src:find("canSave[player]", 1, true) ~= nil, "a failed load can write defaults")
	local main = fs.readFile("src/server/Main.server.luau")
	truthy(main:find("SettingsServer", 1, true) ~= nil, "SettingsServer never starts")
end)

test("Studio r56: every kit window covers the lobby HUD with the kit ground", function()
	local src = fs.readFile("src/client/Ui/Screens/KitWindows.luau")
	truthy(src:find('"window", false', 1, true) == nil, "a kit window has no ground behind it")
	local _, n = src:gsub("ground%(g%.back%)", "")
	truthy(n >= 7, `only {n} windows draw the ground`)
end)
