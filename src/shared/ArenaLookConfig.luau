--!strict
-- Numbers for the world around the bowl (ring road, props, trees, hills). Studs from the arena
-- centre. The road starts just outside the bowl rim (rimRadius + wall + curb + skirt).

local RIM = 112 -- keep equal to GameConfig.Arena.rimRadius (a test checks it)

return {
	seed = 2024, -- same seed = same layout every time
	maxRadius = 450, -- nothing (with its size) goes farther out than this
	outerMin = RIM + 30, -- tall things (towers, trees, rocks, hills) stay at least this far out
	curbInner = RIM + 2, -- white curb ring: 64 to 66, dark steel skirt: 66 to roadInner
	roadInner = RIM + 5,
	roadOuter = RIM + 26,
	grassOuter = 470,
	roadSegments = 24,
	grassSegments = 12,
	oceanSize = 1500, -- square, far below the bowl
	oceanDrop = 60, -- studs under the bowl floor
	towers = { count = 4, radius = RIM + 38, startDeg = 45, height = 30 },
	hazardPads = { count = 4, radius = RIM + 15, startDeg = 0, sizeX = 10, sizeZ = 12 },
	tires = { count = 10, minR = RIM + 9, maxR = RIM + 21, radius = 2.4, gap = 3 },
	cones = { count = 14, minR = RIM + 8, maxR = RIM + 21, gap = 2 },
	barriers = { count = 8, radius = RIM + 23.5, startDeg = 22.5, length = 8 },
	trees = { count = 44, minR = RIM + 36, maxR = 300, gap = 12 },
	hills = { count = 14, minR = 300, maxR = 370, minScale = 30, maxScale = 44 },
	rocks = { count = 20, minR = RIM + 34, maxR = 330, minScale = 2, maxScale = 5 },
	clouds = { count = 5, minR = 250, maxR = 400, minY = 120, maxY = 160 },
}
