--!strict
-- The tiny match goal (carter 10-31 pick 3): the next step above your smashes, calm at the end.
local H = require("./harness")
local MatchGoal = require("../src/shared/MatchGoal")

local test, eq, truthy = H.test, H.eq, H.truthy

print("MatchGoal")

test("match goal: starts at SMASH 1, then 3, 5, 8, then NICE!", function()
	eq(MatchGoal.read(0).words, "SMASH 1")
	eq(MatchGoal.read(1).words, "SMASH 3")
	eq(MatchGoal.read(2).words, "SMASH 3")
	eq(MatchGoal.read(3).words, "SMASH 5")
	eq(MatchGoal.read(7).words, "SMASH 8")
	eq(MatchGoal.read(8).words, "NICE!")
	eq(MatchGoal.read(40).done, true)
end)

test("match goal: the bar fills toward the step and never leaves 0..1", function()
	eq(MatchGoal.read(0).f, 0)
	truthy(math.abs(MatchGoal.read(2).f - 2 / 3) < 1e-9)
	eq(MatchGoal.read(99).f, 1)
end)

test("match goal: junk smashes count as 0", function()
	eq(MatchGoal.read(nil).words, "SMASH 1")
	eq(MatchGoal.read("x").words, "SMASH 1")
	eq(MatchGoal.read(-5).words, "SMASH 1")
	eq(MatchGoal.read(0 / 0).words, "SMASH 1")
end)

test(
	"match goal: the pill, SPECIAL and arrows go once the clock runs out, though InMatch stays on",
	function()
		truthy(MatchGoal.live(true, 100, 50), "mid match")
		truthy(MatchGoal.live(true, 100, 100.5), "a second of grace")
		truthy(not MatchGoal.live(true, 100, 102), "the break")
		truthy(not MatchGoal.live(false, 100, 50), "not in a match")
		truthy(not MatchGoal.live(true, nil, 50), "no end time")
		truthy(not MatchGoal.live(nil, 100, 50), "no flag")
	end
)

-- ===== where the pill sits on a phone / PC: clear of every match HUD piece and the stick =====
local UiScreens = require("../src/shared/UiScreens")

-- the safe area a CoreUISafeInsets gui fills (x, y, w, h): the top bar, a notch, the home bar
local SAFE = {
	{ 667, 375, { 0, 58, 667, 375 - 58 } },
	{ 844, 390, { 47, 58, 844 - 94, 390 - 58 - 21 } },
	{ 932, 430, { 59, 58, 932 - 118, 430 - 58 - 21 } },
	{ 1366, 768, { 0, 58, 1366, 768 - 58 } },
	{ 1920, 1080, { 0, 58, 1920, 1080 - 58 } },
}

-- A HUD piece's box: Base.place puts the anchor at (x + ax*w) / W, (y + ay*h) / H of the safe
-- area and fits the piece inside a w:h shape at k = min(sw / W, sh / H).
local function pieceBox(screen: string, name: string, s: { number }): { number }
	local pc = UiScreens.piece(screen, name)
	local ax, ay = UiScreens.anchor(pc)
	local k = math.min(s[3] / UiScreens.W, s[4] / UiScreens.H)
	local w, h = pc.w * k, pc.h * k
	local px = s[1] + (pc.x + ax * pc.w) / UiScreens.W * s[3] - ax * w
	local py = s[2] + (pc.y + ay * pc.h) / UiScreens.H * s[4] - ay * h
	return { px, py, px + w, py + h }
end

test(
	"match goal: the pill covers no match HUD piece and not the stick, on phones and PC",
	function()
		for _, sz in SAFE do
			local s = sz[3]
			local pl = s[1] + MatchGoal.PILL.x
			local pt = s[2] + MatchGoal.PILL.top * s[4]
			local pr, pb = pl + MatchGoal.PILL.w, pt + MatchGoal.PILL.h
			for _, screen in { "match", "matchTouch" } do
				for _, name in { "Place", "Board", "Feed", "Clock", "Health", "Fire" } do
					local ok, _ = pcall(UiScreens.piece, screen, name)
					if not ok then
						continue
					end
					local b = pieceBox(screen, name, s)
					truthy(
						not (pl < b[3] and b[1] < pr and pt < b[4] and b[2] < pb),
						`pill on {name} ({screen}) at {sz[1]}x{sz[2]}`
					)
				end
			end
			-- the drive stick's corner: bottom left, 140 design px square
			local k = math.min(s[3] / UiScreens.W, s[4] / UiScreens.H)
			truthy(pb <= s[2] + s[4] - UiScreens.STICK * k, `pill on the stick at {sz[1]}x{sz[2]}`)
		end
	end
)
