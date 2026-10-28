--!strict
-- Smash game screens (WINDOWS): the match end (YOU WON! / TOP 3! / NICE TRY!, steps 2-1-3 with
-- names and smashes, Rewards with coins and your place, PLAY AGAIN that presses itself) and the
-- 3-step how-to over a match (DRIVE!, GRAB A ?, TAP FIRE!). Places come from shared/SmashScreens,
-- words and numbers from shared/MatchEnd.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
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

local function piece(id: string, path: string): UiScreens.Piece
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

local function placedButton(canvas: Instance, id: string, name: string, onClick: () -> ()): TextButton
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

-- gold, silver, bronze (top, middle, bottom of the step)
local METAL = {
	[1] = { Color3.fromRGB(255, 243, 166), Color3.fromRGB(255, 194, 46), Color3.fromRGB(217, 138, 0) },
	[2] = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(195, 205, 220), Color3.fromRGB(127, 142, 166) },
	[3] = { Color3.fromRGB(255, 209, 166), Color3.fromRGB(214, 138, 76), Color3.fromRGB(154, 83, 32) },
}

-- ===== Match end =====

-- a car's own colour, or one per step for a bot with no car of ours (three different colours)
local STEP_COLORS = { "danger", "blue", "pink" }
local function carColor(carId: string?, pl: number): Color3
	local c = if carId then CarCatalog.get(carId) else nil
	if c and c.color and #c.color >= 3 then
		return Color3.fromRGB(c.color[1], c.color[2], c.color[3])
	end
	return Base.color(STEP_COLORS[pl] or "blue")
end

-- view: MatchEnd.read(...); actions: again()
-- The handle's set(secondsLeft) updates "NEXT MATCH IN n".
function Smash.matchEnd(view: MatchEnd.View, actions: Screen.Actions?): Screen.Handle
	return Screen.open("matchEnd", "full", true, function(g)
		local back = g.back :: ScreenGui
		Kit.backdrop(back, "showroom")
		local place = view.place
		if place >= 1 and place <= 3 then
			Kit.confetti(back:FindFirstChild("Backdrop") :: Frame, 30)
		end
		local sp = piece("matchEnd", "Shout")
		Kit.shout(spot(g.canvas, "matchEnd", "Shout"), 0, 0, sp.w, sp.h, MatchEnd.shout(place), "go", "l")
		-- the steps, left to right: 2nd, 1st, 3rd; each with the car, the name and its smashes
		local area = spot(g.canvas, "matchEnd", "Steps")
		local ap = piece("matchEnd", "Steps")
		local heights = { [1] = 132, [2] = 92, [3] = 62 }
		local steps: { GuiObject } = {}
		for col, pl in { 2, 1, 3 } do
			local row = view.top[pl]
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
			Pattern.attach(Base.box(stepF, "Clip", 4, 4, 144, h, 1))
			Base.text(stepF, "Number", 40, 6, 72, 44, tostring(pl), { stroke = 7, drop = 5, z = 4 })
			if row then
				-- smashes on the step under the number (the 3rd step is short: smaller words)
				Base.text(stepF, "Smashes", 8, math.min(54, h - 26), 136, 20, MatchEnd.smashWords(row.smashes), {
					stroke = 4,
					z = 4,
				})
				local cw = if pl == 1 then 150 else 122
				local ch = cw * 0.64
				local car = Icons.car(area, x + (152 - cw) / 2, top - ch + 10, cw, ch, { id = row.carId, color = carColor(row.carId, pl), z = 4 })
				if row.me then
					Anim.bob(car, UiTheme.MOTION.carBob, 5)
				end
				Base.text(area, "Name" .. pl, x, top - ch - 16, 152, 22, if row.me then "YOU" else row.name, {
					color = if row.me then Base.color("lime") else WHITE,
					stroke = 5,
					z = 5,
				})
				if row.me and pl == 1 then
					local tro = Icons.make(area, "trophy", x + 56, top - ch - 58, 40, { z = 5 })
					Anim.bob(tro, UiTheme.MOTION.carBob, 5)
				end
			end
			table.insert(steps, stepF)
		end
		Anim.cascade(steps)
		-- the Rewards window (no X): coins, then your place and smashes
		local rp = piece("matchEnd", "Rewards")
		local win = Kit.window(g.canvas, rp, { title = "Rewards", noClose = true })
		win.open()
		local cp = piece("matchEnd", "Rewards.Coins")
		local coins = Kit.currency(win.content, "Coins", cp.x, cp.y, cp.w, cp.h, { value = 0 })
		coins.set(view.coins)
		local pp = piece("matchEnd", "Rewards.Place")
		local placeWords = MatchEnd.placeWords(place, view.total)
		Base.text(
			win.content,
			"Place",
			pp.x,
			pp.y + 2,
			pp.w,
			pp.h - 4,
			if placeWords == "" then MatchEnd.smashWords(view.smashes)
				else `{placeWords}, {MatchEnd.smashWords(view.smashes)}`,
			{ color = INK, align = "l", z = 4 }
		)
		-- the count to the next match, over PLAY AGAIN
		local kp = piece("matchEnd", "Count")
		local count = Base.text(spot(g.canvas, "matchEnd", "Count"), "Words", 0, 0, kp.w, kp.h, "", {
			color = Base.color("go"),
			stroke = 5,
			z = 5,
		})
		local function set(left: number)
			count.Text = if left > 0 then `NEXT MATCH IN {left}` else "GO!"
		end
		set(MatchEnd.AUTO)
		placedButton(g.canvas, "matchEnd", "Again", Screen.act(actions, "again"))
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
				local a = Icons.make(spot(g.canvas, "howTo", st.arrow), "arrow", 0, 0, ap.w, { z = 6 })
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
