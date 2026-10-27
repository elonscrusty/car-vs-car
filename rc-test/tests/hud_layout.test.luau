--!strict
-- The screen map: no two buttons or chips cover each other, on phones and on PC.
local fs = require("@lune/fs")
local H = require("./harness")
local HudLayout = require("../src/shared/HudLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("HudLayout")

-- small phone, big phone, wide Studio window, PC
local SCREENS = {
	{ 667, 375 },
	{ 1024, 768 },
	{ 1180, 820 },
	{ 844, 390 },
	{ 932, 430 },
	{ 1914, 753 },
	{ 1366, 768 },
	{ 1920, 1080 },
}

test("nothing covers anything else, in walk or drive", function()
	for _, s in SCREENS do
		local hits = HudLayout.overlaps(s[1], s[2])
		eq(#hits, 0, `{s[1]}x{s[2]}: {table.concat(hits, ", ")}`)
	end
end)

test("everything stays on the screen", function()
	for _, s in SCREENS do
		for _, spot in HudLayout.SPOTS do
			local l, t, r, b = HudLayout.box(spot, s[1], s[2])
			truthy(
				l >= 0 and t >= 0 and r <= s[1] and b <= s[2],
				`{spot.name} off a {s[1]}x{s[2]} screen`
			)
		end
	end
end)

test("top rows start under the Roblox top bar", function()
	for _, s in SCREENS do
		for _, spot in HudLayout.SPOTS do
			local _, t = HudLayout.box(spot, s[1], s[2])
			truthy(t >= 58, `{spot.name} under the top bar`)
		end
	end
end)

test("the overlap check finds a real overlap", function()
	local coins = HudLayout.find("CoinCount", "walk") :: any -- always shown
	table.insert(HudLayout.SPOTS, {
		name = "Test",
		mode = "walk",
		owner = "test",
		ax = 0,
		ay = 0,
		x = coins.x,
		xo = 0,
		y = 0,
		yo = 70,
		w = 0,
		wo = 50,
		h = 0,
		ho = 20,
	})
	local hits = HudLayout.overlaps(844, 390)
	table.remove(HudLayout.SPOTS)
	eq(#hits, 1)
	eq(hits[1], "walk: CoinCount / Test")
end)

test("popups draw over the HUD", function()
	truthy(HudLayout.POPUP > HudLayout.HUD)
	truthy(HudLayout.find("Join", "walk") ~= nil and HudLayout.find("Join", "drive") ~= nil)
end)

test("FINISH IN / RESULTS IN sits clear of AUTO GAS and the timer, on every screen", function()
	-- (it was half the screen wide at the top and sat on AUTO GAS, Studio final-44)
	local hurry = HudLayout.find("Hurry", "drive") :: HudLayout.Spot
	truthy(hurry ~= nil, "Hurry has a spot")
	local sizes = table.clone(SCREENS)
	table.insert(sizes, { 1914, 604 }) -- (the Studio window)
	for _, s in sizes do
		local hl, ht, hr, hb = HudLayout.box(hurry, s[1], s[2])
		for _, name in { "AutoGas", "Timer", "DriftScore", "Speed" } do
			local l, t, r, b =
				HudLayout.box(HudLayout.find(name, "drive") :: HudLayout.Spot, s[1], s[2])
			truthy(
				not (hl < r and l < hr and ht < b and t < hb),
				`Hurry on {name} at {s[1]}x{s[2]}`
			)
		end
	end
end)

test("a spot that sits under another one is never on the screen with it", function()
	for _, s in HudLayout.SPOTS do
		if s.notWith then
			truthy(HudLayout.find(s.notWith, s.mode) ~= nil, `{s.name}: no spot {s.notWith}`)
		end
	end
	-- (the plot word hides in a race, the only time the hurry pill shows)
	local hud = fs.readFile("src/client/Hud.luau")
	truthy(string.find(hud, "b.Visible = i == index and not inRace", 1, true) ~= nil, "Track hides")
	local race = fs.readFile("src/client/ServerRace.client.luau")
	truthy(string.find(race, 'hurry.Visible = phase == "racing"', 1, true) ~= nil, "Hurry: racing")
end)
