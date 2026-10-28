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
	close = 54,
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
UiTheme.FONT = "FredokaOne"
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
