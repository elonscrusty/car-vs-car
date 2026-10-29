--!strict
-- carter's UI kit v41 windows (WINDOWS, ui-kit/v41/WINDOWS-PLAN.md), Smash only: the Shop (one
-- CRATES tab with the crates you can buy), Crate odds (always before OPEN) and the Crate reveal.
-- Places come from shared/SmashScreens, prices and odds from shared/Crates (via the caller); the
-- server decides every buy and every kart, these only show it and ask.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	return Screen.open("crates", "window", false, function(g)
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
			Icons.car(row, 8, rh * 0.1, rh * 1.5, rh * 0.8, { color = color, z = 5 })
			local dot = Base.fill(row, "Dot", rh * 1.5 + 16, rh * 0.3, rh * 0.4, rh * 0.4, color, 5)
			Base.corner(dot)
			Base.outline(dot, 2, WHITE)
			Base.text(
				row,
				"Word",
				rh * 1.9 + 22,
				rh * 0.22,
				rw * 0.6 - (rh * 1.9 + 22) - 8,
				rh * 0.56,
				UiTheme.RARITY[UiTheme.rarityId(r.rarity)].word,
				{ stroke = 3, align = "l", z = 5 }
			)
			Base.text(
				row,
				"Chance",
				rw * 0.6,
				rh * 0.18,
				rw * 0.4 - 12,
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
		Kit.backdrop(back, "reveal", colorName)
		Kit.confetti(back:FindFirstChild("Backdrop") :: Frame, 22)
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
--   claimWords? } (the gift is already paid by the server: CLAIM only takes it)
-- actions: claim(), close()
function KitWindows.daily(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("daily", "window", false, function(g)
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
		placedButton(canvas, "kitDaily", "Claim", Screen.act(actions, "claim"))
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
		Base.text(
			canvas,
			"Note",
			np.x,
			np.y + 8,
			np.w,
			np.h - 16,
			data.claimWords or SmashScreens.KIT_WORDS.dailyNote,
			{
				stroke = 3,
				z = 3,
			}
		)
		return {}
	end)
end

-- ===== Quests (today's jobs): a row each with its icon tile, words, bar and gold coin pill =====

-- data: { title?, timer?, rows = { { icon, words, have, need, reward, done } } }
-- actions: close()
function KitWindows.quests(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("quests", "window", false, function(g)
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

return KitWindows
