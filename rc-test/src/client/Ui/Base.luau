--!strict
-- Car VS Car screens (carter 10-27, CarVsCar_UI_Handoff.md): the ground every piece stands on.
--   * Each screen is a ScreenGui inside the phone's safe area (ScreenInsets = CoreUISafeInsets)
--     with a Canvas: the 756 x 390 design (844 x 390 phone minus 44 px each side).
--   * Pieces sit on the canvas by Scale (UiScreens numbers) with a UIAspectRatioConstraint, so
--     they keep their shape on every screen and shrink toward the corner they hold to.
--   * Inside a piece everything is Scale of that piece: each frame remembers its design size
--     (attributes DW, DH) and children are placed in those px.
--   * Outlines and word strokes are px, so they follow the screen size (k = screen / design).
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))

local Base = {}

Base.W = UiTheme.DESIGN.w
Base.H = UiTheme.DESIGN.h
Base.FONT = Enum.Font.FredokaOne

local colors: { [string]: Color3 } = {}
function Base.color(name: string): Color3
	local c = colors[name]
	if not c then
		c = Color3.fromRGB(UiTheme.rgb(name))
		colors[name] = c
	end
	return c
end
Base.WHITE = Color3.new(1, 1, 1)

-- ===== screen size: k = how many real px one design px is =====

Base.k = 1
local strokes: { [UIStroke]: number } = setmetatable({}, { __mode = "k" }) :: any
local onScale: { () -> () } = {}

local function setK(size: Vector2)
	if size.X < 10 or size.Y < 10 then
		return
	end
	local k = math.min(size.X / Base.W, size.Y / Base.H)
	if math.abs(k - Base.k) < 1e-3 then
		return
	end
	Base.k = k
	for s, px in strokes do
		if s.Parent then
			s.Thickness = px * k
		end
	end
	for _, fn in onScale do
		task.spawn(fn)
	end
end

-- fn runs whenever the screen size changes (things drawn in px)
function Base.onScale(fn: () -> ())
	table.insert(onScale, fn)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
Base.playerGui = playerGui

do
	-- a hidden probe in the same safe area as every screen, to know k
	local probe = Instance.new("ScreenGui")
	probe.Name = "UiProbe"
	probe.ResetOnSpawn = false
	probe.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	probe.Enabled = true
	local f = Instance.new("Frame")
	f.Name = "Size"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = probe
	probe.Parent = playerGui
	f:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		setK(f.AbsoluteSize)
	end)
	setK(f.AbsoluteSize)
end

-- ===== screens =====

export type Gui = { gui: ScreenGui, canvas: Frame, back: ScreenGui? }

-- A screen: its own ScreenGui (on or off as a whole) with the design canvas. `full` adds a second
-- ScreenGui under it that covers the whole screen, notch and top bar too (scrims, backdrops).
function Base.screen(name: string, order: number, full: boolean?): Gui
	local back: ScreenGui? = nil
	if full then
		local b = Instance.new("ScreenGui")
		b.Name = name .. "Back"
		b.ResetOnSpawn = false
		b.ScreenInsets = Enum.ScreenInsets.None
		b.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		b.DisplayOrder = order
		b.Enabled = false
		b.Parent = playerGui
		back = b
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order + 1
	gui.Enabled = false
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas:SetAttribute("DW", Base.W)
	canvas:SetAttribute("DH", Base.H)
	canvas.Parent = gui
	gui.Parent = playerGui
	return { gui = gui, canvas = canvas, back = back }
end

function Base.show(s: Gui, on: boolean)
	s.gui.Enabled = on
	if s.back then
		s.back.Enabled = on
	end
end

-- ScreenGui.DisplayOrder for each layer (two each: the back and the front)
Base.ORDER = { hud = 6, window = 22, popup = 26, celebrate = 30, loading = 40 }

-- ===== placing =====

local function designSize(obj: Instance): (number, number)
	local w, h = obj:GetAttribute("DW"), obj:GetAttribute("DH")
	if type(w) == "number" and type(h) == "number" then
		return w, h
	end
	return Base.W, Base.H
end
Base.designSize = designSize

-- Put a piece on the canvas where UiScreens says (Scale + aspect ratio).
function Base.place(obj: GuiObject, piece: UiScreens.Piece)
	local ax, ay = UiScreens.anchor(piece)
	obj.AnchorPoint = Vector2.new(ax, ay)
	obj.Position =
		UDim2.fromScale((piece.x + ax * piece.w) / Base.W, (piece.y + ay * piece.h) / Base.H)
	obj.Size = UDim2.fromScale(piece.w / Base.W, piece.h / Base.H)
	local ar = obj:FindFirstChild("Shape") :: UIAspectRatioConstraint?
	if not ar then
		local made = Instance.new("UIAspectRatioConstraint")
		made.Name = "Shape"
		made.Parent = obj
		ar = made
	end
	(ar :: UIAspectRatioConstraint).AspectRatio = piece.w / piece.h
	obj:SetAttribute("DW", piece.w)
	obj:SetAttribute("DH", piece.h)
end

-- Put obj at x, y, w, h px of its parent's design size (Scale).
function Base.at(obj: GuiObject, x: number, y: number, w: number, h: number, parent: Instance?)
	local pw, ph = designSize(parent or obj.Parent :: Instance)
	obj.Position = UDim2.fromScale(x / pw, y / ph)
	obj.Size = UDim2.fromScale(w / pw, h / ph)
	obj:SetAttribute("DW", w)
	obj:SetAttribute("DH", h)
end

-- Same, but the point (x, y) is where AnchorPoint (ax, ay) goes (for things that scale or spin
-- around their middle).
function Base.atAnchored(
	obj: GuiObject,
	x: number,
	y: number,
	w: number,
	h: number,
	ax: number,
	ay: number
)
	local pw, ph = designSize(obj.Parent :: Instance)
	obj.AnchorPoint = Vector2.new(ax, ay)
	obj.Position = UDim2.fromScale((x + ax * w) / pw, (y + ay * h) / ph)
	obj.Size = UDim2.fromScale(w / pw, h / ph)
	obj:SetAttribute("DW", w)
	obj:SetAttribute("DH", h)
end

-- A plain see-through frame at x, y, w, h of parent.
function Base.box(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	z: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	Base.at(f, x, y, w, h)
	return f
end

-- A filled frame.
function Base.fill(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	z: number?
): Frame
	local f = Base.box(parent, name, x, y, w, h, z)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	return f
end

-- Round corners of `px` design px (0.5 of the short side = fully round).
function Base.corner(obj: GuiObject, px: number?): UICorner
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	if px then
		local w, h = designSize(obj)
		c.CornerRadius = UDim.new(math.min(px / math.min(w, h), 0.5), 0)
	else
		c.CornerRadius = UDim.new(0.5, 0)
	end
	c.Parent = obj
	return c
end

-- An outline of `px` design px (it follows the screen size).
function Base.outline(
	obj: GuiObject,
	px: number,
	color: Color3?,
	mode: Enum.ApplyStrokeMode?
): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Color = color or Base.color("ink")
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Thickness = px * Base.k
	s.Parent = obj
	strokes[s] = px
	return s
end

-- Change a stroke made by outline() to a new design px.
function Base.restroke(s: UIStroke, px: number)
	strokes[s] = px
	s.Thickness = px * Base.k
end

-- ===== words =====

export type TextStyle = {
	color: Color3?,
	stroke: number?, -- CSS px of the ink stroke (the spec's numbers); nil = none
	strokeColor: Color3?,
	align: string?, -- "l", "c" (default), "r"
	drop: number?, -- px of a solid drop under the words
	dropColor: Color3?,
	z: number?,
}

-- Words filling x, y, w, h (TextScaled: the box height is the letter size). A stroke of the spec's
-- CSS px is half as thick as a UIStroke (CSS strokes sit half inside the letters).
function Base.text(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	words: string,
	style: TextStyle?
): TextLabel
	local st: TextStyle = style or {}
	local z = st.z or 3
	local function make(n: string): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = n
		l.BackgroundTransparency = 1
		l.Font = Base.FONT
		l.TextScaled = true
		l.Text = words
		l.TextWrapped = false
		l.TextXAlignment = if st.align == "l"
			then Enum.TextXAlignment.Left
			elseif st.align == "r" then Enum.TextXAlignment.Right
			else Enum.TextXAlignment.Center
		l.ZIndex = z
		l.Parent = parent
		Base.at(l, x, y, w, h)
		return l
	end
	if st.drop then
		local d = make(name .. "Drop")
		d.ZIndex = z - 1
		d.TextColor3 = st.dropColor or Base.color("ink")
		Base.at(d, x, y + st.drop, w, h)
		if st.stroke then
			Base.outline(
				d,
				st.stroke / 2,
				st.dropColor or Base.color("ink"),
				Enum.ApplyStrokeMode.Contextual
			)
		end
	end
	local l = make(name)
	l.TextColor3 = st.color or Base.WHITE
	if st.stroke then
		Base.outline(
			l,
			st.stroke / 2,
			st.strokeColor or Base.color("ink"),
			Enum.ApplyStrokeMode.Contextual
		)
	end
	return l
end

-- Change words on a label and its drop, if it has one.
function Base.setText(l: TextLabel, words: string)
	l.Text = words
	local d = l.Parent and l.Parent:FindFirstChild(l.Name .. "Drop")
	if d and d:IsA("TextLabel") then
		d.Text = words
	end
end

-- ===== the world blurs behind a window (spec 7); the shop darkens it instead =====

local blurs = 0
local blur: BlurEffect? = nil
function Base.blur(on: boolean)
	blurs = math.max(0, blurs + (if on then 1 else -1))
	if blurs > 0 and not blur then
		local b = Instance.new("BlurEffect")
		b.Name = "UiBlur"
		b.Size = 12
		b.Parent = Lighting
		blur = b
	elseif blurs == 0 and blur then
		blur:Destroy()
		blur = nil
	end
end

-- ===== reduced motion =====

-- On when the device asks for less motion (the settings screen can turn it on too).
Base.forceReduced = false
function Base.reduced(): boolean
	local ok, on = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return Base.forceReduced or (ok and on == true)
end

return Base
