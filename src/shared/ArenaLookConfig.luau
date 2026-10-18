--!strict
-- Numbers for the world around the bowl (ring road, props, trees, hills). Studs from the arena
-- centre. The road starts just outside the bowl rim (rimRadius 62 + wall + curb + skirt).

return {
	seed = 2024, -- same seed = same layout every time
	maxRadius = 250, -- nothing (with its size) goes farther out than this
	outerMin = 92, -- tall things (towers, trees, rocks, hills) stay at least this far out
	curbInner = 64, -- white curb ring: 64 to 66, dark steel skirt: 66 to roadInner
	roadInner = 67,
	roadOuter = 88,
	grassOuter = 262,
	roadSegments = 24,
	grassSegments = 12,
	oceanSize = 1000, -- square, far below the bowl
	oceanDrop = 40, -- studs under the bowl floor
	towers = { count = 4, radius = 100, startDeg = 45, height = 26 },
	hazardPads = { count = 4, radius = 77, startDeg = 0, sizeX = 10, sizeZ = 12 },
	tires = { count = 10, minR = 71, maxR = 83, radius = 2.4, gap = 3 },
	cones = { count = 14, minR = 70, maxR = 83, gap = 2 },
	barriers = { count = 8, radius = 85.5, startDeg = 22.5, length = 8 },
	trees = { count = 28, minR = 98, maxR = 168, gap = 12 },
	hills = { count = 12, minR = 170, maxR = 205, minScale = 30, maxScale = 44 },
	rocks = { count = 16, minR = 96, maxR = 185, minScale = 2, maxScale = 5 },
	clouds = { count = 5, minR = 150, maxR = 230, minY = 80, maxY = 110 },
}
