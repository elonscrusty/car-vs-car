--!strict
-- The screen map: no two buttons or chips cover each other, on phones and on PC.
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
	table.insert(HudLayout.SPOTS, {
		name = "Test",
		mode = "walk",
		owner = "test",
		ax = 0.5,
		ay = 0,
		x = 0.5,
		xo = 0,
		y = 0,
		yo = 120,
		w = 0,
		wo = 50,
		h = 0,
		ho = 20,
	})
	local hits = HudLayout.overlaps(844, 390)
	table.remove(HudLayout.SPOTS)
	eq(#hits, 1)
	eq(hits[1], "walk: Quick / Test")
end)

test("popups draw over the HUD", function()
	truthy(HudLayout.POPUP > HudLayout.HUD)
	truthy(HudLayout.find("Join", "walk") ~= nil and HudLayout.find("Join", "drive") ~= nil)
end)
