--!strict
-- Smash game screens (WINDOWS): the match end (YOU WON! / TOP 3! / NICE TRY!, steps 2-1-3 with
-- names and smashes, Rewards with coins and your place, PLAY AGAIN that presses itself) and the
-- 3-step how-to over a match (DRIVE!, GRAB A ?, TAP FIRE!). Places come from shared/SmashScreens,
-- words and numbers from shared/MatchEnd.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local MatchEnd = require(Shared:WaitForChild("MatchEnd"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Pattern = require(Ui:WaitForChild("Pattern"))
local Screen = require(Ui:WaitForChild("Screen"))

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

-- gold, silver, bronze place discs
local METAL = {
	[1] = Color3.fromRGB(255, 194, 46),
	[2] = Color3.fromRGB(195, 205, 220),
	[3] = Color3.fromRGB(214, 138, 76),
}

-- a car's own colour, or one per place for a bot with no car of ours (three different colours)
local PLACE_COLORS = { "danger", "blue", "pink" }
local function carColor(carId: string?, pl: number): Color3
	local c = if carId then CarCatalog.get(carId) else nil
	if c and c.color and #c.color >= 3 then
		return Color3.fromRGB(c.color[1], c.color[2], c.color[3])
	end
	return Base.color(PLACE_COLORS[pl] or "blue")
end

-- a white panel at a screen piece
local function panel(canvas: Instance, id: string, name: string): (Frame, SmashScreens.Piece)
	local pc = piece(id, name)
	local holder = spot(canvas, id, name)
	local f = Base.fill(holder, "Panel", 0, 0, pc.w, pc.h, WHITE, 2)
	Base.corner(f, 22)
	Base.outline(f, UiTheme.OUTLINE.thick)
	Pattern.dots(Base.box(f, "Back", 6, 6, pc.w - 12, pc.h - 12, 1))
	return f, pc
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

-- ===== Between rounds (12 s): ROUND OVER, "<name> WINS" + the winner's kart, the top 3 with
-- smashes, your coins and XP popping in, NEW ROUND STARTING IN n, a small LEAVE =====

-- view: MatchEnd.read(...); actions: leave()
-- The handle's set(secondsLeft) updates the count.
function Smash.matchEnd(view: MatchEnd.View, actions: Screen.Actions?): Screen.Handle
	return Screen.open("matchEnd", "full", true, function(g)
		local back = g.back :: ScreenGui
		Kit.backdrop(back, "showroom")
		Kit.confetti(back:FindFirstChild("Backdrop") :: Frame, if view.place == 1 then 30 else 14)
		local sp = piece("matchEnd", "Shout")
		Kit.shout(spot(g.canvas, "matchEnd", "Shout"), 0, 0, sp.w, sp.h, "ROUND OVER!", "go")
		local wp = piece("matchEnd", "Wins")
		local wins = Base.text(
			spot(g.canvas, "matchEnd", "Wins"),
			"Words",
			0,
			0,
			wp.w,
			wp.h,
			MatchEnd.winWords(view),
			{
				color = if view.winner and view.winner.me then Base.color("lime") else WHITE,
				stroke = 5,
				drop = 3,
				z = 5,
			}
		)
		Anim.pop(wins, 0.5, 0.3, 0.3)
		-- the winner's kart on show, turning slowly in the rays
		local w = view.winner
		if w then
			local kp = piece("matchEnd", "Winner")
			local stage = spot(g.canvas, "matchEnd", "Winner")
			Kit.rays(stage, kp.w / 2, kp.h / 2, kp.h * 1.5, "go", 0.7)
			local cw = kp.w * 0.9
			local car = Icons.car(stage, (kp.w - cw) / 2, (kp.h - cw * 0.64) / 2, cw, cw * 0.64, {
				id = w.carId,
				color = carColor(w.carId, 1),
				z = 4,
			})
			Anim.pop(car, 0.6, 0.2, 0.4)
			Anim.bob(car, UiTheme.MOTION.carBob, 5)
			if w.me then
				local tro = Icons.make(stage, "trophy", kp.w / 2 - 22, 0, 44, { z = 5 })
				Anim.bob(tro, UiTheme.MOTION.carBob, 5)
			end
		end
		-- the top 3: a metal place disc, the name, the smashes
		local top, tp = panel(g.canvas, "matchEnd", "Top3")
		local rows: { GuiObject } = {}
		for i, row in view.top do
			local y = 10 + (i - 1) * 50
			local r = Base.box(top, "Row" .. i, 10, y, tp.w - 20, 46, 3)
			local disc = Base.fill(r, "Disc", 0, 4, 38, 38, METAL[i], 3)
			Base.corner(disc)
			Base.outline(disc, UiTheme.OUTLINE.normal)
			Base.text(disc, "N", 0, 2, 38, 34, tostring(i), { stroke = 4, z = 4 })
			Base.text(
				r,
				"Name",
				46,
				6,
				tp.w - 20 - 46 - 58,
				34,
				if row.me then "YOU" else row.name,
				{
					color = if row.me then Base.color("limeDeep") else INK,
					align = "l",
					z = 4,
				}
			)
			Base.text(r, "Smashes", tp.w - 20 - 56, 2, 56, 26, tostring(row.smashes), {
				color = Base.color("danger"),
				stroke = 4,
				align = "r",
				z = 4,
			})
			Base.text(
				r,
				"Word",
				tp.w - 20 - 76,
				28,
				76,
				14,
				if row.smashes == 1 then "SMASH" else "SMASHES",
				{
					color = Base.color("inkMuted"),
					align = "r",
					z = 4,
				}
			)
			table.insert(rows, r)
		end
		Anim.cascade(rows)
		-- what you got, popping in one after the other: coins, XP, then your place
		local rew, rp = panel(g.canvas, "matchEnd", "Rewards")
		local coins = Kit.currency(rew, "Coins", 12, 12, rp.w - 24, 46, { value = 0 })
		popLater(coins.button, 1.0, function()
			coins.set(view.coins)
		end)
		if view.xp > 0 then
			local xp = Base.text(rew, "Xp", 12, 66, rp.w - 24, 40, `+{view.xp} XP`, {
				color = Base.color("blue"),
				stroke = 5,
				strokeColor = WHITE,
				drop = 3,
				dropColor = Base.color("blueDeep"),
				align = "l",
				z = 4,
			})
			popLater(xp, 1.6)
		end
		local you = MatchEnd.placeWords(view.place, view.total)
		if you ~= "" then
			local pl = Base.text(rew, "Place", 12, 114, rp.w - 24, 40, `YOU: {you}`, {
				color = INK,
				align = "l",
				z = 4,
			})
			popLater(pl, 2.2)
		end
		-- the count to the next round
		local kp = piece("matchEnd", "Count")
		local count =
			Base.text(spot(g.canvas, "matchEnd", "Count"), "Words", 0, 0, kp.w, kp.h, "", {
				color = Base.color("go"),
				stroke = 5,
				drop = 3,
				z = 5,
			})
		local function set(left: number)
			count.Text = MatchEnd.countWords(left)
		end
		set(MatchEnd.AUTO)
		placedButton(g.canvas, "matchEnd", "Leave", Screen.act(actions, "leave"))
		return { set = set }
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
		local tp = piece("howTo", "Tip")
		local holder = spot(g.canvas, "howTo", "Tip")
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
			local card = Base.fill(holder, "Card", 0, 0, tp.w, tp.h, WHITE, 3)
			Base.corner(card, 22)
			Base.outline(card, UiTheme.OUTLINE.thick)
			table.insert(built, card)
			local tx = 14
			if st.id == "grab" then
				questionBox(card, 14, (tp.h - 56) / 2, 56)
				tx = 82
			end
			Base.text(card, "Words", tx, 8, tp.w - tx - 14, 46, st.words, {
				color = Base.color("blue"),
				stroke = 6,
				strokeColor = WHITE,
				drop = 3,
				dropColor = Base.color("blueDeep"),
				z = 5,
			})
			Base.text(card, "Help", tx, 58, tp.w - tx - 14, 24, st.help, {
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
			if st.arrow then
				local ap = piece("howTo", st.arrow)
				local a =
					Icons.make(spot(g.canvas, "howTo", st.arrow), "arrow", 0, 0, ap.w, { z = 6 })
				a.Rotation = 90 -- the arrow points right; down at the stick or FIRE
				Anim.bob(a.Parent :: GuiObject, 0.9, 8)
				table.insert(built, a.Parent :: Instance)
			end
		end
		set(step)
		return { set = set, noBlur = true }
	end)
end

return Smash
