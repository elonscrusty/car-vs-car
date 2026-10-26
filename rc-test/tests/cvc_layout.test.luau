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
	{ 750, 381 }, -- (the Studio check window)
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

test("the main buttons are bigger still on a phone (56 px+)", function()
	for _, s in SIZES do
		each(function(screen, name, b)
			if b.main then
				local l, t, r, bt = CvcLayout.box(screen, name, s[1], s[2])
				truthy(
					r - l >= CvcLayout.MAIN and bt - t >= CvcLayout.MAIN,
					`{screen}.{name} is {math.floor(r - l)}x{math.floor(bt - t)} on {s[1]}x{s[2]}`
				)
			end
		end)
	end
	if Features.CVC then
		for _, s in SIZES do
			for _, it in { { "Coach", "walk" }, { "BigJoin", "walk" }, { "Boost", "drive" } } do
				local l, t, r, b =
					HudLayout.box(HudLayout.find(it[1], it[2] :: any) :: any, s[1], s[2])
				truthy(
					r - l >= CvcLayout.MAIN and b - t >= CvcLayout.MAIN,
					`{it[1]} is {math.floor(r - l)}x{math.floor(b - t)} on {s[1]}x{s[2]}`
				)
			end
		end
	end
end)

test("the how-to tip never covers COACH, JOIN, CRATE or MY GARAGE", function()
	if not Features.CVC then
		return
	end
	local TIPS = { { "Coach", true }, { "BigJoin", false }, { "Crate", true }, { "Garage", true } }
	for _, s in SIZES do
		local rects: { [string]: CvcLayout.Rect } = {}
		for _, it in TIPS do
			local l, t, r, b = HudLayout.box(HudLayout.find(it[1], "walk") :: any, s[1], s[2])
			rects[it[1]] = { l, t, r, b }
		end
		for _, it in TIPS do
			local avoid = {}
			for name, r in rects do
				if name ~= it[1] then
					table.insert(avoid, r)
				end
			end
			local tip = CvcLayout.tip(rects[it[1]], it[2], s[1], s[2], avoid)
			for part, r in { arrow = tip.arrow, words = tip.words, skip = tip.skip } do
				truthy(
					not CvcLayout.hits(r, rects[it[1]]),
					`{it[1]} tip {part} on its button at {s[1]}x{s[2]}`
				)
				for name, o in rects do
					if name ~= it[1] then
						truthy(
							not CvcLayout.hits(r, o),
							`{it[1]} tip {part} covers {name} at {s[1]}x{s[2]}`
						)
					end
				end
				truthy(
					r[1] >= 0 and r[2] >= 0 and r[3] <= s[1] and r[4] <= s[2],
					`{it[1]} tip {part} off {s[1]}x{s[2]}`
				)
			end
		end
	end
end)

test("COACH steps under the race call strip, clear of it and of the other buttons", function()
	if not Features.CVC then
		return
	end
	local coach = HudLayout.find("Coach", "walk") :: any
	for _, s in SIZES do
		local strip = CvcLayout.callStrip(s[1])
		local l, t, r, b = HudLayout.box(coach, s[1], s[2])
		-- where it normally sits, the strip would cover it (the Studio find)
		local moved =
			{ l, CvcLayout.coachUnderCall(s[1]), r, CvcLayout.coachUnderCall(s[1]) + (b - t) }
		truthy(not CvcLayout.hits(moved, strip), `COACH under the strip at {s[1]}x{s[2]}`)
		truthy(moved[4] <= s[2], `COACH on screen at {s[1]}x{s[2]}`)
		for _, spot in HudLayout.SPOTS do
			if spot.mode == "walk" and not spot.off and spot.name ~= "Coach" then
				local ol, ot, orr, ob = HudLayout.box(spot, s[1], s[2])
				truthy(
					not CvcLayout.hits(moved, { ol, ot, orr, ob }),
					`moved COACH covers {spot.name} at {s[1]}x{s[2]}`
				)
			end
		end
	end
end)

test("the BOOST tip never covers the race chips (the lap box with 5TH OF 8, DRIFT, ...)", function()
	if not Features.CVC then
		return
	end
	for _, s in SIZES do
		local boost: CvcLayout.Rect, avoid = {}, {}
		for _, spot in HudLayout.SPOTS do
			if spot.mode == "drive" and not spot.off then
				local l, t, r, b = HudLayout.box(spot, s[1], s[2])
				if spot.name == "Boost" then
					boost = { l, t, r, b }
				elseif CvcLayout.boostAvoids(spot.name) then
					table.insert(avoid, { l, t, r, b })
				end
			end
		end
		local tip = CvcLayout.tip(boost, false, s[1], s[2], avoid)
		for part, r in { arrow = tip.arrow, words = tip.words, skip = tip.skip } do
			for _, o in avoid do
				truthy(
					not CvcLayout.hits(r, o),
					`BOOST tip {part} covers a race chip at {s[1]}x{s[2]}`
				)
			end
		end
	end
end)

test("after a race the cards take turns: no two that cover each other show at once", function()
	if not Features.CVC then
		return
	end
	for _, s in SIZES do
		local sw, sh = s[1], s[2]
		local function finish(name: string): CvcLayout.Rect
			local l, t, r, b = CvcLayout.box("finish", name, sw, sh)
			return { l, t, r, b }
		end
		local cards: { [string]: CvcLayout.Rect } = {
			-- the biggest result card: 8 racers, the 2X line and NEXT RACE IN, the podium
			Result = CvcLayout.resultBox(sw, sh, 10, true),
			Finish = finish("Card"),
			QuickChat = finish("Chat"),
			RacePrize = CvcLayout.prizeBox(sw, sh),
		}
		for a, ra in cards do
			for b, rb in cards do
				if a < b and CvcLayout.turnOf(a) == CvcLayout.turnOf(b) then
					truthy(not CvcLayout.hits(ra, rb), `{a} covers {b} at {sw}x{sh}`)
				end
			end
		end
		-- (the Studio find: the win card on the ribbon, GG!/AGAIN! and NEXT CAR on the rows)
		for _, name in { "Finish", "QuickChat", "RacePrize" } do
			truthy(
				CvcLayout.turnOf(name) > CvcLayout.turnOf("Result"),
				`{name} waits for the result`
			)
		end
		truthy(
			CvcLayout.turnOf("RacePrize") > CvcLayout.turnOf("QuickChat"),
			"NEXT CAR waits for GG! / AGAIN!"
		)
	end
	-- every card in the turns
	for _, c in CvcLayout.AFTER_RACE do
		truthy(CvcLayout.turnOf(c.name) == c.turn, `{c.name} has one turn`)
	end
end)
