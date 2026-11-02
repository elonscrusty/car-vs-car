--!strict
-- The second arena: FROSTY YARD (carter's pick "C" on the arena preview page, 2026-11-02). It is the
-- same tested yard (same walls, hills, ramps, boxes and starts, so bots and fairness don't change),
-- dressed in snow, with ONE new danger: ICE PATCHES. A kart on ice has little grip, so it slides
-- (the wheels read the part's "Grip" attribute, like the soft sand does). Daytime only, nothing glows.
--
-- How it works (looks cost nothing on the network):
--   * the SERVER picks the look for each round (FrostYard.next) and puts it on workspace attribute
--     FrostYard.ATTR ("yard" or "frost"); it parks the ice and the snow props in or out of the world.
--   * every CLIENT re-colours the arena parts by name (FrostYard.RECOLOR) and cools the sky a little.
-- Plain numbers and tables, so Lune tests run it. Picture units are the arena's 240 x 240 picture.

local FrostYard = {}

FrostYard.ATTR = "ArenaTheme" -- workspace attribute: "yard" (the sunny junkyard) or "frost"
FrostYard.YARD, FrostYard.FROST = "yard", "frost"
FrostYard.MAX_RUN = 2 -- the same look at most this many rounds in a row

-- The look for the next round. `roll` is a random 0..1; `last` is the look just played and `run`
-- how many rounds in a row it has been on (so a look never lasts more than MAX_RUN rounds).
function FrostYard.next(last: string?, run: number, roll: number): string
	local pick = if roll < 0.5 then FrostYard.YARD else FrostYard.FROST
	if last == FrostYard.YARD or last == FrostYard.FROST then
		if run >= FrostYard.MAX_RUN then
			return if last == FrostYard.YARD then FrostYard.FROST else FrostYard.YARD
		end
	end
	return pick
end

-- ICE: {x, y, radius}. Open flat ground, off the sand, far from starts, boxes, kegs, drums, pits,
-- crates, wrenches and the crane (tests/frost_yard.test checks all of that).
FrostYard.ICE = {
	{ 70, 25, 13 },
	{ 185, 220, 11 },
	{ 220, 35, 10 },
	{ 45, 180, 10 },
	{ 125, 100, 9 },
} :: { { number } }
FrostYard.ICE_GRIP = 0.3 -- of normal grip (sand is 0.85): slides, but the kart still steers
FrostYard.ICE_DRAG = 0 -- no extra drag: ice is fast
FrostYard.ICE_COLOR = { 112, 206, 236 }
FrostYard.ICE_RIM = { 52, 150, 205 }
FrostYard.ICE_CRACK = { 244, 250, 255 }

-- Snow props OUTSIDE the wall (looks only; the arena inside is untouched).
FrostYard.PINES = 28 -- a double ring of pines round the walls
FrostYard.CABIN = { x = 168, y = -34, yaw = 0 } -- a log cabin past the north wall
FrostYard.SNOWMEN = { { 12, -14 }, { 228, -14 }, { 12, 254 }, { 228, 254 } } :: { { number } }
-- snow drifts piled along the foot of the wall, inside it (looks only, not solid)
FrostYard.DRIFT_STEP = 13
FrostYard.DRIFT_FROM, FrostYard.DRIFT_TO = 24, 216 -- along each side, past the round corners

-- pines: deterministic spots in a ring past the wall: {x, y, size 0.8..1.4}
function FrostYard.pines(): { { number } }
	local out: { { number } } = {}
	local s = 17
	local function rnd(): number
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
	for k = 0, FrostYard.PINES - 1 do
		local a = k / FrostYard.PINES * math.pi * 2 + rnd() * 0.12
		-- picture units from the middle along the square (the wall is at 120): 28..70 past the wall
		local reach = (148 + rnd() * 42) / math.max(math.abs(math.cos(a)), math.abs(math.sin(a)))
		local x, y = 120 + math.cos(a) * reach, 120 + math.sin(a) * reach
		-- keep the ring clear of the cabin
		local c = FrostYard.CABIN
		if math.sqrt((x - c.x) ^ 2 + (y - c.y) ^ 2) > 26 then
			table.insert(out, { x, y, 0.8 + rnd() * 0.6 })
		end
	end
	return out
end

-- The re-colour by part name (the names ArenaBuilder and ArenaHorizon give): the part's own colour
-- is mixed toward `c` by `a` (0 keeps it, 1 is all `c`), so checkers and sheet colours stay varied.
export type Rule = { c: { number }, a: number }
FrostYard.RECOLOR = {
	Grass = { c = { 238, 245, 252 }, a = 0.92 },
	GrassPatch = { c = { 216, 232, 246 }, a = 0.85 },
	Tuft = { c = { 240, 248, 255 }, a = 0.85 },
	Skid = { c = { 178, 198, 216 }, a = 0.85 },
	Sand = { c = { 178, 192, 210 }, a = 0.9 }, -- the mud pit, frozen over
	OuterWall = { c = { 208, 224, 240 }, a = 0.85 },
	WallTrim = { c = { 112, 170, 224 }, a = 0.75 },
	WallCorner = { c = { 208, 224, 240 }, a = 0.85 },
	WallPillar = { c = { 200, 216, 234 }, a = 0.8 },
	Skirting = { c = { 196, 214, 232 }, a = 0.8 },
	Wreck = { c = { 228, 238, 248 }, a = 0.6 }, -- crushed cars under snow
	Sheet = { c = { 228, 238, 248 }, a = 0.6 },
	Platform = { c = { 188, 208, 228 }, a = 0.8 },
	Stand = { c = { 200, 214, 232 }, a = 0.7 },
	Rock = { c = { 230, 238, 247 }, a = 0.7 },
	Cover = { c = { 150, 192, 228 }, a = 0.7 },
	CoverCap = { c = { 230, 240, 250 }, a = 0.7 },
	CoverSheet = { c = { 214, 228, 242 }, a = 0.5 },
	HighPink = { c = { 206, 222, 240 }, a = 0.8 },
	LowPink = { c = { 206, 222, 240 }, a = 0.8 },
	HillSlab = { c = { 218, 228, 240 }, a = 0.6 },
	HillFoot = { c = { 190, 208, 228 }, a = 0.6 },
	RampFlank = { c = { 224, 236, 248 }, a = 0.8 },
	RampDeck = { c = { 216, 228, 242 }, a = 0.7 },
	TreeTop = { c = { 44, 112, 80 }, a = 0.92 }, -- the candy tops become pines
	Bush = { c = { 58, 128, 92 }, a = 0.55 },
	FarGrass = { c = { 228, 239, 249 }, a = 1 },
	FarGround = { c = { 232, 241, 250 }, a = 1 },
	FarHill = { c = { 216, 230, 244 }, a = 0.9 },
	Cliff = { c = { 178, 194, 216 }, a = 0.7 },
	FarFactory = { c = { 204, 216, 232 }, a = 0.55 },
	FarChimney = { c = { 214, 224, 238 }, a = 0.55 },
	FarCrane = { c = { 214, 224, 236 }, a = 0.5 },
} :: { [string]: Rule }

-- A cooler, bluer afternoon (the arena's light is ArenaData.lighting; this only shifts colours).
FrostYard.sky = {
	ambient = { 112, 122, 148 },
	outdoorAmbient = { 140, 152, 178 },
	colorShiftTop = { 255, 250, 240 },
	atmosphereColor = { 178, 214, 246 },
	atmosphereDecay = { 120, 170, 230 },
	tint = { 236, 246, 255 },
	saturation = 0.05,
}

return FrostYard
