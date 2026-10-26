--!strict
-- One map of every button and chip on the screen, so nothing sits on top of anything else.
-- Each piece has its own spot for "walk" (on foot in the lobby) and/or "drive" (in a car).
-- Popups (shops, gift card, rivals, results) are not here: they sit in the middle on the
-- POPUP layer, over the HUD. Short flash words (GO!, LAP, CHECKPOINT) are not here either.
-- A spot is a UDim2 written out as numbers (scale + pixels) so Lune can test it at phone and
-- PC sizes; see tests/hud_layout.test.luau. Top rows start at 64 px, under Roblox's top bar.

export type Mode = "walk" | "drive"
export type Spot = {
	name: string,
	mode: Mode,
	owner: string, -- the script that makes it
	ax: number, -- AnchorPoint
	ay: number,
	x: number, -- Position: x scale, x pixels, y scale, y pixels
	xo: number,
	y: number,
	yo: number,
	w: number, -- Size: w scale, w pixels, h scale, h pixels
	wo: number,
	h: number,
	ho: number,
	square: boolean?, -- width = height (UIAspectRatioConstraint on height)
	leftOf: string?, -- sits just left of this spot (same mode), bottoms lined up; x is ignored
}

local HudLayout = {}

-- ScreenGui.DisplayOrder: popups always draw over the HUD buttons
HudLayout.HUD = 5
HudLayout.POPUP = 20
-- pixels between BRAKE and GAS
HudLayout.PAD_GAP = 12

local function spot(
	name: string,
	mode: Mode,
	owner: string,
	anchor: { number },
	pos: { number },
	size: { number },
	square: boolean?
): Spot
	return {
		name = name,
		mode = mode,
		owner = owner,
		ax = anchor[1],
		ay = anchor[2],
		x = pos[1],
		xo = pos[2],
		y = pos[3],
		yo = pos[4],
		w = size[1],
		wo = size[2],
		h = size[3],
		ho = size[4],
		square = square,
	}
end

local TL, TC, TR, BC, BR = { 0, 0 }, { 0.5, 0 }, { 1, 0 }, { 0.5, 1 }, { 1, 1 }

HudLayout.SPOTS = {
	-- ===== walk: top left, your counts and buttons =====
	spot("StarCount", "walk", "Stars", TL, { 0.02, 0, 0, 64 }, { 0.11, 0, 0, 36 }),
	spot("CoinCount", "walk", "Stars", TL, { 0.14, 0, 0, 64 }, { 0.11, 0, 0, 36 }),
	-- row 2 stays under the chips (no further right): a third button there covered the car show board
	-- (NOT SAVING shows above the star chip)
	spot("Rivals", "walk", "Stars", TL, { 0.02, 0, 0, 110 }, { 0.11, 0, 0, 32 }),
	spot("Looks", "walk", "PlotShop", TL, { 0.14, 0, 0, 110 }, { 0.11, 0, 0, 32 }),
	spot("DailyJobs", "walk", "Stars", TL, { 0.02, 0, 0, 146 }, { 0.3, 0, 0.12, 60 }),
	-- what you're saving up for (Stars): under the jobs
	spot("NextUnlock", "walk", "Stars", TL, { 0.02, 0, 0.12, 212 }, { 0, 200, 0, 54 }), -- short, big words
	-- ===== walk: top middle, one stack =====
	spot("Friends", "walk", "Lobby", TC, { 0.5, 0, 0, 64 }, { 0, 170, 0, 36 }),
	spot("Quick", "walk", "Lobby", TC, { 0.5, 0, 0, 194 }, { 0, 170, 0, 44 }), -- off for now (Lobby QUICK)
	spot("WeekendBanner", "walk", "Stars", TR, { 0.98, 0, 0, 116 }, { 0, 200, 0, 30 }), -- top right: off your plot's name on the gate
	spot("Join", "walk", "ServerRace", TR, { 0.98, 0, 0, 64 }, { 0, 168, 0, 46 }), -- top right, off the gate's name and the pad words
	spot("PlotTop", "walk", "Stars", TR, { 0.98, 0, 0, 152 }, { 0, 200, 0, 100 }), -- the plot's top 3 while you stand on its pad
	-- ===== walk: bottom middle =====
	spot("Drive", "walk", "Lobby", BC, { 0.47, 0, 0.96, 0 }, { 0, 160, 0, 64 }), -- thumb size, low (off the plot view)
	spot("Build", "walk", "BuildMode", BC, { 0.47, 150, 0.96, 0 }, { 0, 120, 0, 52 }), -- reopen the build screen in the break (right of DRIVE)
	spot("Goal", "walk", "PlotGuide", BC, { 0.5, 0, 0.96, -66 }, { 0, 230, 0, 30 }), -- what to do next (clear of DailyJobs on a small phone)

	-- ===== drive: top (made by the RC car thread; driving is locked, so these stay put) =====
	spot("Timer", "drive", "Hud", TL, { 0.02, 0, 0, 64 }, { 0.24, 0, 0.14, 0 }),
	spot("MedalGoal", "drive", "Stars", TL, { 0.02, 0, 0.14, 70 }, { 0, 110, 0, 30 }), -- next medal on this plot (small)
	spot("Track", "drive", "Hud", TC, { 0.5, 0, 0, 64 }, { 0.1012, 0, 0.1, 0 }), -- the one lit plot name
	spot("DriftScore", "drive", "Hud", TC, { 0.5, 0, 0.12, 72 }, { 0.32, 0, 0.1, 0 }),
	spot("Join", "drive", "ServerRace", TC, { 0.5, 0, 0.22, 80 }, { 0, 220, 0, 44 }),
	spot("AutoGas", "drive", "Controls", TR, { 0.704, 0, 0, 64 }, { 0.083, 0, 0.12, 0 }), -- 45+ px tall on a phone
	spot("Smoke", "drive", "Controls", TR, { 0.796, 0, 0, 64 }, { 0.083, 0, 0.12, 0 }), -- 7+ px apart
	spot("View", "drive", "Controls", TR, { 0.888, 0, 0, 64 }, { 0.083, 0, 0.12, 0 }),
	spot("Cam", "drive", "Controls", TR, { 0.98, 0, 0, 64 }, { 0.083, 0, 0.12, 0 }), -- RESET on rocks
	spot("Speed", "drive", "Hud", TR, { 0.98, 0, 0.12, 68 }, { 0.1, 0, 0.05, 0 }),
	-- ===== drive: thumbs =====
	spot("SteerHint", "drive", "Controls", BC, { 0.22, 0, 0.93, 0 }, { 0.3, 0, 0.08, 0 }),
	-- 0.47: clear of the steer hint on a small phone and of BRAKE on a 4:3 tablet
	spot("Walk", "drive", "Lobby", BC, { 0.47, 0, 0.9, 0 }, { 0, 120, 0, 52 }),
	-- BRAKE hugs GAS (Controls moves it when the screen size changes), so they never touch
	(function()
		local s = spot("Brake", "drive", "Controls", BR, { 0, 0, 0.95, 0 }, { 0, 0, 0.22, 0 }, true)
		s.leftOf = "Gas"
		return s
	end)(),
	spot("Drift", "drive", "Controls", BR, { 0.97, 0, 0.58, 0 }, { 0, 0, 0.22, 0 }, true), -- big RESET on rocks
	spot("Gas", "drive", "Controls", BR, { 0.97, 0, 0.95, 0 }, { 0, 0, 0.34, 0 }, true),
}

function HudLayout.find(name: string, mode: Mode): Spot?
	for _, s in HudLayout.SPOTS do
		if s.name == name and s.mode == mode then
			return s
		end
	end
	return nil
end

-- the box a spot covers on a screen of sw x sh pixels: left, top, right, bottom
function HudLayout.box(s: Spot, sw: number, sh: number): (number, number, number, number)
	local hgt = s.h * sh + s.ho
	local wid = if s.square then hgt else s.w * sw + s.wo
	local left = s.x * sw + s.xo - s.ax * wid
	local top = s.y * sh + s.yo - s.ay * hgt
	local other = if s.leftOf then HudLayout.find(s.leftOf, s.mode) else nil
	if other then
		local ol, _, _, ob = HudLayout.box(other, sw, sh)
		left, top = ol - HudLayout.PAD_GAP - wid, ob - hgt
	end
	return left, top, left + wid, top + hgt
end

-- every pair of spots in the same mode that cover each other on this screen
function HudLayout.overlaps(sw: number, sh: number): { string }
	local out = {}
	local list = HudLayout.SPOTS
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.mode == b.mode then
				local al, at, ar, ab = HudLayout.box(a, sw, sh)
				local bl, bt, br, bb = HudLayout.box(b, sw, sh)
				if al < br and bl < ar and at < bb and bt < ab then
					table.insert(out, `{a.mode}: {a.name} / {b.name}`)
				end
			end
		end
	end
	return out
end

-- put a GuiObject in its spot (the ScreenGui must have IgnoreGuiInset = true)
function HudLayout.place(obj: GuiObject, name: string, mode: Mode?)
	local s = HudLayout.find(name, mode or "walk")
	assert(s, `HudLayout has no spot {name}`)
	obj.AnchorPoint = Vector2.new(s.ax, s.ay)
	obj.Position = UDim2.new(s.x, s.xo, s.y, s.yo)
	obj.Size = UDim2.new(s.w, s.wo, s.h, s.ho)
end

return HudLayout
