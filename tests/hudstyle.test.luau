--!strict
local Harness = require("./harness")
local HudStyle = require("../src/shared/HudStyle")

local test, eq = Harness.test, Harness.eq

local function rgb(frac: number): string
	local r, g, b = HudStyle.hpColor(frac)
	return `{r},{g},{b}`
end

print("HudStyle")

test("hpColor endpoints are green, yellow and red", function()
	eq(rgb(1), "80,220,90")
	eq(rgb(0), "255,50,50")
	eq(rgb(0.5), "255,210,40")
end)

test("hpColor clamps out-of-range and NaN", function()
	eq(rgb(5), rgb(1))
	eq(rgb(-2), rgb(0))
	eq(rgb(0 / 0), rgb(0))
end)

test("hpColor gets redder as HP drops", function()
	local last = -math.huge
	for i = 20, 0, -1 do
		local r, g = HudStyle.hpColor(i / 20)
		local redness = r - g
		eq(redness >= last, true)
		last = redness
	end
end)

test("fillSize clamps", function()
	eq(HudStyle.fillSize(0.4), 0.4)
	eq(HudStyle.fillSize(-1), 0)
	eq(HudStyle.fillSize(3), 1)
	eq(HudStyle.fillSize(0 / 0), 0)
end)

test("button and joystick sizes clamp", function()
	eq(HudStyle.buttonSize(100), HudStyle.BUTTON_MIN)
	eq(HudStyle.buttonSize(5000), HudStyle.BUTTON_MAX)
	eq(HudStyle.buttonSize(360) >= 60, true)
	eq(HudStyle.joystickSize(100), HudStyle.JOY_MIN)
	eq(HudStyle.joystickSize(5000), HudStyle.JOY_MAX)
end)

test("two buttons fit beside the joystick on a 640x360 phone", function()
	local w, h = 640, 360
	local joyRight = HudStyle.EDGE + HudStyle.joystickSize(h)
	local rowLeft = w - HudStyle.EDGE - HudStyle.buttonRowWidth(h)
	eq(rowLeft > joyRight, true)
	eq(HudStyle.buttonSize(h) * 2 + HudStyle.BUTTON_GAP <= w / 2, true)
end)
