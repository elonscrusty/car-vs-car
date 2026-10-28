--!strict
-- The new screens (carter 10-27, CarVsCar_UI_Handoff.md): colors and timings match the spec, the
-- pattern tile has its sparkle and holed diamond, and every screen keeps the phone rules.
local H = require("./harness")
local UiTheme = require("../src/shared/UiTheme")
local UiMotion = require("../src/shared/UiMotion")
local UiPattern = require("../src/shared/UiPattern")
local UiScreens = require("../src/shared/UiScreens")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("UiScreens")

test("the colors are the spec's hex values", function()
	local spec = {
		ink = "0d2c40",
		inkMuted = "3f5872",
		surface = "ffffff",
		sky100 = "e6f5ff",
		sky300 = "8fd8ff",
		blue = "1fa8f5",
		blueDeep = "0b78c9",
		lime = "8be81c",
		limeDeep = "3f9a0c",
		go = "ffd93b",
		goDeep = "d99a00",
		danger = "ec1c2e",
		dangerDeep = "a3001b",
		boost = "ff7a1a",
		boostDeep = "c44d00",
		pink = "ff4f9a",
		pinkDeep = "c8206a",
		gold = "f9b709",
		navy = "13304a",
		alert = "ff3b3b",
		barEmpty = "d9e4f5",
		scrim = "081828",
		common = "a7b2cc",
		rare = "1fa8f5",
		epic = "8a4dff",
		legendary = "ffd93b",
		bronze = "d68a4c",
		silver = "c3cddc",
		leagueGold = "ffc22e",
		diamond = "5ee0f0",
	}
	for name, hex in spec do
		eq(UiTheme.HEX[name], hex, name)
	end
	local r, g, b = UiTheme.rgb("ink")
	eq(r, 13)
	eq(g, 44)
	eq(b, 64)
end)

test("every tone has a fill and a darker ledge, and stats keep one color each", function()
	for name, tone in UiTheme.TONES do
		truthy(UiTheme.HEX[tone.fill], name .. " fill")
		truthy(UiTheme.HEX[tone.deep], name .. " deep")
	end
	-- the plot board's colors and words: SPEED blue (treadmills), BOOST orange (ramps), TURN
	-- green (speed tracks), so a screen and the pads always say the same
	local want = { power = "blue", air = "boost", speed = "lime" }
	local words = { power = "SPEED", air = "BOOST", speed = "TURN" }
	for _, s in UiTheme.STATS do
		eq(s.tone, want[s.key], s.key)
		eq(s.word, words[s.key], s.key)
	end
	eq(UiTheme.rarityId("legend"), "legendary")
	eq(UiTheme.rarityId(nil), "common")
end)

test("the pattern slides 44 px every 3.4 s", function()
	near(UiMotion.patternOffset(0), 0)
	near(UiMotion.patternOffset(1.7), 22)
	near(UiMotion.patternOffset(3.4), 0)
	near(UiMotion.patternOffset(1), 44 / 3.4, 1e-6)
end)

test("the pattern tile: sparkle at (11,11), holed diamond at (33,33), empty elsewhere", function()
	local m = UiPattern.mask()
	local n = UiPattern.SIZE
	eq(#m, n * n)
	local function at(x: number, y: number): number
		return m[y * n + x + 1]
	end
	eq(at(11, 11), 1, "sparkle middle")
	truthy(at(11, 6) > 0.5, "sparkle top point")
	eq(at(5, 5), 0, "between the sparkle's points")
	eq(at(33, 33), 0, "the diamond's hole")
	eq(at(38, 33), 1, "the diamond's ring")
	eq(at(0, 43), 0, "empty corner")
	eq(at(22, 22), 0, "empty middle")
	-- both shapes about 15 px across
	local first, last = n, -1
	for x = 0, n - 1 do
		if at(x, 33) > 0.5 then
			first, last = math.min(first, x), math.max(last, x)
		end
	end
	local wide = last - first + 1
	truthy(wide >= 12 and wide <= 16, `diamond {wide} px across`)
	-- faint: under a fifth of the tile is drawn
	local sum = 0
	for _, a in m do
		sum += a
	end
	truthy(sum / (n * n) < 0.2, "too much ink")
	local buf = buffer.create(n * n * 4)
	UiPattern.fill(buf)
	eq(buffer.readu8(buf, (11 * n + 11) * 4 + 3), 255)
	eq(buffer.readu8(buf, (22 * n + 22) * 4 + 3), 0)
end)

test("numbers: commas, clocks, places, shouts", function()
	eq(UiMotion.commas(2450), "2,450")
	eq(UiMotion.commas(999), "999")
	eq(UiMotion.commas(1234567), "1,234,567")
	eq(UiMotion.commas(-1500), "-1,500")
	eq(UiMotion.clock(102), "1:42")
	eq(UiMotion.clock(0), "0:00")
	eq(UiMotion.place(1), "1ST")
	eq(UiMotion.place(2), "2ND")
	eq(UiMotion.place(3), "3RD")
	eq(UiMotion.place(8), "8TH")
	eq(UiMotion.place(11), "11TH")
	eq(UiMotion.place(22), "22ND")
	eq(UiMotion.finishShout(1), "YOU WON!")
	eq(UiMotion.finishShout(3), "TOP 3!")
	eq(UiMotion.finishShout(6), "NICE TRY!")
	eq(UiMotion.percent(60), "60%")
	eq(UiMotion.percent(0.5), "0.5%")
	eq(UiMotion.percent(4.5), "4.5%")
end)

test("count up: starts at the old value, lands on the new one at 0.9 s", function()
	eq(UiMotion.countUp(0, 250, 0), 0)
	eq(UiMotion.countUp(0, 250, 0.9), 250)
	eq(UiMotion.countUp(100, 200, 5), 200)
	local mid = UiMotion.countUp(0, 1000, 0.45)
	truthy(mid > 500 and mid < 1000, "ease out: past half at half time")
end)

test("shout and GO! keyframes: from small, past full, settle at 100%", function()
	near(UiMotion.keyed(UiMotion.SHOUT_KEYS, 0), 0.3)
	near(UiMotion.keyed(UiMotion.SHOUT_KEYS, 0.6), 1.12)
	near(UiMotion.keyed(UiMotion.SHOUT_KEYS, 1), 1)
	near(UiMotion.keyed(UiMotion.GO_KEYS, 0), 0.2)
	near(UiMotion.keyed(UiMotion.GO_KEYS, 0.35), 1.18)
	near(UiMotion.keyed(UiMotion.GO_KEYS, 0.55), 0.94)
	near(UiMotion.keyed(UiMotion.GO_KEYS, 1), 1)
	near(UiMotion.stagger(1), 0)
	near(UiMotion.stagger(3), 0.12)
	local f, words = UiMotion.cooldown(24, 60)
	near(f, 0.4)
	eq(words, "0:24")
	eq(select(2, UiMotion.cooldown(0, 60)), "")
end)

-- ===== the screens =====

local W, Hh = UiScreens.W, UiScreens.H

local function eachPiece(fn: (
	screen: UiScreens.Screen,
	piece: UiScreens.Piece,
	outer: UiScreens.Piece?
) -> ())
	for _, s in UiScreens.LIST do
		for _, piece in s.pieces do
			fn(s, piece, nil)
			for _, inner in piece.inner or {} do
				fn(s, inner, piece)
			end
		end
	end
end

test(
	"18 screens: the spec's 17, numbered 0 to 16 in its order, then the SMASH match HUD",
	function()
		eq(#UiScreens.LIST, 18)
		for i, s in UiScreens.LIST do
			eq(s.n, i - 1, s.id)
		end
	end
)

test("everything sits inside the safe area (and inside its window)", function()
	eachPiece(function(s, piece, outer)
		local where = `{s.id}.{if outer then outer.name .. "." else ""}{piece.name}`
		if outer then
			truthy(piece.x >= 0 and piece.y >= 0, where .. " starts outside its window")
			truthy(
				piece.x + piece.w <= outer.w and piece.y + piece.h <= outer.h,
				where .. " runs out of its window"
			)
		else
			truthy(piece.x >= 0 and piece.y >= 0, where .. " starts outside the safe area")
			truthy(
				piece.x + piece.w <= W and piece.y + piece.h <= Hh,
				where .. " runs out of the safe area"
			)
			UiScreens.anchor(piece) -- a known anchor
		end
	end)
end)

test("windows leave room for their title, X and back slab", function()
	for _, s in UiScreens.LIST do
		for _, piece in s.pieces do
			if piece.name == "Window" then
				truthy(
					piece.y >= UiScreens.WINDOW_TOP or piece.text == nil,
					s.id .. " title off the top"
				)
				truthy(piece.x + piece.w + UiScreens.WINDOW_RIGHT <= W, s.id .. " X off the right")
				truthy(piece.x >= UiScreens.WINDOW_LEFT, s.id .. " slab off the left")
			end
		end
	end
end)

test("gameplay screens keep the bottom-left 140 px free for the move stick", function()
	local stick = UiScreens.stickZone()
	for _, s in UiScreens.LIST do
		if s.gameplay then
			for _, piece in s.pieces do
				if not piece.world then
					truthy(
						not UiScreens.overlap(piece, stick),
						`{s.id}.{piece.name} sits on the move stick`
					)
				end
			end
		end
	end
end)

test("the plot has at most 4 side tiles; the race shows at most 4 things plus the stick", function()
	local tiles = 0
	for _, piece in UiScreens.get("plot").pieces do
		if piece.w == UiTheme.SIZE.side and piece.h == UiTheme.SIZE.side then
			tiles += 1
		end
	end
	eq(tiles, 4)
	eq(#UiScreens.get("race").pieces, 4)
	-- ONE big round thumb button, bottom right: COACH on the plot, BOOST in a race
	local coach = UiScreens.piece("plot", "Coach")
	local boost = UiScreens.piece("race", "Boost")
	eq(coach.anchor, "br")
	eq(boost.anchor, "br")
	eq(coach.w, UiTheme.SIZE.coach)
	eq(boost.w, UiTheme.SIZE.boost)
end)

test("on the plot nothing on screen covers anything else", function()
	local list = {}
	for _, piece in UiScreens.get("plot").pieces do
		if not piece.world then
			table.insert(list, piece)
		end
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			-- (a live-game piece shown in place of a viewer one never shares the screen with it)
			local swap = a.instead == b.name or b.instead == a.name
			truthy(swap or not UiScreens.overlap(a, b), `{a.name} covers {b.name}`)
		end
	end
end)

test("buttons: short ALL CAPS words, big enough to tap, a known tone", function()
	eachPiece(function(s, piece)
		if piece.tone then
			local where = `{s.id}.{piece.name}`
			truthy(UiTheme.TONES[piece.tone], where .. " tone")
			local text = piece.text or ""
			eq(text, string.upper(text), where .. " not ALL CAPS")
			local words = 0
			for _ in text:gmatch("%S+") do
				words += 1
			end
			truthy(words >= 1 and words <= 3, where .. " has " .. words .. " words")
		end
		if piece.tone or piece.tap then
			truthy(piece.w >= 44 and piece.h >= 44, `{s.id}.{piece.name} too small to tap`)
		end
	end)
end)

test("one main action per screen, lime (or yellow to celebrate)", function()
	for _, s in UiScreens.LIST do
		local mains = 0
		for _, piece in s.pieces do
			for _, q in { piece, table.unpack(piece.inner or {}) } do
				if q.main then
					mains += 1
					truthy(
						q.tone == "lime" or q.tone == "go",
						s.id .. " main is " .. tostring(q.tone)
					)
				end
			end
		end
		truthy(mains <= 1, s.id .. " has " .. mains .. " main actions")
	end
end)

test("the crate window shows the odds before its OPEN button can be pressed", function()
	truthy(UiScreens.piece("crates", "Window.Odds"))
	eq(UiScreens.piece("crates", "Window.Open").text, "OPEN")
end)

test("no emoji or odd letters in screen words", function()
	eachPiece(function(s, piece)
		for _, t in { piece.text } do
			truthy(not t:find("[\128-\255]"), `{s.id}.{piece.name}: {t}`)
		end
	end)
end)

test("losing never says YOU LOST", function()
	for place = 1, 8 do
		truthy(not UiMotion.finishShout(place):find("LOST"))
	end
end)
