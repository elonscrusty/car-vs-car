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
			p("Top3", 0, 104, 250, 168, { anchor = "l" }),
			-- what you got: coins, XP, your place
			p("Rewards", 506, 104, 250, 168, { anchor = "r" }),
			p("Count", 128, 292, 500, 40, { anchor = "b" }),
			-- (56 tall: 44 px, a thumb, on a phone)
			p("Leave", 636, 328, 120, 56, { anchor = "br", tone = "white", text = "LEAVE" }),
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
					-- (64 tall: each tab 56, 44 px on a phone)
					p("Tabs", 14, 14, 240, 64, { tap = true }),
					p("Grid", 14, 86, 468, 172),
					p("Equip", 14, 266, 180, 56, { tone = "lime", text = "EQUIP", main = true }),
					p("Note", 206, 270, 276, 48),
				},
			}),
			-- the kart you drive, with its hat, on a glowing card
			p("Card", 540, 12, 196, 356, { anchor = "r" }),
		},
	},
	-- a phone's lobby (carter 10-29: too cluttered): one MENU tile opens this, the rest of the
	-- lobby's buttons (CUSTOMIZE, CRATES, SHOP, LEAGUE, SPIN, JOBS, INVITE) in two rows of 4
	{
		id = "menu",
		n = 104,
		title = "Menu",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Window", 158, 60, 440, 270, {
				anchor = "c",
				text = "Menu",
				inner = {
					p("Grid", 20, 18, 400, 182),
				},
			}),
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
			-- DRIVE! sits bottom left, just over the stick it explains: on the right it covered
			-- the nearest ? box at GO, where the kid should drive (audit R8-4)
			p("TipDrive", 8, 172, 220, 72, { anchor = "l", tap = true }),
			-- TAP FIRE! just above the FIRE button it explains: higher up on the right it
			-- half-covered a ? box (Studio round 10)
			p("TipFire", 516, 162, 220, 76, { anchor = "br", tap = true }),
			-- the arrow for each step: just right of the stick corner pointing left at it (the
			-- scoreboard sits above the corner), and just left of FIRE pointing at it
			p("ArrowDrive", 148, 290, 56, 56, { anchor = "bl" }),
			p("ArrowFire", 556, 276, 56, 56, { anchor = "br" }),
		},
	},
	-- carter's kit v41 windows (ui-kit/v41/WINDOWS-PLAN.md), in the kit pictures' places
	-- the shop: only tabs with real items (Lead 10-29: no COINS or BOOSTS saying SOON), so one
	-- CRATES tab over the crates you can buy (SmashScreens.shopTiles places them in the panel)
	{
		id = "kitShop",
		n = 105,
		title = "Shop",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Coins", 8, 6, 170, 44, { anchor = "tl" }),
			p("Tabs", 268, 4, 220, 52, { anchor = "t", tap = true }),
			p("Close", 700, 2, 52, 52, { anchor = "tr", tap = true }),
			-- (16 px clear of the bottom: the panel's ink line sits 6 px outside it, Studio r51)
			p("Panel", 8, 66, 740, 308, { anchor = "c" }),
		},
	},
	-- one crate's odds, always before OPEN: the big crate and OPEN left, the odds right
	{
		id = "kitOdds",
		n = 106,
		title = "Crate odds",
		kind = "window",
		gameplay = false,
		pieces = {
			-- (8 in: the tilted X lost ~5 px on a 667 phone, Studio r52)
			p("Close", 8, 0, 52, 52, { anchor = "tl", tap = true }),
			p("Coins", 72, 4, 160, 44, { anchor = "tl" }),
			p("Crate", 60, 56, 270, 214, { anchor = "l" }),
			p(
				"Open",
				80,
				284,
				230,
				70,
				{ anchor = "b", tone = "lime", text = "OPEN", main = true }
			),
			p("Title", 400, 0, 340, 56, { anchor = "tr" }),
			p("Odds", 400, 62, 340, 248, { anchor = "r" }),
			p("Note", 400, 316, 340, 60, { anchor = "br" }),
		},
	},
	-- a new kart from a crate: its card (rarity ribbon, the 3D kart, NEW KART!) over the open crate
	{
		id = "kitReveal",
		n = 107,
		title = "Crate reveal",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Card", 258, 6, 240, 250, { anchor = "t" }),
			p("Crate", 303, 262, 150, 128, { anchor = "b" }),
			p("SideL", 0, 120, 130, 120, { anchor = "l" }),
			p("SideR", 626, 70, 130, 120, { anchor = "r" }),
			-- (14 in, the buttons 12 in: the panel line and the button rims poked past a 667 phone, r56)
			p("Note", 14, 300, 206, 62, { anchor = "bl" }),
			p(
				"Cool",
				554,
				228,
				190,
				66,
				{ anchor = "br", tone = "lime", text = "COOL!", main = true }
			),
			p("Again", 504, 306, 240, 58, { anchor = "br", tone = "white", text = "OPEN ANOTHER" }),
		},
	},
	-- the daily gift: 7 day cards (day 7 gold), CLAIM and the streak track under them
	{
		id = "kitDaily",
		n = 108,
		title = "Daily",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Close", 700, 0, 52, 52, { anchor = "tr", tap = true }),
			-- (today's glow reaches ~10 px past its card: inset 12, clear of Close and CLAIM)
			p("Days", 12, 62, 732, 180, { anchor = "t" }),
			p(
				"Claim",
				8,
				254,
				250,
				66,
				{ anchor = "bl", tone = "lime", text = "CLAIM", main = true }
			),
			-- (CLAIM is wide enough for a "+1,000" chip and still reads)
			p("Track", 270, 268, 478, 38, { anchor = "b" }),
			p("Note", 270, 318, 478, 40, { anchor = "b" }),
		},
	},
	-- today's jobs: a row each (icon, words, bar, the coins it pays)
	{
		id = "kitQuests",
		n = 109,
		title = "Jobs",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Title", 8, 0, 240, 54, { anchor = "tl" }),
			p("Timer", 260, 8, 300, 40, { anchor = "t" }),
			p("Close", 700, 0, 52, 52, { anchor = "tr", tap = true }),
			p("List", 8, 62, 740, 322, { anchor = "b" }),
		},
	},
	-- the trophies board: GLOBAL (the saved board) / FRIENDS (friends in this server), 5 rows
	{
		id = "kitBoard",
		n = 110,
		title = "Leaderboard",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Mine", 8, 6, 200, 44, { anchor = "tl" }),
			p("Tabs", 248, 4, 260, 52, { anchor = "t", tap = true }),
			p("Close", 700, 0, 52, 52, { anchor = "tr", tap = true }),
			-- (ends 16 px above the canvas bottom: its light line is drawn ~4 px outside, Studio r65)
			p("Panel", 8, 64, 740, 310, { anchor = "b" }),
		},
	},
	-- LEAGUE UP!: the new badge with wings and rays, the league's name and pay, arrows rising
	{
		id = "kitLeagueUp",
		n = 111,
		title = "League up",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Title", 178, 2, 400, 70, { anchor = "t" }),
			p("Badge", 293, 74, 170, 170, { anchor = "c" }),
			p("Name", 238, 250, 280, 52, { anchor = "b" }),
			-- (off the bottom edge, Studio r56)
			p(
				"Awesome",
				283,
				310,
				190,
				60,
				{ anchor = "b", tone = "go", text = "AWESOME!", main = true }
			),
			p("ArrowL1", 20, 230, 72, 150, { anchor = "bl" }),
			p("ArrowL2", 104, 282, 52, 100, { anchor = "bl" }),
			p("ArrowR2", 600, 282, 52, 100, { anchor = "br" }),
			p("ArrowR1", 664, 230, 72, 150, { anchor = "br" }),
		},
	},
	-- the garage (CUSTOMIZE): KARTS / HATS tabs, a 4-wide grid of cards with rarity dots, the
	-- picked one big in 3D on the right, EQUIP under it (karts are looks: no stat bars)
	{
		id = "kitGarage",
		n = 112,
		title = "Garage",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Tabs", 8, 4, 300, 52, { anchor = "tl", tap = true }),
			p("Close", 700, 0, 52, 52, { anchor = "tr", tap = true }),
			p("Grid", 8, 64, 500, 318, { anchor = "bl" }),
			p("Show", 524, 64, 224, 228, { anchor = "r" }),
			p(
				"Equip",
				524,
				302,
				224,
				70,
				{ anchor = "br", tone = "lime", text = "EQUIP", main = true }
			),
		},
	},
	-- settings: only what the game can really do (music, sounds, shadows, name tags)
	{
		id = "kitSettings",
		n = 113,
		title = "Settings",
		kind = "window",
		gameplay = false,
		pieces = {
			p("Title", 8, 0, 300, 56, { anchor = "tl" }),
			p("Close", 700, 0, 52, 52, { anchor = "tr", tap = true }),
			-- the sliders (400 wide) and toggles (324) side by side in one piece, so a wide
			-- computer keeps them together in the middle (one piece each hugged the edges, Studio r60)
			-- (ends 16 px above the canvas bottom, as the board: at 8 its line sat 4.5 px off, r65)
			p("Body", 8, 66, 740, 308, { anchor = "b" }),
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
export type Step = {
	id: string,
	words: string,
	help: string,
	arrow: string?,
	rot: number,
	tip: string?, -- its card's piece (default "Tip")
}
local STEPS: { Step } = {
	-- (rot: the arrow drawing points right; 180 = left)
	{
		id = "drive",
		words = "DRIVE!",
		help = "Move the stick to drive.",
		arrow = "ArrowDrive",
		rot = 180,
		tip = "TipDrive",
	},
	{ id = "grab", words = "GRAB A ?", help = "Drive into a red ? box.", arrow = nil, rot = 0 },
	{
		id = "fire",
		words = "TAP FIRE!",
		help = "Smash the other cars!",
		arrow = "ArrowFire",
		rot = 0,
		tip = "TipFire",
	},
}
SmashScreens.STEPS = STEPS
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

-- ===== the kit shop and crates =====

-- The crates on the shop's CRATES tab: a free one first while you have any, then the 3 you buy
-- with coins (Crates.SHOP; their prices come from Crates.price, never written here).
export type CrateTile = { kind: string, word: string, rarity: string }
SmashScreens.CRATE_TILES = {
	{ kind = "free", word = "FREE CRATE", rarity = "common" },
	{ kind = "basic", word = "SMALL CRATE", rarity = "common" },
	{ kind = "big", word = "BIG CRATE", rarity = "rare" },
	{ kind = "mega", word = "MEGA CRATE", rarity = "epic" },
} :: { CrateTile }

function SmashScreens.crateTiles(free: number): { CrateTile }
	local out: { CrateTile } = {}
	for _, t in SmashScreens.CRATE_TILES do
		if t.kind ~= "free" or free > 0 then
			table.insert(out, t)
		end
	end
	return out
end

-- Where n tiles sit in the shop panel (pw wide): the same size side by side, in the middle.
export type Box = { x: number, y: number, w: number, h: number }
function SmashScreens.shopTiles(n: number, pw: number): { Box }
	local gap, edge = 14, 16
	local w = math.min(216, (pw - 2 * edge - (n - 1) * gap) / math.max(n, 1))
	local x0 = (pw - (n * w + (n - 1) * gap)) / 2
	local out: { Box } = {}
	for i = 1, n do
		out[i] = { x = x0 + (i - 1) * (w + gap), y = 16, w = w, h = 236 }
	end
	return out
end

-- A crate's odds rows, rarest last, from Crates.odds (by CarCatalog id: legend), as the screen's
-- rarity ids; a 0% row is a word to read that never matters, so it is left out.
export type OddsRow = { rarity: string, chance: number }
local ODDS_ORDER =
	{ { "common", "common" }, { "rare", "rare" }, { "epic", "epic" }, { "legend", "legendary" } }
function SmashScreens.oddsRows(odds: { [string]: number }): { OddsRow }
	local out: { OddsRow } = {}
	for _, r in ODDS_ORDER do
		local chance = odds[r[1]] or 0
		if chance > 0 then
			table.insert(out, { rarity = r[2], chance = chance })
		end
	end
	return out
end

-- The daily gift's 7 days, from Profile.DAILY (coins a day): "got" before today, "today" (its
-- coins as the server paid them, a boost included; crate: a free crate came too), "later" after.
export type Day = { day: number, coins: number, state: string, crate: boolean }
function SmashScreens.dailyDays(
	daily: { number },
	today: number,
	coins: number?,
	crate: boolean?
): { Day }
	local out: { Day } = {}
	local t = math.clamp(today, 1, #daily)
	for i, c in daily do
		out[i] = {
			day = i,
			coins = if i == t then coins or c else c,
			state = if i < t then "got" elseif i == t then "today" else "later",
			crate = i == t and crate == true,
		}
	end
	return out
end

-- A job line's icon (DailyJobs' words; Smash jobs first)
function SmashScreens.jobIcon(text: string): string
	local t = string.lower(text)
	if t:find("smash") then
		return "nuke"
	elseif t:find("crate") then
		return "crate"
	elseif t:find("match") or t:find("top 3") or t:find("race") then
		return "trophy"
	elseif t:find("spin") or t:find("gumball") then
		return "mystery"
	end
	return "coin"
end

-- The FRIENDS tab: you and your friends in this server ({ userId, name, score, me? }), most
-- trophies first (ties: you first, then by name), at most `limit`.
export type BoardRow = { userId: number, name: string, score: number, me: boolean? }
function SmashScreens.friendRows(list: { BoardRow }, limit: number): { BoardRow }
	local out = table.clone(list)
	table.sort(out, function(a: BoardRow, b: BoardRow)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if (a.me == true) ~= (b.me == true) then
			return a.me == true
		end
		return a.name < b.name
	end)
	while #out > limit do
		table.remove(out)
	end
	return out
end

-- A rarity as dots on a card: how many of the 4 are lit (common 1 .. legendary 4).
function SmashScreens.rarityDots(rarity: string?): number
	local r = if rarity == "legend" then "legendary" else rarity
	for i, id in { "common", "rare", "epic", "legendary" } do
		if r == id then
			return i
		end
	end
	return 1
end

-- The garage grid's card boxes: 4 across in a w-wide area (gap 10), rows down from 0.
function SmashScreens.garageCards(n: number, w: number): { Box }
	local cols, gap, h = 4, 10, 140
	local cw = (w - (cols - 1) * gap) / cols
	local out: { Box } = {}
	for i = 1, n do
		local col, row = (i - 1) % cols, (i - 1) // cols
		out[i] = { x = col * (cw + gap), y = row * (h + gap), w = cw, h = h }
	end
	return out
end

-- The kit windows' lines (crates give looks, never a win)
SmashScreens.KIT_WORDS = {
	shopNote = "Crates change the look only.",
	oddsNote = "Crates give skins only. They change the look, not speed.",
	newKart = "NEW KART!",
	dailyNote = "Come back every day for more coins!",
	noJobs = "No jobs yet. Play a match!",
	noScores = "No scores yet. Play a match!",
	loading = "Loading...",
	noFriends = "Invite friends to see them here!",
	noKarts = "Open a crate to get a kart!",
	hatsSoon = "HATS COMING SOON!",
}

return SmashScreens
