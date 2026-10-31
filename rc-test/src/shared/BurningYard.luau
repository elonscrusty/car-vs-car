--!strict
-- The Burning Yard look (carter picked arena 1 "Burning Yard", 10-30; then 10-30 15:17 "no
-- nighttime, too much glowing, I can't tell what's going on", picked the SUNNY DAY try): a calm
-- daytime junkyard. Wreck piles with only a thin grey smoke, rows of concrete barriers on the
-- walls, plain floodlight masts past the corners, smoke over the fire pits. Nothing glows. Looks
-- only: nothing here is solid or hurts anyone. server/BurningYardServer builds it.
-- Picture units (the arena's 240 x 240 picture) for every spot; plain numbers so Lune tests run it.

local BurningYard = {}

export type Pt = { number }

-- Wreck piles that smoulder. Open, flat, far from start spots, "?" boxes, kegs, drums, pits, crates and
-- the crane (tests/burning_yard.test checks); each is a heap of dead cars with a thin smoke column.
-- `yaw` turns the heap, `side` says which wall it leans on (a row of barriers runs along it).
BurningYard.PILES = {
	{ x = 70, y = 20, yaw = 0.3, along = { 1, 0 } },
	{ x = 180, y = 220, yaw = 2.6, along = { 1, 0 } },
	{ x = 225, y = 110, yaw = 1.2, along = { 0, -1 } },
} :: { { x: number, y: number, yaw: number, along: Pt } }
BurningYard.PILE_SCALE = 0.4 -- studs per data unit of JunkPropData.junkCars (17 wide, 6.5 tall)
BurningYard.BARRIER_GAP = 13 -- picture units from a pile to its barrier row
BurningYard.BARRIER_SCALE = 0.3

-- Floodlight masts: one past each corner of the wall (dark steel, no light on in the day).
BurningYard.TOWERS = {
	{ -14, -14 },
	{ 254, -14 },
	{ -14, 254 },
	{ 254, 254 },
} :: { Pt }
BurningYard.TOWER_H = 17 -- studs (RC): well above the chase cam

return BurningYard
