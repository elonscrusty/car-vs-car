--!strict
-- Oil slick puddle, the LOOK (carter picked try A "Round Blob", 10-29): a fat black wet puddle made
-- of overlapping flat discs, a rainbow shine swirl on top, and bubbles that grow, wobble and pop at
-- the edge. Pure numbers (no Roblox types) so Lune tests can check them; server/OilSlickModel
-- builds the parts from this. Sizes are in "big units" (a kart is 3 x 5.5), times the caller's SCALE.
-- Preview: car-vs-car/oil-slick-preview/oil-tries.html (try A).

local OilSlick = {}

OilSlick.NAME = "Oil Slick"
OilSlick.HEIGHT = 0.14 -- puddle thickness
OilSlick.SPREAD_TIME = 0.7 -- seconds from a tiny drop to full size
OilSlick.COLOR = { 4, 4, 8 } -- near black (RGB 0-255)
OilSlick.RAINBOW = { { 255, 63, 164 }, { 53, 224, 255 }, { 141, 91, 255 }, { 125, 255, 106 }, { 255, 210, 63 } }

export type Lobe = { x: number, z: number, rx: number, rz: number, rot: number }
-- x, z = centre; rx, rz = half sizes; rot = turn in radians
OilSlick.LOBES = {
	{ x = 0, z = 0, rx = 5.6, rz = 5.2, rot = 0.2 },
	{ x = -2.8, z = 1.6, rx = 3.3, rz = 3.0, rot = 0 },
	{ x = 3.1, z = -1.9, rx = 3.5, rz = 2.9, rot = 0.6 },
	{ x = 1.2, z = 3.8, rx = 2.7, rz = 2.4, rot = 0 },
	{ x = -3.6, z = -3.0, rx = 2.6, rz = 2.2, rot = 0.3 },
	{ x = 4.4, z = 2.0, rx = 2.3, rz = 2.0, rot = 0 },
	{ x = -0.5, z = -5.2, rx = 2.2, rz = 1.7, rot = 0 },
	{ x = -5.4, z = 0.6, rx = 1.8, rz = 1.5, rot = 0 },
	-- little drops flung off the edge
	{ x = 6.9, z = 0.4, rx = 0.5, rz = 0.45, rot = 0 },
	{ x = -6.2, z = -4.2, rx = 0.4, rz = 0.4, rot = 0 },
	{ x = 2.2, z = -6.2, rx = 0.35, rz = 0.35, rot = 0 },
	{ x = 5.4, z = 5.0, rx = 0.3, rz = 0.3, rot = 0 },
} :: { Lobe }

-- The rainbow shine: soft rings drawn on a flat sheet over the middle. `radius` is the sheet's
-- half size, `turn` how fast it drifts round (radians a second, sign = direction).
export type Sheet = { radius: number, x: number, z: number, rings: number, turn: number }
OilSlick.SHEETS = {
	{ radius = 5.0, x = -0.6, z = 0.3, rings = 6, turn = 0.25 },
	{ radius = 3.4, x = 0.6, z = -0.3, rings = 5, turn = -0.45 },
} :: { Sheet }

export type Bubble = { x: number, z: number, r: number, phase: number, period: number, hue: number }
OilSlick.BUBBLES = {
	{ x = -2.2, z = 1.6, r = 0.6, phase = 0, period = 2.6, hue = 0 },
	{ x = 1.6, z = -0.6, r = 0.42, phase = 0.3, period = 3.2, hue = 1 },
	{ x = 3.4, z = 1.8, r = 0.72, phase = 0.6, period = 3.8, hue = 2 },
	{ x = -4.0, z = -1.4, r = 0.46, phase = 0.15, period = 3.0, hue = 3 },
	{ x = 0.5, z = 3.2, r = 0.36, phase = 0.8, period = 2.8, hue = 4 },
	{ x = -1.2, z = -3.6, r = 0.62, phase = 0.45, period = 3.6, hue = 0 },
	{ x = 4.2, z = -2.6, r = 0.32, phase = 0.9, period = 2.6, hue = 1 },
	{ x = -0.3, z = 0.9, r = 0.3, phase = 0.55, period = 3.0, hue = 2 },
} :: { Bubble }

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- Puddle size 0..~1.1 over time since it landed: pops out a little past full, then settles.
function OilSlick.spread(t: number): number
	if t <= 0 then
		return 0.01
	end
	local u = math.min(1, t / OilSlick.SPREAD_TIME)
	local c = 2.70158
	return math.max(0.01, 1 + c * (u - 1) ^ 3 + 1.70158 * (u - 1) ^ 2)
end

-- Where a bubble is in its life (0..1) at time t.
function OilSlick.bubbleLife(b: Bubble, t: number): number
	return (math.max(t, 0) / b.period + b.phase) % 1
end

-- Bubble size (0..~1.35) and pop-ring progress (0 = no ring, else 0..1) at life u:
-- grows for half its life, wobbles, swells, pops.
function OilSlick.bubbleSize(u: number): (number, number)
	if u < 0.5 then
		return smooth(u / 0.5), 0
	elseif u < 0.84 then
		return 1 + 0.04 * math.sin((u - 0.5) * 28), 0
	elseif u < 0.9 then
		return 1 + 0.35 * ((u - 0.84) / 0.06), 0
	end
	return 0, (u - 0.9) / 0.1
end

return OilSlick
