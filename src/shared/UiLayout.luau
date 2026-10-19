--!strict
-- Pure phone layout rules (no Roblox types, so Lune can test them). Every HUD piece is a `Spec`:
-- anchor + scale position + pixel offset + scale size clamped by min/max pixels. The client puts
-- the same numbers on a GuiObject (anchor, UDim2 scale/offset, UISizeConstraint), and the tests
-- resolve them to pixel rects for several screen sizes and check overlap, size and bounds.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("UiLayoutConfig")
local HudStyle = sibling("HudStyle")
local UiSize = sibling("UiSize")

local UiLayout = {}

export type Spec = {
	ax: number, -- anchor point
	ay: number,
	px: number, -- position, share of the screen
	py: number,
	ox: number, -- position, pixel offset
	oy: number,
	sw: number, -- size, share of the screen
	sh: number,
	minW: number,
	minH: number,
	maxW: number,
	maxH: number,
}

export type Rect = { x: number, y: number, w: number, h: number }

local function spec(s: { [string]: number }): Spec
	return {
		ax = s.ax or 0,
		ay = s.ay or 0,
		px = s.px or 0,
		py = s.py or 0,
		ox = s.ox or 0,
		oy = s.oy or 0,
		sw = s.sw or 0,
		sh = s.sh or 0,
		minW = s.minW or 0,
		minH = s.minH or 0,
		maxW = s.maxW or math.huge,
		maxH = s.maxH or math.huge,
	}
end

-- Pixel rectangle of a spec on a screen of width x height pixels.
function UiLayout.rect(s: Spec, width: number, height: number): Rect
	local w = math.clamp(s.sw * width, s.minW, math.max(s.minW, s.maxW))
	local h = math.clamp(s.sh * height, s.minH, math.max(s.minH, s.maxH))
	return {
		x = s.px * width + s.ox - s.ax * w,
		y = s.py * height + s.oy - s.ay * h,
		w = w,
		h = h,
	}
end

-- Rect of a piece placed inside another rect by shares {x, y, w, h}.
function UiLayout.inside(outer: Rect, frac: { number }): Rect
	return {
		x = outer.x + outer.w * frac[1],
		y = outer.y + outer.h * frac[2],
		w = outer.w * frac[3],
		h = outer.h * frac[4],
	}
end

-- The empty middle of the screen during a fight.
function UiLayout.centerZone(width: number, height: number): Rect
	local share = Config.centerShare
	return {
		x = width * (1 - share) / 2,
		y = height * (1 - share) / 2,
		w = width * share,
		h = height * share,
	}
end

function UiLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function UiLayout.inBounds(r: Rect, width: number, height: number): boolean
	return r.x >= 0 and r.y >= 0 and r.x + r.w <= width and r.y + r.h <= height
end

-- Smallest text label height that fits `minText` px text plus padding.
function UiLayout.minLabelHeight(): number
	return Config.minText + 2 * Config.textPad
end

export type Fight = { [string]: Spec }

-- Everything on screen during a fight, by name. Joystick and buttons are fixed pixel sizes taken
-- from HudStyle for this screen height.
function UiLayout.fight(height: number): Fight
	local top, lane = Config.topRow, Config.lane
	local rowTop = Config.topInset
	local half = Config.gap / 2
	local joy = HudStyle.joystickSize(height)
	local btn = HudStyle.buttonSize(height)
	local edge = Config.edge
	return {
		vsBanner = spec({
			ax = 1,
			px = 0.5,
			ox = -half,
			oy = rowTop,
			sw = top.vsShare,
			sh = top.heightShare,
			minW = top.vsMinW,
			maxW = top.vsMaxW,
			minH = top.minH,
			maxH = top.maxH,
		}),
		modeBanner = spec({
			px = 0.5,
			ox = half,
			oy = rowTop,
			sw = top.modeShare,
			sh = top.heightShare,
			minW = top.modeMinW,
			maxW = top.modeMaxW,
			minH = top.minH,
			maxH = top.maxH,
		}),
		msg = spec({
			ax = 0.5,
			px = 0.5,
			py = lane.msgY,
			sw = lane.widthShare,
			sh = lane.msgH,
			minW = lane.minW,
			maxW = lane.maxW,
			minH = lane.msgMinH,
			maxH = lane.msgMaxH,
		}),
		hint = spec({
			ax = 0.5,
			px = 0.5,
			py = lane.hintY,
			sw = lane.widthShare,
			sh = lane.hintH,
			minW = lane.minW,
			maxW = lane.maxW,
			minH = lane.hintMinH,
			maxH = lane.hintMaxH,
		}),
		-- LOBBY (leave the match): left edge, under the top row, clear of the middle and the joystick.
		leave = spec({
			ox = edge,
			oy = rowTop + top.maxH + Config.gap,
			minW = Config.leave.w,
			maxW = Config.leave.w,
			minH = Config.leave.h,
			maxH = Config.leave.h,
		}),
		powerBar = spec({
			ax = 0.5,
			px = 0.5,
			py = lane.powerY,
			sw = lane.widthShare,
			sh = lane.powerH,
			minW = lane.minW,
			maxW = lane.maxW,
			minH = lane.powerMinH,
			maxH = lane.powerMaxH,
		}),
		joystick = spec({
			ay = 1,
			ox = edge,
			py = 1,
			oy = -edge,
			minW = joy,
			maxW = joy,
			minH = joy,
			maxH = joy,
		}),
		-- Right to left: ability is the outer button, boost sits left of it.
		ability = spec({
			ax = 1,
			ay = 1,
			px = 1,
			py = 1,
			ox = -edge,
			oy = -edge,
			minW = btn,
			maxW = btn,
			minH = btn,
			maxH = btn,
		}),
		boost = spec({
			ax = 1,
			ay = 1,
			px = 1,
			py = 1,
			ox = -edge - btn - HudStyle.BUTTON_GAP,
			oy = -edge,
			minW = btn,
			maxW = btn,
			minH = btn,
			maxH = btn,
		}),
	}
end

-- Names of fight pieces a thumb presses (must be >= the touch minimum even while pressed).
UiLayout.touchPieces = { "joystick", "boost", "ability" }
-- Names of fight pieces that hold text (must fit the minimum text size).
UiLayout.textPieces = { "vsBanner", "modeBanner", "msg", "hint" }

function UiLayout.endScreen(): { [string]: Spec }
	local e = Config.endScreen
	return {
		banner = spec({
			ax = 0.5,
			px = 0.5,
			py = e.bannerY,
			sw = e.bannerW,
			sh = e.bannerH,
		}),
		rematch = spec({
			ax = 0.5,
			px = 0.5,
			py = e.rematchY,
			sw = e.rematchW,
			sh = e.rematchH,
			minW = e.rematchMinW,
			minH = UiSize.BUTTON_MIN,
			maxW = e.rematchMaxW,
		}),
		lobby = spec({
			ay = 1,
			ox = Config.edge,
			py = 1,
			oy = -Config.edge,
			minW = e.lobbyW,
			maxW = e.lobbyW,
			minH = e.lobbyH,
			maxH = e.lobbyH,
		}),
		invite = spec({
			ax = 0.5,
			px = 0.5,
			py = e.inviteY,
			sw = e.inviteW,
			sh = e.inviteH,
			minW = e.inviteMinW,
			minH = UiSize.BUTTON_MIN,
			maxW = e.inviteMaxW,
		}),
	}
end

-- Menu column: pixel height available, and how many buttons fit in one column.
function UiLayout.menuColumnHeight(screenHeight: number, studio: boolean): number
	local m = Config.menu
	local top = if studio then m.topStudio else m.top
	return math.max(m.buttonH, screenHeight - top - m.bottomMargin)
end

function UiLayout.menuRows(screenHeight: number, studio: boolean): number
	local m = Config.menu
	local h = UiLayout.menuColumnHeight(screenHeight, studio)
	return math.max(1, math.floor((h + m.gap) / (m.buttonH + m.gap)))
end

-- Pixel rect of the menu button at 0-based `index` (column-major, wraps to the next column).
function UiLayout.menuButton(index: number, screenHeight: number, studio: boolean): Rect
	local m = Config.menu
	local rows = UiLayout.menuRows(screenHeight, studio)
	local col, row = index // rows, index % rows
	local top = if studio then m.topStudio else m.top
	return {
		x = 8 + col * (m.buttonW + m.gap),
		y = top + row * (m.buttonH + m.gap),
		w = m.buttonW,
		h = m.buttonH,
	}
end

return UiLayout
