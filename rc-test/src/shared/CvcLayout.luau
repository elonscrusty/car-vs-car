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
local TOP_MID = { 0.5, 0 }
local TAP = { tap = true }
local MAIN = { main = true }

-- the folded daily JOBS chip's size (Stars.client; px): the how-to tip keeps clear of it
CvcLayout.JOBS_CHIP = { 130, 34 }

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
		-- up top under Roblox's bar, over JOIN (COACH steps away while it shows)
		Card = box(nil, TOP_MID, { 0.5, 0, 0, 64 }, { 0.36, 0, 0.34, 0 }, { max = { 420, 260 } }),
		-- right of the big JOIN button (BigJoin: bottom middle, 240 wide), bottoms lined up: it sat
		-- on JOIN (Studio final-10); on a phone it shrinks to the room left of the screen edge
		Chat = box(
			nil,
			BOTTOM_LEFT,
			{ 0.5, 120 + 10, 0.96, -102 },
			{ 0.5, -(120 + 10 + 14), 0, 56 },
			{ max = { 300, 56 } }
		),
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
export type Tip = { arrow: Rect, words: Rect, skip: Rect, side: string } -- side: "under", "over" or "left" of the button

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
local function search(
	target: Rect,
	below: boolean,
	sw: number,
	sh: number,
	avoid: { Rect }
): (Tip?, Tip)
	local A, WH, SK = CvcLayout.TIP_ARROW, CvcLayout.TIP_WORDS_H, CvcLayout.TIP_SKIP
	local cx = (target[1] + target[3]) / 2
	local midY = (target[2] + target[4]) / 2

	local function ok(t: Tip, reach: Rect): boolean
		for _, r in { reach, t.words, t.skip } do
			if not onScreen(r, sw, sh) or CvcLayout.hits(r, target) then
				return false
			end
			for _, a in avoid do
				if CvcLayout.hits(r, a) then
					return false
				end
			end
		end
		return not CvcLayout.hits(t.words, reach)
			and not CvcLayout.hits(t.skip, reach)
			and not CvcLayout.hits(t.skip, t.words)
	end

	local first: Tip? = nil
	-- the arrow past the button's top or bottom edge first, else on its left (pointing right)
	-- (on the left: level with the button's middle, bottom or top)
	local sides: { { side: string, y: number } } = {
		{ side = if below then "under" else "over", y = midY },
		{ side = "left", y = midY },
		{ side = "left", y = target[4] - A / 2 },
		{ side = "left", y = target[2] + A / 2 },
	}
	for _, sideAt in sides do
		local side, ay = sideAt.side, sideAt.y
		local arrow: Rect
		local reach: Rect -- (the arrow bobs up to 10 px away from the button)
		local spots: { { number } } = {}
		local dir = if side == "under" then 1 else -1
		for _, want in { 300, 190, 130 } do
			local w = math.min(want, sw - 24)
			if side == "left" then
				arrow = rect(target[1] - 3 - A / 2, ay, A, A)
				local from = arrow[1] - 14
				table.insert(spots, { from - w / 2, ay, w })
				table.insert(spots, { from - w / 2, ay - A, w })
				table.insert(spots, { from - w / 2, ay + A, w })
			else
				local edge = if side == "under" then target[4] else target[2]
				arrow = rect(cx, edge + dir * (A / 2 + 3), A, A)
				-- past the arrow: centred, or lined up with either edge of the button; or beside it
				local stackY = edge + dir * (A + 13 + WH / 2 + 2)
				table.insert(spots, { math.clamp(cx, w / 2 + 12, sw - w / 2 - 12), stackY, w })
				table.insert(spots, { math.clamp(target[1], 12, sw - 12 - w) + w / 2, stackY, w })
				table.insert(spots, { math.clamp(target[3], 12 + w, sw - 12) - w / 2, stackY, w })
				table.insert(spots, { target[3] + 10 + w / 2, midY, w })
				table.insert(spots, { target[1] - 10 - w / 2, midY, w })
			end
		end
		arrow = arrow :: any
		reach = if side == "under"
			then { arrow[1], arrow[2], arrow[3], arrow[4] + 10 }
			elseif side == "over" then { arrow[1], arrow[2] - 10, arrow[3], arrow[4] }
			else { arrow[1] - 10, arrow[2], arrow[3], arrow[4] }
		for _, at in spots do
			local words = rect(at[1], at[2], at[3], WH)
			-- SKIP right of the words, past them, or before them
			for _, skip in
				{
					rect(words[3] + 8 + SK[1] / 2, at[2], SK[1], SK[2]),
					rect(at[1], at[2] + dir * (WH / 2 + SK[2] / 2 + 4), SK[1], SK[2]),
					rect(at[1], at[2] - dir * (WH / 2 + SK[2] / 2 + 4), SK[1], SK[2]),
				}
			do
				local t = { arrow = arrow, words = words, skip = skip, side = side }
				first = first or t
				if ok(t, reach) then
					return t, t
				end
			end
		end
	end
	return nil, first :: Tip
end

function CvcLayout.tip(target: Rect, below: boolean, sw: number, sh: number, avoid: { Rect }): Tip
	local good, first = search(target, below, sw, sh, avoid)
	return good or first
end

-- The tip clear of `extra` too (the JOBS chip), or nil when there is no such spot: then that
-- piece steps away while the tip shows
function CvcLayout.tipClearOf(
	target: Rect,
	below: boolean,
	sw: number,
	sh: number,
	avoid: { Rect },
	extra: Rect
): Tip?
	local all = table.clone(avoid)
	table.insert(all, extra)
	return (search(target, below, sw, sh, all))
end

-- ===== the race call strip (ServerRace.client "Call", on foot): COACH steps down under it =====
-- (the same numbers ServerRace.client uses: top middle, 58 px down, half the screen wide, 7:1)
CvcLayout.CALL_STRIP = { y = 58, w = 0.5, aspect = 7 }
CvcLayout.COACH_GAP = 8

function CvcLayout.callStrip(sw: number): Rect
	local c = CvcLayout.CALL_STRIP
	local w = c.w * sw
	local h = w / c.aspect
	return { sw / 2 - w / 2, c.y, sw / 2 + w / 2, c.y + h }
end

-- COACH's top (px) while the call strip is up: just under it
function CvcLayout.coachUnderCall(sw: number): number
	return CvcLayout.callStrip(sw)[4] + CvcLayout.COACH_GAP
end

-- the driving spots the BOOST tip keeps clear of: all of them but BOOST itself and the drive
-- JOIN (ServerRace hides that while racing, and the tip only shows while racing)
function CvcLayout.boostAvoids(name: string): boolean
	return name ~= "Boost" and name ~= "Join"
end

-- ===== after a race the cards take turns (Studio check 10-26: they sat on each other) =====
-- 1. the race result with the podium (ServerRace.client "Result", ServerRace.SHOW seconds),
-- 2. the win card with GG! / AGAIN! (CvcRace "Finish" and "QuickChat"; they go together),
-- 3. a new league's big words (Cvc "Kart_League": GOLD LEAGUE!, it came with the win card and
-- was never seen), 4. NEXT CAR (Stars "RacePrize"), 5. short words like +50 COINS: JOB DONE!
-- (Stars "Toast": it sat on the result's rows, Studio final-49). Each waits until the ones before
-- it are gone.
CvcLayout.AFTER_RACE = {
	{ turn = 1, gui = "ServerRace", name = "Result" },
	{ turn = 2, gui = "CvcRaceTop", name = "Finish" },
	{ turn = 2, gui = "CvcRaceTop", name = "QuickChat" },
	{ turn = 3, gui = "CvcTop", name = "Kart_League" },
	{ turn = 4, gui = "StarsTop", name = "RacePrize" },
	{ turn = 5, gui = "StarsTop", name = "Toast" },
}

-- while the race result card shows, the driving pieces of these owners (HudLayout spot owners) step
-- away: the race is over, and they sat on the card (AUTO GAS on its ribbon, Studio
-- morning-podium). Hud and Controls: Main.client turns RCControls off; Cvc: CvcRace's BOOST;
-- ServerRace: its JOIN pill; Lobby: WALK.
CvcLayout.AFTER_RACE_HIDES =
	{ Hud = true, Controls = true, Cvc = true, ServerRace = true, Lobby = true }

-- the result card's ribbon (ServerRace: 80% of the card wide, 13% of the screen tall, half over
-- its top edge)
function CvcLayout.resultRibbonBox(sw: number, sh: number): Rect
	local R = CvcLayout.RESULT
	local w = 0.8 * R.w
	return { sw * (0.5 - w / 2), sh * (R.top - 0.065), sw * (0.5 + w / 2), sh * (R.top + 0.065) }
end

-- the league words' box (CvcUi.bigWords: the middle, 40% down, 60% x 14%)
function CvcLayout.leagueBox(sw: number, sh: number): Rect
	return { sw * 0.2, sh * 0.33, sw * 0.8, sh * 0.47 }
end

function CvcLayout.turnOf(name: string): number
	for _, c in CvcLayout.AFTER_RACE do
		if c.name == name then
			return c.turn
		end
	end
	error(`not an after-race card: {name}`)
end

-- the race result card (ServerRace.client "Result"): its top at 31%, 68% wide, 20% for the
-- ribbon and edges, 6.5% a row and the podium's 24%; it all shrinks together so the card ends
-- above the screen's bottom (Studio check 10-26: 8 racers and the podium ran off at 604 px)
CvcLayout.RESULT = { top = 0.31, w = 0.68, base = 0.2, row = 0.065, podium = 0.24, bottom = 0.97 }

-- how much the result card shrinks (1 = not at all) for `lines` rows, with or without the podium
function CvcLayout.resultFit(lines: number, podium: boolean): number
	local R = CvcLayout.RESULT
	local tall = R.base + R.row * lines + (if podium then R.podium else 0)
	return math.min(1, (R.bottom - R.top) / tall)
end

function CvcLayout.resultBox(sw: number, sh: number, lines: number, podium: boolean): Rect
	local R = CvcLayout.RESULT
	local tall = (R.base + R.row * lines + (if podium then R.podium else 0))
		* CvcLayout.resultFit(lines, podium)
	return { sw * (0.5 - R.w / 2), sh * R.top, sw * (0.5 + R.w / 2), sh * (R.top + tall) }
end

-- the NEXT CAR card (Stars "RacePrize") once the result is gone (you're on foot then): in the
-- middle, 30% x 11%, between the left and right button columns; at 64% down, or higher to sit
-- over the big JOIN button (its top at joinTop px) with a gap (Studio check 10-26: it covered
-- JOIN on a short screen)
CvcLayout.PRIZE = { x = 0.5, y = 0.64, w = 0.3, h = 0.11, gap = 10 }

function CvcLayout.prizeY(sh: number, joinTop: number?): number
	local P = CvcLayout.PRIZE
	if not joinTop then
		return P.y
	end
	return math.max(0.12, math.min(P.y, (joinTop - P.gap) / sh - P.h))
end

function CvcLayout.prizeBox(sw: number, sh: number, joinTop: number?): Rect
	local P = CvcLayout.PRIZE
	local y = CvcLayout.prizeY(sh, joinTop)
	return { sw * (P.x - P.w / 2), sh * y, sw * (P.x + P.w / 2), sh * (y + P.h) }
end

-- (client) wait until every after-race card from an earlier turn than `name` is off the screen,
-- for a moment (the next card can take a beat to come up: a later turn waits longer, so the
-- turn before it has come up first); at most `most` seconds
function CvcLayout.waitTurn(playerGui: Instance, name: string, most: number)
	local turn = CvcLayout.turnOf(name)
	local function up(): boolean
		for _, c in CvcLayout.AFTER_RACE do
			local g = if c.turn < turn then playerGui:FindFirstChild(c.gui) else nil
			local f = if g then g:FindFirstChild(c.name, true) else nil
			if f and f:IsA("GuiObject") and f.Visible then
				return true
			end
		end
		return false
	end
	local stop = os.clock() + most
	local clearSince = nil :: number?
	while os.clock() < stop do
		if up() then
			clearSince = nil
		elseif not clearSince then
			clearSince = os.clock()
		elseif os.clock() - clearSince >= 0.3 * math.max(1, turn - 1) then
			return
		end
		task.wait(0.1)
	end
end

return CvcLayout
