--!strict
-- EDGE ARROWS (carter's Lead pick "1 Chevron"): a small chevron on the screen edge points at a
-- kart or a box you cannot see. Pure maths (Lune tests it); client/EdgeArrows draws it.
local EdgeArrow = {}

EdgeArrow.MAX_KARTS = 3 -- the nearest enemy karts only (calm: never a ring of arrows)
EdgeArrow.MAX_BOXES = 1 -- the nearest box that is up
EdgeArrow.MIN_DIST = 40 -- studs: nearer than this you can see it anyway, no arrow
EdgeArrow.MAX_DIST = 400 -- studs: further than this it does not matter yet

export type Spot = { x: number, y: number, angle: number, inside: boolean }

-- where the chevron sits for a target at screen pixel (sx, sy) on a w x h screen, kept inside
-- the rect inset by (l, t, r, b); angle = degrees, 0 = pointing right, clockwise (screen y is down).
-- inside = the target is already on screen (no arrow wanted).
function EdgeArrow.place(
	w: number,
	h: number,
	sx: number,
	sy: number,
	l: number,
	t: number,
	r: number,
	b: number
): Spot
	local cx, cy = w / 2, h / 2
	local dx, dy = sx - cx, sy - cy
	local angle = math.deg(math.atan2(dy, dx))
	local inside = sx >= 0 and sx <= w and sy >= 0 and sy <= h
	if math.abs(dx) < 1e-6 and math.abs(dy) < 1e-6 then
		return { x = cx, y = cy, angle = angle, inside = inside }
	end
	-- the inset rect, as distances from the middle along each side
	local left, top = cx - l, cy - t
	local right, bottom = (w - r) - cx, (h - b) - cy
	local k = math.huge
	if dx > 0 then
		k = math.min(k, right / dx)
	elseif dx < 0 then
		k = math.min(k, -left / dx)
	end
	if dy > 0 then
		k = math.min(k, bottom / dy)
	elseif dy < 0 then
		k = math.min(k, -top / dy)
	end
	k = math.min(k, 1) -- never push a target further out than where it is
	return { x = cx + dx * k, y = cy + dy * k, angle = angle, inside = inside }
end

-- Phone: the lowest y a chevron may sit at on the RIGHT edge (screen px, h = the screen height).
-- Below it is the DRIFT button, whose top is 0.54 - 0.22 = 0.32 of the screen height (the controls
-- gui covers the whole screen), then FIRE; either would hide the chevron. 22 px = half a chevron
-- and a gap.
function EdgeArrow.rightCeiling(h: number): number
	return 0.32 * h - 22
end

-- a target behind the camera (z < 0 in view space): mirror it through the middle so the
-- arrow points the way to turn
function EdgeArrow.behind(w: number, h: number, sx: number, sy: number): (number, number)
	return w - sx, h - sy
end

export type Item = { dist: number, enemy: boolean }

-- indexes of the items to show: the nearest MAX_KARTS enemies and MAX_BOXES boxes, within range
function EdgeArrow.pick(items: { Item }): { number }
	local karts: { number } = {}
	local boxes: { number } = {}
	for i, it in items do
		if it.dist >= EdgeArrow.MIN_DIST and it.dist <= EdgeArrow.MAX_DIST then
			table.insert(if it.enemy then karts else boxes, i)
		end
	end
	local function nearest(list: { number }, n: number): { number }
		table.sort(list, function(a, c)
			return items[a].dist < items[c].dist
		end)
		local out = {}
		for i = 1, math.min(n, #list) do
			out[i] = list[i]
		end
		return out
	end
	local out = nearest(karts, EdgeArrow.MAX_KARTS)
	for _, i in nearest(boxes, EdgeArrow.MAX_BOXES) do
		table.insert(out, i)
	end
	return out
end

-- how strong the chevron is: nearer = stronger (0.45 .. 0.9 opacity), so the closest threat reads
function EdgeArrow.strength(dist: number): number
	local k =
		math.clamp((EdgeArrow.MAX_DIST - dist) / (EdgeArrow.MAX_DIST - EdgeArrow.MIN_DIST), 0, 1)
	return 0.45 + 0.45 * k
end

return EdgeArrow
