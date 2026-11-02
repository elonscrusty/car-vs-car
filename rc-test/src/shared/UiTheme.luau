--!strict
-- Car VS Car screens (carter 10-27, CarVsCar_UI_Handoff.md): every color, size and timing of the
-- new look in one place. Pure numbers, so Lune tests them against the spec; client/Ui builds the
-- screens from them. Sizes are design px on the 844 x 390 phone; the canvas inside the 44 px side
-- safe area is 756 x 390.

local UiTheme = {}

-- section 2 of the spec, as hex
UiTheme.HEX = {
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
	-- rarity
	common = "a7b2cc",
	rare = "1fa8f5",
	epic = "8a4dff",
	legendary = "ffd93b",
	-- league
	bronze = "d68a4c",
	silver = "c3cddc",
	leagueGold = "ffc22e",
	diamond = "5ee0f0",
	-- the design system's light rows inside white windows
	rowFill = "eef6ff",
	rowEdge = "cfe3f5",
	lockedFill = "d5e0ec",
	lockedEdge = "9fb2c8",
	claimFill = "fff6cc",
	doneFill = "e4ecf4",
	purple = "6a3df0",
	purpleDark = "2a1a6e",
	lilac = "b38bff",
}

UiTheme.SCRIM_ALPHA = 0.6 -- scrim at 60%

-- "0d2c40" -> 13, 44, 64
function UiTheme.rgb(name: string): (number, number, number)
	local hex = UiTheme.HEX[name]
	assert(hex, "no color " .. name)
	return tonumber(hex:sub(1, 2), 16) :: number,
		tonumber(hex:sub(3, 4), 16) :: number,
		tonumber(hex:sub(5, 6), 16) :: number
end

-- Button tones: fill and its darker ledge (section 4, 5)
export type Tone = { fill: string, deep: string, word: string }
UiTheme.TONES = {
	lime = { fill = "lime", deep = "limeDeep", word = "do it" },
	go = { fill = "go", deep = "goDeep", word = "open or celebrate" },
	blue = { fill = "blue", deep = "blueDeep", word = "go somewhere" },
	danger = { fill = "danger", deep = "dangerDeep", word = "no or delete" },
	white = { fill = "surface", deep = "barEmpty", word = "back" },
	boost = { fill = "boost", deep = "boostDeep", word = "BOOST only" },
	pink = { fill = "pink", deep = "pinkDeep", word = "COACH" },
	gold = { fill = "gold", deep = "goDeep", word = "golden" },
} :: { [string]: Tone }

-- Rarity: always with its word. The game's ids (CarCatalog) are common, rare, epic, legend.
UiTheme.RARITY = {
	common = { color = "common", word = "COMMON" },
	rare = { color = "rare", word = "RARE" },
	epic = { color = "epic", word = "EPIC" },
	legendary = { color = "legendary", word = "LEGENDARY" },
	golden = { color = "gold", word = "GOLDEN" },
}
UiTheme.RARITY_ORDER = { "common", "rare", "epic", "legendary" }
function UiTheme.rarityId(id: string?): string
	if id == "legend" then
		return "legendary"
	end
	if id and UiTheme.RARITY[id] then
		return id
	end
	return "common"
end

-- Leagues: each has its own emblem too (1, 2, 3 stars, gem), so rank never needs color alone.
UiTheme.LEAGUES = {
	{ id = "bronze", word = "BRONZE", color = "bronze", stars = 1, wings = false },
	{ id = "silver", word = "SILVER", color = "silver", stars = 2, wings = false },
	{ id = "gold", word = "GOLD", color = "leagueGold", stars = 3, wings = true },
	{ id = "diamond", word = "DIAMOND", color = "diamond", stars = 0, wings = true },
}

-- The 3 stats, one color each everywhere. `bar` is the game's name for it (Training.BARS), and
-- `station` the machine that trains it most (Training.MAIN).
-- (the words and colors are the plot's board: the treadmill trains SPEED, the ramp BOOST, the
-- speed track TURN, so a screen never names a bar the pads don't; the spec's POWER / AIR / SPEED
-- are the keys)
UiTheme.STATS = {
	{ key = "power", word = "SPEED", tone = "blue", bar = "speed", station = "treadmill" },
	{ key = "air", word = "BOOST", tone = "boost", bar = "boost", station = "ramp" },
	{ key = "speed", word = "TURN", tone = "lime", bar = "turn", station = "track" },
}

-- carter's UI kit v41 (ui-kit/v41, "UI chrome v2", 10-29): the chunky 3D look. A tone's face
-- runs hi -> c -> c2 top to bottom over its deep base; panels and cards are navy and blue.
export type Face = { hi: string, c: string, c2: string, deep: string }
UiTheme.FACE = {
	lime = { hi = "d2ff96", c = "55ea2c", c2 = "2bc414", deep = "178f0a" },
	blue = { hi = "c4ecff", c = "3fb8ff", c2 = "1c84ea", deep = "0b5cb4" },
	go = { hi = "fff7b8", c = "ffd93b", c2 = "ffb400", deep = "b86d00" },
	gold = { hi = "fff7b8", c = "ffd93b", c2 = "ffb400", deep = "b86d00" },
	pink = { hi = "ffd0e6", c = "ff5fa6", c2 = "e6267c", deep = "a50f56" },
	danger = { hi = "ffc0c0", c = "ff4a4a", c2 = "e01428", deep = "8f0014" },
	boost = { hi = "ffd2a8", c = "ff8a2a", c2 = "f0660a", deep = "a84000" },
	white = { hi = "ffffff", c = "f1f5fb", c2 = "d3dcea", deep = "8794ad" },
	steel = { hi = "f1f5fb", c = "b8c4d8", c2 = "8794ad", deep = "4a566e" },
	navy = { hi = "5a8fe0", c = "2f5fae", c2 = "22478a", deep = "122a55" },
	off = { hi = "dfe5ec", c = "b8c2cc", c2 = "9aa5b1", deep = "6d7884" },
} :: { [string]: Face }

-- a bar's fill (the kit's .tr > b): green, blue, yellow; other colors use their button face
UiTheme.BAR_FACE = {
	lime = { hi = "c4ff8a", c = "48e322", c2 = "25b812", deep = "178f0a" },
	blue = { hi = "bfe9ff", c = "38b0ff", c2 = "1a7fe6", deep = "0b5cb4" },
	go = { hi = "fff6b0", c = "ffd93b", c2 = "ffb000", deep = "b86d00" },
} :: { [string]: Face }

UiTheme.CHROME = {
	ground = { "21468f", "0b1a3d" }, -- the menu ground behind full screens
	panel = { "27509a", "183a74", "112b5c" }, -- .pn
	panelRim = "4f93ec",
	card = { "3d7bd2", "2a5aa8", "1f4382" }, -- .cd
	cardSelected = "ffd93b",
	track = { "071226", "10264a" }, -- a bar or toggle's recessed track
	tabOff = { "1e3d76", "14305f" },
	tabOffWords = "9fc0ec",
	tabOn = { "9fdcff", "3fb3ff", "1c7ee6" },
	tabGold = { "fff7b8", "ffd93b", "ffb400" },
	-- titles: white -> sky, gold, red, ice (the kit's .t-title)
	title = {
		white = { "ffffff", "ffffff", "e2f2ff", "bfe3ff" },
		gold = { "fffbd0", "ffe95a", "ffc21f", "ff8f00" },
		red = { "ffd3c6", "ff6a4a", "ec1c2e", "b80d22" },
		ice = { "ffffff", "dff5ff", "8fd8ff", "3aa2f0" },
	},
	rim = 0.8, -- a face's inner white rim, 20% white
	gloss = 0.34, -- the top gloss band's share of the face
	press = 3, -- px the face moves down on a press
}

-- "ffd93b" -> Color3
function UiTheme.hex(h: string): (number, number, number)
	return tonumber(h:sub(1, 2), 16) :: number,
		tonumber(h:sub(3, 4), 16) :: number,
		tonumber(h:sub(5, 6), 16) :: number
end

UiTheme.DESIGN = {
	phoneW = 844,
	phoneH = 390,
	safe = 44, -- each side
	w = 756, -- the canvas: the phone minus both safe sides
	h = 390,
	stick = 140, -- bottom-left square kept free for the move stick on gameplay screens
	minTap = 44,
}

UiTheme.SIZE = {
	buttonL = 66,
	buttonM = 50,
	close = 56,
	side = 62,
	boost = 118,
	coach = 92,
	toggleW = 76,
	toggleH = 40,
	slot = 56,
}

UiTheme.CORNER = { button = 16, window = 22, slot = 14, close = 14, card = 24 }
UiTheme.OUTLINE = { thick = 4, normal = 3, small = 2.5 }
UiTheme.LEDGE = 7 -- the darker strip inside a button's bottom
UiTheme.DROP = 4 -- the ink drop under a button
UiTheme.CLOSE_TILT = 5
UiTheme.SLAB = { x = -8, y = 9 } -- the blue slab behind a window

-- Type: font px at 844 x 390, and the stroke in CSS px (half of it is a UIStroke's Thickness:
-- CSS strokes sit half inside the letters, UIStroke all outside)
UiTheme.FONT = "Oswald"
UiTheme.TYPE = {
	shout = { size = 52, stroke = 7, drop = 5 },
	title = { size = 45, stroke = 9, drop = 3 },
	buttonL = { size = 28, stroke = 5 },
	buttonM = { size = 21, stroke = 4 },
	label = { size = 18, stroke = 3.5 },
	small = { size = 13, stroke = 3 },
}

-- Section 7: the sliding pattern
UiTheme.PATTERN = {
	tile = 44,
	period = 3.4, -- 44 px right and 44 px down every 3.4 s
	onColor = 0.26, -- white at 26% on colored fills
	onWhite = 0.08, -- ink at 8% on white fills
	sparkle = { x = 11, y = 11, size = 15 },
	diamond = { x = 33, y = 33, size = 15, hole = 6.8 },
}

-- Section 7: entrances and idle life, in seconds
UiTheme.MOTION = {
	staggerStep = 0.7, -- a new player's plot screen: the next piece pops in after this long
	windowIn = 0.38,
	windowFrom = 0.8,
	titleIn = 0.55,
	titleDelay = 0.1,
	titleFrom = 0.3,
	titleTilt = -10,
	titleWobble = 3.2,
	closeIn = 0.5,
	closeDelay = 0.25,
	listIn = 0.5,
	listRise = 16,
	listFrom = 0.94,
	listGap = 0.06,
	barFill = 1,
	barDelay = 0.25,
	barStripes = 0.7,
	countUp = 0.9,
	coinSpin = 3,
	shoutIn = 0.6,
	cardFlip = 0.18,
	shine = 2.8,
	dotBounce = 1.8,
	tagWiggle = 2.4,
	sideNudge = 4.5,
	iconBob = 2.2,
	nextUpBounce = 1.6,
	glow = 2.2,
	slotShimmer = 1.3,
	boostPulse = 0.9,
	crateShake = 2.4,
	carBob = 1.8,
	raysTurn = 30,
	press = 0.1,
	pressTo = 0.9,
	popupWords = 0.15,
}

return UiTheme
