--!strict
-- Car VS Car screens (carter 10-27, CarVsCar_UI_Handoff.md section 6): where every piece of the
-- 17 screens sits, in design px on the 756 x 390 canvas (the 844 x 390 phone inside its 44 px
-- side safe area). client/Ui/Screens place things from here, so tests/ui_screens.test.luau can
-- check the rules on the same numbers: inside the safe area, the move-stick corner left free on
-- gameplay screens, big enough to tap, short ALL CAPS button words, one main action, odds on the
-- crate window.
--
-- A piece: x, y, w, h; `anchor` is the corner it holds to on screens of other shapes (tl, t, tr,
-- l, c, r, bl, b, br; default tl). Buttons have `tone` and `text`; `tap` marks other things you
-- tap. Windows list their own pieces in `inner`, in px from the window body's top-left.

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
	world: boolean?, -- a sign in the 3D world, not on the screen (shown in the viewer only)
	instead: string?, -- shown in the live game in place of that piece (never both on screen)
	inner: { Piece }?,
}
export type Screen = {
	id: string,
	n: number, -- its number in the spec
	title: string,
	kind: string, -- "hud" (over the game), "window", "full" (covers the game)
	gameplay: boolean, -- the move stick is on screen
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

local function button(
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	tone: string,
	text: string,
	more: any?
): Piece
	local extra: any = { tone = tone, text = text }
	if more then
		for k, v in more do
			extra[k] = v
		end
	end
	return p(name, x, y, w, h, extra)
end

local UiScreens = {}

UiScreens.W = 756
UiScreens.H = 390
UiScreens.STICK = 140 -- the bottom-left square for the move stick
-- around a window body: the title sits 40 px above it, the X hangs 20 px off the right and 24 px
-- above, and the blue slab peeks 8 px out on the left
UiScreens.WINDOW_TOP = 40
UiScreens.WINDOW_RIGHT = 20
UiScreens.WINDOW_LEFT = 8

local LIST: { Screen } = {
	{
		id = "loading",
		n = 0,
		title = "Loading",
		kind = "full",
		gameplay = false,
		pieces = {
			p("CarLeft", 90, 96, 170, 110, { anchor = "t" }),
			p("CarMid", 278, 66, 200, 140, { anchor = "t" }),
			p("CarRight", 496, 96, 170, 110, { anchor = "t" }),
			p("Bar", 150, 252, 456, 32, { anchor = "b" }),
			p("Words", 150, 288, 456, 28, { anchor = "b" }),
			p("Tip", 128, 334, 500, 40, { anchor = "b" }),
		},
	},
	{
		id = "pick",
		n = 1,
		title = "Pick your first car",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 28, 10, 700, 46, { anchor = "t" }),
			p("Card1", 21, 80, 226, 214, { anchor = "t", tap = true }),
			p("Card2", 265, 80, 226, 214, { anchor = "t", tap = true }),
			p("Card3", 509, 80, 226, 214, { anchor = "t", tap = true }),
			button("Go", 258, 312, 240, 66, "lime", "LET'S GO!", { anchor = "b", main = true }),
		},
	},
	{
		id = "plot",
		n = 2,
		title = "Plot",
		kind = "hud",
		gameplay = true,
		pieces = {
			p("NextUp", 233, 20, 290, 74, { anchor = "t" }),
			p("Coins", 548, 8, 204, 50, { anchor = "tr", tap = true }),
			-- (the live game: coins toward the next station or crate, under the coins' plate)
			p("Next", 568, 60, 184, 44, { anchor = "tr", tap = true, instead = "MyCar" }),
			p("Garage", 12, 66, 62, 62, { anchor = "tl", tap = true, text = "GARAGE" }),
			p("Crates", 82, 66, 62, 62, { anchor = "tl", tap = true, text = "CRATES" }),
			p("Shop", 12, 152, 62, 62, { anchor = "tl", tap = true, text = "SHOP" }),
			p("League", 82, 152, 62, 62, { anchor = "tl", tap = true, text = "LEAGUE" }),
			p("MyCar", 530, 64, 218, 156, { anchor = "tr" }),
			button("Coach", 644, 284, 92, 92, "pink", "COACH", { anchor = "br" }),
			-- (the live game: join the next BIG RACE, bottom middle by the thumbs, off the stick;
			-- today's jobs at the right edge, off the speed tracks)
			button("Race", 288, 312, 180, 64, "lime", "RACE!", { anchor = "b", main = true }),
			p("Jobs", 640, 228, 112, 44, { anchor = "tr", tap = true }),
			-- (ask friends in: left of JOBS, over the speed tracks' edge, clear of COACH)
			p("Invite", 522, 228, 112, 44, { anchor = "tr", tap = true }),
			p("SignPower", 150, 110, 150, 40, { world = true }),
			p("SignAir", 320, 190, 130, 40, { world = true }),
			p("SignSpeed", 250, 290, 150, 40, { world = true }),
		},
	},
	{
		id = "start",
		n = 3,
		title = "Race start",
		kind = "hud",
		gameplay = true,
		pieces = {
			p("Lights", 305, 14, 146, 58, { anchor = "t" }),
			p("Go", 178, 96, 400, 140, { anchor = "c" }),
			p("Lap", 0, 16, 124, 46, { anchor = "tl" }),
		},
	},
	{
		id = "race",
		n = 4,
		title = "Race",
		kind = "hud",
		gameplay = true,
		pieces = {
			p("Lap", 0, 14, 124, 46, { anchor = "tl" }),
			p("Place", 253, 4, 250, 66, { anchor = "t" }),
			p("Top3", 0, 70, 160, 102, { anchor = "tl" }),
			button("Boost", 618, 244, 118, 118, "boost", "BOOST", { anchor = "br" }),
		},
	},
	{
		id = "podium",
		n = 5,
		title = "Podium",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 10, 8, 330, 54, { anchor = "tl" }),
			p("Steps", 18, 110, 450, 270, { anchor = "bl" }),
			p("Rewards", 512, 46, 236, 150, {
				anchor = "tr",
				inner = {
					p("Coins", 14, 30, 208, 46),
					p("Trophies", 14, 84, 208, 46),
				},
			}),
			-- "+N SPD from training!" between Rewards and the buttons
			p("Trained", 512, 202, 236, 34, { anchor = "tr" }),
			button("Next", 512, 244, 236, 66, "lime", "NEXT RACE", { anchor = "br", main = true }),
			button("Back", 512, 322, 236, 50, "white", "BACK TO PLOT", { anchor = "br" }),
		},
	},
	{
		id = "crates",
		n = 6,
		title = "Crates",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 48, 40, 660, 332, {
				anchor = "c",
				text = "Crates",
				inner = {
					p("Choice1", 96, 26, 64, 82, { tap = true }),
					p("Choice2", 172, 26, 64, 82, { tap = true }),
					p("Choice3", 248, 26, 64, 82, { tap = true }),
					p("Crate", 134, 112, 140, 128),
					p("Tag", 52, 120, 110, 26),
					button("Open", 84, 256, 240, 66, "lime", "OPEN", { main = true }),
					p("Section", 410, 26, 234, 22),
					p("Odds", 410, 54, 234, 146),
					p("Note", 410, 206, 234, 40),
					p("Coins", 446, 256, 162, 44),
				},
			}),
		},
	},
	{
		id = "reveal",
		n = 7,
		title = "Crate reveal",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 178, 6, 400, 62, { anchor = "t" }),
			p("Card", 280, 74, 196, 290, { anchor = "c" }),
			button("Cool", 558, 230, 190, 66, "lime", "COOL!", { anchor = "br", main = true }),
			button("Again", 508, 312, 240, 56, "white", "OPEN ANOTHER", { anchor = "br" }),
			p("Note", 8, 300, 210, 62, { anchor = "bl" }),
		},
	},
	{
		id = "garage",
		n = 8,
		title = "Garage",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 8, 40, 496, 328, {
				anchor = "l",
				text = "Garage",
				inner = {
					p("OnTrack", 14, 22, 468, 20),
					p("OnSlots", 147, 46, 202, 62),
					p("Mine", 14, 114, 468, 20),
					p("Grid", 14, 138, 468, 128),
					button("EquipBest", 14, 272, 180, 50, "lime", "EQUIP BEST", { main = true }),
					p("Room", 302, 276, 180, 42),
				},
			}),
			p("Card", 540, 12, 196, 356, {
				anchor = "r",
				inner = {
					button("Equip", 10, 302, 84, 46, "lime", "EQUIP"),
					button("Delete", 102, 302, 84, 46, "danger", "DELETE"),
				},
			}),
		},
	},
	{
		id = "shop",
		n = 9,
		title = "Shop",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Title", 0, 4, 110, 54, { anchor = "tl" }),
			p("Tabs", 116, 10, 430, 44, { anchor = "tl", tap = true }),
			button("Close", 700, 4, 56, 56, "danger", "X", { anchor = "tr" }),
			p("Offer", 0, 64, 500, 158, {
				anchor = "l",
				inner = {
					button("Buy", 116, 102, 150, 50, "lime", "R$ ???", { main = true }),
				},
			}),
			p("Sale", 520, 64, 236, 158, {
				anchor = "r",
				inner = {
					button("Buy", 80, 106, 144, 44, "lime", "3,500"),
				},
			}),
			p("Mini1", 0, 228, 180, 138, { anchor = "bl" }),
			p("Mini2", 192, 228, 180, 138, { anchor = "b" }),
			p("Mini3", 384, 228, 180, 138, { anchor = "b" }),
			p("Mini4", 576, 228, 180, 138, { anchor = "br" }),
			p("Footer", 0, 370, 756, 18, { anchor = "b" }),
		},
	},
	{
		id = "leagueUp",
		n = 10,
		title = "League up",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 128, 8, 500, 60, { anchor = "t" }),
			p("Old", 124, 90, 124, 158, { anchor = "c" }),
			p("Arrow", 262, 150, 64, 46, { anchor = "c" }),
			p("New", 350, 70, 200, 230, { anchor = "c" }),
			p("Reward", 168, 312, 210, 58, { anchor = "b" }),
			button("Awesome", 392, 308, 210, 66, "go", "AWESOME!", { anchor = "b", main = true }),
		},
	},
	{
		id = "daily",
		n = 11,
		title = "Daily rewards",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 18, 44, 716, 300, {
				anchor = "c",
				text = "Daily Rewards",
				inner = {
					p("Help", 16, 26, 470, 24),
					p("Streak", 532, 20, 172, 38),
					p("Tiles", 16, 66, 566, 118),
					p("Day7", 592, 66, 112, 118),
					button("Claim", 240, 210, 240, 66, "lime", "CLAIM DAY 3", { main = true }),
				},
			}),
		},
	},
	{
		id = "book",
		n = 12,
		title = "Car book",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 12, 40, 724, 336, {
				anchor = "c",
				text = "Car Book",
				inner = {
					p("Tabs", 14, 22, 400, 44, { tap = true }),
					p("Found", 484, 28, 226, 30),
					p("Milestones", 36, 70, 652, 50),
					p("Grid", 14, 126, 696, 198),
				},
			}),
		},
	},
	{
		id = "settings",
		n = 13,
		title = "Settings",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 98, 52, 560, 296, {
				anchor = "c",
				text = "Settings",
				inner = {
					p("Music", 18, 28, 257, 54, { tap = true }),
					p("Sounds", 285, 28, 257, 54, { tap = true }),
					p("Vibrate", 18, 92, 257, 54, { tap = true }),
					p("Low", 285, 92, 257, 54, { tap = true }),
					p("Camera", 18, 156, 524, 54, { tap = true }),
					button("Codes", 18, 226, 257, 50, "blue", "CODES"),
					button("Reset", 285, 226, 257, 50, "white", "RESET"),
				},
			}),
		},
	},
	{
		id = "leaderboard",
		n = 14,
		title = "Leaderboard",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 58, 42, 640, 320, {
				anchor = "c",
				text = "Top Racers",
				inner = {
					p("Tabs", 130, 22, 380, 44, { tap = true }),
					p("Row1", 14, 74, 612, 48),
					p("Row2", 14, 128, 612, 48),
					p("Row3", 14, 182, 612, 48),
					p("Dots", 14, 234, 612, 16),
					p("Me", 14, 256, 612, 50),
				},
			}),
		},
	},
	{
		id = "quests",
		n = 15,
		title = "Quests",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 68, 42, 620, 326, {
				anchor = "c",
				text = "Quests",
				inner = {
					p("Tabs", 14, 22, 240, 44, { tap = true }),
					p("Timer", 420, 26, 186, 38),
					p("Row1", 14, 76, 592, 72),
					p("Row2", 14, 156, 592, 72),
					p("Row3", 14, 236, 592, 72),
				},
			}),
		},
	},
	{
		id = "popups",
		n = 16,
		title = "Popups",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 253, 94, 250, 202, {
				anchor = "c",
				inner = {
					p("Icon", 97, 8, 56, 56),
					p("Title", 10, 66, 230, 30),
					p("Text", 10, 98, 230, 22),
					button("Yes", 10, 136, 111, 50, "lime", "YES"),
					button("No", 129, 136, 111, 50, "danger", "NO"),
				},
			}),
		},
	},
	-- Car VS Car SMASH (10-28): the match HUD: your place and the scoreboard top left, the clock and
	-- your health top middle, the kill list top right, one big FIRE thumb button (VIDEO-STUDY)
	{
		id = "match",
		n = 17,
		title = "Match",
		kind = "hud",
		gameplay = true,
		pieces = {
			p("Place", 0, 8, 150, 48, { anchor = "tl" }),
			-- (the top 3 + you, 27 px a row: level badge, name, smashes, clear of the stick corner;
			-- words 18 tall so they read 14 px on a 667x375 phone, Lead road to 9/10 item 5)
			-- (224 wide: any wider and it sits under the SMASHED BY words, SmashJuice.WORDS)
			p("Board", 0, 60, 224, 108, { anchor = "tl" }),
			p("Feed", 486, 8, 270, 88, { anchor = "tr" }),
			p("Clock", 323, 4, 110, 36, { anchor = "t" }),
			p("Health", 250, 44, 230, 30, { anchor = "t" }),
			-- the short flash words (STUCK - BACK TO START...), drawn by client/Hud: under the health
			-- bar, clear of the board and the feed (they sat on the health bar, Studio round 5)
			p("Words", 244, 110, 264, 34, { anchor = "t" }),
			button("Fire", 618, 244, 118, 118, "danger", "FIRE", { anchor = "br" }),
		},
	},
	-- the match HUD on a phone (carter 10-29: "can't see on mobile, too cluttered"): the Smash
	-- Karts minimum, every piece at an edge and the middle half of the screen empty. A tiny 2/8
	-- chip and your row + the leader top left, the clock over a slim health bar top centre, two
	-- small kill lines top right, FIRE (with the weapon and ammo on it) bottom right.
	{
		id = "matchTouch",
		n = 18,
		title = "Match (phone)",
		kind = "hud",
		gameplay = true,
		pieces = {
			p("Place", 6, 6, 74, 30, { anchor = "tl" }),
			p("Board", 6, 40, 170, 47, { anchor = "tl" }),
			-- (the top centre ends by 39: on a 667x375 phone under the 58 px top bar that is just
			-- above the middle half; the kill lines stay in the right quarter, even on a tall phone)
			p("Feed", 566, 6, 190, 56, { anchor = "tr" }),
			p("Clock", 336, 3, 84, 27, { anchor = "t" }),
			p("Health", 318, 32, 120, 7, { anchor = "t" }),
			p("Words", 228, 54, 300, 30, { anchor = "t" }),
			-- (112: 88 px on a 667x375 phone)
			button("Fire", 624, 260, 112, 112, "danger", "FIRE", { anchor = "br" }),
		},
	},
}

UiScreens.LIST = LIST

local byId: { [string]: Screen } = {}
for _, s in LIST do
	byId[s.id] = s
end

function UiScreens.get(id: string): Screen
	local s = byId[id]
	assert(s, "no screen " .. id)
	return s
end

local function find(list: { Piece }, name: string): Piece?
	for _, piece in list do
		if piece.name == name then
			return piece
		end
	end
	return nil
end

-- One piece of a screen; "Window.Open" reaches into a window's own pieces.
function UiScreens.piece(id: string, path: string): Piece
	local s = UiScreens.get(id)
	local dot = path:find(".", 1, true)
	if dot then
		local outer = find(s.pieces, path:sub(1, dot - 1))
		local got = outer and outer.inner and find(outer.inner, path:sub(dot + 1))
		assert(got, `no piece {path} on {id}`)
		return got
	end
	local got = find(s.pieces, path)
	assert(got, `no piece {path} on {id}`)
	return got
end

-- Do two pieces cover each other?
function UiScreens.overlap(a: Piece, b: Piece): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- The move stick's corner, as a piece.
function UiScreens.stickZone(): Piece
	return p("Stick", 0, UiScreens.H - UiScreens.STICK, UiScreens.STICK, UiScreens.STICK)
end

-- What a piece's anchor means as an AnchorPoint (x, y from 0 to 1).
UiScreens.ANCHORS = {
	tl = { 0, 0 },
	t = { 0.5, 0 },
	tr = { 1, 0 },
	l = { 0, 0.5 },
	c = { 0.5, 0.5 },
	r = { 1, 0.5 },
	bl = { 0, 1 },
	b = { 0.5, 1 },
	br = { 1, 1 },
}
function UiScreens.anchor(piece: Piece): (number, number)
	local a = UiScreens.ANCHORS[piece.anchor or "tl"]
	assert(a, "bad anchor " .. tostring(piece.anchor))
	return a[1], a[2]
end

return UiScreens
