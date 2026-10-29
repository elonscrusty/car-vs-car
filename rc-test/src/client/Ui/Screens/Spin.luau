--!strict
-- The Lucky Spin window (Smash plan, REWARDS row), in the Windows look: the wheel on the left with
-- its pointer on top, every prize and its chance on the right (shown BEFORE you spin), your hats
-- to wear, and SPIN! (or when the next free spin comes). Looks only: the server rolls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Screen = require(Ui:WaitForChild("Screen"))

local Spin = {}

local INK, WHITE = Base.color("ink"), Base.WHITE

Spin.SPIN_SECS = 3.6 -- how long the wheel turns
Spin.TURNS = 5 -- whole turns before it stops

-- the window and its pieces, in design px (the daily window's size and place)
local WINDOW: UiScreens.Piece = {
	name = "Window",
	x = 18,
	y = 44,
	w = 716,
	h = 300,
	anchor = "c",
	text = "Lucky Spin",
}
local WHEEL = { x = 26, y = 22, s = 244 }
local ODDS = { x = 300, y = 16, w = 400, row = 16, gap = 2 }
local HATS = { x = 300, y = 200, w = 400, h = 32 }
local GO = { x = 430, y = 240, w = 270, h = 52 }

-- "5:02:09" for the next free spin
function Spin.clock(secs: number): string
	local s = math.max(math.floor(secs), 0)
	return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end

-- The wheel's turn (degrees) that puts prize `i` of `n` under the top pointer, at least
-- `from` + TURNS whole turns on.
function Spin.stopAt(i: number, n: number, from: number): number
	local want = -90 - (i - 1) * 360 / n -- spoke i points right (0) before the wheel turns
	local base = from + Spin.TURNS * 360
	return base + ((want - base) % 360)
end

local function rarityColor(rarity: string): Color3
	return Base.color(UiTheme.RARITY[UiTheme.rarityId(rarity)].color)
end

-- data: { prizes = { { label, chance, rarity, kind } }, wait (s, 0 = ready),
--   hats = { { id, name, rarity, on } } (owned) }
-- actions: spin(), equip(id or ""), close()
-- api: spinTo(i, done), setWait(secs), setHats(hats)
function Spin.window(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("spin", "window", false, function(g)
		local win = Kit.window(g.canvas, WINDOW, { onClose = Screen.act(actions, "close") })
		win.open()
		local c = win.content
		local prizes: { { [string]: any } } = data.prizes or {}
		local n = math.max(#prizes, 1)

		-- the wheel: a round face, one spoke per prize (its word at the outer end)
		local s = WHEEL.s
		local holder = Base.box(c, "Wheel", WHEEL.x, WHEEL.y, s, s, 3)
		local drop = Base.fill(holder, "Drop", 0, 6, s, s, INK, 1)
		Base.corner(drop, s)
		local face = Base.fill(holder, "Face", 0, 0, s, s, WHITE, 2)
		Base.corner(face, s)
		Base.outline(face, UiTheme.OUTLINE.thick, Base.color("blueDeep"))
		Kit.gloss(face, Base.color("lilac"), 0.25)
		local turn = Base.box(face, "Turn", 0, 0, s, s, 3)
		for i, p in prizes do
			local spoke = Base.box(turn, "Spoke" .. i, 0, s / 2 - 13, s, 26, 3)
			spoke.Rotation = (i - 1) * 360 / n
			local pill =
				Base.fill(spoke, "Pill", s / 2 + 18, 1, s / 2 - 26, 24, rarityColor(p.rarity), 3)
			Base.corner(pill, 12)
			Base.outline(pill, UiTheme.OUTLINE.small)
			Base.text(pill, "Word", 4, 3, s / 2 - 34, 18, p.label or "", { stroke = 2.5, z = 4 })
		end
		local hub = Base.fill(face, "Hub", s / 2 - 22, s / 2 - 22, 44, 44, Base.color("blue"), 6)
		Base.corner(hub, 44)
		Base.outline(hub, UiTheme.OUTLINE.normal)
		-- the pointer on top: a turned square, half of it showing
		local pin = Base.fill(holder, "Pointer", s / 2 - 13, -16, 26, 26, Base.color("danger"), 8)
		pin.Rotation = 45
		Base.outline(pin, UiTheme.OUTLINE.normal)

		-- the odds, before any spin: every prize and its chance
		Base.text(c, "OddsTitle", ODDS.x, ODDS.y - 14, 200, 14, "PRIZES AND ODDS", {
			color = Base.color("blue"),
			stroke = 2,
			strokeColor = WHITE,
			align = "l",
			z = 4,
		})
		local rows: { GuiObject } = {}
		for i, p in prizes do
			local y = ODDS.y + 4 + (i - 1) * (ODDS.row + ODDS.gap)
			local r =
				Base.fill(c, "Odds" .. i, ODDS.x, y, ODDS.w, ODDS.row, Base.color("rowFill"), 3)
			Base.corner(r, 8)
			Base.outline(r, UiTheme.OUTLINE.small, Base.color("rowEdge"))
			local dot = Base.fill(r, "Dot", 6, 3, 10, 10, rarityColor(p.rarity), 4)
			Base.corner(dot, 10)
			Base.text(r, "Word", 22, 1, 260, ODDS.row - 2, p.label or "", {
				color = INK,
				align = "l",
				z = 4,
			})
			Base.text(
				r,
				"Chance",
				ODDS.w - 90,
				1,
				82,
				ODDS.row - 2,
				UiMotion.percent(p.chance or 0),
				{
					color = INK,
					align = "r",
					z = 4,
				}
			)
			table.insert(rows, r)
		end
		Anim.cascade(rows)

		-- your hats: tap one to wear it (NONE takes it off)
		local hatBox = Base.box(c, "Hats", HATS.x, HATS.y, HATS.w, HATS.h, 3)
		local function setHats(hats: { { [string]: any } })
			for _, k in hatBox:GetChildren() do
				k:Destroy()
			end
			if #hats == 0 then
				Base.text(hatBox, "None", 0, 6, HATS.w, 20, "Win a hat for your kart!", {
					color = Base.color("inkMuted"),
					align = "l",
					z = 4,
				})
				return
			end
			local list: { { [string]: any } } = { { id = "", name = "NONE", on = true } }
			for _, h in hats do
				if h.on then
					list[1].on = false
				end
				table.insert(list, h)
			end
			local w = math.min(80, (HATS.w - 4 * (#list - 1)) / #list)
			for i, h in list do
				local id = h.id
				Kit.button(
					hatBox,
					"Hat" .. i,
					(i - 1) * (w + 4),
					0,
					w,
					HATS.h,
					if h.on then "lime" else "white",
					string.upper(h.name or ""),
					{
						size = 11,
						onClick = function()
							Screen.act(actions, "equip")(id)
						end,
					}
				)
			end
		end
		setHats(data.hats or {})

		-- SPIN! or the clock to the next free one
		local busy = false
		local go = Kit.button(c, "Spin", GO.x, GO.y, GO.w, GO.h, "lime", "SPIN!", {
			main = true,
			onClick = function()
				if not busy then
					Screen.act(actions, "spin")()
				end
			end,
		})
		local function setWait(secs: number)
			local ready = secs <= 0
			Kit.setTone(go, if ready then "lime" else "white")
			Kit.setWords(go, if ready then "SPIN!" else "NEXT FREE SPIN " .. Spin.clock(secs))
			Kit.enable(go, ready and not busy)
		end
		setWait(data.wait or 0)

		local function spinTo(i: number, done: (() -> ())?)
			busy = true
			Kit.enable(go, false)
			local stop = Spin.stopAt(i, n, turn.Rotation)
			local function finish()
				turn.Rotation = stop % 360
				busy = false
				if done then
					done()
				end
			end
			local tw = Anim.to(
				turn,
				Spin.SPIN_SECS,
				{ Rotation = stop },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)
			if tw then
				tw.Completed:Once(finish)
			else
				finish()
			end
		end

		return { spinTo = spinTo, setWait = setWait, setHats = setHats }
	end)
end

return Spin
