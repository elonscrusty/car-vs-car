--!strict
local Harness = require("./harness")
local UiLayout = require("../src/shared/UiLayout")
local UiLayoutConfig = require("../src/shared/UiLayoutConfig")
local UiSize = require("../src/shared/UiSize")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("UiLayout")

-- Landscape screens: two phones, a laptop window, full HD. 568x320 is a small iPhone.
local SIZES = { { 640, 360 }, { 800, 360 }, { 568, 320 }, { 1280, 720 }, { 1920, 1080 } }

local function fightRects(w: number, h: number): { [string]: UiLayout.Rect }
	local out: { [string]: UiLayout.Rect } = {}
	for name, spec in UiLayout.fight(h) do
		out[name] = UiLayout.rect(spec, w, h)
	end
	return out
end

local function each(fn: (w: number, h: number) -> ())
	for _, s in SIZES do
		fn(s[1], s[2])
	end
end

test("fight pieces stay inside the screen", function()
	each(function(w, h)
		for name, r in fightRects(w, h) do
			truthy(UiLayout.inBounds(r, w, h), `{name} out of bounds at {w}x{h}`)
		end
	end)
end)

test("no two fight pieces overlap", function()
	each(function(w, h)
		local rects = fightRects(w, h)
		for a, ra in rects do
			for b, rb in rects do
				if a < b then
					eq(UiLayout.overlaps(ra, rb), false, `{a} overlaps {b} at {w}x{h}`)
				end
			end
		end
	end)
end)

test("nothing sits in the middle 40% of the screen", function()
	each(function(w, h)
		local zone = UiLayout.centerZone(w, h)
		for name, r in fightRects(w, h) do
			eq(UiLayout.overlaps(r, zone), false, `{name} in the middle at {w}x{h}`)
		end
	end)
end)

test("top row clears the 56 px top bar", function()
	each(function(w, h)
		local rects = fightRects(w, h)
		for _, name in { "vsBanner", "modeBanner" } do
			truthy(rects[name].y >= UiLayoutConfig.topInset, `{name} under the top bar at {w}x{h}`)
		end
	end)
	eq(UiLayoutConfig.topInset, 56)
end)

test("thumb pieces are at least 48 px, also while pressed", function()
	each(function(w, h)
		local rects = fightRects(w, h)
		for _, name in UiLayout.touchPieces do
			local r = rects[name]
			truthy(r.w * UiSize.PRESS_SCALE >= UiSize.MIN_TOUCH, `{name} too narrow at {w}x{h}`)
			truthy(r.h * UiSize.PRESS_SCALE >= UiSize.MIN_TOUCH, `{name} too short at {w}x{h}`)
		end
	end)
end)

test("joystick is bottom-left, buttons bottom-right (thumb zones)", function()
	each(function(w, h)
		local rects = fightRects(w, h)
		local lowY = h * UiLayoutConfig.thumbLowShare
		local sideX = w * UiLayoutConfig.thumbShare
		local j = rects.joystick
		truthy(j.x + j.w <= sideX and j.y >= lowY, `joystick outside its zone at {w}x{h}`)
		for _, name in { "boost", "ability" } do
			local r = rects[name]
			truthy(r.x >= w - sideX and r.y >= lowY, `{name} outside its zone at {w}x{h}`)
		end
	end)
end)

test("text pieces are tall enough for 14 px text", function()
	each(function(w, h)
		local rects = fightRects(w, h)
		for _, name in UiLayout.textPieces do
			truthy(rects[name].h >= UiLayout.minLabelHeight(), `{name} too short at {w}x{h}`)
		end
	end)
	eq(UiLayout.minLabelHeight(), 22)
end)

test("end screen pieces fit, do not overlap and are big enough", function()
	each(function(w, h)
		local specs = UiLayout.endScreen()
		local banner = UiLayout.rect(specs.banner, w, h)
		local rects: { [string]: UiLayout.Rect } = {
			head = UiLayout.inside(banner, UiLayoutConfig.endScreen.head),
			sub = UiLayout.inside(banner, UiLayoutConfig.endScreen.sub),
			rematch = UiLayout.rect(specs.rematch, w, h),
			invite = UiLayout.rect(specs.invite, w, h),
			lobby = UiLayout.rect(specs.lobby, w, h),
		}
		for name, r in rects do
			truthy(UiLayout.inBounds(r, w, h), `{name} out of bounds at {w}x{h}`)
		end
		for a, ra in rects do
			for b, rb in rects do
				if a < b then
					eq(UiLayout.overlaps(ra, rb), false, `{a} overlaps {b} at {w}x{h}`)
				end
			end
		end
		truthy(rects.sub.h >= UiLayout.minLabelHeight(), `sub line short at {w}x{h}`)
		for _, name in { "rematch", "invite", "lobby" } do
			truthy(rects[name].h >= UiSize.BUTTON_MIN, `{name} short at {w}x{h}`)
			truthy(rects[name].w >= UiSize.BUTTON_MIN, `{name} narrow at {w}x{h}`)
		end
	end)
end)

test("menu column wraps instead of running off the screen", function()
	for _, studio in { false, true } do
		each(function(w, h)
			for i = 0, 11 do
				local r = UiLayout.menuButton(i, h, studio)
				truthy(r.y + r.h <= h, `menu button {i} falls off at {w}x{h}`)
				truthy(r.h >= UiSize.BUTTON_MIN and r.w >= UiSize.BUTTON_MIN, "menu button small")
			end
			local a, b = UiLayout.menuButton(0, h, studio), UiLayout.menuButton(1, h, studio)
			eq(UiLayout.overlaps(a, b), false)
		end)
	end
end)

test("HudStyle edge matches the layout edge", function()
	eq(require("../src/shared/HudStyle").EDGE, UiLayoutConfig.edge)
end)

test("rect resolves anchors, shares, offsets and clamps", function()
	local specs = UiLayout.fight(360)
	local r = UiLayout.rect(specs.msg, 640, 360)
	eq(r.x + r.w / 2, 320)
	eq(r.w, 256)
	local tiny = UiLayout.rect(specs.msg, 200, 360)
	eq(tiny.w, UiLayoutConfig.lane.minW)
end)
