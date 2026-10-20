--!strict
-- Where a tutorial bubble stands (pure, tested). A bubble sits NEXT TO the button it talks about
-- (carter's L15) and the middle of the screen stays clear. All numbers are screen pixels.

local BubbleLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Size = { w: number, h: number }

export type Placement = {
	x: number, -- top-left of the bubble
	y: number,
	side: string, -- where the bubble stands compared with the target: "left" | "right" | "above" | "below" | "top"
	tailX: number, -- where the little pointer starts, from the bubble's top-left (on the edge facing the target)
	tailY: number,
	pointsAt: Rect?, -- the target (nil for a bubble with no button)
}

BubbleLayout.margin = 8 -- the bubble keeps this far from every screen edge
BubbleLayout.gap = 14 -- space between the bubble and its target

-- The middle of the screen: what the bubbles must keep clear.
function BubbleLayout.centerBox(screen: Size): Rect
	return { x = screen.w * 0.3, y = screen.h * 0.3, w = screen.w * 0.4, h = screen.h * 0.4 }
end

-- Area where two rectangles overlap (0 when they do not touch).
function BubbleLayout.overlap(a: Rect, b: Rect): number
	local w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
	local h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
	if w <= 0 or h <= 0 then
		return 0
	end
	return w * h
end

local function clamp(v: number, lo: number, hi: number): number
	if hi < lo then
		return lo
	end
	return math.max(lo, math.min(hi, v))
end

local function inside(screen: Size, size: Size, x: number, y: number): (number, number)
	local m = BubbleLayout.margin
	return clamp(x, m, screen.w - size.w - m), clamp(y, m, screen.h - size.h - m)
end

-- A bubble with no button to point at: centered at the top, `topY` pixels down (under SKIP).
function BubbleLayout.top(screen: Size, size: Size, topY: number): Placement
	local x, y = inside(screen, size, (screen.w - size.w) / 2, topY)
	return { x = x, y = y, side = "top", tailX = size.w / 2, tailY = 0, pointsAt = nil }
end

-- A bubble at the bottom middle (the PC key hints: there is no on-screen button).
function BubbleLayout.bottom(screen: Size, size: Size, bottomGap: number): Placement
	local x, y = inside(screen, size, (screen.w - size.w) / 2, screen.h - size.h - bottomGap)
	return { x = x, y = y, side = "top", tailX = size.w / 2, tailY = 0, pointsAt = nil }
end

-- Next to `target`: the side with the most room that does not cover the middle of the screen.
function BubbleLayout.place(target: Rect, screen: Size, size: Size): Placement
	local gap = BubbleLayout.gap
	local cx = target.x + target.w / 2
	local cy = target.y + target.h / 2
	local order = if cx > screen.w / 2
		then { "left", "above", "below", "right" }
		else { "right", "above", "below", "left" }
	local center = BubbleLayout.centerBox(screen)
	local best: Placement? = nil
	local bestScore = math.huge
	for rank, side in order do
		local x, y
		if side == "left" then
			x, y = target.x - gap - size.w, cy - size.h / 2
		elseif side == "right" then
			x, y = target.x + target.w + gap, cy - size.h / 2
		elseif side == "above" then
			x, y = cx - size.w / 2, target.y - gap - size.h
		else
			x, y = cx - size.w / 2, target.y + target.h + gap
		end
		x, y = inside(screen, size, x, y)
		local box: Rect = { x = x, y = y, w = size.w, h = size.h }
		-- covering the button itself is much worse than covering a corner of the middle; the order
		-- of `order` breaks ties
		local score = BubbleLayout.overlap(box, center)
			+ BubbleLayout.overlap(box, target) * 1000
			+ rank * 0.01
		if score < bestScore then
			bestScore = score
			-- the pointer starts on the edge that faces the target, level with the target
			local tailX, tailY
			if side == "left" then
				tailX, tailY = size.w, clamp(cy - y, 12, size.h - 12)
			elseif side == "right" then
				tailX, tailY = 0, clamp(cy - y, 12, size.h - 12)
			elseif side == "above" then
				tailX, tailY = clamp(cx - x, 12, size.w - 12), size.h
			else
				tailX, tailY = clamp(cx - x, 12, size.w - 12), 0
			end
			best = {
				x = x,
				y = y,
				side = side,
				tailX = tailX,
				tailY = tailY,
				pointsAt = target,
			}
		end
	end
	return best :: Placement
end

return BubbleLayout
