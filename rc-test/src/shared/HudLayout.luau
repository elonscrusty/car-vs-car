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
	off: boolean?, -- its part is switched off (Features): never shown, so it may sit under others
	notWith: string?, -- never on the screen with this spot (same mode), so it may sit under it
}

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Features = sibling("Features")

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

-- the top left row: coins, then coins a minute (one column further right while stars show)
local STARS = Features.STARS
local CVC = Features.CVC

-- a spot whose part is switched off (the overlap test skips it)
local function off(s: Spot, isOff: boolean): Spot
	s.off = isOff or nil
	return s
end
-- Car VS Car: row 2 (CRATE, MY GARAGE) is thumb size, so the jobs and NEXT box sit a bit lower
local ROW2_Y, ROW2_H = if CVC then 106 else 110, if CVC then 44 else 32
local DROP = if CVC then 12 else 0
local COL1 = if STARS then 0.14 else 0.02
local COL2 = if STARS then 0.26 else 0.14

local TL, TC, TR, BC, BR = { 0, 0 }, { 0.5, 0 }, { 1, 0 }, { 0.5, 1 }, { 1, 1 }

HudLayout.SPOTS = {
	-- ===== walk: top left, your counts and buttons =====
	-- (stars off, Features.STARS: the coins take the star chip's place, so no hole at the left;
	-- the star chip and LOOKS, hidden then, wait in row 2 out of the way)
	off(
		spot(
			"StarCount",
			"walk",
			"Stars",
			TL,
			{ if STARS then 0.02 else 0.26, 0, 0, if STARS then 64 else 110 },
			{ 0.11, 0, 0, 36 }
		),
		not STARS
	),

	spot("CoinCount", "walk", "Stars", TL, { COL1, 0, 0, 64 }, { 0.11, 0, 0, 36 }),
	-- row 2 stays under the chips (no further right): a third button there covered the car show board
	-- (NOT SAVING shows above the star chip)
	off(
		spot(
			"Looks",
			"walk",
			"PlotShop",
			TL,
			{ if STARS then 0.14 else 0.38, 0, 0, 110 },
			{ 0.11, 0, 0, 32 }
		),
		not STARS
	),

	-- the tycoon (Tycoon.client): coins a minute right of the coins, GARAGE under it
	spot("Income", "walk", "Tycoon", TL, { COL2, 0, 0, 64 }, { 0.1, 0, 0, 36 }),
	spot("Garage", "walk", "Tycoon", TL, { COL2, 0, 0, ROW2_Y }, { 0.1, 0, 0, ROW2_H }),
	-- Car VS Car: CRATES under the coins (Cvc crate screen; only with a crate to open)
	off(spot("Crate", "walk", "Cvc", TL, { 0.02, 0, 0, ROW2_Y }, { 0.1, 0, 0, ROW2_H }), not CVC),
	spot("DailyJobs", "walk", "Stars", TL, { 0.02, 0, 0, 146 + DROP }, { 0.3, 0, 0.12, 60 }),
	-- what you're saving up for (Stars): under the jobs
	spot("NextUnlock", "walk", "Stars", TL, { 0.02, 0, 0.12, 212 + DROP }, { 0, 200, 0, 54 }), -- short, big words
	-- ===== walk: top middle, one stack =====
	off(
		spot("Friends", "walk", "Lobby", TC, { 0.5, 0, 0, 64 }, { 0, 170, 0, 36 }),
		not Features.PLOT_RACING
	),
	off(
		spot("Quick", "walk", "Lobby", TC, { 0.5, 0, 0, 194 }, { 0, 170, 0, 44 }),
		not Features.PLOT_RACING
	), -- off for now (Lobby QUICK)
	-- Car VS Car (Cvc.client): COACH in the top middle, the big JOIN over the goal line
	off(spot("Coach", "walk", "Cvc", TC, { 0.5, 0, 0, 64 }, { 0, 170, 0, 56 }), not CVC),
	off(spot("BigJoin", "walk", "Cvc", BC, { 0.5, 0, 0.96, -102 }, { 0, 240, 0, 64 }), not CVC),
	spot("WeekendBanner", "walk", "Stars", TR, { 0.98, 0, 0, 116 }, { 0, 200, 0, 30 }), -- top right: off your plot's name on the gate
	spot("Join", "walk", "ServerRace", TR, { 0.98, 0, 0, 64 }, { 0, 168, 0, 46 }), -- top right, off the gate's name and the pad words
	-- Car VS Car: RACE ME! (CvcInvite) asks a friend in, under the weekend banner
	off(spot("Invite", "walk", "Cvc", TR, { 0.98, 0, 0, 154 }, { 0, 150, 0, 44 }), not CVC),
	-- ===== walk: bottom middle =====
	spot("Drive", "walk", "Lobby", BC, { 0.47, 0, 0.96, 0 }, { 0, 160, 0, 64 }), -- thumb size, low (off the plot view)
	spot("Goal", "walk", "PlotGuide", BC, { 0.5, 0, 0.96, -66 }, { 0, 230, 0, 30 }), -- what to do next (clear of DailyJobs on a small phone)

	-- ===== drive: top (made by the RC car thread; driving is locked, so these stay put) =====
	spot("Timer", "drive", "Hud", TL, { 0.02, 0, 0, 64 }, { 0.24, 0, 0.14, 0 }),
	spot("Track", "drive", "Hud", TC, { 0.5, 0, 0, 64 }, { 0.1012, 0, 0.1, 0 }), -- the one lit plot name
	spot("DriftScore", "drive", "Hud", TC, { 0.5, 0, 0.12, 72 }, { 0.32, 0, 0.1, 0 }),
	-- FINISH IN 0:04! / RESULTS IN (ServerRace): between the timer and AUTO GAS (it was half the
	-- screen wide and sat on AUTO GAS, Studio final-44); the plot word hides in a race (Hud.setRace)
	(function()
		local s = spot("Hurry", "drive", "ServerRace", TC, { 0.44, 0, 0, 64 }, { 0.3, 0, 0.08, 0 })
		s.notWith = "Track"
		return s
	end)(),
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
	-- Car VS Car: the big BOOST thumb button, left of DRIFT (Cvc.client)
	(function()
		local s = spot("Boost", "drive", "Cvc", BR, { 0, 0, 0.58, 0 }, { 0, 0, 0.2, 0 }, true)
		s.leftOf = "Drift"
		return off(s, not CVC)
	end)(),
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
			local apart = a.notWith == b.name or b.notWith == a.name
			if a.mode == b.mode and not a.off and not b.off and not apart then
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
