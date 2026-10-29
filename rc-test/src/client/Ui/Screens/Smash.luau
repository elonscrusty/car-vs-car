--!strict
-- Smash game screens (WINDOWS): the match end (YOU WON! / TOP 3! / NICE TRY!, steps 2-1-3 with
-- names and smashes, Rewards with coins and your place, PLAY AGAIN that presses itself) and the
-- 3-step how-to over a match (DRIVE!, GRAB A ?, TAP FIRE!). Places come from shared/SmashScreens,
-- words and numbers from shared/MatchEnd.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local MatchEnd = require(Shared:WaitForChild("MatchEnd"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Screen = require(Ui:WaitForChild("Screen"))
local KartView = require(script.Parent:WaitForChild("KartView"))

local Smash = {}

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
	onClick: () -> ()
): TextButton
	local pc = piece(id, name)
	return Kit.button(
		spot(canvas, id, name),
		"Button",
		0,
		0,
		pc.w,
		pc.h,
		pc.tone or "lime",
		pc.text or "",
		{ main = pc.main, onClick = onClick }
	)
end

-- a car's own colour, or one per place for a bot with no car of ours (three different colours)
local PLACE_COLORS = { "danger", "blue", "pink" }
local function carColor(carId: string?, pl: number): Color3
	local c = if carId then CarCatalog.get(carId) else nil
	if c and c.color and #c.color >= 3 then
		return Color3.fromRGB(c.color[1], c.color[2], c.color[3])
	end
	return Base.color(PLACE_COLORS[pl] or "blue")
end

-- show `obj` after `delay` s with a pop (the screen may be closed by then: then nothing)
local function popLater(obj: GuiObject, delay: number, then_: (() -> ())?)
	obj.Visible = false
	task.delay(delay, function()
		if obj.Parent then
			obj.Visible = true
			Anim.pop(obj, 0.38, 0.3)
			if then_ then
				then_()
			end
		end
	end)
end

-- ===== Between rounds (12 s), carter's pick B (10-29, win-screen/ in project files): YOU WIN! in
-- gold (or "<NAME> WINS!"), the top 3 karts on podium steps 2-1-3 with names and smashes, a navy
-- strip with your coins, XP and place, NEXT ROUND n counting down, a small LEAVE =====

-- the podium steps, left to right: which place, x, height (design px in the Podium piece)
local STEPS = { { 2, 0, 100 }, { 1, 192, 130 }, { 3, 384, 78 } }
local STEP_W = 176
-- gold, silver, bronze: the step's face and its place disc (the kit's leaderboard rows)
local STEP_FACE = {
	{ "fff7b8", "ffd93b", "ffb400" },
	{ "e6f0ff", "a9c3ea", "7f9cc8" },
	{ "ffd2b8", "e89a6c", "c06a3c" },
}
local STEP_DISC = { "ffc22e", "c3cddc", "d68a4c" }

-- view: MatchEnd.read(...); actions: leave()
-- The handle's set(secondsLeft) updates the count.
function Smash.matchEnd(
	view: MatchEnd.View,
	actions: Screen.Actions?,
	bar: MatchEnd.XpBar?
): Screen.Handle
	return Screen.open("matchEnd", "full", true, function(g)
		local back = g.back :: ScreenGui
		-- the kit's navy ground with gold rays (as League up)
		local bd = Kit.backdrop(back, "showroom")
		local sky = bd:FindFirstChildOfClass("UIGradient")
		if sky then
			sky:Destroy()
		end
		Kit.face(bd, UiTheme.CHROME.ground)
		local floor = bd:FindFirstChild("Floor")
		if floor then
			floor:Destroy()
		end
		local won = view.winner ~= nil and view.winner.me
		if won then
			Kit.confetti(bd, 30)
		end
		local canvas = g.canvas
		local sp = piece("matchEnd", "Shout")
		local title = Kit.title(
			spot(canvas, "matchEnd", "Shout"),
			0,
			0,
			sp.w,
			sp.h,
			MatchEnd.winWords(view),
			if won then "gold" else "white"
		)
		Anim.shout(title)
		-- the podium: each kart on its step, a place disc, the name and the smashes
		local pp = piece("matchEnd", "Podium")
		local podium = spot(canvas, "matchEnd", "Podium")
		for _, st in STEPS do
			local i, x, h = st[1], st[2], st[3]
			local row = view.top[i]
			if not row then
				continue
			end
			local top = pp.h - h
			local hold = Base.box(podium, "Step" .. i, x, 0, STEP_W, pp.h, 3)
			-- the kart, bigger for the winner, bobbing on top of its step
			local cw = if i == 1 then 168 else 150
			local ch = cw * 0.55
			local cx, cy = (STEP_W - cw) / 2, top - ch + 4
			local car: GuiObject = KartView.make(hold, cx, cy, cw, ch, row.carId, 4)
				or Icons.car(hold, cx, cy + ch * 0.1, cw, cw * 0.5, {
					id = row.carId,
					color = carColor(row.carId, i),
					z = 4,
				})
			Anim.pop(car, 0.5, 0.2 + i * 0.12, 0.3)
			if i == 1 then
				Anim.bob(car, UiTheme.MOTION.carBob, 5)
			end
			local step = Base.fill(hold, "Step", 0, top, STEP_W, h, WHITE, 3)
			Base.corner(step, 14)
			Kit.face(step, STEP_FACE[i])
			-- (you: a lime ring round your step)
			if row.me then
				Base.outline(step, 4, Base.color("lime"))
			else
				Base.outline(step, UiTheme.OUTLINE.normal)
			end
			local disc =
				Base.fill(hold, "Disc", STEP_W / 2 - 20, top - 18, 40, 40, Kit.hex(STEP_DISC[i]), 6)
			Base.corner(disc)
			Base.outline(disc, UiTheme.OUTLINE.small)
			Base.text(disc, "N", 0, 6, 40, 28, tostring(i), { stroke = 3, z = 7 })
			Base.text(
				step,
				"Name",
				8,
				24,
				STEP_W - 16,
				26,
				if row.me then "YOU" else SmashJuice.shortName(row.name),
				{
					color = if row.me then Base.color("lime") else WHITE,
					stroke = 4,
					z = 5,
				}
			)
			Base.text(step, "Smashes", 8, 50, STEP_W - 16, 22, MatchEnd.smashWords(row.smashes), {
				stroke = 3,
				z = 5,
			})
			Anim.pop(step, 0.4, 0.15 + i * 0.12, 0.3)
		end
		-- what you got, popping in one after the other: coins, XP, the level bar, then your place
		-- (all in by 1.6 s: a shot in the first seconds read as a half-empty panel, auditor 14:48)
		local rp = piece("matchEnd", "Rewards")
		local rew =
			Kit.navyPanel(spot(canvas, "matchEnd", "Rewards"), "Panel", 0, 0, rp.w, rp.h, 16)
		-- what this round paid (not your wallet): a spinning coin and "+25"
		local paid = Base.box(rew, "Coins", 10, 6, 150, 34, 4)
		local coin = Icons.make(paid, "coin", 0, 0, 34, { z = 5 })
		Kit.coinSpin(coin)
		Base.text(paid, "Amount", 40, 0, 110, 34, `+{view.coins}`, {
			color = Base.color("go"),
			stroke = 4,
			drop = 2,
			align = "l",
			z = 5,
		})
		popLater(paid, 0.5)
		if view.xp > 0 then
			local xp = Base.text(rew, "Xp", 170, 6, 214, 24, `+{view.xp} XP`, {
				color = Kit.hex("9fe0ff"),
				stroke = 3,
				align = "r",
				z = 5,
			})
			popLater(xp, 0.8)
		end
		-- the level bar filling from before the round to now; LEVEL UP! when it crosses (no popup)
		if bar then
			local row = Base.box(rew, "Level", 170, 36, 214, 24, 4)
			local lv = Base.text(row, "Lv", 0, 0, 52, 24, `LV {bar.fromLevel}`, {
				stroke = 3,
				align = "l",
				z = 5,
			})
			local bw = 214 - 56
			local track = Kit.bar(row, "Bar", 56, 3, bw, 18, "blue", { value = bar.fromF, z = 5 })
			local num = Base.text(row, "Num", 56, 3, bw, 18, `{bar.into} / {bar.need}`, {
				stroke = 3,
				z = 8,
			})
			num.Visible = false
			-- (over the bar, then the numbers take its place)
			local up = Base.text(row, "LevelUp", 56, -4, bw, 28, "LEVEL UP!", {
				color = Base.color("go"),
				stroke = 4,
				z = 9,
			})
			up.Visible = false
			popLater(row, 1.0, function()
				if bar.levelUp then
					Kit.setBar(track, 1)
					task.delay(0.5, function()
						if not row.Parent then
							return
						end
						Base.setText(lv, `LV {bar.toLevel}`)
						up.Visible = true
						Anim.pop(up, 0.38, 0.3)
						local fill = track:FindFirstChild("Fill") :: Frame?
						if fill then
							fill.Size = UDim2.fromScale(0, 1)
						end
						Kit.setBar(track, bar.toF)
						task.delay(1.4, function()
							if row.Parent then
								up.Visible = false
								num.Visible = true
							end
						end)
					end)
				else
					Kit.setBar(track, bar.toF)
					num.Visible = true
				end
			end)
		end
		local you = MatchEnd.placeWords(view.place, view.total)
		if you ~= "" then
			local pl = Base.text(rew, "Place", 10, 44, 150, 20, `YOU: {you}`, {
				color = if view.place == 1 then Base.color("go") else WHITE,
				stroke = 3,
				align = "l",
				z = 5,
			})
			popLater(pl, 1.2)
		end
		-- the count to the next round, on a lime plate (the round starts by itself: no tap)
		local kp = piece("matchEnd", "Count")
		local countSpot = spot(canvas, "matchEnd", "Count")
		local drop = Base.fill(countSpot, "Drop", 0, 4, kp.w, kp.h - 4, INK, 2)
		Base.corner(drop, 16)
		local plate = Base.fill(countSpot, "Plate", 0, 0, kp.w, kp.h - 4, WHITE, 3)
		Base.corner(plate, 16)
		local lime = UiTheme.FACE.lime
		Kit.face(plate, { lime.hi, lime.c, lime.c2 })
		Base.outline(plate, UiTheme.OUTLINE.normal)
		local count = Base.text(plate, "Words", 10, 10, kp.w - 20, kp.h - 24, "", {
			stroke = 4,
			drop = 2,
			z = 5,
		})
		Anim.pulse(countSpot, 1.04, 1)
		local function set(left: number)
			Base.setText(count, MatchEnd.countWords(left))
		end
		set(MatchEnd.AUTO)
		placedButton(canvas, "matchEnd", "Leave", Screen.act(actions, "leave"))
		return { set = set }
	end)
end

-- ===== Menu: a phone's lobby buttons in one window =====

local MENU_TILE = 62 * 1.6 -- a tile in the MENU (design px)

-- data: { items = { { id, word, icon, dot: number? } } } (up to 8, in order)
-- actions: [id]() for each item (the window closes first), close()
function Smash.menu(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("menu", "window", false, function(g)
		local o: { [string]: any } = { onClose = Screen.act(actions, "close") }
		local win = Kit.window(g.canvas, piece("menu", "Window"), o)
		win.open()
		local gp = piece("menu", "Window.Grid")
		local grid = Base.box(win.content, "Grid", gp.x, gp.y, gp.w, gp.h, 3)
		-- (each tile 1.6x the lobby's: its word and dot 14 px on a phone; the two rows spread
		-- over the grid with a gap, every word inside its own tile at one shared size: they
		-- spilled wider than the tiles and row 1 touched row 2, auditor 14:55)
		local items = data.items or {}
		local k = MENU_TILE / 62
		local size = 62 * k
		local cols = 4
		local step = (gp.w - size) / (cols - 1)
		local rowStep = gp.h - size
		local longest = 1
		for i, it in items do
			if i <= cols * 2 then
				longest = math.max(longest, #tostring(it.word or ""))
			end
		end
		local tiles: { GuiObject } = {}
		local words: { TextLabel } = {}
		for i, it in items do
			if i > cols * 2 then
				break
			end
			local col, r = (i - 1) % cols, (i - 1) // cols
			local cell = Base.box(grid, "Item" .. i, col * step, r * rowStep, 62, 62, 3)
			local grow = Instance.new("UIScale")
			grow.Scale = k
			grow.Parent = cell
			local side = Kit.side(cell, "Tile", 0, 0, it.word, it.icon, i)
			side.setDot(it.dot)
			side.button.Activated:Connect(function()
				Screen.closeOver() -- (the menu goes, then its window opens)
				Screen.act(actions, it.id)()
			end)
			local tile = side.button:FindFirstChild("Tile")
			local word = tile and tile:FindFirstChild("Word")
			if word and word:IsA("TextLabel") then
				Base.at(word, 1, 62 - 19, 60, 17)
				table.insert(words, word)
			end
			table.insert(tiles, side.button)
		end
		-- one text size for every word: what the longest one gets (about 0.62 of a letter's
		-- height across, FredokaOne capitals)
		if #words > 0 then
			local cap: { UITextSizeConstraint } = {}
			for _, w in words do
				local c = Instance.new("UITextSizeConstraint")
				c.Parent = w
				table.insert(cap, c)
			end
			local function fit()
				local w = words[1].AbsoluteSize
				local px = math.floor(math.min(w.Y, w.X / (longest * 0.62)))
				for _, c in cap do
					c.MaxTextSize = math.max(1, px)
				end
			end
			fit()
			words[1]:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		end
		Anim.cascade(tiles)
		return nil
	end)
end

-- ===== Customize: KARTS / HATS tabs, a grid, EQUIP, and the kart you drive (with its hat) on a
-- card =====

-- A simple hat drawing (brim + crown) in a colour: the hat pictures come later (REWARDS).
local function hat(parent: Instance, x: number, y: number, s: number, color: Color3): Frame
	local f = Base.box(parent, "Hat", x, y, s, s, 6)
	local crown = Base.fill(f, "Crown", s * 0.28, s * 0.18, s * 0.44, s * 0.5, color, 6)
	Base.corner(crown, 6)
	Base.outline(crown, UiTheme.OUTLINE.normal)
	Kit.gloss(crown, color, 0.35)
	local brim = Base.fill(f, "Brim", s * 0.1, s * 0.62, s * 0.8, s * 0.16, color, 7)
	Base.corner(brim)
	Base.outline(brim, UiTheme.OUTLINE.normal)
	return f
end

Smash.hat = hat
Smash.carColor = carColor

local function rarityColor(r: string?): Color3
	return Base.color(UiTheme.RARITY[UiTheme.rarityId(r or "common")].color)
end

-- data: { tab: 1 | 2, karts = { Item }, hats = { Item }?, hatsSoon: boolean?,
--   driving = { id, name, rarity }?, hatOn = { name, rarity }? }
--   Item = { name, rarity, id? (a kart's car id), own: boolean?, on: boolean? }
-- actions: tab(i), equip(tab, i), close()
function Smash.customize(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("customize", "window", false, function(g)
		local o: { [string]: any } = { onClose = Screen.act(actions, "close") }
		local win = Kit.window(g.canvas, piece("customize", "Window"), o)
		win.open()
		local c = win.content
		local tab = if data.tab == 2 then 2 else 1
		local picked = 1
		local gp = piece("customize", "Window.Grid")
		local np = piece("customize", "Window.Note")
		local grid: Frame? = nil
		local note: TextLabel? = nil
		local ep = piece("customize", "Window.Equip")
		local equip: TextButton
		local function list(): { any }
			return (if tab == 1 then data.karts else data.hats) or {}
		end
		local function refreshButton()
			local words, works = SmashScreens.equipButton(list()[picked], tab == 2)
			Kit.setWords(equip, words)
			Kit.enable(equip, works)
		end
		equip = Kit.button(c, "Equip", ep.x, ep.y, ep.w, ep.h, "lime", "EQUIP", {
			main = true,
			onClick = function()
				local _, works = SmashScreens.equipButton(list()[picked], tab == 2)
				if works then
					Screen.act(actions, "equip")(tab, picked)
				end
			end,
		})
		local function fill()
			if grid then
				grid:Destroy()
			end
			if note then
				note:Destroy()
				note = nil
			end
			local holder = Base.box(c, "Grid", gp.x, gp.y, gp.w, gp.h, 3)
			grid = holder
			local items = list()
			if tab == 2 and data.hatsSoon then
				Base.text(holder, "Soon", 0, gp.h / 2 - 24, gp.w, 48, "HATS COMING SOON!", {
					color = Base.color("blue"),
					stroke = 5,
					strokeColor = WHITE,
					z = 4,
				})
				refreshButton()
				Kit.enable(equip, false)
				return
			end
			-- (2 rows of 7 fit over EQUIP; a third row sat on it)
			local cols, rowsFit, size, gap = 7, 2, 60, 6
			local slots: { Kit.Slot } = {}
			local shown: { GuiObject } = {}
			-- the one on now is picked first
			picked = 1
			for i, it in items do
				if it.on then
					picked = i
				end
			end
			for i, it in items do
				if i > cols * rowsFit then
					break -- (a scroller can come with more karts)
				end
				local col, r = (i - 1) % cols, (i - 1) // cols
				local isKart = tab == 1
				local s = Kit.slot(
					holder,
					"Item" .. i,
					4 + col * (size + gap),
					4 + r * (size + gap),
					size,
					{
						tone = if it.own == false then "locked" elseif it.on then "lime" else "blue",
						badge = if it.on then "ON" else nil,
						selected = i == picked,
						car = if isKart then { id = it.id, color = carColor(it.id, 1) } else nil,
					}
				)
				if not isKart and it.own ~= false then
					hat(s.button, size * 0.15, size * 0.12, size * 0.7, rarityColor(it.rarity))
				end
				s.button.Activated:Connect(function()
					local was = slots[picked]
					if was then
						was.setSelected(false)
					end
					picked = i
					s.setSelected(true)
					refreshButton()
					if note then
						note.Text =
							`{string.upper(it.name or "")}, {UiTheme.RARITY[UiTheme.rarityId(
								it.rarity or "common"
							)].word}`
					end
				end)
				slots[i] = s
				table.insert(shown, s.button)
			end
			Anim.cascade(shown)
			local first = items[picked]
			note = Base.text(
				c,
				"Note",
				np.x,
				np.y,
				np.w,
				np.h,
				if first
					then `{string.upper(first.name or "")}, {UiTheme.RARITY[UiTheme.rarityId(
						first.rarity or "common"
					)].word}`
					else if tab == 1 then "Open a crate to get a kart!" else "No hats yet.",
				{ color = Base.color("inkMuted"), align = "l", z = 4 }
			)
			refreshButton()
		end
		local tp = piece("customize", "Window.Tabs")
		local tabs: Kit.Tabs
		tabs = Kit.tabs(c, tp.x, tp.y, tp.w, tp.h, { "KARTS", "HATS" }, tab, function(i: number)
			tabs.set(i) -- (Kit.tabs only tells us: the highlight moves here)
			tab = i
			Screen.act(actions, "tab")(i)
			fill()
		end)
		fill()
		-- the kart you drive, with its hat
		local d = data.driving
		if d then
			local cp = piece("customize", "Card")
			local spotF = spot(g.canvas, "customize", "Card")
			local card = Kit.card(spotF, "Card", 0, 0, cp.w, cp.h, {
				name = d.name,
				rarity = d.rarity,
				carId = d.id,
				color = carColor(d.id, 1),
				tilt = 2,
			})
			local h = data.hatOn
			if h then
				hat(card.card, cp.w / 2 - 22, card.contentY + 4, 44, rarityColor(h.rarity))
				Base.text(
					card.card,
					"HatName",
					8,
					card.contentY + 52,
					cp.w - 16,
					22,
					string.upper(h.name or ""),
					{
						stroke = 4,
						z = 6,
					}
				)
			else
				Base.text(card.card, "HatName", 8, card.contentY + 20, cp.w - 16, 22, "NO HAT", {
					stroke = 4,
					z = 6,
				})
			end
		elseif #(data.karts or {}) == 0 then
			-- (a new kid with no kart yet: say where karts come from, not an empty card)
			local cp = piece("customize", "Card")
			local spotF = spot(g.canvas, "customize", "Card")
			local box = Base.fill(spotF, "Empty", 0, 0, cp.w, cp.h, Base.color("blue"), 3)
			Base.corner(box, 14)
			Base.outline(box, UiTheme.OUTLINE.normal)
			Base.text(
				box,
				"Words",
				10,
				cp.h / 2 - 40,
				cp.w - 20,
				80,
				"OPEN A CRATE TO GET A KART!",
				{
					stroke = 4,
					z = 6,
				}
			)
		end
		return {}
	end)
end

-- ===== How-to: one tip card at a time =====

-- The red "?" box the arena has (drawn here, no picture needed).
local function questionBox(parent: Instance, x: number, y: number, s: number): Frame
	local b = Base.fill(parent, "QBox", x, y, s, s, Base.color("danger"), 4)
	Base.corner(b, 10)
	Base.outline(b, UiTheme.OUTLINE.normal)
	Kit.gloss(b, Base.color("danger"), 0.35)
	Base.text(b, "Mark", 0, 2, s, s - 4, "?", { stroke = 5, z = 5 })
	return b
end

-- step: 1..3 (SmashScreens.STEPS); actions: skip() (tapping the card)
-- The handle's set(step) moves to another step.
function Smash.howTo(step: number, actions: Screen.Actions?): Screen.Handle
	return Screen.open("howTo", "hud", false, function(g)
		-- (each step's card in its own spot: DRIVE! by the stick, the rest on the right)
		local holders: { [string]: Frame } = {}
		local function holderFor(name: string): Frame
			local h = holders[name]
			if not h then
				h = spot(g.canvas, "howTo", name)
				holders[name] = h
			end
			return h
		end
		local built: { Instance } = {}
		local function set(n: number)
			for _, x in built do
				x:Destroy()
			end
			table.clear(built)
			local st = SmashScreens.STEPS[n]
			if not st then
				return
			end
			local tipName = st.tip or "Tip"
			local tp = piece("howTo", tipName)
			local card = Base.fill(holderFor(tipName), "Card", 0, 0, tp.w, tp.h, WHITE, 3)
			Base.corner(card, 22)
			Base.outline(card, UiTheme.OUTLINE.thick)
			table.insert(built, card)
			local tx = 14
			if st.id == "grab" then
				questionBox(card, 12, (tp.h - 52) / 2, 52)
				tx = 74
			end
			Base.text(card, "Words", tx, 4, tp.w - tx - 14, tp.h * 0.55, st.words, {
				color = Base.color("blue"),
				stroke = 6,
				strokeColor = WHITE,
				drop = 3,
				dropColor = Base.color("blueDeep"),
				z = 5,
			})
			Base.text(card, "Help", tx, tp.h * 0.6, tp.w - tx - 14, tp.h * 0.3, st.help, {
				color = Base.color("inkMuted"),
				z = 5,
			})
			-- a tap on the card skips this step
			local tap = Instance.new("TextButton")
			tap.Name = "Tap"
			tap.BackgroundTransparency = 1
			tap.Text = ""
			tap.Size = UDim2.fromScale(1, 1)
			tap.ZIndex = 9
			tap.Parent = card
			tap.Activated:Connect(Screen.act(actions, "skip"))
			Anim.pop(card, 0.38, 0.8)
			-- (the DRIVE arrow points at the phone's stick; with no stick on screen it meant
			-- nothing, audit R3-1)
			if st.arrow and (st.id ~= "drive" or UserInputService.TouchEnabled) then
				local ap = piece("howTo", st.arrow)
				local a =
					Icons.make(spot(g.canvas, "howTo", st.arrow), "arrow", 0, 0, ap.w, { z = 6 })
				a.Rotation = st.rot
				Anim.bob(a.Parent :: GuiObject, 0.9, 8)
				table.insert(built, a.Parent :: Instance)
			end
		end
		set(step)
		return { set = set, noBlur = true }
	end)
end

return Smash
