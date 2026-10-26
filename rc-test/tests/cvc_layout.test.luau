--!strict
-- Car VS Car screens on a phone: every button is thumb size, nothing falls off its panel or the
-- screen, and no two buttons cover each other (CvcLayout, HudLayout).
local H = require("./harness")
local CvcLayout = require("../src/shared/CvcLayout")
local Features = require("../src/shared/Features")
local HudLayout = require("../src/shared/HudLayout")

local test, truthy = H.test, H.truthy

print("CvcLayout")

-- the small phone first, then bigger phones, tablets and PC
local SIZES = {
	{ 667, 375 },
	{ 844, 390 },
	{ 932, 430 },
	{ 1024, 768 },
	{ 1366, 768 },
	{ 1920, 1080 },
}
local THUMB = CvcLayout.THUMB

local function each(fn: (screen: string, name: string, b: CvcLayout.Box) -> ())
	for screen, boxes in CvcLayout.SCREENS :: any do
		for name, b in boxes do
			fn(screen, name, b)
		end
	end
end

test("every Car VS Car button is thumb size", function()
	for _, s in SIZES do
		each(function(screen, name, b)
			if b.tap then
				local l, t, r, bt = CvcLayout.box(screen, name, s[1], s[2])
				truthy(
					r - l >= THUMB and bt - t >= THUMB,
					`{screen}.{name} is {math.floor(r - l)}x{math.floor(bt - t)} on {s[1]}x{s[2]}`
				)
			end
		end)
	end
end)

test("every piece stays on the screen and inside its panel", function()
	for _, s in SIZES do
		each(function(screen, name, b)
			local l, t, r, bt = CvcLayout.box(screen, name, s[1], s[2])
			truthy(
				l >= 0 and t >= 0 and r <= s[1] and bt <= s[2],
				`{screen}.{name} off {s[1]}x{s[2]}`
			)
			-- (the big X sits on the panel's corner on purpose)
			if b.parent and name ~= "Close" then
				local pl, pt, pr, pb = CvcLayout.box(screen, b.parent, s[1], s[2])
				truthy(
					l >= pl - 0.5 and t >= pt - 0.5 and r <= pr + 0.5 and bt <= pb + 0.5,
					`{screen}.{name} sticks out of {b.parent} on {s[1]}x{s[2]}`
				)
			end
		end)
	end
end)

test("no two buttons on a screen cover each other", function()
	for _, s in SIZES do
		for screen, boxes in CvcLayout.SCREENS :: any do
			local taps = {}
			for name, b in boxes do
				if b.tap then
					table.insert(taps, name)
				end
			end
			for i = 1, #taps do
				for j = i + 1, #taps do
					local al, at, ar, ab = CvcLayout.box(screen, taps[i], s[1], s[2])
					local bl, bt, br, bb = CvcLayout.box(screen, taps[j], s[1], s[2])
					truthy(
						not (al < br and bl < ar and at < bb and bt < ab),
						`{screen}: {taps[i]} / {taps[j]} on {s[1]}x{s[2]}`
					)
				end
			end
		end
	end
end)

test("the popups' tops clear the screen edge (the ribbon sits over it)", function()
	for _, s in SIZES do
		for _, screen in { "pick", "garage", "crate" } do
			local _, t = CvcLayout.box(screen, "Panel", s[1], s[2])
			truthy(t >= 24, `{screen} panel top {t} on {s[1]}x{s[2]}`)
		end
	end
end)

test("a station card has room for its car and bars on a phone", function()
	local _, t, _, b = CvcLayout.box("garage", "CardTop", 667, 375)
	truthy(b - t >= 110, `card top is {b - t} px`)
end)

test("the Car VS Car HUD buttons are thumb size", function()
	if not Features.CVC then
		return
	end
	for _, s in SIZES do
		for _, it in
			{
				{ "Coach", "walk" },
				{ "BigJoin", "walk" },
				{ "Crate", "walk" },
				{ "Garage", "walk" },
				{ "Boost", "drive" },
			}
		do
			local spot = HudLayout.find(it[1], it[2] :: any)
			truthy(spot, it[1])
			local l, t, r, b = HudLayout.box(spot :: any, s[1], s[2])
			truthy(
				r - l >= THUMB and b - t >= THUMB,
				`{it[1]} is {math.floor(r - l)}x{math.floor(b - t)} on {s[1]}x{s[2]}`
			)
		end
	end
end)
