--!strict
-- Pure look and size rules for the fight HUD (no Roblox types, so Lune can test it).

local HudStyle = {}

HudStyle.BUTTON_MIN, HudStyle.BUTTON_MAX = 64, 120 -- px, ability/boost side
HudStyle.JOY_MIN, HudStyle.JOY_MAX = 110, 220 -- px, joystick base
HudStyle.BUTTON_GAP = 10
HudStyle.EDGE = 16 -- px from the screen edge

local BUTTON_SHARE = 0.17 -- of the screen height
local JOY_SHARE = 0.36

local function clamp01(frac: number): number
	if frac ~= frac then
		return 0
	end
	return math.clamp(frac, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- HP bar colour as 0-255 r, g, b: green when full, yellow at half, red when nearly out.
function HudStyle.hpColor(frac: number): (number, number, number)
	local f = clamp01(frac)
	if f >= 0.5 then
		local t = (f - 0.5) * 2
		return math.floor(lerp(255, 80, t) + 0.5),
			math.floor(lerp(210, 220, t) + 0.5),
			math.floor(lerp(40, 90, t) + 0.5)
	end
	local t = f * 2
	return 255, math.floor(lerp(50, 210, t) + 0.5), math.floor(lerp(50, 40, t) + 0.5)
end

-- Share (0..1) of the bar track the fill covers.
function HudStyle.fillSize(frac: number): number
	return clamp01(frac)
end

function HudStyle.buttonSize(screenHeight: number): number
	return math.clamp(
		math.floor(screenHeight * BUTTON_SHARE),
		HudStyle.BUTTON_MIN,
		HudStyle.BUTTON_MAX
	)
end

function HudStyle.joystickSize(screenHeight: number): number
	return math.clamp(math.floor(screenHeight * JOY_SHARE), HudStyle.JOY_MIN, HudStyle.JOY_MAX)
end

-- Width of the two-button group (BOOST + ABILITY).
function HudStyle.buttonRowWidth(screenHeight: number): number
	return HudStyle.buttonSize(screenHeight) * 2 + HudStyle.BUTTON_GAP
end

return HudStyle
