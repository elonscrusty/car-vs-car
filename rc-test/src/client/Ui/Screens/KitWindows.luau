--!strict
-- carter's UI kit v41 windows (WINDOWS, ui-kit/v41/WINDOWS-PLAN.md), Smash only: the Shop (one
-- CRATES tab with the crates you can buy), Crate odds (always before OPEN) and the Crate reveal.
-- Places come from shared/SmashScreens, prices and odds from shared/Crates (via the caller); the
-- server decides every buy and every kart, these only show it and ask.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Screen = require(Ui:WaitForChild("Screen"))
local KartView = require(script.Parent:WaitForChild("KartView"))
local Smash = require(script.Parent:WaitForChild("Smash"))

local KitWindows = {}

local INK, WHITE = Base.color("ink"), Base.WHITE

local function piece(id: string, path: string): SmashScreens.Piece
	return SmashScreens.piece(id, path)
end

-- a see-through frame at a screen piece
local function spot(canvas: Instance, id: string, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Parent = canvas
	Base.place(f, piece(id, name))
	return f
end

local function placedButton(
	canvas: Instance,
	id: string,
	name: string,
	onClick: () -> (),
	opts: { [string]: any }?
): TextButton
	local pc = piece(id, name)
	local o: { [string]: any } = opts or {}
	o.main = pc.main
	o.onClick = onClick
	return Kit.button(
		spot(canvas, id, name),
		"Button",
		0,
		0,
		pc.w,
		pc.h,
		pc.tone or "lime",
		pc.text or "",
		o
	)
end

local function rarityColor(r: string?): Color3
	return Base.color(UiTheme.RARITY[UiTheme.rarityId(r)].color)
end

-- the kit's deep-blue ground behind a full window (its back layer)
local function ground(back: ScreenGui?)
	if not back then
		return
	end
	local f = Instance.new("Frame")
	f.Name = "Ground"
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Active = true
	f.Parent = back
	Kit.face(f, UiTheme.CHROME.ground)
end

-- a navy pill with a coin and a price (or words like FREE x2)
local function pricePill(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string,
	coin: boolean
)
	local pill = Base.fill(parent, "Price", x, y, w, h, Kit.hex(UiTheme.CHROME.track[2]), 4)
	Base.corner(pill)
	Base.outline(pill, UiTheme.OUTLINE.small)
	local left = h * 0.3
	if coin then
		Icons.make(pill, "coin", h * 0.12, h * 0.1, h * 0.8, { z = 5 })
		left = h * 1.0
	end
	Base.text(
		pill,
		"Words",
		left,
		h * 0.16,
		w - left - h * 0.3,
		h * 0.68,
		words,
		{ stroke = 3, z = 5 }
	)
	return pill
end

-- ===== Shop: one CRATES tab (only tabs with real items), a tile per crate, the "looks only" pill =====

-- data: { coins: number, tiles = { { kind, word, rarity, price?, priceWords? } } }
-- actions: pick(kind), close()
function KitWindows.shop(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("shop", "window", true, function(g)
		ground(g.back)
		local canvas = g.canvas
		local kp = piece("kitShop", "Coins")
		Kit.currency(canvas, "Coins", kp.x, kp.y, kp.w, kp.h, { value = data.coins or 0 })
		local tp = piece("kitShop", "Tabs")
		Kit.tabs(
			spot(canvas, "kitShop", "Tabs"),
			0,
			0,
			tp.w,
			tp.h,
			{ "CRATES" },
			1,
			nil,
			nil,
			"gold"
		)
		local cp = piece("kitShop", "Close")
		Kit.close(spot(canvas, "kitShop", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local pp = piece("kitShop", "Panel")
		local holder = spot(canvas, "kitShop", "Panel")
		local panel = Kit.navyPanel(holder, "Panel", 0, 0, pp.w, pp.h)
		local tiles: { { [string]: any } } = data.tiles or {}
		local boxes = SmashScreens.shopTiles(#tiles, pp.w)
		local shown: { GuiObject } = {}
		for i, t in tiles do
			local b = boxes[i]
			local tile = Instance.new("TextButton")
			tile.Name = "Tile" .. i
			tile.Text = ""
			tile.AutoButtonColor = false
			tile.BackgroundTransparency = 1
			tile.ZIndex = 4
			tile.Parent = panel
			Base.at(tile, b.x, b.y, b.w, b.h)
			local plate = Kit.plate(tile, "Plate", 0, 0, b.w, b.h)
			-- the tier ring in the crate's rarity color (the kit's green / blue / purple / gold)
			local ring = plate:FindFirstChildOfClass("UIStroke")
			if ring then
				ring.Color = rarityColor(t.rarity)
				Base.restroke(ring, 4)
			end
			local cs = math.min(b.w - 30, 132)
			local crate =
				Icons.make(plate, "crate", (b.w - cs) / 2, 18, cs, { rarity = t.rarity, z = 4 })
			Anim.bob(crate, UiTheme.MOTION.carBob, 4, i * 0.3)
			Base.text(plate, "Word", 8, 156, b.w - 16, 26, t.word or "", { stroke = 3.5, z = 4 })
			local free = t.priceWords ~= nil
			pricePill(
				plate,
				12,
				b.h - 50,
				b.w - 24,
				40,
				t.priceWords or UiMotion.commas(t.price or 0),
				not free
			)
			Anim.press(tile)
			tile.Activated:Connect(function()
				Screen.act(actions, "pick")(t.kind)
			end)
			table.insert(shown, tile)
		end
		task.defer(function()
			Anim.cascade(shown)
		end)
		-- the "looks only" pill, bottom right of the panel (the kit's info pill)
		local nw = 300
		local note = Base.fill(
			panel,
			"Note",
			pp.w - nw - 16,
			pp.h - 50,
			nw,
			36,
			Kit.hex(UiTheme.CHROME.track[2]),
			4
		)
		Base.corner(note)
		Base.outline(note, UiTheme.OUTLINE.small, Kit.hex(UiTheme.CHROME.panelRim))
		local dot = Base.fill(note, "Info", 8, 7, 22, 22, Base.color("blue"), 5)
		Base.corner(dot)
		Base.text(dot, "I", 0, 3, 22, 16, "i", { z = 6 })
		Base.text(note, "Words", 38, 8, nw - 48, 20, SmashScreens.KIT_WORDS.shopNote, {
			align = "l",
			z = 5,
		})
		return {}
	end)
end

-- ===== Crate odds: the big crate with rays, OPEN with its price; the odds rows tinted by rarity =====

-- data: { kind, word, rarity, price?, priceWords?, coins, odds = { { rarity, chance } } }
-- actions: open(), close()
function KitWindows.crateOdds(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("crates", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local cp = piece("kitOdds", "Close")
		Kit.close(spot(canvas, "kitOdds", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local kp = piece("kitOdds", "Coins")
		Kit.currency(canvas, "Coins", kp.x, kp.y, kp.w, kp.h, { value = data.coins or 0 })
		local bp = piece("kitOdds", "Crate")
		local big = spot(canvas, "kitOdds", "Crate")
		Kit.rays(
			big,
			bp.w / 2,
			bp.h / 2,
			bp.h * 1.3,
			UiTheme.RARITY[UiTheme.rarityId(data.rarity)].color,
			0.55
		)
		local cs = bp.h - 10
		local crate =
			Icons.make(big, "crate", (bp.w - cs) / 2, 5, cs, { rarity = data.rarity, z = 3 })
		Anim.shake(crate)
		local words = data.priceWords or UiMotion.commas(data.price or 0)
		placedButton(canvas, "kitOdds", "Open", Screen.act(actions, "open"), {
			chip = words,
			chipIcon = if data.priceWords then false else nil,
		})
		local tp = piece("kitOdds", "Title")
		Kit.title(spot(canvas, "kitOdds", "Title"), 0, 0, tp.w, tp.h, "CRATE ODDS")
		local op = piece("kitOdds", "Odds")
		local panel = Kit.navyPanel(spot(canvas, "kitOdds", "Odds"), "Panel", 0, 0, op.w, op.h)
		local rows: { { [string]: any } } = data.odds or {}
		local n = math.max(#rows, 1)
		local pad, gap = 12, 8
		local rh = math.min(52, (op.h - 2 * pad - (n - 1) * gap) / n)
		local list: { GuiObject } = {}
		for i, r in rows do
			local color = rarityColor(r.rarity)
			local row = Base.fill(
				panel,
				"Row" .. i,
				pad,
				pad + (i - 1) * (rh + gap),
				op.w - 2 * pad,
				rh,
				color,
				4
			)
			Base.corner(row, 12)
			Base.outline(row, UiTheme.OUTLINE.small)
			Kit.gloss(row, color, 0.25)
			-- (darker than the plain color, as the kit's tinted rows)
			local shade = Base.fill(row, "Shade", 0, 0, op.w - 2 * pad, rh, INK, 1)
			shade.BackgroundTransparency = 0.55
			Base.corner(shade, 12)
			local rw = op.w - 2 * pad
			-- every rarity word the same size, the size LEGENDARY fits (TextScaled made COMMON and
			-- LEGENDARY smaller than RARE and EPIC, Studio r51)
			local wordX = rh * 1.6 + 26
			local wordW = rw * 0.72 - wordX - 8
			local wordH = math.min(rh * 0.5, wordW / (9 * 0.62))
			Icons.car(row, 8, rh * 0.1, rh * 1.2, rh * 0.8, { color = color, z = 5 })
			local dot = Base.fill(row, "Dot", rh * 1.2 + 14, rh * 0.3, rh * 0.4, rh * 0.4, color, 5)
			Base.corner(dot)
			Base.outline(dot, 2, WHITE)
			Base.text(
				row,
				"Word",
				wordX,
				(rh - wordH) / 2,
				wordW,
				wordH,
				UiTheme.RARITY[UiTheme.rarityId(r.rarity)].word,
				{ stroke = 3, align = "l", z = 5 }
			)
			Base.text(
				row,
				"Chance",
				rw * 0.72,
				rh * 0.18,
				rw * 0.28 - 12,
				rh * 0.64,
				UiMotion.percent(r.chance),
				{ stroke = 3.5, align = "r", z = 5 }
			)
			table.insert(list, row)
		end
		task.defer(function()
			Anim.cascade(list)
		end)
		local np = piece("kitOdds", "Note")
		local note = Base.text(
			canvas,
			"Note",
			np.x,
			np.y + 6,
			np.w,
			np.h - 12,
			SmashScreens.KIT_WORDS.oddsNote,
			{
				z = 3,
			}
		)
		note.TextWrapped = true
		return {}
	end)
end

-- ===== Crate reveal: the rarity card with its ribbon, the 3D kart and NEW KART!, over the crate =====

-- data: { id, rarity, note, again: boolean }; actions: cool(), again()
function KitWindows.reveal(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("reveal", "full", true, function(g)
		local r = UiTheme.rarityId(data.rarity)
		local colorName = UiTheme.RARITY[r].color
		local color = Base.color(colorName)
		local back = g.back :: ScreenGui
		local bdrop = Kit.backdrop(back, "reveal", colorName)
		-- the kit's warm ground: purple at the top to orange at the bottom (Studio r51: flat navy)
		bdrop.BackgroundColor3 = WHITE
		Kit.face(bdrop, { "5a2a8c", "9a3f8f", "e07a4a" })
		Kit.confetti(bdrop, 22)
		local canvas = g.canvas
		-- the crates it came from, small and dim at the sides, and the open one under the card
		for i, side in { "SideL", "SideR" } do
			local sp = piece("kitReveal", side)
			local c = Icons.make(
				spot(canvas, "kitReveal", side),
				"crate",
				0,
				0,
				sp.h,
				{ rarity = data.rarity, z = 2 }
			)
			c.Rotation = if i == 1 then -8 else 8
			Anim.bob(c, UiTheme.MOTION.carBob, 5, i * 0.5)
		end
		local crp = piece("kitReveal", "Crate")
		Icons.make(
			spot(canvas, "kitReveal", "Crate"),
			"crate",
			(crp.w - crp.h) / 2,
			0,
			crp.h,
			{ rarity = data.rarity, open = true, z = 2 }
		)
		-- the card: rarity face, a white rim and an ink drop, tilted a little as in the kit
		local cp = piece("kitReveal", "Card")
		local holder = spot(canvas, "kitReveal", "Card")
		holder.Rotation = -3
		local drop = Base.fill(holder, "Drop", 0, 6, cp.w, cp.h, INK, 3)
		Base.corner(drop, 22)
		local card = Base.fill(holder, "Card", 0, 0, cp.w, cp.h, color, 4)
		Base.corner(card, 22)
		Base.outline(card, 5, WHITE)
		Kit.gloss(card, color, 0.3)
		Kit.rays(card, cp.w / 2, cp.h * 0.42, cp.w * 1.1, "go", 0.75)
		local view = Base.box(card, "KartSpot", 10, 30, cp.w - 20, cp.h * 0.56, 6)
		if not KartView.over(view, data.id) then
			Icons.car(view, 0, 0, cp.w - 20, cp.h * 0.56, { id = data.id, color = color, z = 6 })
		end
		Kit.tag(card, 14, 10, UiTheme.RARITY[r].word, colorName, 30, 9)
		Kit.title(card, 6, cp.h - 70, cp.w - 12, 60, SmashScreens.KIT_WORDS.newKart, "gold")
		Anim.pop(holder, 0.5, 0.4)
		for i, s in { { 210, 60 }, { 520, 40 }, { 506, 214 }, { 232, 236 } } do
			Kit.sparkle(canvas, s[1], s[2], 26, i * 0.3)
		end
		placedButton(canvas, "kitReveal", "Cool", Screen.act(actions, "cool"))
		-- (again = false: no OPEN ANOTHER, there's none left to open)
		if data.again ~= false then
			placedButton(canvas, "kitReveal", "Again", Screen.act(actions, "again"))
		end
		local np = piece("kitReveal", "Note")
		local note = Kit.navyPanel(spot(canvas, "kitReveal", "Note"), "Note", 0, 0, np.w, np.h, 14)
		Base.text(
			note,
			"Words",
			12,
			10,
			np.w - 24,
			np.h - 20,
			data.note or "",
			{ align = "l", z = 5 }
		).TextWrapped =
			true
		return {}
	end)
end

-- ===== Daily: 7 day cards (got dim with a check, today ringed, day 7 gold), CLAIM, the track =====

-- data: { days = { { day, coins, state = "got" | "today" | "later", crate } } (7), today: n,
--   claimWords? (unused here: today's card shows the crate) } (the gift is already paid by
--   the server: CLAIM only takes it)
-- actions: claim(), close()
function KitWindows.daily(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("daily", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local cp = piece("kitDaily", "Close")
		Kit.close(spot(canvas, "kitDaily", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local dp = piece("kitDaily", "Days")
		local holder = spot(canvas, "kitDaily", "Days")
		local days: { { [string]: any } } = data.days or {}
		local n = math.max(#days, 1)
		local gap = 8
		local cw = (dp.w - (n - 1) * gap) / n
		local cards: { GuiObject } = {}
		for i, d in days do
			local x = (i - 1) * (cw + gap)
			local last = i == #days
			-- (each card in its own holder, so its drop and glow rise with it)
			local box = Base.box(holder, "Day" .. i, x, 0, cw, dp.h, 2)
			local card = Kit.plate(box, "Card", 0, 0, cw, dp.h, d.state == "today")
			if last then
				Kit.face(card, UiTheme.CHROME.tabGold)
			end
			if d.state == "today" then
				-- (the kit rings today in green)
				local ring = card:FindFirstChild("Ring")
				for _, st in if ring then ring:GetDescendants() else {} do
					if st:IsA("UIStroke") then
						st.Color = Base.color("lime")
					end
				end
			end
			Base.text(card, "Head", 4, 8, cw - 8, 22, `DAY {d.day}`, { stroke = 3, z = 5 })
			local slot = Base.fill(
				card,
				"Slot",
				8,
				38,
				cw - 16,
				dp.h - 82,
				Kit.hex(UiTheme.CHROME.track[2]),
				3
			)
			Base.corner(slot, 10)
			local s = math.min(cw - 24, dp.h - 96)
			local icon = Icons.make(
				slot,
				if d.crate then "crate" else "coin",
				(cw - 16 - s) / 2,
				(dp.h - 82 - s) / 2,
				s,
				{
					rarity = "common", -- (the free crate the server gives)
					z = 4,
				}
			)
			if d.state == "today" then
				Anim.bob(icon, UiTheme.MOTION.carBob, 4)
			end
			Base.text(card, "Coins", 4, dp.h - 38, cw - 8, 26, `+{UiMotion.commas(d.coins or 0)}`, {
				stroke = 3,
				z = 5,
			})
			if d.state == "got" then
				local dim = Base.fill(card, "Dim", 0, 0, cw, dp.h, INK, 6)
				dim.BackgroundTransparency = 0.5
				Base.corner(dim, 14)
				Icons.make(card, "check", (cw - 44) / 2, (dp.h - 44) / 2, 44, { z = 7 })
			end
			table.insert(cards, box)
		end
		task.defer(function()
			Anim.cascade(cards)
		end)
		-- (today's coins on CLAIM's chip: alone at the bottom they read as a stray line, r56)
		local todayDay = days[math.clamp(data.today or 1, 1, math.max(#days, 1))]
		placedButton(canvas, "kitDaily", "Claim", Screen.act(actions, "claim"), {
			chip = if todayDay then `+{UiMotion.commas(todayDay.coins or 0)}` else nil,
		})
		-- the streak track: a dot a day, lit up to today
		local tp = piece("kitDaily", "Track")
		local track = spot(canvas, "kitDaily", "Track")
		local today = math.clamp(data.today or 1, 1, n)
		local bh = 14
		local bar = Kit.bar(track, "Bar", 0, (tp.h - bh) / 2, tp.w, bh, "go", { still = true })
		bar.ClipsDescendants = false
		Kit.setBar(bar, if n > 1 then (today - 1) / (n - 1) else 1, true)
		for i = 1, n do
			local ds = if i == today then 30 else 22
			local cx = if n > 1 then (i - 1) / (n - 1) * (tp.w - 30) + 15 else tp.w / 2
			local dot = Base.fill(
				track,
				"Dot" .. i,
				cx - ds / 2,
				(tp.h - ds) / 2,
				ds,
				ds,
				Base.color(if i <= today then "go" else "barEmpty"),
				4
			)
			Base.corner(dot)
			Base.outline(dot, UiTheme.OUTLINE.small)
		end
		local np = piece("kitDaily", "Note")
		local notePill =
			Kit.navyPanel(spot(canvas, "kitDaily", "Note"), "Pill", 0, 0, np.w, np.h, 14)
		Base.text(notePill, "Note", 12, 8, np.w - 24, np.h - 16, SmashScreens.KIT_WORDS.dailyNote, {
			stroke = 3,
			z = 3,
		})
		return {}
	end)
end

-- ===== Quests (today's jobs): a row each with its icon tile, words, bar and gold coin pill =====

-- data: { title?, timer?, rows = { { icon, words, have, need, reward, done } } }
-- actions: close()
function KitWindows.quests(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("quests", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local tp = piece("kitQuests", "Title")
		Kit.title(
			spot(canvas, "kitQuests", "Title"),
			0,
			0,
			tp.w,
			tp.h,
			data.title or "JOBS",
			nil,
			"l"
		)
		if data.timer and data.timer ~= "" then
			local mp = piece("kitQuests", "Timer")
			Base.text(
				canvas,
				"Timer",
				mp.x,
				mp.y + 6,
				mp.w,
				mp.h - 12,
				`NEW JOBS IN {data.timer}`,
				{
					stroke = 3,
					z = 3,
				}
			)
		end
		local cp = piece("kitQuests", "Close")
		Kit.close(spot(canvas, "kitQuests", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local lp = piece("kitQuests", "List")
		local list = spot(canvas, "kitQuests", "List")
		local rows: { { [string]: any } } = data.rows or {}
		if #rows == 0 then
			Base.text(
				list,
				"Empty",
				0,
				120,
				lp.w,
				40,
				SmashScreens.KIT_WORDS.noJobs,
				{ stroke = 3, z = 3 }
			)
		end
		local n = math.max(#rows, 1)
		local gap = 10
		local rh = math.min(78, (lp.h - (n - 1) * gap) / n)
		local shown: { GuiObject } = {}
		for i, r in rows do
			local box =
				Base.box(list, "Row" .. i, 6, (i - 1) * (rh + gap) + 4, lp.w - 12, rh - 8, 2)
			local row = Kit.navyPanel(box, "Panel", 0, 0, lp.w - 12, rh - 8, 14)
			local rw = lp.w - 12
			local ih = rh - 22
			local tile = Base.fill(
				row,
				"Icon",
				8,
				7,
				ih,
				ih,
				Base.color(if r.done then "lime" else "blue"),
				4
			)
			Base.corner(tile, 10)
			Base.outline(tile, UiTheme.OUTLINE.small)
			Kit.gloss(tile, tile.BackgroundColor3, 0.3)
			Icons.make(tile, r.icon or "coin", ih * 0.12, ih * 0.12, ih * 0.76, { z = 5 })
			local left = ih + 22
			local pw = 130
			local mid = rw - left - pw - 22
			Base.text(
				row,
				"Words",
				left,
				6,
				mid,
				(rh - 8) * 0.38,
				r.words or "",
				{ stroke = 3, align = "l", z = 5 }
			)
			local need = math.max(r.need or 1, 1)
			local have = math.clamp(r.have or 0, 0, need)
			local bar = Kit.bar(
				row,
				"Bar",
				left,
				(rh - 8) * 0.52,
				mid,
				(rh - 8) * 0.34,
				if r.done then "lime" else "blue",
				{
					z = 5,
				}
			)
			Kit.setBar(bar, have / need, true)
			Base.text(
				bar,
				"Count",
				0,
				2,
				mid,
				(rh - 8) * 0.34 - 4,
				`{have}/{need}`,
				{ stroke = 2.5, z = 6 }
			)
			local pill = Base.fill(
				row,
				"Reward",
				rw - pw - 10,
				7,
				pw,
				rh - 22,
				Kit.hex(UiTheme.CHROME.track[2]),
				4
			)
			Base.corner(pill, 12)
			Base.outline(pill, 2.5, Kit.hex(UiTheme.CHROME.cardSelected))
			local ps = rh - 34
			Icons.make(pill, if r.done then "check" else "coin", 8, 6, ps, { z = 5 })
			Base.text(
				pill,
				"Coins",
				ps + 14,
				8,
				pw - ps - 22,
				ps - 4,
				if r.done then "DONE!" else UiMotion.commas(r.reward or 0),
				{
					stroke = 3,
					align = "l",
					z = 5,
				}
			)
			table.insert(shown, box)
		end
		task.defer(function()
			Anim.cascade(shown)
		end)
		return {}
	end)
end

-- ===== Leaderboard: GLOBAL / FRIENDS tabs, 5 rows (top 3 gold, silver, bronze), face, kart =====

local PLACE_FACE = {
	{ "fff7b8", "ffd93b", "ffb400" },
	{ "e6f0ff", "a9c3ea", "7f9cc8" },
	{ "ffd2b8", "e89a6c", "c06a3c" },
}
local PLACE_DISC = { "ffc22e", "c3cddc", "d68a4c" }

-- data: { tab = 1 | 2, rows = { { userId, name, score, carId?, me? } }?, words? (shown when no
--   rows: loading, none yet), mine: number (your trophies) }
-- actions: tab(i), close()
function KitWindows.board(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("leaderboard", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local mp = piece("kitBoard", "Mine")
		Kit.currency(
			canvas,
			"Mine",
			mp.x,
			mp.y,
			mp.w,
			mp.h,
			{ value = data.mine or 0, icon = "trophy" }
		)
		local tp = piece("kitBoard", "Tabs")
		Kit.tabs(
			spot(canvas, "kitBoard", "Tabs"),
			0,
			0,
			tp.w,
			tp.h,
			{ "GLOBAL", "FRIENDS" },
			data.tab or 1,
			Screen.act(actions, "tab")
		)
		local cp = piece("kitBoard", "Close")
		Kit.close(spot(canvas, "kitBoard", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local pp = piece("kitBoard", "Panel")
		local panel = Kit.navyPanel(spot(canvas, "kitBoard", "Panel"), "Panel", 0, 0, pp.w, pp.h)
		local rows: { { [string]: any } } = data.rows or {}
		if #rows == 0 then
			Base.text(
				panel,
				"Empty",
				20,
				pp.h / 2 - 20,
				pp.w - 40,
				40,
				data.words or "",
				{ stroke = 3, z = 5 }
			)
			return {}
		end
		local pad, gap = 12, 8
		local rh = (pp.h - 2 * pad - 4 * gap) / 5
		local rw = pp.w - 2 * pad
		local shown: { GuiObject } = {}
		for i, r in rows do
			if i > 5 then
				break
			end
			local box = Base.box(panel, "Row" .. i, pad, pad + (i - 1) * (rh + gap), rw, rh, 4)
			local row = Kit.plate(box, "Plate", 0, 0, rw, rh - 4, r.me == true, 12)
			local face = PLACE_FACE[i]
			if face then
				Kit.face(row, face)
			end
			local ih = rh - 12
			-- the place: a metal disc for the top 3, else the number
			if PLACE_DISC[i] then
				local disc = Base.fill(row, "Disc", 10, 4, ih, ih, Kit.hex(PLACE_DISC[i]), 5)
				Base.corner(disc)
				Base.outline(disc, UiTheme.OUTLINE.small)
				Base.text(disc, "N", 0, ih * 0.15, ih, ih * 0.7, tostring(i), { stroke = 3, z = 6 })
			else
				Base.text(row, "N", 10, 6, ih, ih - 4, tostring(i), { stroke = 3, z = 5 })
			end
			-- their face (Roblox's own head shot of the user id)
			local fx = ih + 20
			local ring = Base.fill(row, "Face", fx, 4, ih, ih, Kit.hex(UiTheme.CHROME.panelRim), 5)
			Base.corner(ring)
			Base.outline(ring, UiTheme.OUTLINE.small)
			local img = Instance.new("ImageLabel")
			img.Name = "Head"
			img.BackgroundTransparency = 1
			img.ZIndex = 6
			img.Image = `rbxthumb://type=AvatarHeadShot&id={math.floor(r.userId or 0)}&w=150&h=150`
			img.Size = UDim2.fromScale(1, 1)
			img.Parent = ring
			Base.corner(img)
			-- their kart, when we know it (players in this server)
			local kx = fx + ih + 10
			local kw = ih * 1.6
			if r.carId then
				KartView.make(row, kx, 0, kw, rh - 4, r.carId, 6)
			end
			local nx = kx + kw + 10
			Base.text(row, "Name", nx, rh * 0.24, rw * 0.62 - nx - 8, rh * 0.42, r.name or "", {
				stroke = 3,
				align = "l",
				z = 6,
			})
			Base.text(
				row,
				"Score",
				rw * 0.62,
				rh * 0.16,
				rw * 0.38 - 16,
				rh * 0.56,
				UiMotion.commas(r.score or 0),
				{
					stroke = 3.5,
					align = "r",
					z = 6,
				}
			)
			table.insert(shown, box)
		end
		task.defer(function()
			Anim.cascade(shown)
		end)
		return {}
	end)
end

-- ===== League up: LEAGUE UP! in gold, the new badge with rays, its name and pay, arrows rising =====

-- data: { to: number (1..4), name, pay, color: Color3, confetti: number, hold: number (AWESOME!
--   waits this long), shake: boolean, top: boolean }
-- actions: ok()
function KitWindows.leagueUp(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("leagueUp", "full", true, function(g)
		local back = g.back :: ScreenGui
		local bd = Kit.backdrop(back, "showroom")
		-- the kit's ground: blue at the top to warm orange (r56: sky blue)
		bd.BackgroundColor3 = WHITE
		-- (the showroom's own sky gradient goes first: two UIGradients on one frame, one wins)
		local sky = bd:FindFirstChildOfClass("UIGradient")
		if sky then
			sky:Destroy()
		end
		Kit.face(bd, { "3f7fe0", "8a6aa8", "d9784a" })
		local floor = bd:FindFirstChild("Floor")
		if floor then
			floor:Destroy()
		end
		Kit.confetti(bd, 22 + (data.confetti or 0))
		local canvas = g.canvas
		local tp = piece("kitLeagueUp", "Title")
		local title =
			Kit.title(spot(canvas, "kitLeagueUp", "Title"), 0, 0, tp.w, tp.h, "LEAGUE UP!", "gold")
		Anim.shout(title)
		local bp = piece("kitLeagueUp", "Badge")
		local color: Color3 = data.color or Base.color("go")
		local rays = Kit.rays(canvas, bp.x + bp.w / 2, bp.y + bp.h / 2, 360, "go", 0.3)
		for _, r in rays:GetChildren() do
			if r:IsA("Frame") then
				r.BackgroundColor3 = color
			end
		end
		local badgeSpot = spot(canvas, "kitLeagueUp", "Badge")
		badgeSpot.ZIndex = 3
		local badge = Icons.badge(badgeSpot, data.to or 2, 0, 0, bp.w, false)
		Anim.pop(badge, 0.6, 0.3, 0.3)
		Anim.bob(badgeSpot, UiTheme.MOTION.carBob, 6)
		if data.shake and not Base.reduced() then
			task.delay(0.6, function()
				for i, deg in { -8, 8, -6, 6, -3, 0 } do
					task.delay((i - 1) * 0.07, function()
						if badgeSpot.Parent then
							Anim.to(badgeSpot, 0.07, { Rotation = deg })
						end
					end)
				end
			end)
		end
		for i, name in { "ArrowL1", "ArrowL2", "ArrowR2", "ArrowR1" } do
			local ap = piece("kitLeagueUp", name)
			local holder = spot(canvas, "kitLeagueUp", name)
			local s = math.min(ap.w, ap.h)
			local arrow = Icons.make(holder, "arrow", (ap.w - s) / 2, ap.h - s, s, { z = 3 })
			arrow.Rotation = -90
			Anim.bob(holder, 1.2, 8, i * 0.25)
		end
		for i, sp in { { 230, 110 }, { 520, 96 }, { 560, 220 }, { 196, 240 } } do
			Kit.sparkle(canvas, sp[1], sp[2], 26, i * 0.4)
		end
		local np = piece("kitLeagueUp", "Name")
		local pill =
			Kit.navyPanel(spot(canvas, "kitLeagueUp", "Name"), "Pill", 0, 0, np.w, np.h, 16)
		Base.text(
			pill,
			"League",
			10,
			4,
			np.w - 20,
			26,
			if data.top then "TOP LEAGUE!" else data.name or "",
			{
				color = color,
				stroke = 4,
				z = 5,
			}
		)
		Base.text(pill, "Pay", 10, 32, np.w - 20, 18, data.pay or "", { z = 5 })
		Anim.pop(pill, 0.5, 0.3, 0.5)
		-- AWESOME! comes last, so a tapping kid doesn't skip the moment
		local ok = placedButton(canvas, "kitLeagueUp", "Awesome", Screen.act(actions, "ok"))
		local okSpot = ok.Parent :: GuiObject
		okSpot.Visible = false
		task.delay(data.hold or 0.9, function()
			if okSpot.Parent then
				okSpot.Visible = true
				Anim.pop(okSpot, 0.35, 0.6)
			end
		end)
		return {}
	end)
end

-- A scrolling area x, y, w, h of parent whose list is contentH tall (in design px; sized from
-- the scroller's real width so it never stretches)
local function scroller(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	contentH: number
): Frame
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "Scroll"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ScrollBarImageColor3 = Kit.hex(UiTheme.CHROME.panelRim)
	sf.ScrollBarThickness = math.floor(6 * Base.k)
	sf.ZIndex = 4
	sf.Parent = parent
	Base.at(sf, x, y, w, h)
	local total = math.max(h, contentH)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list:SetAttribute("DW", w)
	list:SetAttribute("DH", total)
	list.Parent = sf
	local function room()
		local aw = sf.AbsoluteSize.X
		local ah = aw * total / w
		list.Size = UDim2.fromOffset(aw, ah)
		sf.CanvasSize = UDim2.fromOffset(0, ah)
	end
	sf:GetPropertyChangedSignal("AbsoluteSize"):Connect(room)
	room()
	return list
end

-- ===== Garage (CUSTOMIZE): KARTS / HATS, a card grid with rarity dots, the picked one big, EQUIP =====

-- data: { tab: 1 | 2, karts = { Item }, hats = { Item }?, hatsSoon: boolean?, hatOn = { name }? }
--   Item = { name, rarity, id? (a kart's car id), own: boolean?, on: boolean? }
-- actions: tab(i), equip(tab, i), close()  (the same as Smash.customize)
function KitWindows.garage(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("customize", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local tab = if data.tab == 2 then 2 else 1
		local picked = 1
		local cp = piece("kitGarage", "Close")
		Kit.close(spot(canvas, "kitGarage", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local gp = piece("kitGarage", "Grid")
		local gridPanel =
			Kit.navyPanel(spot(canvas, "kitGarage", "Grid"), "Panel", 0, 0, gp.w, gp.h)
		local sp = piece("kitGarage", "Show")
		local showPanel =
			Kit.navyPanel(spot(canvas, "kitGarage", "Show"), "Panel", 0, 0, sp.w, sp.h)
		local equip: TextButton
		local function list(): { any }
			return (if tab == 1 then data.karts else data.hats) or {}
		end
		local function refreshButton()
			local words, works = SmashScreens.equipButton(list()[picked], tab == 2)
			Kit.setWords(equip, words)
			Kit.enable(equip, works)
		end
		equip = placedButton(canvas, "kitGarage", "Equip", function()
			local _, works = SmashScreens.equipButton(list()[picked], tab == 2)
			if works then
				Screen.act(actions, "equip")(tab, picked)
			end
		end)
		local show: Frame? = nil
		-- the picked one, big: the 3D kart (or the hat), its name and rarity
		local function showPicked()
			if show then
				show:Destroy()
			end
			local holder = Base.box(showPanel, "Show", 0, 0, sp.w, sp.h, 4)
			show = holder
			local it = list()[picked]
			if tab == 2 and data.hatsSoon then
				return -- (the grid already says hats are on the way)
			end
			if not it then
				local words = if tab == 1 then SmashScreens.KIT_WORDS.noKarts else "No hats yet."
				Base.text(
					holder,
					"Empty",
					12,
					sp.h / 2 - 30,
					sp.w - 24,
					60,
					words,
					{ stroke = 3, z = 5 }
				).TextWrapped =
					true
				return
			end
			local color = if tab == 1 then Smash.carColor(it.id, 1) else rarityColor(it.rarity)
			Kit.rays(
				holder,
				sp.w / 2,
				84,
				160,
				UiTheme.RARITY[UiTheme.rarityId(it.rarity)].color,
				0.7
			)
			if tab == 1 then
				local view = Base.box(holder, "KartSpot", 10, 10, sp.w - 20, 150, 5)
				if not KartView.over(view, it.id) then
					Icons.car(view, 0, 0, sp.w - 20, 150, { id = it.id, color = color, z = 5 })
				end
				-- the hat on the kart you drive, in the corner (the old card's "with its hat")
				local hatOn = data.hatOn
				if it.on and hatOn then
					Smash.hat(holder, 8, 6, 40, rarityColor(hatOn.rarity))
					Base.text(holder, "HatName", 4, 46, 90, 16, string.upper(hatOn.name or ""), {
						stroke = 2.5,
						z = 7,
					})
				end
			elseif it.own ~= false then
				Smash.hat(holder, sp.w / 2 - 50, 30, 100, color)
			else
				Icons.make(holder, "lock", sp.w / 2 - 36, 44, 72, { z = 5 })
			end
			Base.text(
				holder,
				"Name",
				10,
				164,
				sp.w - 20,
				28,
				string.upper(it.name or ""),
				{ stroke = 3.5, z = 6 }
			)
			Base.text(
				holder,
				"Rarity",
				10,
				194,
				sp.w - 20,
				22,
				UiTheme.RARITY[UiTheme.rarityId(it.rarity)].word,
				{
					color = color,
					stroke = 3,
					z = 6,
				}
			)
		end
		local grid: Frame? = nil
		local function fill()
			if grid then
				grid:Destroy()
			end
			local holder = Base.box(gridPanel, "Grid", 0, 0, gp.w, gp.h, 4)
			grid = holder
			local items = list()
			picked = 1
			for i, it in items do
				if it.on then
					picked = i
				end
			end
			if tab == 2 and data.hatsSoon then
				Base.text(
					holder,
					"Soon",
					12,
					gp.h / 2 - 24,
					gp.w - 24,
					48,
					SmashScreens.KIT_WORDS.hatsSoon,
					{
						stroke = 4,
						z = 5,
					}
				)
				showPicked()
				refreshButton()
				Kit.enable(equip, false)
				return
			end
			-- (cards 8 in from the scroller's sides: the picked one's ring and glow sit outside its
			-- card, and the scroller clips; room for the scroll bar on the right)
			local pad, edge = 4, 8
			local boxes = SmashScreens.garageCards(#items, gp.w - 2 * pad - 2 * edge - 8)
			local last = boxes[#boxes]
			local inner = scroller(
				holder,
				pad,
				pad,
				gp.w - 2 * pad,
				gp.h - 2 * pad,
				if last then last.y + last.h + 2 * edge else 0
			)
			local cards: { Frame } = {}
			local shown: { GuiObject } = {}
			for i, it in items do
				local b = boxes[i]
				local tile = Instance.new("TextButton")
				tile.Name = "Item" .. i
				tile.Text = ""
				tile.AutoButtonColor = false
				tile.BackgroundTransparency = 1
				tile.ZIndex = 5
				tile.Parent = inner
				Base.at(tile, b.x + edge, b.y + edge, b.w, b.h)
				local card = Kit.plate(tile, "Card", 0, 0, b.w, b.h - 4, i == picked, 12)
				-- (a kart's own colour: drawn karts of one rarity all looked alike)
				local color = if tab == 1 then Smash.carColor(it.id, 1) else rarityColor(it.rarity)
				if tab == 1 then
					Icons.car(card, 6, 14, b.w - 12, b.h - 54, { id = it.id, color = color, z = 4 })
				elseif it.own ~= false then
					Smash.hat(card, b.w / 2 - 34, 22, 68, color)
				else
					Icons.make(card, "lock", b.w / 2 - 24, 30, 48, { z = 4 })
				end
				if tab == 2 then
					-- (a hat's name under it: the cards were nameless, Studio r56)
					Base.text(
						card,
						"Name",
						6,
						b.h - 50,
						b.w - 12,
						18,
						string.upper(it.name or ""),
						{
							stroke = 2.5,
							z = 5,
						}
					)
				end
				if it.on then
					Kit.tag(card, 8, 8, "ON", "lime", 22, 9)
				end
				-- the rarity dots (lit up to its rarity, in its colour)
				local lit = SmashScreens.rarityDots(it.rarity)
				local ds, dg = 12, 6
				local dx = (b.w - (4 * ds + 3 * dg)) / 2
				for d = 1, 4 do
					local dot = Base.fill(
						card,
						"Dot" .. d,
						dx + (d - 1) * (ds + dg),
						b.h - 30,
						ds,
						ds,
						if d <= lit then color else Kit.hex(UiTheme.CHROME.track[2]),
						5
					)
					Base.corner(dot)
					Base.outline(dot, 1.5)
				end
				Anim.press(tile)
				tile.Activated:Connect(function()
					local was = cards[picked]
					if was then
						Kit.select(was, false)
					end
					picked = i
					Kit.select(card, true)
					refreshButton()
					showPicked()
				end)
				cards[i] = card
				table.insert(shown, tile)
			end
			task.defer(function()
				Anim.cascade(shown)
			end)
			showPicked()
			refreshButton()
		end
		local tp = piece("kitGarage", "Tabs")
		local tabs: Kit.Tabs
		tabs = Kit.tabs(
			spot(canvas, "kitGarage", "Tabs"),
			0,
			0,
			tp.w,
			tp.h,
			{ "KARTS", "HATS" },
			tab,
			function(i: number)
				tabs.set(i) -- (Kit.tabs only tells us: the highlight moves here)
				tab = i
				Screen.act(actions, "tab")(i)
				fill()
			end
		)
		fill()
		return {}
	end)
end

-- ===== Settings: MUSIC and SOUNDS sliders, SHADOWS and NAME TAGS switches =====

-- A slider: a recessed bar and a knob, set by a tap or a drag (0..1); onChange on letting go.
local function slider(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	value: number,
	onChange: (v: number) -> ()
)
	local b = Instance.new("TextButton")
	b.Name = "Slider"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 5
	b.Parent = parent
	Base.at(b, x, y, w, h)
	local bh = 16
	local knobS = 36
	local track =
		Kit.bar(b, "Bar", knobS / 2, (h - bh) / 2, w - knobS, bh, "blue", { still = true, z = 5 })
	local knob = Base.fill(b, "Knob", 0, (h - knobS) / 2, knobS, knobS, WHITE, 7)
	Base.corner(knob)
	Base.outline(knob, UiTheme.OUTLINE.normal)
	local kg = Instance.new("UIGradient")
	kg.Rotation = 90
	kg.Color = ColorSequence.new(WHITE, Kit.hex("8fd8ff"))
	kg.Parent = knob
	local v = math.clamp(value, 0, 1)
	local function draw()
		local fill = track:FindFirstChild("Fill") :: Frame?
		if fill then
			fill.Size = UDim2.fromScale(v, 1)
		end
		knob.Position = UDim2.fromScale(v * (w - knobS) / w, knob.Position.Y.Scale)
	end
	draw()
	local function at(px: number)
		local left = b.AbsolutePosition.X + b.AbsoluteSize.X * (knobS / 2) / w
		local span = b.AbsoluteSize.X * (w - knobS) / w
		v = math.clamp((px - left) / math.max(span, 1), 0, 1)
		draw()
	end
	local moving: RBXScriptConnection? = nil
	local ending: RBXScriptConnection? = nil
	local function stop()
		if moving then
			moving:Disconnect()
			moving = nil
		end
		if ending then
			ending:Disconnect()
			ending = nil
		end
	end
	b.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		stop()
		at(input.Position.X)
		moving = UserInputService.InputChanged:Connect(function(m: InputObject)
			if m.UserInputType == Enum.UserInputType.MouseMovement or m == input then
				at(m.Position.X)
			end
		end)
		ending = UserInputService.InputEnded:Connect(function(e: InputObject)
			if e == input or e.UserInputType == Enum.UserInputType.MouseButton1 then
				stop()
				onChange(v)
			end
		end)
	end)
	-- (the window closes mid-drag: nothing left listening)
	b.Destroying:Connect(stop)
end

-- data: { music: 0..1, sfx: 0..1, shadows: boolean, names: boolean }
-- actions: set(key, value), close()
function KitWindows.settings(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("settings", "window", true, function(g)
		ground(g.back) -- (the lobby HUD showed through the kit's gaps, Studio r56)
		local canvas = g.canvas
		local tp = piece("kitSettings", "Title")
		Kit.title(spot(canvas, "kitSettings", "Title"), 0, 0, tp.w, tp.h, "SETTINGS", nil, "l")
		local cp = piece("kitSettings", "Close")
		Kit.close(spot(canvas, "kitSettings", "Close"), 0, 0, Screen.act(actions, "close"), cp.w)
		local set = Screen.act(actions, "set")
		local sp = piece("kitSettings", "Sliders")
		local left =
			Kit.navyPanel(spot(canvas, "kitSettings", "Sliders"), "Panel", 0, 0, sp.w, sp.h)
		for i, row in { { "music", "MUSIC" }, { "sfx", "SOUNDS" } } do
			local y = 30 + (i - 1) * 120
			Base.text(
				left,
				"Word" .. i,
				20,
				y,
				sp.w - 40,
				32,
				row[2],
				{ stroke = 3.5, align = "l", z = 5 }
			)
			slider(
				left,
				16,
				y + 40,
				sp.w - 32,
				56,
				if type(data[row[1]]) == "number" then data[row[1]] else 1,
				function(v)
					set(row[1], v)
				end
			)
		end
		local op = piece("kitSettings", "Toggles")
		local right =
			Kit.navyPanel(spot(canvas, "kitSettings", "Toggles"), "Panel", 0, 0, op.w, op.h)
		for i, row in { { "shadows", "SHADOWS" }, { "names", "NAME TAGS" } } do
			local y = 24 + (i - 1) * 100
			local key = row[1]
			local state = data[key] ~= false
			-- (the whole row is the tap: the switch alone is under 44 px tall)
			local hit = Instance.new("TextButton")
			hit.Name = "Row" .. i
			hit.Text = ""
			hit.AutoButtonColor = false
			hit.BackgroundTransparency = 1
			hit.ZIndex = 5
			hit.Parent = right
			Base.at(hit, 12, y, op.w - 24, 80)
			local line = Base.fill(
				right,
				"Line" .. i,
				12,
				y + 86,
				op.w - 24,
				2,
				Kit.hex(UiTheme.CHROME.panelRim),
				4
			)
			line.BackgroundTransparency = 0.6
			Base.text(
				hit,
				"Word",
				8,
				24,
				op.w - 130,
				32,
				row[2],
				{ stroke = 3.5, align = "l", z = 6 }
			)
			local toggle: Kit.Toggle
			toggle = Kit.toggle(hit, op.w - 24 - 84, 20, state, function(on: boolean)
				state = on
				set(key, on)
			end)
			toggle.button.ZIndex = 7
			hit.Activated:Connect(function()
				state = not state
				toggle.set(state)
				set(key, state)
			end)
		end
		return {}
	end)
end

return KitWindows
