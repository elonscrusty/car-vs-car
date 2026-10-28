--!strict
-- Car VS Car screens that cover the game (spec section 6): 0 Loading, 1 Pick your first car,
-- 5 Podium, 7 Crate reveal, 10 League up. Each opens from data and calls `actions` on taps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local Flow = {}

local INK, WHITE = Base.color("ink"), Base.WHITE

export type Car = { id: string?, name: string, color: Color3?, kind: string?, me: boolean? }

local function piece(id: string, name: string): UiScreens.Piece
	return UiScreens.piece(id, name)
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
	words: string?
): TextButton
	local pc = piece(id, name)
	local holder = spot(canvas, id, name)
	return Kit.button(
		holder,
		"Button",
		0,
		0,
		pc.w,
		pc.h,
		pc.tone or "lime",
		words or pc.text or "",
		{ main = pc.main, onClick = onClick }
	)
end

-- ===== 0 Loading: showroom, 3 bobbing cars, a wide bar filling lime to yellow, one tip =====

-- data: { progress: number? (0..1; nil = keeps filling), tip: string? }
function Flow.loading(data: { [string]: any }?): Screen.Handle
	local d: { [string]: any } = data or {}
	return Screen.open("loading", "loading", true, function(g)
		Kit.backdrop(g.back :: ScreenGui, "showroom")
		local cars: { { string } } = {
			{ "CarLeft", "racer", "danger" },
			{ "CarMid", "truck", "lime" },
			{ "CarRight", "buggy", "blue" },
		}
		for i, c in cars do
			local holder = spot(g.canvas, "loading", c[1])
			local pc = piece("loading", c[1])
			local car =
				Icons.car(holder, 0, 0, pc.w, pc.h, { kind = c[2], color = Base.color(c[3]) })
			Anim.bob(car, UiTheme.MOTION.carBob, 5, i * 0.3)
		end
		local barHolder = spot(g.canvas, "loading", "Bar")
		local bp = piece("loading", "Bar")
		local track = Kit.bar(barHolder, "Track", 0, 0, bp.w, bp.h, "lime")
		local fill = track:FindFirstChild("Fill") :: Frame
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Base.color("lime"), Base.color("go"))
		grad.Parent = fill
		fill.BackgroundColor3 = WHITE
		local wp = piece("loading", "Words")
		Base.text(
			spot(g.canvas, "loading", "Words"),
			"Words",
			0,
			0,
			wp.w,
			wp.h,
			"Getting your car ready...",
			{ stroke = 5 }
		)
		local _, panel = Kit.placedPanel(g.canvas, piece("loading", "Tip"))
		local tp = piece("loading", "Tip")
		Base.text(panel, "Tip", 14, 9, 46, 22, "TIP:", { color = Base.color("blue"), align = "l" })
		Base.text(
			panel,
			"Line",
			62,
			9,
			tp.w - 76,
			22,
			d.tip or "Tap COACH to train 2x faster for a bit!",
			{ color = INK, align = "l" }
		)
		local function set(p: number)
			fill.Size = UDim2.fromScale(math.clamp(p, 0.04, 1), 1)
		end
		if d.progress then
			set(d.progress)
		elseif not Base.reduced() then
			-- (the viewer: it keeps filling, 4 s a round)
			Anim.tick(fill, function(t)
				local f = (t % 4) / 4
				set(0.04 + 0.96 * math.min(1, f / 0.85))
			end)
		end
		return { set = set }
	end)
end

-- ===== 1 Pick your first car: 3 cards; the picked one lifts, glows lime and gets a check =====

-- data: { cars = { { id, name, word, color, kind, stats = { power, air, speed } (0..1) } } }
-- actions: go(i) when LET'S GO! is tapped with car i picked.
function Flow.pick(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("pick", "full", true, function(g)
		Kit.backdrop(g.back :: ScreenGui, "showroom")
		local sp = piece("pick", "Shout")
		Kit.shout(spot(g.canvas, "pick", "Shout"), 0, 0, sp.w, sp.h, "PICK YOUR FIRST CAR!", nil)
		local picked = 0
		local cards: {
			{
				root: TextButton,
				lift: Frame,
				edge: UIStroke,
				glow: Frame,
				check: Frame,
				name: TextLabel,
			}
		} =
			{}
		local go: TextButton
		local function choose(i: number)
			picked = i
			for j, c in cards do
				local on = j == i
				local s = Anim.scaler(c.lift)
				Anim.to(s, 0.22, { Scale = if on then 1.05 else 1 }, Anim.Back, Anim.Out)
				Anim.to(
					c.lift,
					0.22,
					{ Position = UDim2.fromScale(0, if on then -6 / 214 else 0) },
					Anim.Back,
					Anim.Out
				)
				c.edge.Color = if on then Base.color("limeDeep") else Base.color("blueDeep")
				c.glow.Visible = on
				c.check.Visible = on
				c.name.TextColor3 = if on then Base.color("lime") else Base.color("blue")
				c.root.ZIndex = if on then 3 else 2
				if on then
					Anim.pop(c.check, 0.3, 0.2)
				end
			end
			Kit.enable(go, true)
		end
		local list: { GuiObject } = {}
		for i, car in data.cars or {} do
			local name = "Card" .. i
			local pc = piece("pick", name)
			local w, h = pc.w, pc.h
			local b = Instance.new("TextButton")
			b.Name = name
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.ZIndex = 2
			b.Parent = g.canvas
			Base.place(b, pc)
			local lift = Base.box(b, "Lift", 0, 0, w, h, 1)
			local glow = Base.fill(lift, "Glow", -12, -12, w + 24, h + 24, Base.color("lime"), 1)
			glow.BackgroundTransparency = 0.6
			Base.corner(glow, 30)
			local ring = Base.fill(lift, "Ring", -5, -5, w + 10, h + 10, WHITE, 2)
			Base.corner(ring, 24)
			ring.Visible = false
			local panel = Kit.panel(lift, "Panel", 0, 0, w, h, 22)
			local edge = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
			Base.restroke(edge, 4)
			Kit.tag(lift, 10, -12, car.word or "", "blue", 24)
			local carSpot = Icons.car(
				panel,
				38,
				8,
				150,
				88,
				{ id = car.id, color = car.color, kind = car.kind }
			)
			Anim.bob(carSpot, UiTheme.MOTION.carBob, 5, i * 0.4)
			local nm = Base.text(
				panel,
				"Name",
				10,
				98,
				w - 20,
				30,
				car.name or "",
				{ color = Base.color("blue"), stroke = 5, z = 4 }
			)
			for j, stat in UiTheme.STATS do
				local y = 136 + (j - 1) * 24
				Base.text(
					panel,
					stat.word,
					12,
					y,
					50,
					16,
					stat.word,
					{ color = Base.color("inkMuted"), align = "l" }
				)
				local bar = Kit.bar(panel, "Bar" .. j, 66, y + 1, w - 80, 14, stat.tone)
				Kit.setBar(bar, (car.stats or {})[stat.key] or 0.3, true)
			end
			local check = Base.box(lift, "Check", w - 28, -14, 40, 40, 9)
			Icons.make(check, "check", 0, 0, 40, { z = 9 })
			glow.Visible, check.Visible = false, false
			table.insert(
				cards,
				{ root = b, lift = lift, edge = edge, glow = glow, check = check, name = nm }
			)
			table.insert(list, b)
			b.Activated:Connect(function()
				choose(i)
			end)
			Anim.press(b)
		end
		Anim.cascade(list)
		go = placedButton(g.canvas, "pick", "Go", function()
			if picked > 0 then
				Screen.act(actions, "go")(picked)
			end
		end)
		Kit.enable(go, false)
		if data.picked then
			choose(data.picked)
		end
		return { choose = choose }
	end)
end

-- ===== 5 Podium: YOU WON! / TOP 3! / NICE TRY!, steps 2-1-3, cars on top, confetti, rewards =====

local METAL = {
	[1] = {
		Color3.fromRGB(255, 243, 166),
		Color3.fromRGB(255, 194, 46),
		Color3.fromRGB(217, 138, 0),
	},
	[2] = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(195, 205, 220),
		Color3.fromRGB(127, 142, 166),
	},
	[3] = {
		Color3.fromRGB(255, 209, 166),
		Color3.fromRGB(214, 138, 76),
		Color3.fromRGB(154, 83, 32),
	},
}

-- data: { place: number, top: { Car } (1st, 2nd, 3rd), coins: number, trophies: number,
--   nextWords: string? (the main button's words; NEXT RACE) }
-- actions: next(), back()
function Flow.podium(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("podium", "full", true, function(g)
		local back = g.back :: ScreenGui
		Kit.backdrop(back, "showroom")
		local place = data.place or 1
		-- (confetti for a top 3 only: it fell on NICE TRY too, Studio after818 shot 13)
		if place <= 3 then
			Kit.confetti(back:FindFirstChild("Backdrop") :: Frame, 30)
		end
		local sp = piece("podium", "Shout")
		Kit.shout(
			spot(g.canvas, "podium", "Shout"),
			0,
			0,
			sp.w,
			sp.h,
			UiMotion.finishShout(place),
			"go",
			"l"
		)
		-- the steps, left to right: 2nd, 1st, 3rd
		local area = spot(g.canvas, "podium", "Steps")
		local ap = piece("podium", "Steps")
		local heights = { [1] = 132, [2] = 92, [3] = 62 }
		local order = { 2, 1, 3 }
		local steps: { GuiObject } = {}
		for col, pl in order do
			local car: Car? = (data.top or {})[pl]
			local x = (col - 1) * 156
			local h = heights[pl]
			local top = ap.h - h
			local stepF = Base.fill(area, "Step" .. pl, x, top, 152, h + 8, WHITE, 2)
			Base.corner(stepF, 18)
			Base.outline(stepF, UiTheme.OUTLINE.thick)
			local m = METAL[pl]
			local grad = Instance.new("UIGradient")
			grad.Rotation = 90
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, m[1]),
				ColorSequenceKeypoint.new(0.45, m[2]),
				ColorSequenceKeypoint.new(1, m[3]),
			})
			grad.Parent = stepF
			local clip = Base.box(stepF, "Clip", 4, 4, 144, h, 1)
			Pattern.attach(clip)
			Base.text(stepF, "Number", 40, 6, 72, 50, tostring(pl), { stroke = 7, drop = 5, z = 4 })
			if car then
				local cw = if pl == 1 then 150 else 122
				local ch = cw * 0.64
				local cs = Icons.car(
					area,
					x + (152 - cw) / 2,
					top - ch + 10,
					cw,
					ch,
					{ id = car.id, color = car.color, kind = car.kind, z = 4 }
				)
				if car.me then
					Anim.bob(cs, UiTheme.MOTION.carBob, 5)
				end
				Base.text(area, "Name" .. pl, x, top - ch - 16, 152, 22, car.name, {
					color = if car.me then Base.color("lime") else WHITE,
					stroke = 5,
					z = 5,
				})
				-- (the trophy is for a win: first on the steps after a time-out is NICE TRY!)
				if car.me and pl == 1 and place == 1 then
					local tro = Icons.make(area, "trophy", x + 56, top - ch - 58, 40, { z = 5 })
					Anim.bob(tro, UiTheme.MOTION.carBob, 5)
				end
			end
			table.insert(steps, stepF)
		end
		Anim.cascade(steps)
		-- the Rewards window (no X)
		local rp = piece("podium", "Rewards")
		local win = Kit.window(g.canvas, rp, { title = "Rewards", noClose = true })
		win.open()
		local cp = piece("podium", "Rewards.Coins")
		local coins = Kit.currency(win.content, "Coins", cp.x, cp.y, cp.w, cp.h, { value = 0 })
		coins.set(data.coins or 0)
		local tp = piece("podium", "Rewards.Trophies")
		Icons.make(win.content, "trophy", tp.x, tp.y + 2, tp.h - 4, { z = 4 })
		local tro = Base.text(
			win.content,
			"Trophies",
			tp.x + tp.h + 4,
			tp.y + 4,
			tp.w - tp.h - 4,
			tp.h - 8,
			"+0",
			{ stroke = 5, align = "l", z = 4 }
		)
		Anim.countUp(tro, 0, data.trophies or 0, function(n)
			return "+" .. UiMotion.commas(n)
		end)
		-- what training gave the car since the last race (review fix 4: training -> winning)
		if data.trained then
			Base.text(g.canvas, "Trained", 512, 202, 236, 34, data.trained, {
				color = Base.color("go"),
				stroke = 5,
				z = 5,
			})
		end
		placedButton(g.canvas, "podium", "Next", Screen.act(actions, "next"), data.nextWords)
		placedButton(g.canvas, "podium", "Back", Screen.act(actions, "back"))
		return {}
	end)
end

-- ===== 7 Crate reveal: rays in the rarity color, the shout, the card flips in, sparkles =====

-- data: { rarity, name, id?, color?, kind?, stars?, new: boolean?, note: string? }
-- actions: cool(), again()
function Flow.reveal(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("reveal", "full", true, function(g)
		local r = UiTheme.rarityId(data.rarity)
		local word = UiTheme.RARITY[r].word
		local colorName = UiTheme.RARITY[r].color
		Kit.backdrop(g.back :: ScreenGui, "reveal", colorName)
		local bd = (g.back :: ScreenGui):FindFirstChild("Backdrop") :: Frame
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.55)
		glow.Size = UDim2.fromScale(0.36, 0.77)
		glow.BackgroundColor3 = WHITE
		glow.BorderSizePixel = 0
		glow.ZIndex = 3
		glow.Parent = bd
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.Parent = glow
		Base.corner(glow)
		local gg = Instance.new("UIGradient")
		gg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(0.7, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		gg.Parent = glow
		local sp = piece("reveal", "Shout")
		Kit.shout(spot(g.canvas, "reveal", "Shout"), 0, 0, sp.w, sp.h, word .. "!", nil)
		local cp = piece("reveal", "Card")
		local holder = spot(g.canvas, "reveal", "Card")
		local card = Kit.card(holder, "Card", 0, 0, cp.w, cp.h, {
			name = data.name,
			rarity = r,
			stars = data.stars,
			ribbon = if data.new ~= false then "NEW!" else nil,
			carId = data.id,
			color = data.color,
			kind = data.kind,
			tilt = -3,
		})
		card.flip()
		for i, s in { { 106, 84 }, { 576, 64 }, { 516, 244 }, { 166, 254 } } do
			Kit.sparkle(g.canvas, s[1], s[2], 30, i * 0.3)
		end
		placedButton(g.canvas, "reveal", "Cool", Screen.act(actions, "cool"))
		-- (data.again = false: no OPEN ANOTHER, there's none left to open)
		if data.again ~= false then
			placedButton(g.canvas, "reveal", "Again", Screen.act(actions, "again"))
		end
		local np = piece("reveal", "Note")
		local _, panel = Kit.placedPanel(g.canvas, np)
		Base.text(
			panel,
			"Note",
			12,
			8,
			np.w - 24,
			np.h - 16,
			data.note or "New car! Saved in your GARAGE.",
			{ color = INK, align = "l" }
		).TextWrapped =
			true
		return {}
	end)
end

-- ===== 10 League up: rays, old badge, arrow, new badge (bobbing; wings for gold, diamond), reward =====

-- data: { from: number, to: number (1..4), coins: number? }; actions: ok()
function Flow.leagueUp(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("leagueUp", "full", true, function(g)
		local back = g.back :: ScreenGui
		Kit.backdrop(back, "showroom")
		Kit.confetti(back:FindFirstChild("Backdrop") :: Frame, 22)
		local sp = piece("leagueUp", "Shout")
		Kit.shout(spot(g.canvas, "leagueUp", "Shout"), 0, 0, sp.w, sp.h, "LEAGUE UP!", "go")
		local op = piece("leagueUp", "Old")
		-- the old badge faded as one picture (a CanvasGroup), so its overlapping parts don't show
		-- through each other
		local fade = Instance.new("CanvasGroup")
		fade.Name = "Fade"
		fade.BackgroundTransparency = 1
		fade.GroupTransparency = 0.25
		fade.Size = UDim2.fromScale(1, 1)
		fade:SetAttribute("DW", op.w)
		fade:SetAttribute("DH", op.h)
		fade.Parent = spot(g.canvas, "leagueUp", "Old")
		Icons.badge(fade, data.from or 1, 0, 0, op.w, true)
		local ap = piece("leagueUp", "Arrow")
		Icons.make(spot(g.canvas, "leagueUp", "Arrow"), "arrow", 0, 0, ap.w, { z = 3 })
		local np = piece("leagueUp", "New")
		local newSpot = spot(g.canvas, "leagueUp", "New")
		local badge = Icons.badge(newSpot, data.to or 2, 10, 0, np.w - 20, true)
		Anim.pop(badge, 0.6, 0.3, 0.3)
		Anim.bob(newSpot, UiTheme.MOTION.carBob, 6)
		for i, s in { { 516, 96 }, { 186, 120 }, { 596, 230 } } do
			Kit.sparkle(g.canvas, s[1], s[2], 28, i * 0.4)
		end
		-- (no coins given: no reward box)
		if data.coins then
			local rp = piece("leagueUp", "Reward")
			local _, panel = Kit.placedPanel(g.canvas, rp)
			local coins = Kit.currency(panel, "Coins", 12, 6, rp.w - 24, rp.h - 12, { value = 0 })
			coins.set(data.coins)
		end
		placedButton(g.canvas, "leagueUp", "Awesome", Screen.act(actions, "ok"))
		return {}
	end)
end

return Flow
