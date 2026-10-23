--!strict
-- The build screen for the 5-min break: drag a road tile from the bar onto a square and it
-- swaps in (carter: "tiles that swap in with different road shapes"). Phone first, landscape:
-- the plot grid fills the left; the right holds the countdown, the big READY / GAP chip, a
-- 1-3 word hint, the tile bar, and ERASE / DONE. Pure numbers and tables, so Lune can test it
-- on phone and PC sizes. Also: which road tile fits a square from the sides its road leaves by.

export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	cell: number, -- one grid square, pixels
	grid: Rect,
	timer: Rect,
	status: Rect,
	why: Rect, -- one line: how to build, or why the road is not a loop yet
	tray: Rect, -- special tiles to drag onto the road
	erase: Rect,
	done: Rect,
}
-- which sides of a square the road leaves by, at rotation 0
export type Ends = { N: boolean, E: boolean, S: boolean, W: boolean }
export type Spot = { c: number, r: number }

local BuildLayout = {}

BuildLayout.TOP = 64 -- under Roblox's top bar
BuildLayout.EDGE = 16 -- side gutter
BuildLayout.GAP = 10
BuildLayout.ROW = 48 -- countdown / RACE READY row
BuildLayout.WHY = 24 -- the help / "Road has a gap" line
BuildLayout.BUTTON = 56 -- bottom button row
BuildLayout.MIN_TAP = 36 -- smallest grid square a thumb can hit
BuildLayout.CARD = 76 -- special tile card size
BuildLayout.DRAG = 12 -- pixels a finger moves before a press on a card is a drag

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

-- topBar: first pixel row free of Roblox's top bar (default TOP)
function BuildLayout.fit(
	sw: number,
	sh: number,
	cols: number,
	rows: number,
	topBar: number?
): Layout
	local edge, gap = BuildLayout.EDGE, BuildLayout.GAP
	local top = topBar or BuildLayout.TOP
	local availH = sh - top - edge
	-- the grid gets up to half the width; the right side needs room for two tray cards
	local availW = math.min(sw * 0.5, sw - edge * 3 - BuildLayout.CARD * 2 - gap)
	local cell = math.floor(math.min(availW / cols, availH / rows))
	local gw, gh = cell * cols, cell * rows
	local grid = rect(edge, top + math.floor((availH - gh) / 2), gw, gh)

	local rx = grid.x + gw + edge
	local rw = sw - edge - rx
	local timerW = math.floor((rw - gap) * 0.36)
	local timer = rect(rx, top, timerW, BuildLayout.ROW)
	local status = rect(rx + timerW + gap, top, rw - timerW - gap, BuildLayout.ROW)
	local why = rect(rx, top + BuildLayout.ROW + 6, rw, BuildLayout.WHY)
	local by = sh - edge - BuildLayout.BUTTON
	local half = math.floor((rw - gap) / 2)
	local erase = rect(rx, by, half, BuildLayout.BUTTON)
	local done = rect(rx + half + gap, by, rw - half - gap, BuildLayout.BUTTON)
	local ty = why.y + why.h + 6
	local tray = rect(rx, ty, rw, by - gap - ty)
	return {
		cell = cell,
		grid = grid,
		timer = timer,
		status = status,
		why = why,
		tray = tray,
		erase = erase,
		done = done,
	}
end

-- the grid square under a finger, or nil. col 1 = left; row 1 = the front row (next to the
-- stand), drawn at the BOTTOM of the grid, so north (away from the stand) is up on the screen.
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

-- which side of square a the square b is on (they touch)
function BuildLayout.side(a: Spot, b: Spot): string?
	if b.c == a.c and b.r == a.r + 1 then
		return "N"
	elseif b.c == a.c and b.r == a.r - 1 then
		return "S"
	elseif b.r == a.r and b.c == a.c + 1 then
		return "E"
	elseif b.r == a.r and b.c == a.c - 1 then
		return "W"
	end
	return nil
end

-- the road tile (and quarter turns) whose road leaves by exactly these sides: two opposite
-- sides = straight, two neighbouring sides = turn. nil for anything else.
local STRAIGHT = { N = true, E = false, S = true, W = false }
local TURN = { N = true, E = true, S = false, W = false }
function BuildLayout.roadFor(e: Ends): (string?, number)
	for _, kind in { { "straight", STRAIGHT }, { "turn", TURN } } do
		for rot = 0, 3 do
			local t = BuildLayout.turn(kind[2] :: Ends, rot)
			if t.N == e.N and t.E == e.E and t.S == e.S and t.W == e.W then
				return kind[1] :: string, rot
			end
		end
	end
	return nil, 0
end

function BuildLayout.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function BuildLayout.statusText(ready: boolean): string
	return if ready then "✓ READY" else "GAP!"
end

-- the hint line: 1-3 big words (carter: new players must get it at once)
function BuildLayout.hint(ready: boolean, gap: boolean, erasing: boolean): string
	if erasing then
		return "TAP TO ERASE"
	elseif ready then
		return "TAP DONE!"
	elseif gap then
		return "FIX THE GAP"
	end
	return "DRAG A TILE"
end

return BuildLayout
