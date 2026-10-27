--!strict
-- The car tag's layout in pixels (CarTag draws it, a Lune test checks it): on a 667x375 phone
-- every word must stay readable, so no text row is shorter than MIN_TEXT px and the bars are
-- thick enough to see. Rows are fractions of the tag's height.

local CarTagLayout = {}

CarTagLayout.WIDTH = 230
CarTagLayout.HEIGHT = 124
CarTagLayout.MIN_TEXT = 16 -- the smallest text row, in pixels (TextScaled shrinks to the row)
CarTagLayout.MIN_BAR = 8 -- the thinnest bar, in pixels

-- y and h are fractions of HEIGHT.
CarTagLayout.NAME = { y = 0.02, h = 0.25 }
CarTagLayout.KIND = { y = 0.27, h = 0.15 }
CarTagLayout.BAR_TOP = 0.44
CarTagLayout.BAR_STEP = 0.185
CarTagLayout.BAR_ROW = 0.17
-- columns as fractions of WIDTH
CarTagLayout.LABEL_X, CarTagLayout.LABEL_W = 0.02, 0.27
CarTagLayout.TRACK_X, CarTagLayout.TRACK_W = 0.31, 0.45
CarTagLayout.VALUE_X, CarTagLayout.VALUE_W = 0.78, 0.2

function CarTagLayout.barY(i: number): number
	return CarTagLayout.BAR_TOP + (i - 1) * CarTagLayout.BAR_STEP
end

-- A bar at its car's top looks maxed: the whole bar, gold (the same rule as MY GARAGE, CvcUi.bars).
CarTagLayout.MAX_GOLD = { 255, 196, 30 }
function CarTagLayout.barLook(value: number, cap: number, maxBar: number): (number, boolean)
	local full = value >= cap
	return if full then 1 else math.clamp(value / maxBar, 0, 1), full
end

-- The shortest text row in pixels.
function CarTagLayout.smallestText(): number
	local H = CarTagLayout.HEIGHT
	return math.min(CarTagLayout.NAME.h, CarTagLayout.KIND.h, CarTagLayout.BAR_ROW) * H
end

return CarTagLayout
