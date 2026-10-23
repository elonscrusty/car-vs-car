--!strict
-- Where the build screen's parts go (5-min break: build your plot's track from tiles).
-- Phone first, landscape: the plot grid fills the left, and the right holds the countdown, the
-- RACE READY chip, the tile tray and three big buttons (ROTATE / REMOVE / DONE). Pure numbers,
-- so Lune can test it on phone and PC sizes. Also: how a tile's road ends turn when rotated.

export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	cell: number, -- one grid square, pixels
	grid: Rect,
	timer: Rect,
	status: Rect,
	why: Rect, -- one line under the chip: why the road is not a loop yet
	tray: Rect,
	rotate: Rect,
	remove: Rect,
	done: Rect,
}
-- which sides of a square the road leaves by, at rotation 0
export type Ends = { N: boolean, E: boolean, S: boolean, W: boolean }

local BuildLayout = {}

BuildLayout.TOP = 64 -- under Roblox's top bar
BuildLayout.EDGE = 16 -- side gutter
BuildLayout.GAP = 10
BuildLayout.ROW = 40 -- countdown / status row
BuildLayout.WHY = 22 -- the "Road has a gap" line
BuildLayout.BUTTON = 56 -- bottom button row
BuildLayout.MIN_TAP = 36 -- smallest grid square a thumb can hit
BuildLayout.CARD = 76 -- tray card size

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function BuildLayout.fit(sw: number, sh: number, cols: number, rows: number): Layout
	local edge, gap, top = BuildLayout.EDGE, BuildLayout.GAP, BuildLayout.TOP
	local availH = sh - top - edge
	-- the grid gets up to half the width; the right side needs room for two tray cards
	local availW = math.min(sw * 0.5, sw - edge * 3 - BuildLayout.CARD * 2 - gap)
	local cell = math.floor(math.min(availW / cols, availH / rows))
	local gw, gh = cell * cols, cell * rows
	local grid = rect(edge, top + math.floor((availH - gh) / 2), gw, gh)

	local rx = grid.x + gw + edge
	local rw = sw - edge - rx
	local half = math.floor((rw - gap) / 2)
	local timer = rect(rx, top, half, BuildLayout.ROW)
	local status = rect(rx + half + gap, top, rw - half - gap, BuildLayout.ROW)
	local by = sh - edge - BuildLayout.BUTTON
	local bw = math.floor((rw - gap * 2) / 3)
	local rotate = rect(rx, by, bw, BuildLayout.BUTTON)
	local remove = rect(rx + bw + gap, by, bw, BuildLayout.BUTTON)
	local done = rect(rx + (bw + gap) * 2, by, rw - (bw + gap) * 2, BuildLayout.BUTTON)
	local why = rect(rx, top + BuildLayout.ROW + 4, rw, BuildLayout.WHY)
	local ty = why.y + why.h + 4
	local tray = rect(rx, ty, rw, by - gap - ty)
	return {
		cell = cell,
		grid = grid,
		timer = timer,
		status = status,
		why = why,
		tray = tray,
		rotate = rotate,
		remove = remove,
		done = done,
	}
end

-- the grid square under a tap, or nil. col 1 = left; row 1 = the front row (next to the stand),
-- drawn at the BOTTOM of the grid, so north (away from the stand) is up on the screen.
function BuildLayout.cellAt(
	l: Layout,
	px: number,
	py: number,
	cols: number,
	rows: number
): (number?, number?)
	local c = math.floor((px - l.grid.x) / l.cell) + 1
	local r = rows - math.floor((py - l.grid.y) / l.cell)
	if c < 1 or r < 1 or c > cols or r > rows then
		return nil, nil
	end
	return c, r
end

-- top-left pixel of a grid square, inside the grid (see cellAt)
function BuildLayout.cellPos(l: Layout, c: number, r: number, rows: number): (number, number)
	return (c - 1) * l.cell, (rows - r) * l.cell
end

-- rot = quarter turns clockwise (0..3): a road leaving north at 0 leaves east at 1
function BuildLayout.turn(e: Ends, rot: number): Ends
	local out = { N = e.N, E = e.E, S = e.S, W = e.W }
	for _ = 1, rot % 4 do
		out = { N = out.W, E = out.N, S = out.E, W = out.S }
	end
	return out
end

function BuildLayout.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function BuildLayout.statusText(ready: boolean): string
	return if ready then "RACE READY ✓" else "NEEDS A FULL LOOP"
end

return BuildLayout
