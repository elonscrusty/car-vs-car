--!strict
-- Where the Car VS Car popups put their panels and buttons (Cvc*.client), written out as numbers
-- so Lune can check them on a 667x375 phone and on PC (tests/cvc_layout.test.luau): every button
-- is thumb size (THUMB px or more both ways) and every piece stays inside its panel and the screen.
-- A box is a UDim2 + AnchorPoint in its parent (another box, or the screen), with an optional
-- biggest size (UISizeConstraint).

export type Box = {
	parent: string?, -- nil = the screen
	ax: number, -- AnchorPoint
	ay: number,
	x: number, -- Position: x scale, x pixels, y scale, y pixels
	xo: number,
	y: number,
	yo: number,
	w: number, -- Size: w scale, w pixels, h scale, h pixels
	wo: number,
	h: number,
	ho: number,
	maxW: number?, -- UISizeConstraint.MaxSize
	maxH: number?,
	tap: boolean?, -- a button: thumb size
	main: boolean?, -- a main button (PICK!, OPEN!, ...): bigger still (MAIN)
}

local CvcLayout = {}

-- the smallest a thumb button may be, both ways (px)
CvcLayout.THUMB = 44
-- the main buttons, bigger on a phone (carter's pick 49)
CvcLayout.MAIN = 56

local function box(
	parent: string?,
	anchor: { number },
	pos: { number },
	size: { number },
	opt: any?
): Box
	local o = opt or {}
	return {
		parent = parent,
		ax = anchor[1],
		ay = anchor[2],
		x = pos[1],
		xo = pos[2],
		y = pos[3],
		yo = pos[4],
		w = size[1],
		wo = size[2],
		h = size[3],
		ho = size[4],
		maxW = o.max and o.max[1],
		maxH = o.max and o.max[2],
		tap = o.tap or o.main,
		main = o.main,
	}
end

local TL, MID, BOTTOM_MID, BOTTOM_LEFT = { 0, 0 }, { 0.5, 0.5 }, { 0.5, 1 }, { 0, 1 }
local TAP = { tap = true }
local MAIN = { main = true }

-- the big X on a panel's top right corner
local function closeX(): Box
	return box("Panel", MID, { 1, -6, 0, 6 }, { 0, 48, 0, 48 }, TAP)
end

CvcLayout.SCREENS = {
	-- PICK YOUR FIRST CAR: 3 choices side by side, each a card and PICK!
	pick = {
		Panel = box(nil, MID, { 0.5, 0, 0.53, 0 }, { 0.8, 0, 0.88, 0 }, { max = { 900, 520 } }),
		Choice = box("Panel", TL, { 0, 10, 0.17, 0 }, { 1 / 3, -20, 0.8, 0 }), -- (the first; the others sit right of it)
		Card = box("Choice", TL, { 0, 0, 0, 0 }, { 1, 0, 1, -64 }),
		Pick = box("Choice", BOTTOM_MID, { 0.5, 0, 1, 0 }, { 0.8, 0, 0, 56 }, MAIN),
	},
	-- MY GARAGE: tabs, a body that scrolls (station cards across, or car rows down), MORE STATIONS
	garage = {
		Panel = box(nil, MID, { 0.5, 0, 0.53, 0 }, { 0.86, 0, 0.88, 0 }, { max = { 960, 560 } }),
		Close = closeX(),
		TabStations = box("Panel", TL, { 0.04, 0, 0, 26 }, { 0.25, 0, 0, 44 }, TAP),
		TabCars = box("Panel", TL, { 0.31, 0, 0, 26 }, { 0.25, 0, 0, 44 }, TAP),
		Note = box("Panel", TL, { 0.58, 0, 0, 26 }, { 0.38, 0, 0, 44 }),
		Body = box("Panel", TL, { 0.03, 0, 0, 76 }, { 0.94, 0, 1, -142 }),
		More = box("Panel", BOTTOM_MID, { 0.5, 0, 1, -6 }, { 0.5, 0, 0, 56 }, MAIN),
		-- one station card (the first; the others sit right of it) and its two buttons
		Card = box("Body", TL, { 0, 0, 0, 0 }, { 0, 210, 1, -8 }),
		CardTop = box("Card", TL, { 0, 0, 0, 0 }, { 1, 0, 1, -54 }), -- name, level, car, bars
		Change = box("Card", BOTTOM_LEFT, { 0.06, 0, 1, -6 }, { 0.42, 0, 0, 44 }, TAP),
		Up = box("Card", BOTTOM_LEFT, { 0.52, 0, 1, -6 }, { 0.42, 0, 0, 44 }, TAP),
		-- one car row (the first; the others sit under it) and its button
		Row = box("Body", TL, { 0, 0, 0, 0 }, { 1, -10, 0, 68 }),
		RowButton = box("Row", { 1, 0.5 }, { 1, -8, 0.5, 0 }, { 0.3, 0, 0, 56 }, MAIN),
	},
	-- a crate: the box and its odds, OPEN! / BUY; the new car comes out over it
	crate = {
		Panel = box(nil, MID, { 0.5, 0, 0.53, 0 }, { 0.6, 0, 0.88, 0 }, { max = { 620, 540 } }),
		Close = closeX(),
		Odds = box("Panel", TL, { 0.5, 0, 0.14, 0 }, { 0.46, 0, 0.58, 0 }),
		Reveal = box("Panel", MID, { 0.5, 0, 0.45, 0 }, { 0.5, 0, 0.62, 0 }),
		Open = box("Panel", BOTTOM_MID, { 0.5, 0, 1, -8 }, { 0.46, 0, 0, 56 }, MAIN),
	},
	-- after a race: the result card, then GG! / AGAIN!
	finish = {
		Card = box(nil, MID, { 0.5, 0, 0.36, 0 }, { 0.36, 0, 0.34, 0 }, { max = { 420, 260 } }),
		Chat = box(nil, MID, { 0.5, 0, 0.66, 0 }, { 0, 300, 0, 60 }),
		GG = box("Chat", TL, { 0, 0, 0, 0 }, { 0.47, 0, 1, 0 }, MAIN),
		Again = box("Chat", TL, { 0.53, 0, 0, 0 }, { 0.47, 0, 1, 0 }, MAIN),
	},
}

-- left, top, right, bottom of a box on a screen of sw x sh pixels
function CvcLayout.box(
	screen: string,
	name: string,
	sw: number,
	sh: number
): (number, number, number, number)
	local s = (CvcLayout.SCREENS :: any)[screen]
	local b: Box? = s and s[name]
	assert(b, `CvcLayout has no {screen}.{name}`)
	local pl, pt, pr, pb = 0, 0, sw, sh
	if b.parent then
		pl, pt, pr, pb = CvcLayout.box(screen, b.parent, sw, sh)
	end
	local pw, ph = pr - pl, pb - pt
	local w = b.w * pw + b.wo
	local h = b.h * ph + b.ho
	if b.maxW then
		w = math.min(w, b.maxW)
	end
	if b.maxH then
		h = math.min(h, b.maxH)
	end
	local l = pl + b.x * pw + b.xo - b.ax * w
	local t = pt + b.y * ph + b.yo - b.ay * h
	return l, t, l + w, t + h
end

-- put a GuiObject in its box (in its parent box's object; the ScreenGui has IgnoreGuiInset)
function CvcLayout.place(obj: any, screen: string, name: string)
	local b: Box = (CvcLayout.SCREENS :: any)[screen][name]
	obj.AnchorPoint = Vector2.new(b.ax, b.ay)
	obj.Position = UDim2.new(b.x, b.xo, b.y, b.yo)
	obj.Size = UDim2.new(b.w, b.wo, b.h, b.ho)
	if b.maxW or b.maxH then
		local c = Instance.new("UISizeConstraint")
		c.MaxSize = Vector2.new(b.maxW or math.huge, b.maxH or math.huge)
		c.Parent = obj
	end
end

-- ===== the how-to tip (CvcHowTo): an arrow by a button, its words, and SKIP =====

export type Rect = { number } -- left, top, right, bottom (px)
export type Tip = { arrow: Rect, words: Rect, skip: Rect }

CvcLayout.TIP_ARROW = 54
CvcLayout.TIP_WORDS_H = 40
CvcLayout.TIP_SKIP = { 76, 44 }

local function rect(cx: number, cy: number, w: number, h: number): Rect
	return { cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2 }
end

function CvcLayout.hits(a: Rect, b: Rect): boolean
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

local function onScreen(r: Rect, sw: number, sh: number): boolean
	return r[1] >= 0 and r[2] >= 0 and r[3] <= sw and r[4] <= sh
end

-- Where the tip goes for a button at `target` on a sw x sh screen: the arrow just past the
-- button (under it when `below`, else over it), the words past the arrow, SKIP by the words.
-- When that would cover one of the other buttons (`avoid`), the words and SKIP go beside the
-- button instead (right, then left), so the tip never sits on COACH or JOIN.
function CvcLayout.tip(target: Rect, below: boolean, sw: number, sh: number, avoid: { Rect }): Tip
	local A, WH, SK = CvcLayout.TIP_ARROW, CvcLayout.TIP_WORDS_H, CvcLayout.TIP_SKIP
	local cx = (target[1] + target[3]) / 2
	local dir = if below then 1 else -1
	local edge = if below then target[4] else target[2]
	local arrowY = edge + dir * (A / 2 + 3)
	local arrow = rect(cx, arrowY, A, A)

	-- (the arrow bobs up to 10 px away from the button)
	local arrowReach: Rect = if below
		then { arrow[1], arrow[2], arrow[3], arrow[4] + 10 }
		else { arrow[1], arrow[2] - 10, arrow[3], arrow[4] }
	local function ok(t: Tip): boolean
		for _, r in { arrowReach, t.words, t.skip } do
			if not onScreen(r, sw, sh) or CvcLayout.hits(r, target) then
				return false
			end
			for _, a in avoid do
				if CvcLayout.hits(r, a) then
					return false
				end
			end
		end
		return not CvcLayout.hits(t.words, arrowReach)
			and not CvcLayout.hits(t.skip, arrowReach)
			and not CvcLayout.hits(t.skip, t.words)
	end

	-- the words: past the arrow (centred, or lined up with either edge of the button) or beside
	-- the button; wide first, then narrower. SKIP right of the words, past them, or before them.
	local tries: { Tip } = {}
	local stackY = edge + dir * (A + 13 + WH / 2 + 2) -- (past the bobbing arrow)
	local midY = (target[2] + target[4]) / 2
	for _, want in { 300, 190, 130 } do
		local w = math.min(want, sw - 24)
		local spots: { { number } } = {
			{ math.clamp(cx, w / 2 + 12, sw - w / 2 - 12), stackY },
			{ math.clamp(target[1], 12, sw - 12 - w) + w / 2, stackY },
			{ math.clamp(target[3], 12 + w, sw - 12) - w / 2, stackY },
			{ target[3] + 10 + w / 2, midY },
			{ target[1] - 10 - w / 2, midY },
		}
		for _, at in spots do
			local words = rect(at[1], at[2], w, WH)
			for _, skip in
				{
					rect(words[3] + 8 + SK[1] / 2, at[2], SK[1], SK[2]),
					rect(at[1], at[2] + dir * (WH / 2 + SK[2] / 2 + 4), SK[1], SK[2]),
					rect(at[1], at[2] - dir * (WH / 2 + SK[2] / 2 + 4), SK[1], SK[2]),
				}
			do
				table.insert(tries, { arrow = arrow, words = words, skip = skip })
			end
		end
	end
	for _, t in tries do
		if ok(t) then
			return t
		end
	end
	return tries[1]
end

return CvcLayout
