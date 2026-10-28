--!strict
-- Car VS Car window screens (spec section 6): 6 Crates (odds first), 8 Garage, 11 Daily rewards,
-- 12 Car book, 13 Settings, 14 Leaderboard, 15 Quests, 16 Popups. White windows with the cyan
-- title outside the top-left, the tilted red X, and the world blurred behind; one at a time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Pattern = require(Ui:WaitForChild("Pattern"))
local Screen = require(Ui:WaitForChild("Screen"))

local Windows = {}

local INK, WHITE = Base.color("ink"), Base.WHITE

local function piece(id: string, name: string): UiScreens.Piece
	return UiScreens.piece(id, name)
end

-- The screen's window, opened (entrance), its X calling actions.close.
local function window(
	g: Base.Gui,
	id: string,
	actions: Screen.Actions?,
	opts: { [string]: any }?
): Kit.Window
	local o: { [string]: any } = opts or {}
	o.onClose = Screen.act(actions, "close")
	local w = Kit.window(g.canvas, piece(id, "Window"), o)
	w.open()
	return w
end

local function button(
	parent: Instance,
	id: string,
	path: string,
	onClick: () -> (),
	extra: { [string]: any }?
): TextButton
	local pc = piece(id, path)
	local o: { [string]: any } = extra or {}
	o.main = pc.main
	o.onClick = onClick
	return Kit.button(
		parent,
		pc.name,
		pc.x,
		pc.y,
		pc.w,
		pc.h,
		pc.tone or "lime",
		o.words or pc.text or "",
		o
	)
end

-- A light row inside a white window.
local function row(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: string?,
	edge: string?
): Frame
	local r = Base.fill(parent, name, x, y, w, h, Base.color(fill or "rowFill"), 2)
	Base.corner(r, 14)
	Base.outline(r, UiTheme.OUTLINE.normal, Base.color(edge or "rowEdge"))
	return r
end

-- A scrolling grid area: returns the list frame to place items in (its design height grows).
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
	sf.ScrollBarImageColor3 = Base.color("blue")
	sf.ScrollBarThickness = math.floor(6 * Base.k)
	sf.ZIndex = 3
	sf.Parent = parent
	Base.at(sf, x, y, w, h)
	local total = math.max(h, contentH)
	-- the list is sized in real px from the scroller's real width (Scale inside a ScrollingFrame
	-- goes by the canvas, which stretches), and the scroll room follows it
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

-- ===== 6 Crates: 3 crate choices, a big shaking crate, OPEN with its price, the odds =====

-- data: { choices = { { word, rarity, price, priceWords?, odds = { { rarity, chance } } } } (3), chosen: n,
--   best: n (the BEST VALUE tag), coins: n, note: string }
-- actions: choose(i), open(i), close()
function Windows.crates(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("crates", "window", false, function(g)
		local win = window(g, "crates", actions)
		local c = win.content
		local chosen = data.chosen or 1
		local choices = data.choices or {}
		local slots: { Kit.Slot } = {}
		local bigHolder: Frame? = nil
		local oddsHolder: Frame? = nil
		local openB: TextButton? = nil
		local tag: Frame? = nil
		local function show(i: number)
			chosen = i
			local ch = choices[i] or {}
			for j, s in slots do
				s.setSelected(j == i)
			end
			if bigHolder then
				bigHolder:Destroy()
			end
			local cp = piece("crates", "Window.Crate")
			local holder = Base.box(c, "Big", cp.x, cp.y, cp.w, cp.h, 3)
			bigHolder = holder
			local crate = Icons.make(holder, "crate", 0, 0, cp.w, { rarity = ch.rarity, z = 3 })
			crate.AnchorPoint = Vector2.new(0.5, 0.9)
			crate.Position = UDim2.fromScale(0.5, 0.9)
			Anim.shake(crate)
			if tag then
				tag:Destroy()
				tag = nil
			end
			if data.best == i then
				local tp = piece("crates", "Window.Tag")
				tag = Kit.tag(c, tp.x, tp.y, "BEST VALUE", "danger", tp.h)
			end
			if oddsHolder then
				oddsHolder:Destroy()
			end
			local op = piece("crates", "Window.Odds")
			oddsHolder = Base.box(c, "OddsHolder", op.x, op.y, op.w, op.h, 3)
			Kit.odds(oddsHolder :: Frame, 0, 0, op.w, op.h, ch.odds or {})
			if openB then
				openB:Destroy()
			end
			openB = button(c, "crates", "Window.Open", function()
				Screen.act(actions, "open")(chosen)
			end, { chip = ch.priceWords or UiMotion.commas(ch.price or 0) })
		end
		for i = 1, 3 do
			local ch = choices[i]
			if ch then
				local pc = piece("crates", "Window.Choice" .. i)
				local s = Kit.slot(
					c,
					"Choice" .. i,
					pc.x,
					pc.y,
					64,
					{ tone = if i == 3 then "gold" elseif i == 2 then "blue" else "lime" }
				)
				Icons.make(s.button, "crate", 4, 4, 56, { rarity = ch.rarity, z = 6 })
				Base.text(
					c,
					"Word" .. i,
					pc.x - 8,
					pc.y + 74,
					80,
					14,
					ch.word or "",
					{ color = Base.color("inkMuted"), z = 7 }
				)
				s.button.Activated:Connect(function()
					show(i)
					Screen.act(actions, "choose")(i)
				end)
				slots[i] = s
			end
		end
		local sp = piece("crates", "Window.Section")
		Kit.section(c, sp.x, sp.y, sp.w, sp.h, "WHAT CAN I GET?")
		local np = piece("crates", "Window.Note")
		local note = Base.text(
			c,
			"Note",
			np.x,
			np.y,
			np.w,
			np.h,
			data.note or "1 new car per crate.",
			{ color = Base.color("inkMuted"), z = 3 }
		)
		note.TextWrapped = true
		local kp = piece("crates", "Window.Coins")
		Kit.currency(c, "Coins", kp.x, kp.y, kp.w, kp.h, { value = data.coins or 0 })
		show(chosen)
		return { show = show }
	end)
end

-- ===== 8 Garage: ON TRACK row, MY CARS grid, EQUIP BEST, room pill; the glowing card on the
-- right flips when you tap another car =====

-- data: { onTrack = { car } (3), cars = { car }, selected: n, room: "14 / 50", trackTag: "3/3",
--   trackWord: "ON TRACK" } where car = { id, name, rarity, stars, tone, count, badge, color,
--   kind, stats = { power, air, speed } (words like "12") }
--   live game extras: slots (how many ON TRACK slots), more (a + slot), equipWord, deleteWord,
--   deleteTone, bestWord (other words on the buttons; deleteWord = no red X on the car)
-- actions: select(i), equip(i), delete(i), equipBest(), room(), station(i), more(), close()
function Windows.garage(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("garage", "window", false, function(g)
		local win = window(g, "garage", actions)
		local c = win.content
		local op = piece("garage", "Window.OnTrack")
		Kit.section(c, op.x, op.y, op.w, op.h, data.trackWord or "ON TRACK", "goDeep")
		local sp = piece("garage", "Window.OnSlots")
		local onList: { GuiObject } = {}
		-- 3 slots, or one per station (the live game: up to 9, smaller so they fit the row) and
		-- a + slot for one more station
		local onTrack = data.onTrack or {}
		local n = math.max(data.slots or 3, #onTrack) + (if data.more then 1 else 0)
		local ss = math.min(62, (op.w - (n - 1) * 8) / n)
		local ox = if n <= 3 then sp.x else op.x + (op.w - (n * ss + (n - 1) * 8)) / 2
		local oy = sp.y + (62 - ss) / 2
		for i = 1, n do
			local car = onTrack[i]
			local isMore = data.more and i == n
			local s =
				Kit.slot(c, if isMore then "More" else "On" .. i, ox + (i - 1) * (ss + 8), oy, ss, {
					tone = if car then "lime" else "empty",
					count = car and car.count,
					badge = car and car.badge,
					car = car and { id = car.id, color = car.color, kind = car.kind },
				})
			s.button.Activated:Connect(function()
				if isMore then
					Screen.act(actions, "more")()
				else
					Screen.act(actions, "station")(i)
				end
			end)
			table.insert(onList, s.button)
		end
		Anim.cascade(onList)
		local mp = piece("garage", "Window.Mine")
		Kit.section(c, mp.x, mp.y, mp.w, mp.h, "MY CARS")
		local gp = piece("garage", "Window.Grid")
		local cars = data.cars or {}
		local cols, size, gap = 7, 56, 9
		local rows = math.ceil(#cars / cols)
		local list = scroller(c, gp.x, gp.y, gp.w, gp.h, rows * (size + gap) + 8)
		local x0 = (gp.w - (cols * size + (cols - 1) * gap)) / 2
		local slots: { Kit.Slot } = {}
		local cardHolder: Frame? = nil
		local selected = data.selected or 1
		local cp = piece("garage", "Card")
		local cardSpot = Instance.new("Frame")
		cardSpot.Name = "CardSpot"
		cardSpot.BackgroundTransparency = 1
		cardSpot.Parent = g.canvas
		Base.place(cardSpot, cp)
		local function showCard(i: number, flip: boolean)
			local car = cars[i]
			if cardHolder then
				cardHolder:Destroy()
			end
			if not car then
				return
			end
			local holder = Base.box(cardSpot, "Holder", 0, 0, cp.w, cp.h, 2)
			cardHolder = holder
			local card = Kit.card(holder, "Card", 0, 0, cp.w, cp.h, {
				name = car.name,
				rarity = if car.golden then "golden" else car.rarity,
				stars = car.stars,
				ribbon = if car.golden then "GOLDEN" elseif car.new then "NEW!" else nil,
				carId = car.id,
				color = car.color,
				kind = car.kind,
				tilt = 2,
			})
			-- the 3 stats in a dark box
			local box = Base.fill(card.card, "Stats", 10, card.contentY, cp.w - 20, 60, INK, 4)
			box.BackgroundTransparency = 0.78
			Base.corner(box, 12)
			for j, stat in UiTheme.STATS do
				local y = 4 + (j - 1) * 18
				Base.text(
					box,
					stat.word,
					10,
					y,
					80,
					16,
					stat.word,
					{ stroke = 3.5, align = "l", z = 5 }
				)
				Base.text(
					box,
					stat.word .. "Value",
					cp.w - 120,
					y,
					90,
					16,
					tostring((car.stats or {})[stat.key] or ""),
					{
						color = Base.color(UiTheme.TONES[stat.tone].fill),
						stroke = 3.5,
						align = "r",
						z = 5,
					}
				)
			end
			local ep = piece("garage", "Card.Equip")
			Kit.button(
				card.card,
				"Equip",
				ep.x,
				ep.y,
				ep.w,
				ep.h,
				"lime",
				data.equipWord or "EQUIP",
				{
					size = 18,
					z = 8,
					onClick = function()
						Screen.act(actions, "equip")(i)
					end,
				}
			)
			local dp = piece("garage", "Card.Delete")
			Kit.button(
				card.card,
				"Delete",
				dp.x,
				dp.y,
				dp.w,
				dp.h,
				data.deleteTone or "danger",
				data.deleteWord or "DELETE",
				{
					size = 18,
					z = 8,
					onClick = function()
						local s = slots[i]
						if s and not data.deleteWord then
							s.setMarked(true)
						end
						Screen.act(actions, "delete")(i)
					end,
				}
			)
			if flip then
				card.flip()
			end
		end
		local items: { GuiObject } = {}
		for i, car in cars do
			local col, r = (i - 1) % cols, (i - 1) // cols
			local s =
				Kit.slot(list, "Car" .. i, x0 + col * (size + gap), 8 + r * (size + gap), size, {
					tone = car.tone or "blue",
					count = car.count,
					badge = car.badge,
					selected = i == selected,
					marked = car.marked,
					car = { id = car.id, color = car.color, kind = car.kind },
				})
			slots[i] = s
			table.insert(items, s.button)
			s.button.Activated:Connect(function()
				if selected == i then
					return
				end
				local was = slots[selected]
				if was then
					was.setSelected(false)
				end
				selected = i
				s.setSelected(true)
				showCard(i, true)
				Screen.act(actions, "select")(i)
			end)
		end
		Anim.cascade(items)
		showCard(selected, true)
		button(
			c,
			"garage",
			"Window.EquipBest",
			Screen.act(actions, "equipBest"),
			if data.bestWord then { words = data.bestWord } else nil
		)
		local rp = piece("garage", "Window.Room")
		Kit.pill(
			c,
			"Room",
			rp.x,
			rp.y,
			rp.w,
			rp.h,
			data.trackTag or "3/3",
			"lime",
			data.room or "",
			{ plus = true }
		)
		return {}
	end)
end

-- ===== 11 Daily rewards: 6 tiles (claimed dim with a check, today glowing and pulsing, later
-- plain), the big purple Day 7 gift tile, the streak pill, CLAIM DAY n =====

-- data: { days = { { icon, amount, state = "got" | "today" | "later" } } (6), day7 = words,
--   streak = 3, today = 3 }
-- actions: claim(), close()
function Windows.daily(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("daily", "window", false, function(g)
		local win = window(g, "daily", actions)
		local c = win.content
		local hp = piece("daily", "Window.Help")
		Base.text(
			c,
			"Help",
			hp.x,
			hp.y,
			hp.w,
			hp.h,
			"Come back every day! Day 7 is the big one.",
			{ color = Base.color("inkMuted"), align = "l", z = 3 }
		)
		local stp = piece("daily", "Window.Streak")
		Kit.pill(
			c,
			"Streak",
			stp.x,
			stp.y,
			stp.w,
			stp.h,
			"STREAK",
			"boost",
			tostring(data.streak or 1) .. " days"
		)
		local tp = piece("daily", "Window.Tiles")
		local tiles: { GuiObject } = {}
		for i, d in data.days or {} do
			local x = tp.x + (i - 1) * 96
			local st = d.state or "later"
			local holder = Base.box(c, "Day" .. i, x, tp.y, 86, tp.h, 3)
			if st == "today" then
				local glow =
					Base.fill(holder, "Glow", -10, -10, 106, tp.h + 20, Base.color("go"), 1)
				glow.BackgroundTransparency = 0.55
				Base.corner(glow, 24)
				local ring = Base.fill(holder, "Ring", -4, -4, 94, tp.h + 8, WHITE, 2)
				Base.corner(ring, 20)
			end
			local drop = Base.fill(holder, "Drop", 0, 4, 86, tp.h, INK, 3)
			Base.corner(drop, 16)
			local tile = Base.fill(holder, "Tile", 0, 0, 86, tp.h, WHITE, 4)
			Base.corner(tile, 16)
			Base.outline(tile, UiTheme.OUTLINE.normal)
			if st == "got" then
				tile.BackgroundColor3 = Color3.fromRGB(223, 234, 245)
			elseif st == "today" then
				Kit.gloss(tile, Base.color("go"), 0.45)
				Pattern.attach(Base.box(tile, "Clip", 4, 4, 78, tp.h - 8, 1))
				Anim.pulse(holder, 1.05, 1.6)
			else
				local gr = Instance.new("UIGradient")
				gr.Rotation = 90
				gr.Color = ColorSequence.new(WHITE, Color3.fromRGB(232, 243, 255))
				gr.Parent = tile
				Pattern.attach(Base.box(tile, "Clip", 4, 4, 78, tp.h - 8, 1), true)
			end
			Base.text(tile, "Day", 4, 6, 78, 16, "DAY " .. i, {
				color = if st == "today" then WHITE else Base.color("blue"),
				stroke = if st == "today" then 3.5 else 3,
				strokeColor = if st == "today" then INK else WHITE,
				z = 3,
			})
			local ic = Icons.make(tile, d.icon or "coin", 20, 28, 46, { rarity = "epic", z = 3 })
			local amount = Base.text(
				tile,
				"Amount",
				4,
				80,
				78,
				24,
				"x" .. tostring(d.amount or ""),
				{ stroke = 5, z = 3 }
			)
			if st == "got" then
				for _, x2 in ic:GetDescendants() do
					if x2:IsA("GuiObject") then
						x2.BackgroundTransparency = math.max(x2.BackgroundTransparency, 0.55)
					end
				end
				amount.TextTransparency = 0.5
				Icons.make(tile, "check", 21, 37, 44, { z = 6 })
			end
			table.insert(tiles, holder)
		end
		local dp = piece("daily", "Window.Day7")
		local d7 = Base.box(c, "Day7", dp.x, dp.y, dp.w, dp.h, 3)
		local drop = Base.fill(d7, "Drop", 0, 4, dp.w, dp.h, INK, 1)
		Base.corner(drop, 18)
		local t7 = Base.fill(d7, "Tile", 0, 0, dp.w, dp.h, WHITE, 2)
		Base.corner(t7, 18)
		Base.outline(t7, UiTheme.OUTLINE.normal)
		local gr = Instance.new("UIGradient")
		gr.Rotation = 70
		gr.Color = ColorSequence.new(Base.color("lilac"), Base.color("purple"))
		gr.Parent = t7
		Pattern.attach(Base.box(t7, "Clip", 4, 4, dp.w - 8, dp.h - 8, 1))
		Base.text(t7, "Day", 4, 6, dp.w - 8, 16, "DAY 7", { stroke = 3.5, z = 3 })
		local gift = Icons.make(t7, "gift", (dp.w - 64) / 2, 24, 64, { z = 3 })
		Anim.bob(gift, UiTheme.MOTION.carBob, 5)
		Base.text(
			t7,
			"Words",
			4,
			92,
			dp.w - 8,
			18,
			data.day7 or "MYSTERY CAR",
			{ stroke = 4, z = 3 }
		)
		table.insert(tiles, d7)
		Anim.cascade(tiles)
		button(
			c,
			"daily",
			"Window.Claim",
			Screen.act(actions, "claim"),
			{ words = "CLAIM DAY " .. tostring(data.today or 1) }
		)
		return {}
	end)
end

-- ===== 12 Car book: filter tabs, "6 / 36 FOUND", milestone bar, the grid (unowned cars are dark
-- shapes with a lock) =====

-- data: { tabs = { words }, tab = 1, found, total, marks = { { at, label, icon } },
--   cars = { { id, name, color, kind, own, new } } }
-- actions: tab(i), close()
function Windows.book(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("book", "window", false, function(g)
		local win = window(g, "book", actions)
		local c = win.content
		local tp = piece("book", "Window.Tabs")
		Kit.tabs(
			c,
			tp.x,
			tp.y,
			tp.w,
			tp.h,
			data.tabs or { "ALL" },
			data.tab or 1,
			Screen.act(actions, "tab")
		)
		local fp = piece("book", "Window.Found")
		Base.text(
			c,
			"Found",
			fp.x,
			fp.y,
			fp.w,
			fp.h,
			`{data.found or 0} / {data.total or 0} FOUND`,
			{ color = Base.color("blue"), align = "r", z = 3 }
		)
		local mp = piece("book", "Window.Milestones")
		local total = math.max(1, data.total or 1)
		Kit.milestones(c, mp.x, mp.y, mp.w, mp.h, (data.found or 0) / total, data.marks or {})
		local gp = piece("book", "Window.Grid")
		local cars = data.cars or {}
		local cols, gap = 6, 8
		local cw = (gp.w - 12 - (cols - 1) * gap) / cols -- (12 kept for the scroll bar)
		local ch = 84
		local list = scroller(c, gp.x, gp.y, gp.w, gp.h, math.ceil(#cars / cols) * (ch + gap) + 4)
		local items: { GuiObject } = {}
		for i, car in cars do
			local col, r = (i - 1) % cols, (i - 1) // cols
			local x, y = col * (cw + gap), 2 + r * (ch + gap)
			local holder = Base.box(list, "Car" .. i, x, y, cw, ch, 2)
			local drop = Base.fill(holder, "Drop", 0, 3, cw, ch, INK, 1)
			Base.corner(drop, 14)
			local tile = Base.fill(holder, "Tile", 0, 0, cw, ch, WHITE, 2)
			Base.corner(tile, 14)
			tile.ClipsDescendants = true
			if car.own then
				Base.outline(tile, UiTheme.OUTLINE.normal, Base.color("blueDeep"))
				local gr = Instance.new("UIGradient")
				gr.Rotation = 90
				gr.Color = ColorSequence.new(WHITE, Color3.fromRGB(223, 243, 255))
				gr.Parent = tile
				Icons.car(
					tile,
					(cw - 84) / 2,
					4,
					84,
					54,
					{ id = car.id, color = car.color, kind = car.kind }
				)
				Base.text(tile, "Name", 4, 60, cw - 8, 18, car.name or "", { stroke = 3.5, z = 4 })
				if car.new then
					Kit.tag(holder, 2, 2, "NEW", "lime", 18, 9)
				end
			else
				tile.BackgroundColor3 = Base.color("lockedFill")
				Base.outline(tile, UiTheme.OUTLINE.normal, Base.color("lockedEdge"))
				local shade =
					Icons.car(tile, (cw - 84) / 2, 4, 84, 54, { kind = car.kind, color = INK })
				for _, d in shade:GetDescendants() do
					if d:IsA("Frame") then
						d.BackgroundColor3 = INK
						d.BackgroundTransparency = 0.65
						local grad = d:FindFirstChildOfClass("UIGradient")
						if grad then
							grad:Destroy()
						end
					end
				end
				Base.text(
					tile,
					"Name",
					4,
					60,
					cw - 8,
					18,
					"? ? ?",
					{ color = Color3.fromRGB(127, 147, 171), z = 4 }
				)
				Icons.make(holder, "lock", cw - 26, 4, 22, { z = 6 })
			end
			table.insert(items, holder)
		end
		Anim.cascade(items)
		return {}
	end)
end

-- ===== 13 Settings: 2 x 2 toggles, the camera slider, CODES + RESET =====

-- data: { music, sounds, vibrate, low = booleans, camera = 0..1 }
-- actions: toggle(name, on), camera(f), codes(), reset(), close()
function Windows.settings(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("settings", "window", false, function(g)
		local win = window(g, "settings", actions)
		local c = win.content
		local rows: { GuiObject } = {}
		for _, t in
			{
				{ "Music", "music", "Music" },
				{ "Sounds", "sounds", "Sounds" },
				{ "Vibrate", "vibrate", "Vibrate" },
				{ "Low", "low", "Low graphics" },
			}
		do
			local rp = piece("settings", "Window." .. t[1])
			local r = row(c, t[1], rp.x, rp.y, rp.w, rp.h)
			Base.text(r, "Words", 14, 15, rp.w - 110, 24, t[3], { color = INK, align = "l", z = 3 })
			Kit.toggle(r, rp.w - 86, 7, data[t[2]] == true, function(on: boolean)
				Screen.act(actions, "toggle")(t[2], on)
			end)
			table.insert(rows, r)
		end
		Anim.cascade(rows)
		local cp = piece("settings", "Window.Camera")
		local r = row(c, "Camera", cp.x, cp.y, cp.w, cp.h)
		Base.text(r, "Words", 14, 15, 96, 24, "Camera", { color = INK, align = "l", z = 3 })
		local bx, bw = 120, cp.w - 150
		local bar = Kit.bar(r, "Track", bx, 19, bw, 16, "blue", { still = true })
		local knob = Base.fill(r, "Knob", 0, 12, 30, 30, WHITE, 5)
		Base.corner(knob)
		Base.outline(knob, UiTheme.OUTLINE.normal)
		local kg = Instance.new("UIGradient")
		kg.Rotation = 90
		kg.Color = ColorSequence.new(WHITE, Color3.fromRGB(223, 232, 243))
		kg.Parent = knob
		local value = data.camera or 0.6
		local function set(f: number)
			value = math.clamp(f, 0, 1)
			Kit.setBar(bar, value)
			knob.Position = UDim2.fromScale((bx + bw * value - 15) / cp.w, 12 / cp.h)
		end
		set(value)
		local dragging = false
		local function follow(pos: Vector3)
			local a, s = bar.AbsolutePosition, bar.AbsoluteSize
			if s.X > 0 then
				set((pos.X - a.X) / s.X)
			end
		end
		r.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				follow(input.Position)
			end
		end)
		r.Active = true
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				follow(input.Position)
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging = false
				Screen.act(actions, "camera")(value)
			end
		end)
		r.Destroying:Connect(function()
			moved:Disconnect()
			ended:Disconnect()
		end)
		button(c, "settings", "Window.Codes", Screen.act(actions, "codes"))
		button(c, "settings", "Window.Reset", Screen.act(actions, "reset"))
		return {}
	end)
end

-- ===== 14 Leaderboard: tabs, rows with gold / silver / bronze rank discs, car, name, league
-- shield and trophies; your own row pinned at the bottom in lime =====

local MEDAL = {
	[1] = { Color3.fromRGB(255, 243, 166), Color3.fromRGB(255, 194, 46) },
	[2] = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(195, 205, 220) },
	[3] = { Color3.fromRGB(255, 209, 166), Color3.fromRGB(214, 138, 76) },
}

-- data: { tabs = { words }, tab = 1, rows = { { rank, name, league, trophies, color, kind, id } },
--   me = same }
-- actions: tab(i), close()
function Windows.leaderboard(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("leaderboard", "window", false, function(g)
		local win = window(g, "leaderboard", actions)
		local c = win.content
		local tp = piece("leaderboard", "Window.Tabs")
		Kit.tabs(
			c,
			tp.x,
			tp.y,
			tp.w,
			tp.h,
			data.tabs or { "THIS WEEK", "ALL TIME", "FRIENDS" },
			data.tab or 1,
			Screen.act(actions, "tab"),
			{ "trophy" }
		)
		local function line(name: string, e: { [string]: any }, me: boolean): Frame
			local rp = piece("leaderboard", "Window." .. name)
			local r = row(
				c,
				name,
				rp.x,
				rp.y,
				rp.w,
				rp.h,
				if me then "lime" else nil,
				if me then "limeDeep" else nil
			)
			if me then
				Kit.gloss(r, Base.color("lime"), 0.35)
				Pattern.attach(Base.box(r, "Clip", 3, 3, rp.w - 6, rp.h - 6, 1))
				local drop = Base.fill(c, name .. "Drop", rp.x, rp.y + 3, rp.w, rp.h, INK, 1)
				Base.corner(drop, 14)
			end
			local rank = e.rank or 0
			local disc = Base.fill(r, "Rank", 8, (rp.h - 38) / 2, 38, 38, WHITE, 3)
			Base.corner(disc)
			Base.outline(disc, UiTheme.OUTLINE.normal)
			local m = MEDAL[rank]
			if m then
				local gr = Instance.new("UIGradient")
				gr.Rotation = 90
				gr.Color = ColorSequence.new(m[1], m[2])
				gr.Parent = disc
			end
			Base.text(disc, "N", 4, 9, 30, 20, tostring(rank), { stroke = 3.5, z = 4 })
			Icons.car(r, 54, (rp.h - 38) / 2, 60, 38, { id = e.id, color = e.color, kind = e.kind })
			Base.text(r, "Name", 124, (rp.h - 22) / 2, rp.w - 340, 22, e.name or "", {
				color = if me then WHITE else INK,
				stroke = if me then 3.5 else nil,
				align = "l",
				z = 3,
			})
			Icons.badge(r, e.league or 1, rp.w - 200, (rp.h - 36) / 2, 36, false)
			Icons.make(r, "trophy", rp.w - 140, (rp.h - 28) / 2, 28, { z = 3 })
			Base.text(
				r,
				"Trophies",
				rp.w - 108,
				(rp.h - 24) / 2,
				96,
				24,
				UiMotion.commas(e.trophies or 0),
				{ stroke = 5, align = "r", z = 3 }
			)
			return r
		end
		local list: { GuiObject } = {}
		for i, e in data.rows or {} do
			if i <= 3 then
				table.insert(list, line("Row" .. i, e, false))
			end
		end
		local dp = piece("leaderboard", "Window.Dots")
		Base.text(
			c,
			"Dots",
			dp.x,
			dp.y,
			dp.w,
			dp.h,
			". . .",
			{ color = Base.color("inkMuted"), z = 3 }
		)
		if data.me then
			table.insert(list, line("Me", data.me, true))
		end
		Anim.cascade(list)
		return {}
	end)
end

-- ===== 15 Quests: DAILY / WEEKLY tabs, refresh timer, rows with icon tile, progress bar,
-- reward and CLAIM (lime, pulsing) / GO (blue) / DONE! =====

-- data: { tab = 1, timer = "5:12:08", rows = { { icon, words, have, need, rewardIcon, reward,
--   state = "claim" | "go" | "done" } } }
-- actions: tab(i), claim(i), go(i), close()
function Windows.quests(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("quests", "window", false, function(g)
		local win = window(g, "quests", actions)
		local c = win.content
		local tp = piece("quests", "Window.Tabs")
		Kit.tabs(
			c,
			tp.x,
			tp.y,
			tp.w,
			tp.h,
			{ "DAILY", "WEEKLY" },
			data.tab or 1,
			Screen.act(actions, "tab")
		)
		local mp = piece("quests", "Window.Timer")
		Kit.pill(c, "Timer", mp.x, mp.y, mp.w, mp.h, "NEW IN", "blue", data.timer or "")
		local list: { GuiObject } = {}
		for i, q in data.rows or {} do
			if i > 3 then
				break
			end
			local rp = piece("quests", "Window.Row" .. i)
			local st = q.state or "go"
			local r = row(
				c,
				"Row" .. i,
				rp.x,
				rp.y,
				rp.w,
				rp.h,
				if st == "claim" then "claimFill" elseif st == "done" then "doneFill" else nil,
				if st == "claim" then "goDeep" else nil
			)
			local tile = Base.fill(r, "IconTile", 10, 10, 52, 52, Base.color("blueDeep"), 3)
			Base.corner(tile, 14)
			Base.outline(tile, UiTheme.OUTLINE.normal)
			local face = Base.fill(tile, "Face", 0, 0, 52, 48, WHITE, 1)
			Base.corner(face, 14)
			Kit.gloss(face, Base.color("blue"), 0.4)
			Pattern.attach(Base.box(face, "Clip", 3, 3, 46, 42, 1))
			Icons.make(tile, q.icon or "trophy", 7, 5, 38, { z = 4 })
			Base.text(
				r,
				"Words",
				74,
				10,
				250,
				22,
				q.words or "",
				{ color = INK, align = "l", z = 3 }
			)
			local have, need = q.have or 0, math.max(1, q.need or 1)
			local f = math.clamp(have / need, 0, 1)
			local bar = Kit.bar(r, "Bar", 74, 40, 200, 18, if f >= 1 then "lime" else "go")
			Kit.setBar(bar, f, true)
			Base.text(
				r,
				"Count",
				280,
				40,
				50,
				18,
				`{have}/{need}`,
				{ color = Base.color("inkMuted"), align = "l", z = 3 }
			)
			Icons.make(r, q.rewardIcon or "coin", 338, 22, 28, { z = 3 })
			Base.text(
				r,
				"Reward",
				370,
				22,
				70,
				26,
				tostring(q.reward or ""),
				{ stroke = 5, align = "l", z = 3 }
			)
			if st == "claim" then
				local holder = Base.box(r, "Act", 470, 11, 112, 50, 4)
				Kit.button(holder, "Claim", 0, 0, 112, 50, "lime", "CLAIM", {
					onClick = function()
						Screen.act(actions, "claim")(i)
					end,
				})
				Anim.pulse(holder, 1.06, 1.2)
			elseif st == "go" then
				Kit.button(r, "Go", 470, 11, 112, 50, "blue", "GO", {
					onClick = function()
						Screen.act(actions, "go")(i)
					end,
				})
			else
				Base.text(
					r,
					"Done",
					470,
					22,
					112,
					28,
					"DONE!",
					{ color = Base.color("lime"), stroke = 5, z = 3 }
				)
				r.BackgroundTransparency = 0.25
			end
			table.insert(list, r)
		end
		Anim.cascade(list)
		return {}
	end)
end

-- ===== 16 Popups: a blue confirm window that grows from an empty blue box, then the words fade
-- in; YES (lime) LEFT of NO (red). One at a time. =====

Windows.POPUPS = {
	coins = {
		icon = "coin",
		title = "Not enough coins",
		text = "You need 320 more.",
		yes = { "GET COINS", "lime" },
		no = { "LATER", "white" },
	},
	sell = {
		icon = "bag",
		title = "Sell 2 cars?",
		text = "You get 120 coins.",
		yes = { "YES", "lime" },
		no = { "NO", "danger" },
	},
	leave = {
		icon = "trophy",
		title = "Leave race?",
		text = "You will lose this race.",
		yes = { "LEAVE", "danger" },
		no = { "STAY", "lime" },
	},
}

-- data: { kind = "coins" | "sell" | "leave", title?, text?, icon?, yes = { words, tone }?,
--   no = { words, tone }? } (these override the kind's)
-- actions: yes(), no()
function Windows.popup(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("popup", "popup", false, function(g)
		local k = Windows.POPUPS[data.kind or "sell"] or Windows.POPUPS.sell
		local win = Kit.window(g.canvas, piece("popups", "Window"), { blue = true })
		Anim.pop(win.root, 0.3, 0.55)
		local c = win.content
		c.Visible = false
		local ip = piece("popups", "Window.Icon")
		local iconName = data.icon or k.icon
		local icon = Icons.make(c, iconName, ip.x, ip.y, ip.w, { z = 4 })
		if iconName == "coin" then
			Anim.shake(icon)
		end
		local tp = piece("popups", "Window.Title")
		Base.text(c, "Title", tp.x, tp.y, tp.w, tp.h, data.title or k.title, { stroke = 5, z = 4 })
		local xp = piece("popups", "Window.Text")
		Base.text(c, "Text", xp.x, xp.y, xp.w, xp.h, data.text or k.text, { stroke = 3.5, z = 4 })
		local yp, np = piece("popups", "Window.Yes"), piece("popups", "Window.No")
		local yes, no = data.yes or k.yes, data.no or k.no
		Kit.button(
			c,
			"Yes",
			yp.x,
			yp.y,
			yp.w,
			yp.h,
			yes[2],
			yes[1],
			{ onClick = Screen.act(actions, "yes"), size = 17 }
		)
		Kit.button(
			c,
			"No",
			np.x,
			np.y,
			np.w,
			np.h,
			no[2],
			no[1],
			{ onClick = Screen.act(actions, "no"), size = 17 }
		)
		task.delay(if Base.reduced() then 0 else UiTheme.MOTION.popupWords + 0.12, function()
			if c.Parent then
				c.Visible = true
				for _, d in c:GetDescendants() do
					if d:IsA("TextLabel") then
						local want = d.TextTransparency
						d.TextTransparency = 1
						Anim.to(d, 0.2, { TextTransparency = want })
					end
				end
			end
		end)
		-- a dim layer behind so taps outside do nothing but close it
		return {}
	end)
end

return Windows
