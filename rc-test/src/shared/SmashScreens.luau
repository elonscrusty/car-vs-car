--!strict
-- Smash game screens owned by WINDOWS (plans/smash, FINISH-JOBS): where each piece sits, in the
-- same design px and Piece shape as UiScreens (756 x 390 canvas inside the phone's safe area), so
-- client/Ui/Screens/Smash places from here and tests/smash_screens.test.luau checks the same rules
-- (safe area, move-stick corner free while driving, tap sizes, short ALL CAPS button words).
--   matchEnd: the 12 s break between rounds (VIDEO-STUDY.md). ROUND OVER, "<name> WINS" with the
--     winner's kart, the top 3 with smashes, your coins and XP popping in, "NEW ROUND STARTING IN
--     12" (the next round starts by itself), and a small LEAVE back to the lobby.
--   customize: KARTS / HATS tabs, a grid of your karts (or hats), EQUIP, and the kart you drive
--     with its hat on a card.
--   howTo: the 3-step tip over a match (drive, grab a "?", fire), one card at a time.
-- (the same shapes as UiScreens.Piece / UiScreens.Screen; no require, so Lune tests load it)
export type Piece = {
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	anchor: string?,
	tone: string?,
	text: string?,
	tap: boolean?,
	main: boolean?,
	world: boolean?,
	instead: string?,
	inner: { Piece }?,
}
export type Screen = {
	id: string,
	n: number,
	title: string,
	kind: string,
	gameplay: boolean,
	pieces: { Piece },
}

local function p(name: string, x: number, y: number, w: number, h: number, more: any?): Piece
	local out: any = { name = name, x = x, y = y, w = w, h = h }
	if more then
		for k, v in more do
			out[k] = v
		end
	end
	return out :: Piece
end

local SmashScreens = {}

local LIST: { Screen } = {
	{
		id = "matchEnd",
		n = 101,
		title = "Round over",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 178, 4, 400, 58, { anchor = "t" }),
			p("Wins", 178, 62, 400, 34, { anchor = "t" }),
			-- the winner's kart on show in the middle, rays behind it
			p("Winner", 258, 100, 240, 170, { anchor = "c" }),
			-- 1st, 2nd, 3rd with smashes
			p("Top3", 0, 104, 230, 168, { anchor = "l" }),
			-- what you got: coins, XP, your place
			p("Rewards", 526, 104, 230, 168, { anchor = "r" }),
			p("Count", 128, 292, 500, 40, { anchor = "b" }),
			p("Leave", 646, 334, 110, 48, { anchor = "br", tone = "white", text = "LEAVE" }),
		},
	},
	{
		id = "customize",
		n = 103,
		title = "Customize",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 8, 40, 496, 328, {
				anchor = "l",
				text = "Customize",
				inner = {
					p("Tabs", 14, 14, 240, 44, { tap = true }),
					p("Grid", 14, 68, 468, 196),
					p("Equip", 14, 272, 180, 50, { tone = "lime", text = "EQUIP", main = true }),
					p("Note", 206, 276, 276, 42),
				},
			}),
			-- the kart you drive, with its hat, on a glowing card
			p("Card", 540, 12, 196, 356, { anchor = "r" }),
		},
	},
	{
		id = "howTo",
		n = 102,
		title = "How to smash",
		kind = "hud",
		gameplay = true,
		pieces = {
			-- right side, between the feed and FIRE: never over the middle of the road, and 20 off
			-- the edge (its right edge was cut on a phone, audit R6-4)
			p("Tip", 516, 108, 220, 76, { anchor = "r", tap = true }),
			-- the arrow for each step: just right of the stick corner pointing left at it (the
			-- scoreboard sits above the corner), and just left of FIRE pointing at it
			p("ArrowDrive", 148, 290, 56, 56, { anchor = "bl" }),
			p("ArrowFire", 556, 276, 56, 56, { anchor = "br" }),
		},
	},
}

SmashScreens.LIST = LIST

local byId: { [string]: Screen } = {}
for _, s in LIST do
	byId[s.id] = s
end

function SmashScreens.get(id: string): Screen
	local s = byId[id]
	assert(s, "no smash screen " .. id)
	return s
end

-- One piece; "Rewards.Coins" reaches into a window's own pieces.
function SmashScreens.piece(id: string, path: string): Piece
	local s = SmashScreens.get(id)
	local function find(list: { Piece }, name: string): Piece?
		for _, piece in list do
			if piece.name == name then
				return piece
			end
		end
		return nil
	end
	local dot = path:find(".", 1, true)
	local got: Piece?
	if dot then
		local outer = find(s.pieces, path:sub(1, dot - 1))
		got = outer and outer.inner and find(outer.inner, path:sub(dot + 1))
	else
		got = find(s.pieces, path)
	end
	assert(got, `no piece {path} on {id}`)
	return got
end

-- The how-to's 3 steps, in order: the big words, one small line, and the arrow piece (if any).
SmashScreens.STEPS = {
	-- (rot: the arrow drawing points right; 180 = left)
	{
		id = "drive",
		words = "DRIVE!",
		help = "Move the stick to drive.",
		arrow = "ArrowDrive",
		rot = 180,
	},
	{ id = "grab", words = "GRAB A ?", help = "Drive into a red ? box.", arrow = nil, rot = 0 },
	{
		id = "fire",
		words = "TAP FIRE!",
		help = "Smash the other cars!",
		arrow = "ArrowFire",
		rot = 0,
	},
}
-- The customize window's EQUIP button for the picked item: its words and whether it works.
-- item = { own: boolean?, on: boolean? } (a kart in your garage is always owned); offable: the
-- thing on can be taken off (a hat; you always drive some kart)
function SmashScreens.equipButton(
	item: { own: boolean?, on: boolean? }?,
	offable: boolean?
): (string, boolean)
	if not item then
		return "EQUIP", false
	elseif item.own == false then
		return "LOCKED", false
	elseif item.on then
		if offable then
			return "TAKE OFF", true
		end
		return "ON", false
	end
	return "EQUIP", true
end

-- The tip card to show for a step (0 = none): TAP FIRE! only once you hold a weapon (a kid who
-- skipped GRAB A ? sees nothing until a box gives one)
function SmashScreens.cardFor(step: number, weapon: string): number
	if step == 3 and weapon == "" then
		return 0
	end
	return step
end

-- The crate words a Smash kid reads (no training, racing or stats: a kart is a look)
SmashScreens.WORDS = {
	crateNote = "1 new kart per crate.",
	garageFull = "No room for karts.",
	revealNote = "New kart! Try it in CUSTOMIZE.",
}

-- A 3D kart on a screen (KartView: the crate reveal, the round's winner) fills this much of its
-- view's width (auditor R6-5: it was a speck).
SmashScreens.KART_FILL = 0.7

-- How far back (studs) the camera stands from the middle of a kart w x h x l studs so that, turning,
-- it fills `fill` of a view `aspect` wide (width / height) with a `fov` degree (up-down) camera,
-- and never runs off the top or bottom.
function SmashScreens.kartDistance(
	w: number,
	h: number,
	l: number,
	fov: number,
	aspect: number,
	fill: number
): number
	local tanV = math.tan(math.rad(fov) / 2)
	local tanH = tanV * math.max(aspect, 0.1)
	local r = math.sqrt(w * w + l * l) / 2 -- (its widest, side on while it turns)
	local byWidth = r / (fill * tanH)
	local byHeight = (h / 2) / (0.85 * tanV)
	return math.max(byWidth, byHeight, 0.1)
end

SmashScreens.DRIVE_STUDS = 12 -- driven this far = the drive step is done
-- GRAB A ? only in a kid's first seconds of the tips: a minute in it read as late and sat over a
-- box (audit R6-4); after this the next tip is TAP FIRE!, shown once a box gives a weapon
SmashScreens.GRAB_SECS = 15

-- Which how-to step shows now (4 = all done), from the one showing and what the kid has done:
-- moved (studs from where the tip started), weapon ("" = none), fired (ammo went down), secs
-- (since the tips started; GRAB A ? is over at GRAB_SECS).
-- Doing a later thing first skips ahead: a kid who grabs a box before the tip says so never
-- sees GRAB A ?.
function SmashScreens.step(
	at: number,
	did: { moved: number, weapon: string, fired: boolean, secs: number? }
): number
	local s = math.clamp(at, 1, 4)
	if did.fired then
		return 4
	end
	if s <= 2 and did.weapon ~= "" then
		s = 3
	end
	if s == 1 and did.moved >= SmashScreens.DRIVE_STUDS then
		s = 2
	end
	if s == 2 and (did.secs or 0) >= SmashScreens.GRAB_SECS then
		s = 3
	end
	return s
end

-- One place rule for the place chip and the board (audit R7-6: the chip said 3RD while the
-- board had the kid 5th): a kart's place is 1 + the karts with MORE smashes, so karts tied on
-- smashes share it. Sets .rank on each entry ({ smashes, me? }) and returns your place (nil when
-- you're not on the board).
function SmashScreens.rank(list: { { [string]: any } }): number?
	local mine: number? = nil
	for _, e in list do
		local ahead = 0
		for _, o in list do
			if (o.smashes or 0) > (e.smashes or 0) then
				ahead += 1
			end
		end
		e.rank = ahead + 1
		if e.me == true then
			mine = e.rank
		end
	end
	return mine
end

return SmashScreens
