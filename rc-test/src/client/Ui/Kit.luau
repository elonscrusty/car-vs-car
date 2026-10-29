--!strict
-- Car VS Car screens: the shared pieces of the spec (section 5). Each takes its parent and a box
-- in the parent's design px, builds itself from Base (Scale sizes, outlines that follow the
-- screen), Pattern (the sliding tile) and Anim (motion), and hands back what a screen needs to
-- change later.
--   Button, RoundButton (+ arc), CloseButton, Window, SideButton, Currency, QuestBanner, HudPill,
--   StatBar, ItemSlot, CarCard, Tag, Tabs, Toggle, Milestones, OddsList, Panel, Section, Shout,
--   WorldSign, FloatNum, Confetti, Rays, Sparkle, Scrim, Backdrop, Spinner
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Base = require(script.Parent:WaitForChild("Base"))
local Anim = require(script.Parent:WaitForChild("Anim"))
local Pattern = require(script.Parent:WaitForChild("Pattern"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local Kit = {}

local INK = Base.color("ink")
local WHITE = Base.WHITE
local S, C, T, M = UiTheme.SIZE, UiTheme.CORNER, UiTheme.TYPE, UiTheme.MOTION

local function tone(name: string): UiTheme.Tone
	return UiTheme.TONES[name] or UiTheme.TONES.blue
end

-- The glossy fill: white 38% at the top fading by the middle, then the color.
function Kit.gloss(f: GuiObject, color: Color3, amount: number?, rotation: number?): UIGradient
	f.BackgroundColor3 = WHITE
	local g = f:FindFirstChild("Gloss") :: UIGradient?
	if not g then
		local made = Instance.new("UIGradient")
		made.Name = "Gloss"
		made.Parent = f
		g = made
	end
	local gg = g :: UIGradient
	gg.Rotation = rotation or 90
	gg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, amount or 0.38)),
		ColorSequenceKeypoint.new(0.52, color),
		ColorSequenceKeypoint.new(1, color),
	})
	return gg
end

-- carter's kit v41: a hex color, cached
local hexes: { [string]: Color3 } = {}
function Kit.hex(h: string): Color3
	local c = hexes[h]
	if not c then
		c = Color3.fromRGB(UiTheme.hex(h))
		hexes[h] = c
	end
	return c
end

-- A face run top to bottom through the kit's colors (2-4 hex stops, evenly spread; 3 stops put
-- the middle one at 0.5). Its BackgroundColor3 goes white so the gradient is the color.
function Kit.face(f: GuiObject, stops: { string }, rotation: number?): UIGradient
	f.BackgroundColor3 = WHITE
	local g = f:FindFirstChild("Gloss") :: UIGradient?
	if not g then
		local made = Instance.new("UIGradient")
		made.Name = "Gloss"
		made.Parent = f
		g = made
	end
	local gg = g :: UIGradient
	gg.Rotation = rotation or 90
	local keys = {}
	for i, h in stops do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #stops - 1), Kit.hex(h)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, Kit.hex(stops[1])))
	end
	gg.Color = ColorSequence.new(keys)
	return gg
end

-- The kit's inner white rim (2 px at 20% white) just inside a face, and the gloss band over its
-- top third (white 62% fading to 10%).
function Kit.rim(face: Frame, w: number, h: number, radius: number?)
	local r = radius or 12
	local rim = Base.box(face, "Rim", 2, 2, w - 4, h - 4, face.ZIndex)
	Base.corner(rim, math.max(2, r - 2))
	local st = Base.outline(rim, 2, WHITE)
	st.Transparency = UiTheme.CHROME.rim
	-- (a round face: the band inset to stay inside the circle)
	local round = r >= math.min(w, h) / 2 - 0.5
	local top = if round
		then Base.fill(face, "Top", w * 0.2, h * 0.06, w * 0.6, h * 0.22, WHITE, face.ZIndex)
		else Base.fill(
			face,
			"Top",
			7,
			4,
			math.max(1, w - 14),
			h * UiTheme.CHROME.gloss,
			WHITE,
			face.ZIndex
		)
	Base.corner(top, math.max(2, r - 4))
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Transparency = NumberSequence.new(0.38, 0.9)
	tg.Parent = top
end

-- ===== Button =====

export type Button = TextButton

local GREY, GREY_DEEP = Color3.fromRGB(184, 194, 204), Color3.fromRGB(141, 152, 163)

local function paintButton(b: TextButton, toneName: string)
	local t = tone(toneName)
	local body = b:FindFirstChild("Body") :: Frame
	local face = body:FindFirstChild("Face") :: Frame
	local label = body:FindFirstChild("Label") :: TextLabel?
	local off = b:GetAttribute("Off") == true
	-- the kit's 3D face: hi -> c -> c2 over its deep base (carter's kit v41)
	local f3 = UiTheme.FACE[if off then "off" else toneName]
	if f3 then
		body.BackgroundColor3 = Kit.hex(f3.deep)
		Kit.face(face, { f3.hi, f3.c, f3.c2 })
	else
		local fill = if off then GREY else Base.color(t.fill)
		body.BackgroundColor3 = if off then GREY_DEEP else Base.color(t.deep)
		Kit.gloss(face, fill)
	end
	local white = toneName == "white" and not off
	if label then
		label.TextColor3 = if white then INK else WHITE
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = not white
		end
		label.TextTransparency = if off then 0.25 else 0
	end
	local pat = face:FindFirstChild("Clip")
	local layer = pat and pat:FindFirstChild("Pattern")
	if layer then
		local dark = white
		local alpha = if dark then UiTheme.PATTERN.onWhite else UiTheme.PATTERN.onColor
		if layer:IsA("ImageLabel") then
			layer.ImageColor3 = if dark then INK else WHITE
			layer.ImageTransparency = 1 - alpha
		end
	end
	b:SetAttribute("Tone", toneName)
end

-- A glossy rounded-rectangle button (not a pill): darker ledge inside its bottom, ink outline and
-- drop, the sliding pattern behind its stroked white words. h 66 = large, 50 = medium.
-- opts: main (the light sweep), icon (drawn left of the words), chip (a navy price chip with a
-- coin), z, onClick, size (letter px; default by height).
function Kit.button(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	toneName: string,
	words: string,
	opts: { [string]: any }?
): TextButton
	local o: { [string]: any } = opts or {}
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = o.z or 2
	b.Parent = parent
	Base.at(b, x, y, w, h)
	local radius = o.radius or C.button
	local ledge = math.max(4, UiTheme.LEDGE * h / S.buttonL)
	local drop = Base.fill(b, "Drop", 0, UiTheme.DROP, w, h, INK, 1)
	Base.corner(drop, radius)
	local body = Base.fill(b, "Body", 0, 0, w, h, INK, 2)
	Base.corner(body, radius)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local face = Base.fill(body, "Face", 0, 0, w, h - ledge, WHITE, 1)
	Base.corner(face, radius)
	Kit.rim(face, w, h - ledge, radius)
	local inset = radius * 0.25
	local clip =
		Base.box(face, "Clip", inset, inset * 0.6, w - 2 * inset, h - ledge - inset * 1.2, 1)
	Pattern.attach(clip, toneName == "white")
	local big = h >= 60
	local size = o.size
		or (if big then T.buttonL.size else T.buttonM.size)
			* math.min(1, h / (if big then S.buttonL else S.buttonM))
	local stroke = if big then T.buttonL.stroke else T.buttonM.stroke
	local mid = (h - ledge) / 2
	local left, right = 10, 10
	if o.icon then
		local isz = size * 1.25
		Icons.make(body, o.icon, 10, mid - isz / 2, isz, { z = 4 })
		left = 12 + isz
	end
	if o.chip then
		local cw = math.max(70, #tostring(o.chip) * size * 0.55 + 42)
		local chip = Base.fill(
			body,
			"Chip",
			w - cw - 10,
			mid - size * 0.62,
			cw,
			size * 1.24,
			Base.color("navy"),
			4
		)
		Base.corner(chip)
		Base.outline(chip, UiTheme.OUTLINE.small)
		local ch = size * 1.24
		-- (chipIcon = false: words only, like FREE x1, with no coin by them)
		local coinW = if o.chipIcon == false then ch * 0.3 else ch * 0.95
		if o.chipIcon ~= false then
			Icons.make(chip, "coin", 3, ch * 0.1, ch * 0.8, { z = 5 })
		end
		Base.text(
			chip,
			"Price",
			coinW,
			ch * 0.14,
			cw - coinW - 8,
			ch * 0.72,
			tostring(o.chip),
			{ z = 5, align = "l" }
		)
		right = cw + 16
	end
	Base.text(
		body,
		"Label",
		left,
		mid - size * 0.6,
		w - left - right,
		size * 1.2,
		words,
		{ stroke = stroke, z = 4 }
	)
	paintButton(b, toneName)
	if o.main and big then
		Anim.shine(clip)
	end
	Anim.press(b)
	if o.onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Off") ~= true and b:GetAttribute("Waiting") ~= true then
				o.onClick()
			end
		end)
	end
	return b
end

function Kit.setTone(b: TextButton, toneName: string)
	paintButton(b, toneName)
end

function Kit.setWords(b: TextButton, words: string)
	local l = b:FindFirstChild("Body") and (b :: any).Body:FindFirstChild("Label")
	if l then
		Base.setText(l, words)
	end
end

-- Disabled: grey, 60%.
function Kit.enable(b: TextButton, on: boolean)
	b:SetAttribute("Off", not on)
	b.Active = on
	paintButton(b, (b:GetAttribute("Tone") :: string?) or "lime")
end

-- Waiting: a spinner next to the words; taps do nothing.
function Kit.wait(b: TextButton, on: boolean)
	b:SetAttribute("Waiting", on)
	local body = b:FindFirstChild("Body") :: Frame
	local sp = body:FindFirstChild("Spinner")
	if on and not sp then
		local _, h = Base.designSize(b)
		local s = h * 0.36
		Kit.spinner(body, 14, (h - UiTheme.LEDGE) / 2 - s / 2, s)
	elseif not on and sp then
		sp:Destroy()
	end
end

-- A spinner: a white ring with a gap, turning.
function Kit.spinner(parent: Instance, x: number, y: number, s: number): Frame
	local f = Base.box(parent, "Spinner", x, y, s, s, 6)
	Base.corner(f)
	local st = Base.outline(f, s * 0.12, WHITE)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(0.71, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = st
	Anim.spin(f, 0.8)
	return f
end

-- ===== arcs: a ring or a disk shown from the top, clockwise, up to a fraction =====

export type Arc = { frame: Frame, set: (f: number) -> () }

function Kit.arc(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	d: number,
	color: Color3,
	ring: number?,
	z: number?,
	alpha: number?
): Arc
	local holder = Base.box(parent, name, x, y, d, d, z or 1)
	local grads: { UIGradient } = {}
	for i = 1, 2 do
		local clip = Base.box(
			holder,
			if i == 1 then "Right" else "Left",
			if i == 1 then d / 2 else 0,
			0,
			d / 2,
			d,
			1
		)
		clip.ClipsDescendants = true
		local inset = if ring then ring / 2 else 0
		local circle = Base.box(
			clip,
			"Circle",
			(if i == 1 then -d / 2 else 0) + inset,
			inset,
			d - 2 * inset,
			d - 2 * inset,
			1
		)
		Base.corner(circle)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		if ring then
			local st = Base.outline(circle, ring, color)
			g.Parent = st
		else
			circle.BackgroundColor3 = color
			circle.BackgroundTransparency = alpha or 0
			g.Parent = circle
		end
		grads[i] = g
	end
	local function set(f: number)
		local v = math.clamp(f, 0, 1)
		grads[1].Rotation = math.min(v, 0.5) * 360
		grads[2].Rotation = 180 + math.max(v - 0.5, 0) * 360
		holder.Visible = v > 0
	end
	set(0)
	return { frame = holder, set = set }
end

-- ===== RoundButton: BOOST (charge ring) and COACH (cooldown clock) =====

export type Round = {
	button: TextButton,
	setCharge: (f: number) -> (),
	setCooldown: (f: number, words: string) -> (),
}

function Kit.round(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	s: number,
	toneName: string,
	words: string,
	opts: { [string]: any }?
): Round
	local o: { [string]: any } = opts or {}
	local t = tone(toneName)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 3
	b.Parent = parent
	Base.at(b, x, y, s, s)
	local drop = Base.fill(b, "Drop", 0, 5, s, s, INK, 1)
	Base.corner(drop)
	local body = Base.fill(b, "Body", 0, 0, s, s, Base.color(t.deep), 2)
	Base.corner(body)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local face = Base.fill(body, "Face", 0, 0, s, s - 9 * s / 100, WHITE, 1)
	Base.corner(face)
	-- carter's kit v41: the 3D face (hi -> c -> c2 over the deep base) and its rim and gloss
	local f3 = UiTheme.FACE[toneName]
	if f3 then
		body.BackgroundColor3 = Kit.hex(f3.deep)
		Kit.face(face, { f3.hi, f3.c, f3.c2 })
		Kit.rim(face, s, s - 9 * s / 100, s / 2)
	else
		Kit.gloss(face, Base.color(t.fill))
	end
	local clip = Base.box(face, "Clip", s * 0.16, s * 0.16, s * 0.68, s * 0.62, 1)
	Pattern.attach(clip)
	local label = Base.text(
		body,
		"Label",
		s * 0.08,
		s * 0.36,
		s * 0.84,
		s * 0.22,
		words,
		{ stroke = 4, z = 6 }
	)
	-- COACH: a dark clock-sweep over it with the seconds left
	local cool: Arc? = nil
	local coolWords: TextLabel? = nil
	if o.cooldown then
		cool = Kit.arc(body, "Cooldown", 0, 0, s, Color3.fromRGB(27, 35, 80), nil, 4, 0.38)
		coolWords = Base.text(
			body,
			"Seconds",
			s * 0.2,
			s * 0.22,
			s * 0.6,
			s * 0.26,
			"",
			{ stroke = 4, z = 7 }
		)
	end
	-- BOOST: a ring around it, yellow while it fills, lime and pulsing when full
	local charge: Arc? = nil
	if o.charge then
		local ring = Base.box(b, "RingInk", -12, -12, s + 24, s + 24, 0)
		Base.corner(ring)
		Base.outline(ring, 0.1, INK)
		local back = Base.box(b, "RingBack", -10, -10, s + 20, s + 20, 0)
		Base.corner(back)
		Base.outline(back, 12, INK)
		charge = Kit.arc(b, "Charge", -13, -13, s + 26, Base.color("go"), 6, 1)
	end
	Anim.press(b)
	local pulse: Tween? = nil
	local function setCharge(f: number)
		if not charge then
			return
		end
		charge.set(f)
		local full = f >= 1
		for _, side in charge.frame:GetChildren() do
			local circle = side:FindFirstChild("Circle")
			local st = circle and circle:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = if full then Base.color("lime") else Base.color("go")
			end
		end
		if full and not pulse then
			pulse = Anim.pulse(body, 1.07, M.boostPulse)
		elseif not full and pulse then
			pulse:Cancel()
			pulse = nil
			Anim.scaler(body).Scale = 1
		end
	end
	local function setCooldown(f: number, w: string)
		if cool and coolWords then
			cool.set(f)
			coolWords.Text = w
			label.Position = if f > 0
				then UDim2.fromScale(0.08, 0.62)
				else UDim2.fromScale(0.08, 0.36)
		end
	end
	if o.onClick then
		b.Activated:Connect(o.onClick)
	end
	return { button = b, setCharge = setCharge, setCooldown = setCooldown }
end

-- ===== CloseButton: red square X, tilted 5 deg (no pattern) =====

function Kit.close(
	parent: Instance,
	x: number,
	y: number,
	onClick: (() -> ())?,
	s: number?
): TextButton
	local size = s or S.close
	local b = Instance.new("TextButton")
	b.Name = "Close"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 8
	b.Parent = parent
	Base.at(b, x, y, size, size)
	b.Rotation = UiTheme.CLOSE_TILT
	local drop = Base.fill(b, "Drop", 0, UiTheme.DROP, size, size, INK, 1)
	Base.corner(drop, C.close)
	local body = Base.fill(b, "Body", 0, 0, size, size, Base.color("dangerDeep"), 2)
	Base.corner(body, C.close)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local face = Base.fill(body, "Face", 0, 0, size, size - 6, WHITE, 1)
	Base.corner(face, C.close)
	Kit.gloss(face, Base.color("danger"))
	Base.text(
		body,
		"X",
		size * 0.18,
		size * 0.1,
		size * 0.64,
		size * 0.66,
		"X",
		{ stroke = 5, z = 4 }
	)
	Anim.press(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- ===== Window =====

export type Window = {
	root: Frame,
	body: Frame,
	content: Frame,
	title: TextLabel?,
	close: TextButton?,
	open: () -> (),
}

-- A window on the canvas at `piece` (the body's box): white body (faint dots), blue slab 8 px left
-- and 9 px down behind it, cyan title half outside the top-left, tilted red X off the top-right.
-- opts: blue (a blue glossy popup body with the pattern, no X), navy (carter's kit v41: the
-- navy panel body, its title white on an ink outline), noClose, onClose.
function Kit.window(canvas: Instance, piece: UiScreens.Piece, opts: { [string]: any }?): Window
	local o: { [string]: any } = opts or {}
	local w, h = piece.w, piece.h
	local root = Instance.new("Frame")
	root.Name = "Window"
	root.BackgroundTransparency = 1
	root.ZIndex = 2
	root.Parent = canvas
	Base.place(root, piece)
	local body: Frame
	if o.navy then
		body = Kit.navyPanel(root, "Body", 0, 0, w, h, C.window)
	else
		local slab =
			Base.fill(root, "Slab", UiTheme.SLAB.x, UiTheme.SLAB.y, w, h, Base.color("blue"), 1)
		Base.corner(slab, C.window)
		Base.outline(slab, UiTheme.OUTLINE.thick, Base.color("blueDeep"))
		body = Base.fill(root, "Body", 0, 0, w, h, WHITE, 2)
		Base.corner(body, C.window)
		Base.outline(body, UiTheme.OUTLINE.thick, Base.color("blueDeep"))
	end
	local back = Base.box(body, "Back", 6, 6, w - 12, h - 12, 1)
	if o.navy then
		-- (the panel's own stripes are its texture)
	elseif o.blue then
		Kit.gloss(body, Base.color("blue"), 0.3)
		Pattern.attach(back)
	else
		Pattern.dots(back)
	end
	local content = Base.box(body, "Content", 0, 0, w, h, 5)
	local title: TextLabel? = nil
	local words = o.title or piece.text
	if words then
		local tw = math.min(w - 70, #words * 0.6 * T.title.size + 24)
		if o.navy then
			title = Kit.title(root, 14, -40, tw, 50, words, nil, "l")
		else
			title = Base.text(root, "Title", 14, -40, tw, 50, words, {
				color = Base.color("blue"),
				stroke = T.title.stroke,
				strokeColor = WHITE,
				drop = T.title.drop,
				dropColor = Base.color("blueDeep"),
				align = "l",
				z = 9,
			})
		end
	end
	local close: TextButton? = nil
	if not o.blue and not o.noClose then
		close = Kit.close(root, w - 34, -24, o.onClose)
	end
	local function open()
		Anim.windowIn(root, title, close)
	end
	return { root = root, body = body, content = content, title = title, close = close, open = open }
end

-- ===== Panel: a small white panel (MY CAR, tips, notes) =====

function Kit.panel(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	radius: number?
): Frame
	local r = radius or 16
	local slab = Base.fill(parent, name .. "Slab", x - 6, y + 7, w, h, Base.color("blue"), 1)
	Base.corner(slab, r)
	Base.outline(slab, UiTheme.OUTLINE.normal, Base.color("blueDeep"))
	local f = Base.fill(parent, name, x, y, w, h, WHITE, 2)
	Base.corner(f, r)
	Base.outline(f, UiTheme.OUTLINE.normal, Base.color("blueDeep"))
	return f
end

-- A panel placed on the canvas by a UiScreens piece (its slab rides along inside it).
function Kit.placedPanel(canvas: Instance, piece: UiScreens.Piece, radius: number?): (Frame, Frame)
	local holder = Instance.new("Frame")
	holder.Name = piece.name
	holder.BackgroundTransparency = 1
	holder.Parent = canvas
	Base.place(holder, piece)
	local f = Kit.panel(holder, "Panel", 0, 0, piece.w, piece.h, radius)
	return holder, f
end

-- ===== carter's kit v41 chrome: navy panel, blue card, title =====

-- The kit's panel (.pn): navy top to bottom, a 3 px light-blue rim, a 3 px ink line outside it
-- and a soft highlight across the top.
function Kit.navyPanel(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	radius: number?
): Frame
	local r = radius or 20
	-- (the rim and the ink line are frames behind it: a UIStroke on the panel would be tinted by
	-- its navy gradient)
	local line = Base.fill(parent, name .. "Line", x - 6, y - 6, w + 12, h + 12, INK, 1)
	Base.corner(line, r + 6)
	local rim = Base.fill(
		parent,
		name .. "Rim",
		x - 3,
		y - 3,
		w + 6,
		h + 6,
		Kit.hex(UiTheme.CHROME.panelRim),
		2
	)
	Base.corner(rim, r + 3)
	local f = Base.fill(parent, name, x, y, w, h, WHITE, 3)
	Base.corner(f, r)
	Kit.face(f, UiTheme.CHROME.panel)
	-- (the kit's faint 3.5% stripes are left off: a rotated frame is not clipped in Roblox)
	local top = Base.fill(f, "Top", 14, 3, math.max(1, w - 28), math.min(22, h * 0.3), WHITE, 1)
	Base.corner(top, 12)
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Transparency = NumberSequence.new(0.88, 1)
	tg.Parent = top
	return f
end

-- The kit's card (.cd): blue top to bottom, 2.5 px ink outline, an inner light rim and a 4 px ink
-- drop. selected: a 4 px gold ring and a soft gold glow (Kit.select).
function Kit.plate(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	selected: boolean?,
	radius: number?
): Frame
	local r = radius or 14
	local drop = Base.fill(parent, name .. "Drop", x, y + 4, w, h, INK, 1)
	Base.corner(drop, r)
	local f = Base.fill(parent, name, x, y, w, h, WHITE, 2)
	Base.corner(f, r)
	Kit.face(f, UiTheme.CHROME.card)
	Base.outline(f, UiTheme.OUTLINE.small)
	Kit.rim(f, w, h, r)
	Kit.select(f, selected == true)
	return f
end

-- A plate's gold ring and glow, on or off.
function Kit.select(f: Frame, on: boolean)
	local ring = f:FindFirstChild("Ring") :: Frame?
	if not ring then
		local w, h = Base.designSize(f)
		-- (just outside the card's 2.5 px ink outline and its 4 px drop)
		local made = Base.box(f, "Ring", -2.5, -2.5, w + 5, h + 9, f.ZIndex + 1)
		Base.corner(made, 16)
		Base.outline(made, 4, Kit.hex(UiTheme.CHROME.cardSelected))
		local glow = Base.box(made, "Glow", -4, -4, w + 13, h + 17, f.ZIndex)
		Base.corner(glow, 24)
		local gs = Base.outline(glow, 6, Kit.hex(UiTheme.CHROME.cardSelected))
		gs.Transparency = 0.6
		ring = made
	end
	(ring :: Frame).Visible = on
	f:SetAttribute("Selected", on)
end

-- The kit's title (.t-title): a thick ink outline and ink drop, the letters filled top to bottom
-- (look: "white" -> sky, "gold", "red" or "ice"; the kit's thin white inner line is left off).
function Kit.title(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string,
	look: string?,
	align: string?
): TextLabel
	local stops = UiTheme.CHROME.title[look or "white"] or UiTheme.CHROME.title.white
	local l = Base.text(parent, "Title", x, y, w, h - T.title.drop, words, {
		color = WHITE,
		stroke = T.title.stroke,
		drop = T.title.drop,
		align = align,
		z = 9,
	})
	local g = Instance.new("UIGradient")
	g.Name = "Fill"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Kit.hex(stops[1])),
		ColorSequenceKeypoint.new(0.5, Kit.hex(stops[2])),
		ColorSequenceKeypoint.new(0.54, Kit.hex(stops[3])),
		ColorSequenceKeypoint.new(1, Kit.hex(stops[4])),
	})
	g.Parent = l
	return l
end

-- A section line: words with a line each side.
function Kit.section(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string,
	colorName: string?
): TextLabel
	local tw = math.min(w * 0.8, #words * h * 0.62 + 16)
	Base.fill(parent, "LineL", x, y + h / 2 - 1, (w - tw) / 2 - 6, 2, Base.color("barEmpty"), 2)
	Base.fill(
		parent,
		"LineR",
		x + (w + tw) / 2 + 6,
		y + h / 2 - 1,
		(w - tw) / 2 - 6,
		2,
		Base.color("barEmpty"),
		2
	)
	return Base.text(
		parent,
		"Section",
		x + (w - tw) / 2,
		y,
		tw,
		h,
		words,
		{ color = Base.color(colorName or "blue"), z = 3 }
	)
end

-- A shout: one per screen (LEAGUE UP!, YOU WON!, EPIC!): white or colored, 7 px ink stroke and
-- a 5 px ink drop; pops 30% -> 112% -> 100%.
function Kit.shout(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string,
	colorName: string?,
	align: string?
): TextLabel
	local holder = Base.box(parent, "Shout", x, y, w, h, 6)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = holder.Position
		+ UDim2.fromScale(holder.Size.X.Scale / 2, holder.Size.Y.Scale / 2)
	local l = Base.text(holder, "Words", 0, 0, w, h - T.shout.drop, words, {
		color = if colorName then Base.color(colorName) else WHITE,
		stroke = T.shout.stroke,
		drop = T.shout.drop,
		align = align,
		z = 3,
	})
	Anim.shout(holder)
	return l
end

-- ===== SideButton: a 62 px blue tile, its 3D icon poking out the top, its word across the
-- bottom edge, an optional red count dot. Idle: a nudge every 4.5 s, the icon bobs. =====

export type Side = { button: TextButton, setDot: (n: number?) -> () }

function Kit.side(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	word: string,
	icon: string,
	index: number?,
	iconOpts: { [string]: any }?
): Side
	local s = S.side
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 3
	b.Parent = parent
	Base.at(b, x, y, s, s)
	local i = index or 1
	local holder = Base.box(b, "Tile", 0, 0, s, s, 1)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	local drop = Base.fill(holder, "Drop", 0, 3, s, s, INK, 1)
	Base.corner(drop, C.slot)
	local body = Base.fill(holder, "Body", 0, 0, s, s, Base.color("blueDeep"), 2)
	Base.corner(body, C.slot)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local face = Base.fill(body, "Face", 0, 0, s, s - 5, WHITE, 1)
	Base.corner(face, C.slot)
	Kit.gloss(face, Base.color("blue"), 0.35)
	local clip = Base.box(face, "Clip", 3, 3, s - 6, s - 11, 1)
	Pattern.attach(clip)
	local io: { [string]: any } = iconOpts or {}
	io.z = 5
	-- (in the middle of the tile, over its word: it poked out of the top, carter 10-28)
	local ic = Icons.make(holder, icon, (s - 40) / 2, 5, 40, io)
	Base.text(holder, "Word", -8, s - 14, s + 16, 22, word, { stroke = 4, z = 7 })
	-- (26 round, its number 18 tall: 14 px on a phone, carter 10-29)
	local dot = Base.fill(holder, "Dot", s - 16, -10, 26, 26, Base.color("danger"), 8)
	Base.corner(dot)
	Base.outline(dot, UiTheme.OUTLINE.small)
	local dotWords = Base.text(dot, "N", 2, 4, 22, 18, "", { z = 9 })
	dot.Visible = false
	Anim.dot(dot)
	Anim.nudge(holder, 1 + i * 0.6)
	Anim.bob(ic, M.iconBob, 5, i * 0.5)
	Anim.press(b)
	local function setDot(n: number?)
		dot.Visible = n ~= nil and n ~= 0
		dotWords.Text = if n == nil then "" elseif n < 0 then "!" else tostring(n)
	end
	return { button = b, setDot = setDot }
end

-- ===== Currency: spinning coin, big stroked yellow number, small rate, green "+" (opens the
-- shop). No box behind it. =====

export type Currency = { button: TextButton, set: (n: number) -> (), setRate: (words: string?) -> () }

-- Spin a drawn coin on its up-down axis once every 3 s (its width goes to nothing and back).
function Kit.coinSpin(obj: GuiObject)
	if Base.reduced() then
		return
	end
	local full = obj.Size
	obj.AnchorPoint = Vector2.new(0.5, obj.AnchorPoint.Y)
	obj.Position = obj.Position + UDim2.fromScale(full.X.Scale / 2, 0)
	local ar = obj:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ar then
		ar:Destroy()
	end
	Anim.every(obj, M.coinSpin, function()
		Anim.to(
			obj,
			0.22,
			{ Size = UDim2.new(0, 0, full.Y.Scale, 0) },
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.In
		)
		task.delay(0.22, function()
			Anim.to(obj, 0.22, { Size = full }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end)
	end, 1)
end

function Kit.currency(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	opts: { [string]: any }?
): Currency
	local o: { [string]: any } = opts or {}
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 3
	b.Parent = parent
	Base.at(b, x, y, w, h)
	if o.plate then
		-- a dark plate behind the number: over the 3D world it sat on the signs (phone 10-28)
		local plate = Base.fill(b, "Plate", h * 0.4, 3, w - h * 0.4, h - 6, Base.color("ink"), 1)
		plate.BackgroundTransparency = 0.3
		Base.corner(plate)
	end
	local iconName = o.icon or "coin"
	local ic = Icons.make(b, iconName, 0, 2, h - 4, { z = 3 })
	if iconName == "coin" then
		Kit.coinSpin(ic)
	end
	local plusW = if o.plus then h * 0.62 else 0
	local numH = if o.rate ~= nil then h * 0.66 else h * 0.8
	local num = Base.text(
		b,
		"Amount",
		h + 2,
		if o.rate ~= nil then 0 else h * 0.1,
		w - h - plusW - 6,
		numH,
		UiMotion.commas(o.value or 0),
		{
			color = if iconName == "gem" then Color3.fromRGB(127, 227, 255) else Base.color("go"),
			stroke = 5,
			align = "l",
			z = 4,
		}
	)
	local rate: TextLabel? = nil
	if o.rate ~= nil then
		rate = Base.text(
			b,
			"Rate",
			h + 2,
			h * 0.66,
			w - h - plusW - 6,
			h * 0.32,
			o.rate,
			{ stroke = 3, align = "l", z = 4 }
		)
	end
	if o.plus then
		Icons.make(b, "plus", w - plusW, (h - plusW) / 2, plusW, { z = 5 })
	end
	if not o.noPress then
		Anim.press(b)
	end
	local shown = o.value or 0
	local function set(n: number)
		Anim.countUp(num, shown, n)
		shown = n
	end
	local function setRate(words: string?)
		if rate then
			rate.Text = words or ""
		end
	end
	if o.onClick then
		b.Activated:Connect(o.onClick)
	end
	return { button = b, set = set, setRate = setRate }
end

-- ===== QuestBanner: top-centre white card, tilted yellow NEXT UP! tag, big cyan goal =====

export type Banner = {
	frame: Frame,
	set: (title: string, sub: string?) -> (),
	hurry: (on: boolean) -> (),
}

function Kit.banner(canvas: Instance, piece: UiScreens.Piece, tag: string?): Banner
	local w, h = piece.w, piece.h
	local f = Instance.new("Frame")
	f.Name = piece.name
	f.BackgroundTransparency = 1
	f.Parent = canvas
	Base.place(f, piece)
	local drop = Base.fill(f, "Drop", 0, 4, w, h, INK, 1)
	Base.corner(drop, 14)
	local card = Base.fill(f, "Card", 0, 0, w, h, WHITE, 2)
	Base.corner(card, 14)
	Base.outline(card, UiTheme.OUTLINE.normal, Base.color("blueDeep"))
	local clip = Base.box(card, "Clip", 3, 3, w - 6, h - 6, 1)
	Pattern.attach(clip, true)
	local title = Base.text(
		card,
		"Goal",
		12,
		12,
		w - 24,
		34,
		"",
		{ color = Base.color("blue"), stroke = 6, z = 4 }
	)
	local sub = Base.text(card, "Sub", 12, 50, w - 24, 17, "", { color = INK, z = 4 })
	local tagHolder = Base.box(f, "TagHolder", 12, -18, 112, 30, 5)
	tagHolder.Rotation = -6
	Base.text(
		tagHolder,
		"Tag",
		0,
		0,
		112,
		30,
		tag or "NEXT UP!",
		{ color = Base.color("go"), stroke = 5, z = 5 }
	)
	local home = tagHolder.Position
	Anim.loop(
		tagHolder,
		M.nextUpBounce,
		{ Position = home - UDim2.fromOffset(0, 4 * Base.k), Rotation = -2 }
	)
	local pulse: Tween? = nil
	local function set(t: string, s: string?)
		title.Text = t
		sub.Text = s or ""
		sub.Visible = s ~= nil and s ~= ""
	end
	local function hurry(on: boolean)
		if on and not pulse then
			pulse = Anim.pulse(card, 1.05, 0.8)
		elseif not on and pulse then
			pulse:Cancel()
			pulse = nil
			Anim.scaler(card).Scale = 1
		end
	end
	return { frame = f, set = set, hurry = hurry }
end

-- ===== HudPill: navy pill with a colored tag chip (LAP 1/2, timers, streaks) =====

export type Pill = { frame: Frame, set: (words: string) -> (), setTag: (words: string) -> () }

function Kit.pill(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	tag: string?,
	tagTone: string?,
	words: string,
	opts: { [string]: any }?
): Pill
	local o: { [string]: any } = opts or {}
	local f = Base.box(parent, name, x, y, w, h, o.z or 2)
	local drop = Base.fill(f, "Drop", 0, 4, w, h, INK, 1)
	Base.corner(drop)
	local body = Base.fill(f, "Body", 0, 0, w, h, Base.color(o.fill or "navy"), 2)
	Base.corner(body)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local left = h * 0.35
	local tagLabel: TextLabel? = nil
	if tag then
		local tw = math.max(h * 1.1, #tag * h * 0.32 + h * 0.5)
		local chip = Base.fill(
			body,
			"Tag",
			5,
			5,
			tw,
			h - 10,
			Base.color(
				UiTheme.TONES[tagTone or "blue"] and UiTheme.TONES[tagTone or "blue"].fill
					or (tagTone or "blue")
			),
			3
		)
		Base.corner(chip)
		Base.outline(chip, UiTheme.OUTLINE.small)
		tagLabel = Base.text(
			chip,
			"Words",
			4,
			(h - 10) * 0.18,
			tw - 8,
			(h - 10) * 0.64,
			tag,
			{ stroke = 3.5, z = 4 }
		)
		left = tw + 12
	end
	local plusW = if o.plus then h - 8 else 0
	local value = Base.text(
		body,
		"Value",
		left,
		h * (if o.big then 0.12 else 0.2),
		w - left - plusW - h * 0.3,
		h * (if o.big then 0.7 else 0.58),
		words,
		{ z = 4, stroke = if o.stroke then 4 else nil }
	)
	if o.plus then
		Icons.make(body, "plus", w - plusW - 3, 4, plusW, { z = 5 })
	end
	return {
		frame = f,
		set = function(t: string)
			value.Text = t
		end,
		setTag = function(t: string)
			if tagLabel then
				tagLabel.Text = t
			end
		end,
	}
end

-- ===== StatBar: icon square + label + LV n + chunky navy bar with its colored fill =====

export type Bar = {
	frame: Frame,
	set: (f: number, level: (number | string)?, animate: boolean?) -> (),
}

-- Moving diagonal stripes inside a bar fill (one loop every 0.7 s).
local function stripes(fill: Frame)
	local fw, fh = Base.designSize(fill)
	local holder = Base.box(fill, "Stripes", 0, 0, fw, fh, 2)
	holder.ClipsDescendants = true
	local inner = Instance.new("Frame")
	inner.Name = "Moving"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = holder
	local step = 20
	for i = 0, math.ceil(fw / step) + 1 do
		local st = Instance.new("Frame")
		st.Name = "Stripe"
		st.BackgroundColor3 = WHITE
		st.BackgroundTransparency = 0.75
		st.BorderSizePixel = 0
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Rotation = 45
		st.Position = UDim2.fromScale((i * step - step) / fw, 0.5)
		st.Size = UDim2.fromScale(7 / fw, 2.4)
		st.Parent = inner
	end
	if not Base.reduced() then
		Anim.tick(inner, function(t)
			local f = (t % M.barStripes) / M.barStripes
			inner.Position = UDim2.fromScale(f * step / fw, 0)
		end)
	end
end

function Kit.bar(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colorName: string,
	opts: { [string]: any }?
): Frame
	local o: { [string]: any } = opts or {}
	local track = Base.fill(parent, name, x, y, w, h, Base.color(o.track or "navy"), o.z or 2)
	if not o.track then
		-- carter's kit v41: a recessed dark track, its top in shadow
		Kit.face(track, UiTheme.CHROME.track)
	end
	Base.corner(track)
	Base.outline(track, if h < 20 then UiTheme.OUTLINE.small else UiTheme.OUTLINE.normal)
	track.ClipsDescendants = true
	local fill = Base.fill(track, "Fill", 0, 0, w, h, Base.color(colorName), 1)
	Base.corner(fill)
	-- the kit's fill runs light -> color -> deeper: a soft dark band over its lower half (the
	-- color stays the fill's BackgroundColor3, so screens can still recolor it)
	-- (the fill's full size and corners, clear on top: square corners poked out past its ends)
	local low = Base.fill(fill, "Low", 0, 0, w, h, Color3.new(0, 0, 0), 2)
	Base.corner(low)
	local lg = Instance.new("UIGradient")
	lg.Rotation = 90
	lg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.82),
	})
	lg.Parent = low
	local hi = Base.fill(fill, "Shine", 6, 2, w - 12, h * 0.3, WHITE, 3)
	hi.BackgroundTransparency = 0.45
	Base.corner(hi)
	if not o.still then
		stripes(fill)
	end
	fill.Size = UDim2.fromScale(o.value or 0, 1)
	return track
end

-- Set a bar (made by Kit.bar) to f (0..1); grow = fill from empty like a screen opening.
function Kit.setBar(track: Frame, f: number, grow: boolean?)
	local fill = track:FindFirstChild("Fill") :: Frame?
	if not fill then
		return
	end
	if grow then
		Anim.grow(fill, f)
	else
		Anim.to(
			fill,
			0.4,
			{ Size = UDim2.fromScale(math.clamp(f, 0, 1), 1) },
			Enum.EasingStyle.Quart
		)
	end
end

function Kit.statBar(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	statKey: string
): Bar
	local stat = UiTheme.STATS[1]
	for _, s in UiTheme.STATS do
		if s.key == statKey then
			stat = s
		end
	end
	local f = Base.box(parent, "Stat_" .. stat.key, x, y, w, h, 2)
	local col = Base.color(UiTheme.TONES[stat.tone].fill)
	local sq = Base.fill(f, "Icon", 0, 0, h, h, col, 2)
	Base.corner(sq, 12)
	Base.outline(sq, UiTheme.OUTLINE.normal)
	Kit.gloss(sq, col, 0.3)
	Icons.make(sq, stat.key, h * 0.18, h * 0.18, h * 0.64, { z = 3 })
	local tx = h + 8
	Base.text(
		f,
		"Word",
		tx,
		0,
		(w - tx) * 0.6,
		h * 0.4,
		stat.word,
		{ color = INK, align = "l", z = 3 }
	)
	local lv = Base.text(
		f,
		"Level",
		tx + (w - tx) * 0.5,
		0,
		(w - tx) * 0.5,
		h * 0.4,
		"LV 1",
		{ color = INK, align = "r", z = 3 }
	)
	local track = Kit.bar(f, "Track", tx, h * 0.46, w - tx, h * 0.5, stat.tone)
	-- level: a number ("LV 3") or the words to show there ("26/60")
	local function set(v: number, level: (number | string)?, grow: boolean?)
		if type(level) == "string" then
			lv.Text = level
		elseif level then
			lv.Text = "LV " .. tostring(level)
		end
		Kit.setBar(track, v, grow)
	end
	return { frame = f, set = set }
end

-- ===== ItemSlot: a garage square in its state color, the car poking out, a big stroked count
-- bottom-left, a small white badge top-left, a white+ink ring when selected, a red X when
-- marked to delete. tone: lime (equipped), blue, gold (golden), "empty" (dashed +), "locked". =====

export type Slot = {
	button: TextButton,
	setSelected: (on: boolean) -> (),
	setMarked: (on: boolean) -> (),
	setTone: (t: string) -> (),
	car: Frame?,
}

function Kit.slot(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	s: number,
	opts: { [string]: any }?
): Slot
	local o: { [string]: any } = opts or {}
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 2
	b.Parent = parent
	Base.at(b, x, y, s, s)
	local ring = Base.box(b, "Ring", -6, -6, s + 12, s + 12, 1)
	Base.corner(ring, C.slot + 6)
	Base.outline(ring, 4, INK)
	local ringWhite = Base.box(b, "RingWhite", -3, -3, s + 6, s + 6, 1)
	Base.corner(ringWhite, C.slot + 3)
	local white = Base.outline(ringWhite, 4, WHITE)
	local shimmer = Instance.new("UIGradient")
	shimmer.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(0.55, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	shimmer.Parent = white
	ring.Visible, ringWhite.Visible = false, false
	local drop = Base.fill(b, "Drop", 0, 3, s, s, INK, 2)
	Base.corner(drop, C.slot)
	local body = Base.fill(b, "Body", 0, 0, s, s, WHITE, 3)
	Base.corner(body, C.slot)
	local edge = Base.outline(body, UiTheme.OUTLINE.normal)
	local clip = Base.box(body, "Clip", 3, 3, s - 6, s - 6, 1)
	local layer = Pattern.attach(clip)
	local plus = Base.text(
		body,
		"Plus",
		0,
		s * 0.2,
		s,
		s * 0.55,
		"+",
		{ color = Base.color("lockedEdge"), z = 4 }
	)
	local lock: GuiObject? = nil
	local function setTone(t: string)
		local tt = UiTheme.TONES[t]
		if t == "empty" or t == "locked" then
			body.BackgroundColor3 = Base.color(if t == "empty" then "lockedFill" else "lockedFill")
				:Lerp(INK, if t == "locked" then 0.06 else 0)
			local g = body:FindFirstChild("Gloss")
			if g then
				g:Destroy()
			end
			edge.Color = Base.color("lockedEdge")
			layer.Visible = false
		else
			local fill = Base.color(if tt then tt.fill else "blue")
			Kit.gloss(body, fill, 0.35)
			edge.Color = Base.color(if tt then tt.deep else "blueDeep")
			layer.Visible = true
		end
		plus.Visible = t == "empty"
		if t == "locked" and not lock then
			lock = Icons.make(body, "lock", s * 0.25, s * 0.22, s * 0.5, { z = 5 })
		elseif lock then
			lock.Visible = t == "locked"
		end
	end
	setTone(o.tone or "blue")
	local car: Frame? = nil
	if o.car then
		local co = o.car
		co.z = 5
		car = Icons.car(b, -s * 0.08, -s * 0.18, s * 1.16, s * 0.9, co)
	end
	if o.count then
		Base.text(
			b,
			"Count",
			4,
			s * 0.58,
			s * 0.9,
			s * 0.38,
			o.count,
			{ stroke = 5, align = "l", z = 7 }
		)
	end
	if o.badge then
		-- (its words at least 18 tall: 14 px on a phone, Lead item 5)
		local th = math.max(s * 0.18, 18)
		-- (never wider than the slot: TRAIN ran onto the next one)
		local bw = math.min(math.max(s * 0.36, #o.badge * th * 0.66 + 10), s - 8)
		local badge = Base.fill(b, "Badge", 4, 4, bw, th + 6, WHITE, 7)
		Base.corner(badge)
		Base.outline(badge, 2)
		Base.text(badge, "Words", 2, 3, bw - 4, th, o.badge, { color = INK, z = 8 })
	end
	local mark = Base.text(
		b,
		"Mark",
		0,
		0,
		s,
		s,
		"X",
		{ color = Base.color("danger"), stroke = 5, strokeColor = WHITE, z = 9 }
	)
	mark.Visible = false
	local spinning = false
	local function setSelected(on: boolean)
		ring.Visible, ringWhite.Visible = on, on
		if on and not spinning and not Base.reduced() then
			spinning = true
			Anim.tick(shimmer, function(t)
				shimmer.Rotation = (t / M.slotShimmer * 360) % 360
			end)
		end
	end
	local function setMarked(on: boolean)
		mark.Visible = on
		if on then
			Anim.pop(mark, 0.25, 0.3)
		end
	end
	setSelected(o.selected == true)
	setMarked(o.marked == true)
	Anim.press(b)
	return {
		button = b,
		setSelected = setSelected,
		setMarked = setMarked,
		setTone = setTone,
		car = car,
	}
end

-- ===== Tag: a small tilted corner label (BEST DEAL, SALE!, NEW!) that wiggles =====

function Kit.tag(
	parent: Instance,
	x: number,
	y: number,
	words: string,
	colorName: string?,
	h: number?,
	z: number?
): Frame
	local hh = h or 24
	local w = #words * hh * 0.52 + hh * 0.8
	local holder = Base.box(parent, "Tag", x, y, w, hh, z or 8)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = holder.Position
		+ UDim2.fromScale(holder.Size.X.Scale / 2, holder.Size.Y.Scale / 2)
	local body = Base.fill(holder, "Body", 0, 0, w, hh, Base.color(colorName or "danger"), 1)
	Base.corner(body, 8)
	Base.outline(body, UiTheme.OUTLINE.small)
	Base.text(body, "Words", 4, hh * 0.14, w - 8, hh * 0.72, words, { stroke = 3, z = 2 })
	Anim.wiggle(holder)
	return holder
end

-- ===== Tabs: a navy pill of 2-4 tabs (carter's kit v41: the others sit 3 px lower and darker, the
-- selected one raised and cyan, or gold with look "gold" on the shop) =====

export type Tabs = { frame: Frame, set: (i: number) -> () }

function Kit.tabs(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	items: { string },
	active: number?,
	onChange: ((i: number) -> ())?,
	icons: { string? }?,
	look: string?
): Tabs
	local gold = look == "gold"
	local f = Base.fill(parent, "Tabs", x, y, w, h, Base.color("navy"), 3)
	Base.corner(f)
	Base.outline(f, UiTheme.OUTLINE.normal)
	local total = 0
	for _, t in items do
		total += #t + 4
	end
	local pad = 4
	local cx = pad
	local tabs: { { b: TextButton, on: Frame, off: Frame, words: TextLabel, up: UDim2, th: number } } =
		{}
	for i, t in items do
		local tw = (w - pad * 2 - (#items - 1) * 4) * (#t + 4) / total
		local b = Instance.new("TextButton")
		b.Name = "Tab" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.ZIndex = 2
		b.Parent = f
		Base.at(b, cx, pad, tw, h - pad * 2)
		local th = h - pad * 2
		local off = Base.fill(b, "Off", 0, 3, tw, th - 3, WHITE, 1)
		Base.corner(off, 12)
		Kit.face(off, UiTheme.CHROME.tabOff)
		Base.outline(off, UiTheme.OUTLINE.small)
		local on = Base.fill(b, "On", 0, 0, tw, th, Kit.hex(if gold then "b86d00" else "0b5cb4"), 1)
		Base.corner(on, 12)
		Base.outline(on, UiTheme.OUTLINE.small)
		local face = Base.fill(on, "Face", 0, 0, tw, th - 4, WHITE, 1)
		Base.corner(face, 12)
		Kit.face(face, if gold then UiTheme.CHROME.tabGold else UiTheme.CHROME.tabOn)
		Kit.rim(face, tw, th - 4, 12)
		local tx = 6
		local ic = icons and icons[i]
		if ic then
			Icons.make(b, ic, 6, (h - pad * 2) * 0.12, (h - pad * 2) * 0.76, { z = 3 })
			tx = 6 + (h - pad * 2) * 0.8
		end
		local words = Base.text(
			b,
			"Words",
			tx,
			(h - pad * 2) * 0.16,
			tw - tx - 6,
			(h - pad * 2) * 0.62,
			t,
			{ stroke = 3.5, z = 4 }
		)
		table.insert(
			tabs,
			{ b = b, on = on, off = off, words = words, up = words.Position, th = th }
		)
		Anim.press(b)
		b.Activated:Connect(function()
			if onChange then
				onChange(i)
			end
		end)
		cx += tw + 4
	end
	local function set(n: number)
		for i, t in tabs do
			local sel = i == n
			t.on.Visible = sel
			t.off.Visible = not sel
			-- (the words sit 3 px lower with the tab when it is not picked)
			t.words.Position = if sel then t.up else t.up + UDim2.fromScale(0, 3 / t.th)
			local inkWords = sel and gold
			t.words.TextColor3 = if inkWords
				then INK
				elseif sel then WHITE
				else Kit.hex(UiTheme.CHROME.tabOffWords)
			local st = t.words:FindFirstChildOfClass("UIStroke")
			if st then
				st.Enabled = sel and not inkWords
			end
		end
	end
	set(active or 1)
	return { frame = f, set = set }
end

-- ===== Toggle: 76 x 40 ON/OFF switch, the word inside, the knob springs across =====

export type Toggle = { button: TextButton, set: (on: boolean) -> () }

function Kit.toggle(
	parent: Instance,
	x: number,
	y: number,
	on: boolean,
	onChange: ((on: boolean) -> ())?
): Toggle
	local w, h = S.toggleW, S.toggleH
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.ZIndex = 3
	b.Parent = parent
	Base.at(b, x, y, w, h)
	local body = Base.fill(b, "Body", 0, 0, w, h, WHITE, 1)
	Base.corner(body)
	Base.outline(body, UiTheme.OUTLINE.normal)
	local words = Base.text(body, "Words", 0, 11, 0, 18, "", { stroke = 3, z = 3 })
	local knob = Base.fill(body, "Knob", 2, 2, 30, 30, WHITE, 4)
	Base.corner(knob)
	Base.outline(knob, UiTheme.OUTLINE.normal)
	local kg = Instance.new("UIGradient")
	kg.Rotation = 90
	kg.Color = ColorSequence.new(WHITE, Color3.fromRGB(223, 232, 243))
	kg.Parent = knob
	local state = on
	local function set(v: boolean, instant: boolean?)
		state = v
		-- carter's kit v41: green when on, a recessed dark track when off
		if v then
			local f3 = UiTheme.FACE.lime
			Kit.face(body, { f3.hi, f3.c, f3.c2 })
		else
			Kit.face(body, UiTheme.CHROME.track)
		end
		Base.at(words, if v then 8 else 36, 11, 32, 18)
		words.Text = if v then "ON" else "OFF"
		words.TextColor3 = if v then WHITE else Kit.hex(UiTheme.CHROME.tabOffWords)
		local st = words:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = v
		end
		local to = UDim2.fromScale((if v then 42 else 2) / w, 2 / h)
		if instant then
			knob.Position = to
		else
			Anim.to(knob, 0.18, { Position = to }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end
	set(on, true)
	b.Activated:Connect(function()
		set(not state)
		if onChange then
			onChange(state)
		end
	end)
	return {
		button = b,
		set = function(v: boolean)
			set(v)
		end,
	}
end

-- ===== Milestones: a bar with reward boxes on it; reached boxes turn lime =====

export type Mark = { at: number, label: string, icon: string }

function Kit.milestones(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	value: number,
	marks: { Mark }
): Frame
	local f = Base.box(parent, "Milestones", x, y, w, h, 2)
	local track = Kit.bar(f, "Track", 0, 14, w, 22, "go")
	Kit.setBar(track, value, true)
	for i, m in marks do
		local got = value >= m.at
		local bx = math.clamp(m.at * w - 20, 0, w - 40)
		local box =
			Base.fill(f, "Reward" .. i, bx, 2, 40, 40, if got then Base.color("lime") else WHITE, 4)
		Base.corner(box, 12)
		Base.outline(box, UiTheme.OUTLINE.normal)
		Icons.make(box, m.icon, 6, 6, 28, { z = 5 })
		if got then
			-- reached: a check on the corner (the icon stays solid, so it never looks muddy)
			Icons.make(box, "check", 22, -8, 24, { z = 7 })
		end
		-- the number beside its box (left of it at the bar's end), big enough to read
		local right = bx + 40 + 36 <= w
		Base.text(
			f,
			"Label" .. i,
			if right then bx + 44 else bx - 40,
			12,
			36,
			22,
			m.label,
			{ stroke = 4.5, align = if right then "l" else "r", z = 5 }
		)
	end
	return f
end

-- ===== OddsList: one row per rarity with its exact % =====

export type Odds = { rarity: string, chance: number }

function Kit.odds(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	items: { Odds }
): Frame
	local f = Base.box(parent, "Odds", x, y, w, h, 2)
	local n = #items
	local gap = 6
	local rh = (h - gap * (n - 1)) / math.max(n, 1)
	local rows: { GuiObject } = {}
	for i, it in items do
		local r = UiTheme.RARITY[UiTheme.rarityId(it.rarity)]
		local row = Base.fill(f, "Row" .. i, 0, (i - 1) * (rh + gap), w, rh, Base.color(r.color), 2)
		Base.corner(row, 12)
		Base.outline(row, UiTheme.OUTLINE.normal)
		Kit.gloss(row, Base.color(r.color), 0.2)
		Base.text(
			row,
			"Word",
			12,
			rh * 0.18,
			w * 0.6,
			rh * 0.62,
			r.word,
			{ stroke = 3.5, align = "l", z = 3 }
		)
		Base.text(
			row,
			"Chance",
			w * 0.55,
			rh * 0.18,
			w * 0.45 - 12,
			rh * 0.62,
			UiMotion.percent(it.chance),
			{ stroke = 3.5, align = "r", z = 3 }
		)
		table.insert(rows, row)
	end
	task.defer(function()
		Anim.cascade(rows)
	end)
	return f
end

-- ===== CarCard: tall glowing card in its rarity color, tilted 2-3 deg =====

export type Card = { root: Frame, card: Frame, content: Frame, flip: () -> (), contentY: number }

function Kit.card(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	opts: { [string]: any }
): Card
	local rarity = opts.rarity or "rare"
	local glowName = if rarity == "golden"
		then "gold"
		else UiTheme.RARITY[UiTheme.rarityId(rarity)].color
	local glow = Base.color(glowName)
	-- the flip holder: its width shrinks to nothing and grows back
	local root = Base.box(parent, name, x, y, w, h, opts.z or 3)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = root.Position + UDim2.fromScale(root.Size.X.Scale / 2, root.Size.Y.Scale / 2)
	root:SetAttribute("FullW", root.Size.X.Scale)
	local tilt = Base.box(root, "Tilt", 0, 0, w, h, 1)
	tilt.Rotation = opts.tilt or 2
	-- glow: rings of the rarity color, fading out, breathing
	local glows = {}
	for i, g in { { 26, 0.86 }, { 16, 0.74 }, { 8, 0.55 } } do
		local gf = Base.fill(tilt, "Glow" .. i, -g[1], -g[1], w + g[1] * 2, h + g[1] * 2, glow, i)
		gf.BackgroundTransparency = g[2]
		Base.corner(gf, C.card + g[1])
		table.insert(glows, gf)
	end
	local ringW = Base.fill(tilt, "WhiteRing", -6, -6, w + 12, h + 12, WHITE, 4)
	ringW.BackgroundTransparency = 0.45
	Base.corner(ringW, C.card + 6)
	local drop = Base.fill(tilt, "Drop", 0, 6, w, h, INK, 5)
	Base.corner(drop, C.card)
	local card = Base.fill(tilt, "Card", 0, 0, w, h, WHITE, 6)
	Base.corner(card, C.card)
	Base.outline(card, 5)
	Kit.gloss(card, glow, 0.5, 70)
	-- clipping is lost on a tilted frame, so a tilted card's pattern goes in a CanvasGroup
	local clip: GuiObject
	if tilt.Rotation ~= 0 then
		local cg = Instance.new("CanvasGroup")
		cg.Name = "Clip"
		cg.BackgroundTransparency = 1
		cg.ZIndex = 1
		cg.Parent = card
		Base.at(cg, 6, 6, w - 12, h - 12)
		Base.corner(cg, C.card - 6)
		clip = cg
	else
		clip = Base.box(card, "Clip", 6, 6, w - 12, h - 12, 1)
	end
	Pattern.attach(clip)
	local yy = 12
	if opts.ribbon then
		-- (words 18 tall: 14 px on a phone, Lead item 5)
		local rw = #opts.ribbon * 11 + 22
		local rib = Base.fill(card, "Ribbon", 10, 8, rw, 26, INK, 4)
		Base.corner(rib, 8)
		Base.text(rib, "Words", 3, 4, rw - 6, 18, opts.ribbon, { z = 5 })
		yy = 38
	end
	Base.text(card, "Name", 8, yy, w - 16, w * 0.12, opts.name or "CAR", { stroke = 5, z = 4 })
	yy += w * 0.12 + 4
	if opts.stars then
		local sw = 5 * 18 + 16
		-- (over the car, so the car's antenna never hides the stars)
		local band = Base.fill(card, "Stars", (w - sw) / 2, yy, sw, 20, INK, 7)
		band.BackgroundTransparency = 0.75
		Base.corner(band)
		for i = 1, 5 do
			Icons.star(
				band,
				8 + (i - 1) * 18,
				1,
				18,
				if i <= opts.stars then Base.color("go") else Color3.fromRGB(120, 140, 160),
				8
			)
		end
		yy += 42 -- room for the car's antenna ball above it
	else
		yy += 14 -- (the antenna ball sat on the name: "CHOCO SL●IDE", Studio live1)
	end
	local carH = w * 0.74 * 0.54
	local car = Icons.car(
		card,
		w * 0.13,
		yy,
		w * 0.74,
		carH,
		{ id = opts.carId, color = opts.color, kind = opts.kind, z = 5 }
	)
	Anim.bob(car, 2, 5)
	yy += carH + 4
	local word = UiTheme.RARITY[UiTheme.rarityId(rarity)].word
	if rarity == "golden" then
		word = "GOLDEN"
	end
	local cw = #word * 11 + 26
	local chip = Base.fill(card, "Rarity", (w - cw) / 2, yy, cw, 26, INK, 4)
	chip.BackgroundTransparency = 0.7
	Base.corner(chip)
	Base.outline(chip, UiTheme.OUTLINE.small)
	Base.text(chip, "Words", 4, 4, cw - 8, 18, word, { stroke = 3.5, z = 5 })
	yy += 34
	local content = Base.box(card, "Content", 10, yy, w - 20, math.max(10, h - yy - 10), 6)
	-- glow breathes (26 px to 48 px)
	for i, gf in glows do
		local g = ({ 26, 16, 8 })[i]
		local more = g * 0.85
		local size = gf.Size
		Anim.loop(gf, M.glow, {
			Size = size + UDim2.fromScale(more * 2 / w, more * 2 / h),
			Position = gf.Position - UDim2.fromScale(more / w, more / h),
		})
	end
	local function flip()
		Anim.flip(root)
	end
	return { root = root, card = card, content = content, flip = flip, contentY = yy }
end

-- ===== little things =====

-- A world sign ("+3 POWER/MIN"): white words with a blue-deep stroke, the number in its color.
function Kit.sign(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	value: string,
	word: string,
	colorName: string
): Frame
	local f = Base.box(parent, "Sign", x, y, w, h, 3)
	local vw = w * (#value / (#value + #word + 1))
	Base.text(f, "Value", 0, 0, vw, h, value, {
		color = Base.color(colorName),
		stroke = 5,
		strokeColor = Base.color("blueDeep"),
		align = "r",
	})
	Base.text(
		f,
		"Word",
		vw + 4,
		0,
		w - vw - 4,
		h,
		word,
		{ stroke = 5, strokeColor = Base.color("blueDeep"), align = "l" }
	)
	Anim.bob(f, 2.2, 4)
	return f
end

-- A number floating up from where it happened, then fading.
function Kit.floatNum(parent: Instance, x: number, y: number, words: string, colorName: string?)
	-- (wide enough for "2X TRAINING!" at the same size as "+1 SPEED")
	local w = math.max(120, #words * 15)
	local l = Base.text(
		parent,
		"Float",
		x - w / 2,
		y - 16,
		w,
		32,
		words,
		{ color = Base.color(colorName or "go"), stroke = 5, z = 9 }
	)
	local s = Anim.scaler(l)
	s.Scale = 0.8
	Anim.to(s, 0.3, { Scale = 1.1 }, Enum.EasingStyle.Back)
	Anim.to(
		l,
		1.6,
		{ Position = l.Position - UDim2.fromScale(0, 46 / Base.H) },
		Enum.EasingStyle.Quad
	)
	task.delay(1.1, function()
		Anim.to(l, 0.5, { TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			Anim.to(st, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.7, function()
		l:Destroy()
	end)
end

local CONFETTI = { "danger", "go", "lime", "blue", "pink", "boost" }

-- Confetti falling over a full-screen frame, forever (until the frame goes).
function Kit.confetti(parent: GuiObject, n: number)
	if Base.reduced() then
		return
	end
	local layer = Instance.new("Frame")
	layer.Name = "Confetti"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 1
	layer.Parent = parent
	for i = 1, n do
		local p = Instance.new("Frame")
		p.Name = "Bit"
		p.BackgroundColor3 = Base.color(CONFETTI[(i % #CONFETTI) + 1])
		p.BorderSizePixel = 0
		p.Size = UDim2.fromOffset((8 + (i % 3) * 3) * Base.k, (12 + (i % 4) * 2) * Base.k)
		p.ZIndex = 1
		p.Parent = layer
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = 1.5
		st.Parent = p
		local x = ((i * 0.618) % 1)
		local speed = 3 + (i % 5) * 0.4
		local start = (i * 0.37) % speed
		local spin = 360 + (i % 4) * 90
		Anim.tick(p, function(t)
			local f = ((t + start) % speed) / speed
			p.Position = UDim2.new(x, math.sin((t + i) * 2) * 10 * Base.k, -0.08 + f * 1.16, 0)
			p.Rotation = f * spin
		end)
	end
end

-- Rays spinning around (x, y) of parent (30 s a turn), in the rarity / celebration color.
function Kit.rays(
	parent: Instance,
	x: number,
	y: number,
	size: number,
	colorName: string,
	alpha: number?
): Frame
	local f = Base.box(parent, "Rays", x - size / 2, y - size / 2, size, size, 1)
	for i = 0, 17 do
		local r = Base.fill(
			f,
			"Ray",
			size / 2 - size * 0.045,
			0,
			size * 0.09,
			size,
			Base.color(colorName),
			1
		)
		r.Rotation = i * 10
		r.BackgroundTransparency = alpha or 0.6
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(0.65, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = r
	end
	Anim.spin(f, M.raysTurn)
	return f
end

-- A white 4-point sparkle that twinkles.
function Kit.sparkle(parent: Instance, x: number, y: number, s: number, phase: number?): TextLabel
	local l = Base.text(parent, "Sparkle", x, y, s, s, "✦", { z = 8 })
	if not Base.reduced() then
		local ph = phase or 0
		Anim.tick(l, function(t)
			l.TextTransparency = 0.375 + 0.375 * math.cos((t + ph) / 1.4 * 2 * math.pi)
		end)
	end
	return l
end

-- The dark scrim over the world (the shop), on a full-screen back layer.
function Kit.scrim(back: ScreenGui): Frame
	local f = Instance.new("Frame")
	f.Name = "Scrim"
	f.BackgroundColor3 = Base.color("scrim")
	f.BackgroundTransparency = 1 - UiTheme.SCRIM_ALPHA
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.Active = true
	f.Parent = back
	return f
end

-- A soft backdrop on a full-screen back layer, for screens that cover the game: "showroom"
-- (light sky with yellow rays), "reveal" (deep purple with rarity rays).
function Kit.backdrop(back: ScreenGui, kind: string, colorName: string?): Frame
	local f = Instance.new("Frame")
	f.Name = "Backdrop"
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Active = true
	f.Parent = back
	f:SetAttribute("DW", Base.W)
	f:SetAttribute("DH", Base.H)
	if kind == "reveal" then
		f.BackgroundColor3 = Base.color("purpleDark")
	else
		f.BackgroundColor3 = WHITE
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Base.color("sky300"), Base.color("sky100"))
		g.Parent = f
	end
	local rays = Kit.rays(
		f,
		Base.W / 2,
		Base.H / 2,
		900,
		colorName or "go",
		if kind == "reveal" then 0.15 else 0.65
	)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = rays
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.4, 1.4)
	if kind ~= "reveal" then
		local floor = Instance.new("Frame")
		floor.Name = "Floor"
		floor.BackgroundColor3 = Base.color("sky100")
		floor.BorderSizePixel = 0
		floor.Position = UDim2.fromScale(0, 0.78)
		floor.Size = UDim2.fromScale(1, 0.22)
		floor.ZIndex = 2
		floor.Parent = f
	end
	return f
end

return Kit
