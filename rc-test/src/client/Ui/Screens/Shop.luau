--!strict
-- Car VS Car screen 7 Shop (spec section 6): looks only. A big BEST DEAL card, a SALE card and
-- 4 small skin cards, all over the blurred world. The footer says it plainly: nothing here makes
-- a car faster. Every price is a placeholder until carter sets the real ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Pattern = require(Ui:WaitForChild("Pattern"))
local Screen = require(Ui:WaitForChild("Screen"))

local Shop = {}

local INK, WHITE = Base.color("ink"), Base.WHITE
local STRUCK = Color3.fromRGB(255, 179, 179)
local ICE = Color3.fromRGB(127, 227, 255)

local TABS = { "FEATURED", "SKINS", "TRAILS", "COINS" }
local TAB_ICONS: { string? } = { "gift", "bag", "gem", "coin" }

local function piece(id: string, name: string): UiScreens.Piece
	return UiScreens.piece(id, name)
end

local function spot(canvas: Instance, name: string): (Frame, UiScreens.Piece)
	local pc = piece("shop", name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Parent = canvas
	Base.place(f, pc)
	return f, pc
end

-- A shop card: ink drop, ink outline, a color run (from -> to) with a top shine, and the sliding
-- pattern inside. Returns the face to put things on.
local function card(
	parent: Instance,
	w: number,
	h: number,
	from: Color3,
	to: Color3,
	angle: number,
	radius: number
): Frame
	local drop = Base.fill(parent, "Drop", 0, 6, w, h, INK, 1)
	Base.corner(drop, radius)
	local face = Base.fill(parent, "Face", 0, 0, w, h, WHITE, 2)
	face.ClipsDescendants = true
	Base.corner(face, radius)
	Base.outline(face, UiTheme.OUTLINE.thick)
	local g = Instance.new("UIGradient")
	g.Rotation = angle
	g.Color = ColorSequence.new(from, to)
	g.Parent = face
	local clip = Base.box(face, "Clip", 0, 0, w, h, 1)
	Pattern.attach(clip)
	return face
end

-- Old price words with a line through them.
local function struck(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string
): TextLabel
	local l = Base.text(
		parent,
		"Old",
		x,
		y,
		w,
		h,
		words,
		{ color = STRUCK, stroke = 5, align = "l", z = 4 }
	)
	local tw = math.min(w, #words * h * 0.58)
	local line = Base.fill(parent, "Strike", x - 2, y + h * 0.45, tw + 4, 3, INK, 5)
	line.BackgroundColor3 = STRUCK
	Base.outline(line, 1)
	return l
end

-- data: { tab: n, offer = { title, sub, old, price }, sale = { title, sub, old, price },
--   minis = { { name, kind, colorName, bg (rgb {r,g,b}), price, tag } } (4) }
-- actions: tab(i), buyOffer(), buySale(), buyMini(i), close()
function Shop.open(data: { [string]: any }, actions: Screen.Actions?): Screen.Handle
	return Screen.open("shop", "window", true, function(g)
		-- one picture kept to the phone shape, so nothing stretches on a wide screen
		local c = Base.stage(g.canvas)
		if g.back then
			Kit.scrim(g.back)
		end
		-- the top row: title, tabs, X
		local tp = piece("shop", "Title")
		local title = Base.text(c, "Title", tp.x, tp.y + 4, tp.w, tp.h - 8, "Shop", {
			stroke = UiTheme.TYPE.title.stroke,
			strokeColor = Base.color("blueDeep"),
			drop = 3,
			dropColor = Base.color("blueDeep"),
			z = 6,
		})
		local bp = piece("shop", "Tabs")
		local onTab = Screen.act(actions, "tab")
		local tabs: Kit.Tabs
		tabs = Kit.tabs(c, bp.x, bp.y, bp.w, bp.h, TABS, data.tab or 1, function(i: number)
			tabs.set(i)
			onTab(i)
		end, TAB_ICONS)
		local cp = piece("shop", "Close")
		local close = Kit.close(c, cp.x, cp.y, Screen.act(actions, "close"), cp.w)

		-- BEST DEAL: a sunset card, the pack name, the struck old price, the lime buy, a bobbing car
		local offerSpot, op = spot(c, "Offer")
		local offer = data.offer or {}
		local of =
			card(offerSpot, op.w, op.h, Color3.fromRGB(255, 194, 26), Base.color("pink"), 20, 22)
		local run = of:FindFirstChildOfClass("UIGradient")
		if run then
			run.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 26)),
				ColorSequenceKeypoint.new(0.45, Base.color("boost")),
				ColorSequenceKeypoint.new(1, Base.color("pink")),
			})
		end
		Kit.tag(of, 16, 8, "BEST DEAL", "danger", 24, 8)
		Base.text(
			of,
			"Name",
			16,
			36,
			300,
			36,
			offer.title or "Rainbow Pack!",
			{ stroke = 7, drop = 4, align = "l", z = 4 }
		)
		Base.text(
			of,
			"Sub",
			16,
			76,
			300,
			17,
			offer.sub or "3 rainbow skins + a sparkle trail",
			{ stroke = 4, align = "l", z = 4 }
		)
		-- Robux prices are carter's to set: none is made up here (the old price shows only if given)
		if offer.old then
			struck(of, 16, 114, 90, 22, offer.old)
		end
		local ob = piece("shop", "Offer.Buy")
		Kit.button(of, "Buy", ob.x, ob.y - 6, ob.w, ob.h, "lime", offer.price or ob.text or "", {
			main = true,
			z = 4,
			onClick = Screen.act(actions, "buyOffer"),
		})
		local car = Icons.car(
			of,
			op.w - 196,
			20,
			190,
			120,
			{ kind = "racer", color = Base.color("epic"), z = 3 }
		)
		Anim.bob(car, UiTheme.MOTION.iconBob, 5, 0)

		-- SALE: purple card, light-blue name, a bobbing coin, struck price over the coin buy
		local saleSpot, sp = spot(c, "Sale")
		local sale = data.sale or {}
		local sf =
			card(saleSpot, sp.w, sp.h, Base.color("purple"), Base.color("purpleDark"), 70, 22)
		Kit.tag(sf, 14, 8, "SALE!", "pink", 24, 8)
		Base.text(
			sf,
			"Name",
			14,
			28,
			sp.w - 28,
			28,
			sale.title or "Gold Wheels",
			{ color = ICE, stroke = 6, drop = 3, align = "l", z = 4 }
		)
		Base.text(
			sf,
			"Sub",
			14,
			58,
			sp.w - 28,
			15,
			sale.sub or "Shiny rims for every car",
			{ stroke = 3.5, align = "l", z = 4 }
		)
		local coin = Icons.make(sf, "coin", 12, 86, 62, { z = 4 })
		Anim.bob(coin, UiTheme.MOTION.iconBob, 4, 0.5)
		struck(sf, 84, 84, 80, 18, sale.old or "5,000")
		local sb = piece("shop", "Sale.Buy")
		Kit.button(sf, "Buy", sb.x, sb.y, sb.w, sb.h, "lime", sale.price or sb.text or "", {
			icon = "coin",
			z = 4,
			onClick = Screen.act(actions, "buySale"),
		})

		-- 4 small skin cards
		local minis: { { [string]: any } } = data.minis
			or {
				{
					name = "FLAME",
					kind = "racer",
					colorName = "boost",
					bg = { 255, 177, 92 },
					price = "1,200",
					tag = "NEW!",
				},
				{
					name = "MINT",
					kind = "buggy",
					colorName = "lime",
					bg = { 168, 240, 122 },
					price = "900",
				},
				{
					name = "NIGHT",
					kind = "truck",
					colorName = "navy",
					bg = { 127, 196, 255 },
					price = "1,500",
				},
				{
					name = "BUBBLE",
					kind = "buggy",
					colorName = "pink",
					bg = { 255, 166, 204 },
					price = "900",
				},
			}
		local cards: { GuiObject } = {}
		for i = 1, 4 do
			local m = minis[i]
			if not m then
				continue
			end
			local holder, mp = spot(c, "Mini" .. i)
			local bg = if m.bg
				then Color3.fromRGB(m.bg[1], m.bg[2], m.bg[3])
				else Base.color("sky300")
			local mf = card(holder, mp.w, mp.h, bg:Lerp(WHITE, 0.35), bg, 90, 16)
			Icons.car(
				mf,
				(mp.w - 100) / 2,
				2,
				100,
				64,
				{ kind = m.kind or "racer", color = Base.color(m.colorName or "blue"), z = 3 }
			)
			Base.text(mf, "Name", 6, 68, mp.w - 12, 17, m.name or "", { stroke = 4, z = 4 })
			Kit.button(mf, "Buy", 14, 90, mp.w - 28, 40, "lime", m.price or "", {
				icon = "coin",
				size = 17,
				z = 4,
				onClick = function()
					Screen.act(actions, "buyMini")(i)
				end,
			})
			if m.tag then
				-- the tag sits over the card's corner, outside its clip
				Kit.tag(holder, -4, -6, m.tag, "pink", 22, 9)
			end
			table.insert(cards, holder)
		end
		Anim.cascade(cards)

		local fp = piece("shop", "Footer")
		Base.text(
			c,
			"Footer",
			fp.x,
			fp.y,
			fp.w,
			fp.h - 2,
			data.footer or "Skins and trails only. Nothing in the shop makes a car faster.",
			{ stroke = 3.5, z = 4 }
		)

		Anim.windowIn(offerSpot, title, close)
		Anim.pop(saleSpot, nil, nil, 0.08)
		return { setTab = tabs.set }
	end)
end

return Shop
