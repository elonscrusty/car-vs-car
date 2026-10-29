--!nocheck
-- Where each piece of a screen lands on a real phone, from the instances the client's UI code
-- built in the pretend game (fakeroblox S.client): Position / Size (scale + offset), AnchorPoint,
-- UIAspectRatioConstraint (fit inside), UISizeConstraint and UIScale, inside the safe area the
-- screen's ScreenGui sits in. Nothing here is shipped; tests/phone_layout.test.luau uses it.

local L = {}

export type Box = {
	obj: any,
	path: string,
	class: string,
	x: number,
	y: number,
	w: number,
	h: number,
	depth: number,
	clip: { number }?,
}

local function p(inst: any): any
	return (getmetatable(inst) :: any).p
end

local function childOf(inst: any, class: string): any?
	for _, c in p(inst)._children do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end

local GUI = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	CanvasGroup = true,
	ViewportFrame = true,
	TextBox = true,
}
L.GUI = GUI

local function place(inst: any, px: number, py: number, pw: number, ph: number)
	local size = inst.Size
	local pos = rawget(p(inst), "_position")
	if typeof(size) ~= "UDim2" then
		size = nil
	end
	if typeof(pos) ~= "UDim2" then
		pos = nil
	end
	local w = if size then pw * size.X.Scale + size.X.Offset else pw
	local h = if size then ph * size.Y.Scale + size.Y.Offset else ph
	local ar = childOf(inst, "UIAspectRatioConstraint")
	if ar then
		local r = ar.AspectRatio or 1
		if w / math.max(h, 1e-6) > r then
			w = h * r
		else
			h = w / r
		end
	end
	local sc = childOf(inst, "UISizeConstraint")
	if sc then
		local mn, mx = sc.MinSize, sc.MaxSize
		if mx then
			w, h = math.min(w, mx.X), math.min(h, mx.Y)
		end
		if mn then
			w, h = math.max(w, mn.X), math.max(h, mn.Y)
		end
	end
	local us = childOf(inst, "UIScale")
	-- (a "Pop" UIScale is Anim's entrance, which always settles at 1)
	if us and us.Scale and us.Name ~= "Pop" then
		w, h = w * us.Scale, h * us.Scale
	end
	local ax = if inst.AnchorPoint then inst.AnchorPoint.X else 0
	local ay = if inst.AnchorPoint then inst.AnchorPoint.Y else 0
	local x = px + (if pos then pw * pos.X.Scale + pos.X.Offset else 0) - ax * w
	local y = py + (if pos then ph * pos.Y.Scale + pos.Y.Offset else 0) - ay * h
	return x, y, w, h
end

-- Every visible GUI object under a ScreenGui that fills the rect (sx, sy, sw, sh) on screen.
function L.boxes(gui: any, sx: number, sy: number, sw: number, sh: number): { Box }
	local out: { Box } = {}
	local function walk(inst: any, px, py, pw, ph, path: string, depth: number, clip: { number }?)
		for _, c in p(inst)._children do
			if GUI[c.ClassName] and c.Visible ~= false then
				local x, y, w, h = place(c, px, py, pw, ph)
				local here = path .. "." .. c.Name
				-- inside a clipping parent, only what shows counts
				local hidden = clip ~= nil
					and (
						x >= clip[1] + clip[3]
						or y >= clip[2] + clip[4]
						or x + w <= clip[1]
						or y + h <= clip[2]
					)
				if not hidden then
					table.insert(out, {
						obj = c,
						path = here,
						class = c.ClassName,
						x = x,
						y = y,
						w = w,
						h = h,
						depth = depth,
						clip = clip,
					})
					local inner = clip
					if c.ClipsDescendants == true then
						inner = { x, y, w, h }
					end
					walk(c, x, y, w, h, here, depth + 1, inner)
				end
			end
		end
	end
	walk(gui, sx, sy, sw, sh, gui.Name, 0, nil)
	return out
end

-- The letter height TextScaled gives: the box height, or less when the words are too wide for
-- it (Fredoka One capitals are about 0.6 of their height wide).
function L.letters(b: Box): number
	local t = b.obj.Text
	if type(t) ~= "string" or t == "" then
		return math.huge
	end
	local n = math.max(utf8.len(t) or #t, 1)
	local wide = b.w / (0.6 * n)
	local tall = b.h
	if b.obj.TextWrapped == true then
		-- lines of 0.6 s wide letters, each line s tall: the biggest s that fits
		local s = math.min(b.h, math.sqrt(b.w * b.h / (0.6 * n)))
		while s > 1 and math.ceil(n * 0.6 * s / b.w) * s > b.h do
			s -= 0.5
		end
		wide = s
	end
	local cap = b.obj.TextSize -- (TextScaled caps at 100)
	return math.min(tall, wide, 100, if b.obj.TextScaled then 100 else (cap or 100))
end

function L.shows(b: Box): boolean
	local o = b.obj
	if o.ClassName == "TextLabel" or o.ClassName == "TextButton" or o.ClassName == "TextBox" then
		return (o.TextTransparency or 0) < 1
	end
	return true
end

-- Phone screens: the safe area a CoreUISafeInsets ScreenGui fills (the top bar, and the notch
-- and home bar on a newer phone).
L.PHONES = {
	{ name = "667x375", w = 667, h = 375, safe = { 0, 58, 667, 375 - 58 } },
	{ name = "844x390", w = 844, h = 390, safe = { 47, 58, 844 - 94, 390 - 58 - 21 } },
	-- a tall phone (iPhone Pro Max on its side): the island each side and the home bar
	{ name = "932x430", w = 932, h = 430, safe = { 59, 58, 932 - 118, 430 - 58 - 21 } },
}

return L
