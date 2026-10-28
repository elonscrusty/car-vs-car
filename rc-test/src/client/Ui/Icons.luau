--!strict
-- Car VS Car screens: icons and car pictures. An uploaded picture (Images) wins; until there is
-- one, each is drawn from glossy rounded frames with the house ink outline (coin, gem, trophy,
-- bag, gift, crates, lock, check, league shields, the stat glyphs, and a stand-in toy car).
-- Every drawing works in 0..100 units of its own box, so it scales with the box.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Base = require(script.Parent:WaitForChild("Base"))
local Images = require(script.Parent:WaitForChild("Images"))

local Icons = {}

local INK = Base.color("ink")
local WHITE = Base.WHITE

-- A box whose children are drawn in 0..ux by 0..uy units (default 100 x 100).
local function canvas(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	ux: number?,
	uy: number?
): Frame
	local f = Base.box(parent, name, x, y, w, h)
	local ax, ay = ux or 100, uy or 100
	if math.abs(w / h - ax / ay) > 0.01 then
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = ax / ay
		ar.Parent = f
		-- (it shrinks inside the box: keep it in the middle)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = f.Position + UDim2.fromScale(f.Size.X.Scale / 2, f.Size.Y.Scale / 2)
	end
	f:SetAttribute("DW", ax)
	f:SetAttribute("DH", ay)
	f:SetAttribute("Real", math.min(w / ax, h / ay)) -- design px per unit
	return f
end

local function unit(f: Instance): number
	local r = f:GetAttribute("Real")
	return if type(r) == "number" then r else 1
end

-- A filled shape with an ink outline drawn as an ink copy behind it (so shapes that overlap
-- read as one outline). radius in units (nil = round). Returns the fill.
local function shape(
	c: Frame,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	radius: number?,
	ol: number?,
	rot: number?,
	z: number?
): Frame
	local o = (ol or 6) / 2 -- the outline, in units, each side
	local zz = z or 1
	local ink = Base.fill(c, name .. "Ink", x - o, y - o, w + 2 * o, h + 2 * o, INK, zz)
	local fill = Base.fill(c, name, x, y, w, h, color, zz + 1)
	if radius then
		Base.corner(ink, radius + o)
		Base.corner(fill, radius)
	else
		Base.corner(ink)
		Base.corner(fill)
	end
	if rot then
		ink.Rotation = rot
		fill.Rotation = rot
	end
	return fill
end

-- the glossy top: light at the top, the color at the middle
local function gloss(f: GuiObject, color: Color3, amount: number?)
	f.BackgroundColor3 = WHITE
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, amount or 0.45)),
		ColorSequenceKeypoint.new(0.55, color),
		ColorSequenceKeypoint.new(1, color:Lerp(INK, 0.18)),
	})
	g.Parent = f
end

local function shineSpot(c: Frame, x: number, y: number, w: number, h: number, z: number)
	local s = Base.fill(c, "Shine", x, y, w, h, WHITE, z)
	s.BackgroundTransparency = 0.35
	Base.corner(s)
end

local function picture(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	s: number,
	id: string
): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Image = id
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = parent
	Base.at(img, x, y, s, s)
	return img
end

local function star(
	c: Frame,
	x: number,
	y: number,
	s: number,
	color: Color3?,
	z: number?
): TextLabel
	return Base.text(c, "Star", x, y, s, s, "★", {
		color = color or WHITE,
		stroke = s * 0.16 * unit(c),
		z = z or 5,
	})
end
Icons.star = star

-- ===== the icons =====

local DRAW: { [string]: (c: Frame, opts: { [string]: any }) -> () } = {}

DRAW.coin = function(c)
	local go = Base.color("go")
	local body = shape(c, "Body", 8, 8, 84, 84, go, nil, 8)
	gloss(body, go, 0.5)
	local ring = Base.box(c, "Ring", 22, 22, 56, 56, 4)
	Base.corner(ring)
	Base.outline(ring, 5 * unit(c), Base.color("goDeep"))
	shineSpot(c, 24, 18, 22, 12, 5)
end

DRAW.gem = function(c)
	local cyan = Color3.fromRGB(127, 227, 255)
	local body = shape(c, "Body", 21, 21, 58, 58, cyan, 8, 8, 45)
	gloss(body, cyan, 0.5)
	shineSpot(c, 34, 22, 18, 10, 5)
end

DRAW.trophy = function(c)
	local gold = Base.color("leagueGold")
	shape(c, "HandleL", 6, 16, 26, 30, gold, nil, 7)
	shape(c, "HandleR", 68, 16, 26, 30, gold, nil, 7)
	local cup = shape(c, "Cup", 20, 8, 60, 52, gold, 20, 7, nil, 3)
	gloss(cup, gold, 0.5)
	shape(c, "Stem", 42, 56, 16, 16, Base.color("goDeep"), 3, 6, nil, 3)
	local base = shape(c, "Foot", 24, 72, 52, 18, Base.color("goDeep"), 5, 7, nil, 3)
	gloss(base, Base.color("goDeep"), 0.3)
	star(c, 36, 18, 28, WHITE, 6)
end

DRAW.bag = function(c)
	local pink = Base.color("pink")
	local handle = Base.box(c, "Handle", 30, 6, 40, 44, 1)
	Base.corner(handle)
	Base.outline(handle, 7 * unit(c), INK)
	local body = shape(c, "Body", 14, 30, 72, 62, pink, 14, 7, nil, 2)
	gloss(body, pink, 0.45)
	shineSpot(c, 22, 36, 20, 10, 5)
end

DRAW.gift = function(c)
	local red, go = Base.color("danger"), Base.color("go")
	shape(c, "BowL", 26, 6, 24, 22, go, nil, 6)
	shape(c, "BowR", 50, 6, 24, 22, go, nil, 6)
	local box = shape(c, "Box", 14, 40, 72, 52, red, 8, 7, nil, 3)
	gloss(box, red, 0.35)
	local lid = shape(c, "Lid", 8, 26, 84, 20, red, 6, 7, nil, 3)
	gloss(lid, red, 0.45)
	Base.fill(c, "RibbonV", 43, 26, 14, 66, go, 6)
	Base.fill(c, "RibbonH", 14, 58, 72, 10, go, 6)
end

DRAW.lock = function(c)
	local hoop = Base.box(c, "Hoop", 28, 6, 44, 50, 1)
	Base.corner(hoop)
	Base.outline(hoop, 9 * unit(c), Base.color("inkMuted"))
	local body = shape(c, "Body", 16, 40, 68, 54, Base.color("leagueGold"), 12, 7, nil, 2)
	gloss(body, Base.color("leagueGold"), 0.45)
	local hole = Base.fill(c, "Hole", 44, 56, 12, 20, INK, 5)
	Base.corner(hole, 6)
end

DRAW.check = function(c)
	local lime = Base.color("lime")
	local disc = shape(c, "Disc", 6, 6, 88, 88, lime, nil, 8)
	gloss(disc, lime, 0.35)
	local a = Base.fill(c, "A", 18, 50, 34, 14, WHITE, 5)
	a.Rotation = 45
	Base.corner(a)
	local b = Base.fill(c, "B", 34, 40, 52, 14, WHITE, 5)
	b.Rotation = -50
	Base.corner(b)
end

local function crate(c: Frame, opts: { [string]: any })
	local r = UiTheme.rarityId(opts.rarity)
	local col = Base.color(UiTheme.RARITY[r].color)
	local box = shape(c, "Box", 10, 30, 80, 62, col, 10, 7, nil, 2)
	gloss(box, col, 0.4)
	Base.fill(c, "Plank", 10, 56, 80, 8, col:Lerp(INK, 0.3), 4)
	Base.fill(c, "Band", 43, 30, 14, 62, col:Lerp(INK, 0.35), 4)
	if opts.open then
		local lid = shape(c, "Lid", 4, 6, 88, 22, col, 8, 7, -16, 5)
		gloss(lid, col, 0.5)
		star(c, 34, 8, 32, Base.color("go"), 8)
	else
		local lid = shape(c, "Lid", 6, 18, 88, 22, col, 8, 7, nil, 5)
		gloss(lid, col, 0.5)
		Base.fill(c, "Lock", 42, 30, 16, 14, Base.color("go"), 8)
	end
end
DRAW.crate = crate

-- The three stat glyphs (white with ink), for the stat icon squares.
DRAW.power = function(c)
	shape(c, "A", 34, 8, 22, 50, WHITE, 3, 7, 22, 2)
	shape(c, "B", 44, 42, 22, 50, WHITE, 3, 7, 22, 2)
	local mid = Base.fill(c, "Mid", 30, 44, 40, 14, WHITE, 6)
	mid.Rotation = -10
end

DRAW.air = function(c)
	-- a ramp: a right triangle (a square turned 45 deg, cut in half by its box)
	local clip = Base.box(c, "Clip", 6, 20, 88, 70, 1)
	clip.ClipsDescendants = true
	local sq = Base.fill(clip, "Ramp", 44, 44, 110, 110, WHITE, 2)
	sq.Rotation = 33
	Base.outline(sq, 6 * unit(c), INK)
	local floor = Base.fill(c, "Floor", 6, 84, 88, 8, INK, 3)
	Base.corner(floor)
end

DRAW.speed = function(c)
	for i, y in { 18, 44, 70 } do
		local line = Base.fill(
			c,
			"Line" .. i,
			if i == 2 then 4 else 14,
			y,
			if i == 2 then 54 else 44,
			10,
			INK,
			2
		)
		Base.corner(line)
	end
	shape(c, "Head", 52, 28, 34, 34, WHITE, 6, 7, 45, 3)
end

DRAW.arrow = function(c)
	local lime = Base.color("lime")
	shape(c, "Head", 44, 22, 46, 46, lime, 6, 8, 45, 1)
	shape(c, "Shaft", 4, 32, 60, 30, lime, 6, 8, nil, 3)
end

DRAW.plus = function(c)
	local lime = Base.color("lime")
	local disc = shape(c, "Disc", 6, 6, 88, 88, lime, nil, 8)
	gloss(disc, lime, 0.35)
	Base.text(c, "Plus", 10, 4, 80, 84, "+", { stroke = 14 * unit(c), z = 5 })
end

-- Draw icon `name` in x, y, s x s of parent. opts: rarity / open (crates).
function Icons.make(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	s: number,
	opts: { [string]: any }?
): GuiObject
	local o: { [string]: any } = opts or {}
	local key = name
	if name == "crate" then
		key = "crate-" .. UiTheme.rarityId(o.rarity) .. (if o.open then "-open" else "")
	end
	local id = Images.icon(key)
	if id ~= "" then
		local img = picture(parent, "Icon", x, y, s, id)
		img.ZIndex = o.z or 3
		return img
	end
	local c = canvas(parent, "Icon", x, y, s, s)
	c.ZIndex = o.z or 3
	local draw = DRAW[name]
	if draw then
		draw(c, o)
	end
	return c
end

-- ===== league shields: metal shield, emblem (1, 2, 3 stars or a gem), wings for gold and
-- diamond, and a ribbon with the name =====

local METAL = {
	bronze = { "ffd1a6", "d68a4c", "9a5320" },
	silver = { "ffffff", "c3cddc", "7f8ea6" },
	gold = { "fff3a6", "ffc22e", "d98a00" },
	diamond = { "e6fdff", "5ee0f0", "1aa3c9" },
}
local function hex(s: string): Color3
	return Color3.fromRGB(
		tonumber(s:sub(1, 2), 16) :: number,
		tonumber(s:sub(3, 4), 16) :: number,
		tonumber(s:sub(5, 6), 16) :: number
	)
end

function Icons.badge(
	parent: Instance,
	league: number,
	x: number,
	y: number,
	s: number,
	showName: boolean?
): GuiObject
	local L = UiTheme.LEAGUES[math.clamp(league, 1, 4)]
	local h = if showName == false then s else s * 1.2
	local id = Images.icon("badge-" .. L.id)
	local root = canvas(parent, "Badge", x, y, s, h, 100, if showName == false then 100 else 120)
	if id ~= "" then
		picture(root, "Picture", 0, 0, 100, id)
	else
		local m = METAL[L.id]
		local mid = hex(m[2])
		if L.wings then
			shape(root, "WingL", -6, 26, 30, 44, WHITE, nil, 7, -24, 1)
			shape(root, "WingR", 76, 26, 30, 44, WHITE, nil, 7, 24, 1)
		end
		local top = shape(root, "Top", 16, 8, 68, 54, mid, 12, 8, nil, 3)
		local tip = shape(root, "Tip", 25, 36, 50, 50, mid, 10, 8, 45, 3)
		-- (the tip's ink copy would show over the top: lift the fills over both inks)
		-- the top covers the tip where they meet; light to mid on the top, mid to dark on the tip
		-- (the tip is turned 45 deg, so its shading turns back 45 to run the same way)
		top.ZIndex, tip.ZIndex = 5, 4
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(hex(m[1]), mid)
		top.BackgroundColor3 = WHITE
		g.Parent = top
		local g2 = Instance.new("UIGradient")
		g2.Rotation = 45
		g2.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, mid),
			ColorSequenceKeypoint.new(0.5, mid),
			ColorSequenceKeypoint.new(1, hex(m[3])),
		})
		g2.Parent = tip
		tip.BackgroundColor3 = WHITE
		if L.id == "diamond" then
			shape(root, "Gem", 36, 26, 28, 28, WHITE, 4, 6, 45, 7)
		else
			local n = L.stars
			local xs: { number } = if n == 1
				then { 34 }
				elseif n == 2 then { 20, 48 }
				else { 12, 36, 60 }
			local sz = if n == 1 then 32 else 26
			for _, sx in xs do
				star(root, sx, 26, sz, WHITE, 8)
			end
		end
	end
	if showName ~= false then
		shape(root, "Ribbon", 2, 92, 96, 24, hex(METAL[L.id][2]), 4, 6, nil, 9)
		Base.text(root, "Name", 6, 94, 88, 20, L.word, { color = INK, z = 12 })
	end
	return root
end

-- ===== the stand-in toy car (until carter's pictures are in) =====

-- A car's spot: x, y, w, h of parent. `CarImage` holds carter's picture (Images.CARS) and the
-- drawing under it shows until that is filled. view: "side" (default) or "rear";
-- kind: "racer" | "truck" | "buggy" (only the drawing uses it).
function Icons.car(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	opts: { [string]: any }?
): Frame
	local o: { [string]: any } = opts or {}
	local spot = Base.box(parent, "CarSpot", x, y, w, h, o.z or 3)
	spot:SetAttribute("CarId", o.id or "")
	local img = Instance.new("ImageLabel")
	img.Name = "CarImage"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = Images.car(o.id, o.view)
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = 20
	img.Parent = spot
	if img.Image ~= "" then
		return spot
	end
	local color: Color3 = o.color or Base.color("lime")
	local lite = color:Lerp(WHITE, 0.35)
	local sky = Base.color("sky300")
	local navy = Base.color("navy")
	if o.view == "rear" then
		local c = canvas(spot, "Drawing", 0, 0, w, h, 100, 80)
		shape(c, "WheelL", 6, 44, 22, 32, navy, 6, 6, nil, 1)
		shape(c, "WheelR", 72, 44, 22, 32, navy, 6, 6, nil, 1)
		local body = shape(c, "Body", 12, 26, 76, 40, color, 12, 7, nil, 3)
		gloss(body, color, 0.4)
		local cab = shape(c, "Cab", 24, 8, 52, 24, lite, 10, 7, nil, 3)
		gloss(cab, lite, 0.3)
		local win = Base.fill(c, "Window", 30, 12, 40, 14, sky, 6)
		Base.corner(win, 5)
		local l1 = Base.fill(c, "LightL", 16, 36, 14, 8, Base.color("danger"), 6)
		Base.corner(l1, 3)
		local l2 = Base.fill(c, "LightR", 70, 36, 14, 8, Base.color("danger"), 6)
		Base.corner(l2, 3)
		return spot
	end
	local c = canvas(spot, "Drawing", 0, 0, w, h, 100, 64)
	local kind = o.kind or "racer"
	local wy = if kind == "truck" then 36 else 40
	local ws = if kind == "truck" then 26 else 22
	shape(c, "WheelB", 12, wy, ws, ws, navy, nil, 6, nil, 5)
	shape(c, "WheelF", 88 - ws, wy, ws, ws, navy, nil, 6, nil, 5)
	for i, wx in { 12, 88 - ws } do
		local hub = Base.fill(
			c,
			"Hub" .. i,
			wx + ws * 0.3,
			wy + ws * 0.3,
			ws * 0.4,
			ws * 0.4,
			Base.color("silver"),
			8
		)
		Base.corner(hub)
	end
	if kind == "truck" then
		local body = shape(c, "Body", 4, 20, 92, 24, color, 8, 7, nil, 1)
		gloss(body, color, 0.4)
		local cab = shape(c, "Cab", 52, 4, 36, 22, lite, 8, 7, nil, 1)
		gloss(cab, lite, 0.3)
		Base.corner(Base.fill(c, "Window", 58, 8, 22, 12, sky, 4), 4)
	elseif kind == "buggy" then
		local bar = Base.box(c, "Bar", 34, 6, 34, 30, 1)
		Base.corner(bar, 8)
		Base.outline(bar, 4 * unit(c), INK)
		local body = shape(c, "Body", 10, 28, 80, 18, color, 8, 7, nil, 2)
		gloss(body, color, 0.4)
		shape(c, "Seat", 40, 18, 22, 14, lite, 6, 6, nil, 2)
	else
		shape(c, "Wing", 2, 16, 18, 8, color, 3, 6, nil, 1)
		local body = shape(c, "Body", 4, 28, 92, 18, color, 9, 7, nil, 2)
		gloss(body, color, 0.4)
		local cab = shape(c, "Cab", 32, 14, 36, 18, lite, 8, 7, nil, 1)
		gloss(cab, lite, 0.3)
		Base.corner(Base.fill(c, "Window", 38, 17, 24, 10, sky, 4), 4)
	end
	-- the pink antenna ball
	Base.fill(c, "Antenna", 70, 0, 3, 16, INK, 0)
	shape(c, "Ball", 66, -6, 11, 11, Base.color("pink"), nil, 4, nil, 1)
	shineSpot(c, 14, if kind == "truck" then 22 else 30, 22, 5, 9)
	return spot
end

-- A car's drawn colour when no picture is in (from its game colour, else by rarity).
function Icons.carColor(rgb: { number }?, rarity: string?): Color3
	if rgb and #rgb >= 3 then
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	return Base.color(UiTheme.RARITY[UiTheme.rarityId(rarity)].color)
end

return Icons
