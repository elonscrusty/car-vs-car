--!strict
-- Style A, "Kart Party" (KartStyle), on every screen at once: one place for all of them, so a new
-- screen gets it too (like Tap and Readable).
--   * all words in the round kart font; light words get a dark ink outline
--   * the dark grey boxes turn kart blue, with soft diagonal stripes on the big ones
--   * buttons turn glossy: a shine on top, a darker lip at the bottom, an ink rim, and a shine
--     that sweeps across now and then
--   * a piece that comes on screen pops in with a little overshoot; a popup's buttons and cards
--     drop in one after another; a button marked KartPulse = true breathes a glow
-- Only ScreenGuis: the 3D signs (BillboardGui / SurfaceGui) are styled where they are made.
-- Opt out with the attribute NoKart = true on a piece (and everything inside it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local KartStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartStyle"))

local FONT = Font.fromEnum(KartStyle.FONT)
local POP = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CARD = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- across in 0.9 s, then a rest; each button starts at its own moment so they don't all flash at once
local SWEEP = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.6)
local BREATHE = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local done: { [Instance]: boolean } = {}

-- (made here; never styled themselves)
local function ours(d: Instance): boolean
	return string.sub(d.Name, 1, 5) == "Kart_"
end

-- Roblox's own screens in PlayerGui (the phone thumbstick and jump button): left as they are
local NOT_OURS: { [string]: boolean } = { TouchGui = true, Freecam = true, BubbleChat = true }

local function screenOf(d: Instance): ScreenGui?
	local p = d.Parent
	while p do
		if p:IsA("ScreenGui") then
			return if NOT_OURS[p.Name] then nil else p
		elseif p:IsA("LayerCollector") then
			return nil -- a BillboardGui / SurfaceGui
		end
		if p:GetAttribute("NoKart") == true then
			return nil
		end
		p = p.Parent
	end
	return nil
end

-- dark grey / black, the old look's boxes
local function darkGrey(c: Color3): boolean
	local _, s, v = c:ToHSV()
	return v < 0.36 and s < 0.35
end

local function light(c: Color3): boolean
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B > 0.6
end

local function solid(g: GuiObject): boolean
	return g.BackgroundTransparency < 0.85
end

-- a picture inside (a car, a coin): gradients would tint it, and carter's cars keep their colours
local function hasPicture(g: GuiObject): boolean
	return (g:IsA("ImageLabel") or g:IsA("ImageButton")) and g.Image ~= ""
end

-- laid-out children (a list or a grid): an extra frame would take a slot
local function laidOut(g: Instance): boolean
	return g:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function cornerOf(g: GuiObject): UDim
	local c = g:FindFirstChildOfClass("UICorner")
	return if c then c.CornerRadius else UDim.new(0, 0)
end

-- one see-through frame over the whole box for all its overlays: it reaches back over the box's
-- own UIPadding (a chip's number sits padded right of its coin), so the shine covers it all
local function fx(g: GuiObject): Frame
	local have = g:FindFirstChild("Kart_Fx")
	if have and have:IsA("Frame") then
		return have
	end
	local f = Instance.new("Frame")
	f.Name = "Kart_Fx"
	f.Active = false
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	-- under the box's own children (its labels, its buttons), over its background and words
	local screen = screenOf(g)
	f.ZIndex = if screen and screen.ZIndexBehavior == Enum.ZIndexBehavior.Global
		then g.ZIndex
		else 0
	local function cover()
		local pad = g:FindFirstChildOfClass("UIPadding")
		if not pad then
			f.Position = UDim2.fromScale(0, 0)
			f.Size = UDim2.fromScale(1, 1)
			return
		end
		-- inside the padding, a child's scale counts from the padded size: undo that
		local l, r, t, b = pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom
		local kx = 1 - l.Scale - r.Scale
		local ky = 1 - t.Scale - b.Scale
		kx = if kx > 0.05 then kx else 1
		ky = if ky > 0.05 then ky else 1
		local ox, oy = l.Offset + r.Offset, t.Offset + b.Offset
		f.Size = UDim2.new(1 / kx, ox / kx, 1 / ky, oy / ky)
		f.Position = UDim2.new(
			-l.Scale / kx,
			-l.Offset - l.Scale * ox / kx,
			-t.Scale / ky,
			-t.Offset - t.Scale * oy / ky
		)
	end
	cover()
	local pad = g:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.Changed:Connect(cover)
	end
	f.Parent = g
	return f
end

local function overlay(g: GuiObject, name: string, corner: UDim): Frame
	local f = Instance.new("Frame")
	f.Name = "Kart_" .. name
	f.Active = false
	f.BorderSizePixel = 0
	f.BackgroundColor3 = KartStyle.WHITE
	f.Size = UDim2.fromScale(1, 1)
	local c = Instance.new("UICorner")
	c.CornerRadius = corner
	c.Parent = f
	local holder = fx(g)
	f.ZIndex = holder.ZIndex
	f.Parent = holder
	return f
end

-- keep an overlay as see-through as its box when the box fades in and out
local function follow(g: GuiObject, f: Frame, alpha: number)
	local function set()
		f.BackgroundTransparency = 1 - alpha * (1 - g.BackgroundTransparency)
	end
	g:GetPropertyChangedSignal("BackgroundTransparency"):Connect(set)
	set()
end

-- a darker lip along a button's bottom (or a soft shade down a panel), as an ink overlay: a
-- UIGradient on the box itself would colour a text button's words instead of its box
local function shade(g: GuiObject, lip: boolean)
	if laidOut(g) then
		return
	end
	local f = overlay(g, "Shade", cornerOf(g))
	f.BackgroundColor3 = KartStyle.INK
	follow(g, f, 1)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = if lip
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.95),
			NumberSequenceKeypoint.new(0.78, 0.86),
			NumberSequenceKeypoint.new(0.8, 0.6),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		else NumberSequence.new(1, 0.8)
	grad.Parent = f
end

-- an ink rim (or the box's own rim, turned ink)
local function rim(g: GuiObject, thick: number)
	local s = g:FindFirstChildOfClass("UIStroke")
	if s then
		-- (a rim switched off for now is a signal its script lights up: a green "ready" ring)
		if s.Enabled and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			s.Color = KartStyle.INK
			s.Thickness = math.max(s.Thickness, thick)
			s.Transparency = math.min(s.Transparency, 0.1)
		end
		return
	end
	s = Instance.new("UIStroke")
	s.Name = "Kart_Rim"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = KartStyle.INK
	s.Thickness = thick
	s.Parent = g
end

-- the shine band on a button's top half, and a bright streak that sweeps across
local function shine(b: GuiObject)
	if laidOut(b) then
		return
	end
	local corner = cornerOf(b)
	local band = overlay(b, "Band", corner)
	band.AnchorPoint = Vector2.new(0.5, 0)
	band.Position = UDim2.new(0.5, 0, 0, 3)
	band.Size = UDim2.new(1, -10, 0.38, 0)
	local fadeDown = Instance.new("UIGradient")
	fadeDown.Rotation = 90
	fadeDown.Transparency = NumberSequence.new(0.15, 1)
	fadeDown.Parent = band
	follow(b, band, 0.55)

	local streak = overlay(b, "Sweep", corner)
	follow(b, streak, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = streak
	task.delay(math.random() * 3, function()
		if g.Parent then
			TweenService:Create(g, SWEEP, { Offset = Vector2.new(1, 0) }):Play()
		end
	end)
end

-- soft diagonal stripes over a big panel (one gradient: up to 20 steps)
local function stripes(p: GuiObject)
	if laidOut(p) then
		return
	end
	local f = overlay(p, "Stripes", cornerOf(p))
	follow(p, f, 0.07)
	local keys = {}
	for i = 0, 18 do
		table.insert(keys, NumberSequenceKeypoint.new(i / 18, if i % 2 == 0 then 0 else 1))
	end
	local g = Instance.new("UIGradient")
	g.Rotation = -35
	g.Transparency = NumberSequence.new(keys)
	g.Parent = f
end

-- a glow that breathes (DRIVE, OK: the one thing to press)
local function breathe(b: GuiObject)
	if laidOut(b) or b:FindFirstChild("Kart_Glow") then
		return
	end
	local f = overlay(b, "Glow", cornerOf(b))
	f.BackgroundTransparency = 1
	TweenService:Create(f, BREATHE, { BackgroundTransparency = 0.78 }):Play()
end

local function styleText(t: TextLabel | TextButton | TextBox)
	t.FontFace = FONT
	-- the old fonts set later (a name turning bold) come back round
	t:GetPropertyChangedSignal("FontFace"):Connect(function()
		if t.FontFace.Family ~= FONT.Family then
			t.FontFace = FONT
		end
	end)
	if t:IsA("TextButton") then
		-- its UIStroke (if any) is the button's rim: the words use the plain text outline
		if light(t.TextColor3) and t.Text ~= "" then
			t.TextStrokeColor3 = KartStyle.INK
			t.TextStrokeTransparency = 0.2
		end
		return
	end
	if
		t:FindFirstChildOfClass("UIStroke")
		or not light(t.TextColor3)
		or t:GetAttribute("NoOutline") == true
	then
		return
	end
	local s = Instance.new("UIStroke")
	s.Name = "Kart_Ink"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = KartStyle.INK
	local function size()
		-- about one sixteenth of the line's height: fat on big words, thin on small ones
		local h = if t.TextScaled then t.AbsoluteSize.Y else t.TextSize
		s.Thickness = math.clamp(h / 16, 1, KartStyle.TEXT_RIM + 1)
	end
	t:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	size()
	-- the outline comes and goes with the words: a hidden toast's stroke drew its "Label"
	local function fade()
		s.Transparency = t.TextTransparency
	end
	t:GetPropertyChangedSignal("TextTransparency"):Connect(fade)
	fade()
	s.Parent = t
	t.TextStrokeTransparency = 1 -- (Readable's thin outline: the ink rim does it)
end

-- dark boxes turn kart blue, now and whenever their script sets the old dark again
local function blue(g: GuiObject)
	local function set()
		if darkGrey(g.BackgroundColor3) then
			g.BackgroundColor3 = KartStyle.BLUE
		end
	end
	g:GetPropertyChangedSignal("BackgroundColor3"):Connect(set)
	set()
	-- the old see-through dark reads as muddy blue: more solid
	if g.BackgroundTransparency > 0.05 and g.BackgroundTransparency <= 0.5 then
		g.BackgroundTransparency *= 0.3
	end
end

-- a piece on the screen itself (not inside another box): its parents up to the ScreenGui are
-- only see-through, full-screen holders (a StageGate holder, Stars' AfterFirstDrive)
local function topLevel(g: GuiObject): boolean
	local p = g.Parent
	while p and p:IsA("GuiObject") do
		if
			not (
				p:IsA("Frame")
				and p.BackgroundTransparency >= 1
				and p.Size == UDim2.fromScale(1, 1)
			)
		then
			return false
		end
		p = p.Parent
	end
	return p ~= nil and p:IsA("ScreenGui")
end

local function popScaleOf(g: GuiObject): UIScale?
	-- a button: Tap's squish scale (only one UIScale works on a piece; Tap gives way to any other)
	local tap = g:FindFirstChild("TapScale")
	if tap and tap:IsA("UIScale") then
		return tap
	end
	if g:IsA("GuiButton") or g:FindFirstChildOfClass("UIScale") then
		return nil -- a button not hooked by Tap, or a piece that scales itself
	end
	local s = Instance.new("UIScale")
	s.Name = "Kart_Pop"
	s.Parent = g
	return s
end

-- buttons and cards inside a popup land one after another, top left first
local function cascade(panel: GuiObject)
	local list = {}
	for _, d in panel:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible then
			local s = d:FindFirstChild("TapScale")
			if s and s:IsA("UIScale") then
				table.insert(list, { s = s, at = d.AbsolutePosition })
			end
		end
	end
	table.sort(list, function(a, b)
		if math.abs(a.at.Y - b.at.Y) > 8 then
			return a.at.Y < b.at.Y
		end
		return a.at.X < b.at.X
	end)
	for i, item in list do
		local s: UIScale = item.s
		s.Scale = 0
		task.delay(0.12 + math.min(i - 1, 14) * 0.035, function()
			TweenService:Create(s, CARD, { Scale = 1 }):Play()
		end)
	end
end

local function popper(g: GuiObject, screen: ScreenGui, popup: boolean)
	local hiddenAt = os.clock() - 1
	local function shown(): boolean
		local p = g.Parent
		local holderOn = not (p and p:IsA("GuiObject")) or (p :: GuiObject).Visible
		return g.Visible and holderOn and screen.Enabled
	end
	local was = shown()
	local function changed()
		local now = shown()
		if now == was then
			return
		end
		was = now
		if not now then
			hiddenAt = os.clock()
			return
		end
		-- (a piece that blinks off and on, a chip changing text, doesn't bounce every time)
		if os.clock() - hiddenAt < 0.25 then
			return
		end
		local s = popScaleOf(g)
		if not s then
			return
		end
		s.Scale = if popup then 0.55 else 0.4
		TweenService:Create(s, POP, { Scale = 1 }):Play()
		if popup then
			cascade(g)
		end
	end
	g:GetPropertyChangedSignal("Visible"):Connect(changed)
	local p = g.Parent
	if p and p:IsA("GuiObject") then
		p:GetPropertyChangedSignal("Visible"):Connect(changed) -- a StageGate holder opening
	end
	screen:GetPropertyChangedSignal("Enabled"):Connect(changed) -- (DRIVE turns its whole screen on)
end

local function style(d: Instance)
	if done[d] or not d:IsA("GuiObject") or ours(d) or d:GetAttribute("NoKart") == true then
		return
	end
	local screen = screenOf(d)
	if not screen then
		return
	end
	done[d] = true
	d.Destroying:Connect(function()
		done[d] = nil
	end)
	local g = d :: GuiObject
	if g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox") then
		styleText(g)
	end
	local popup = screen.DisplayOrder >= HudLayout.POPUP
	local top = topLevel(g)
	-- a whole-screen dim cover (tap outside, NEW CAR!'s back) stays a plain dim
	local cover = g:GetAttribute("NoTap") == true or (top and g.Size == UDim2.fromScale(1, 1))
	if solid(g) and not cover and not hasPicture(g) and not g:IsA("ScrollingFrame") then
		if g:IsA("GuiButton") then
			blue(g)
			shade(g, true)
			rim(g, KartStyle.BUTTON_RIM)
			shine(g)
		elseif top then
			-- a chip or a panel on the screen
			blue(g)
			shade(g, false)
			rim(g, if popup then KartStyle.PANEL_RIM else KartStyle.BUTTON_RIM)
			local size = g.AbsoluteSize
			if popup or (size.X > 260 and size.Y > 160) then
				stripes(g)
			end
		end
	end
	if g:GetAttribute("KartPulse") == true then
		breathe(g)
	end
	if top and not cover then
		popper(g, screen, popup)
	end
end

local pgui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, d in pgui:GetDescendants() do
	task.delay(0.1, style, d)
end
pgui.DescendantAdded:Connect(function(d: Instance)
	-- after its maker has set its colours, size and parent, and after Tap has hooked it
	task.delay(0.1, style, d)
end)
