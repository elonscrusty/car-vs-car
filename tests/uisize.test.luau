--!strict
local Harness = require("./harness")
local UiSize = require("../src/shared/UiSize")

local test, eq = Harness.test, Harness.eq

print("UiSize")

test("touch minimum holds even while pressed", function()
	eq(UiSize.MIN_TOUCH, 48)
	eq(UiSize.BUTTON_MIN * UiSize.PRESS_SCALE >= 48, true)
	eq(UiSize.touchSide(20), 48)
	eq(UiSize.touchSide(90), 90)
end)

test("portrait phone stacks choice cards that fit the screen", function()
	local c = UiSize.choiceCards(360, 604, 3, 8, 64, 12, 520)
	eq(c.vertical, true)
	eq(c.width, 336)
	eq(c.height, 170)
	eq(c.height * 3 + 16 <= 604 - 64 - 12, true)
end)

test("landscape phone lines choice cards up in a row", function()
	local c = UiSize.choiceCards(800, 324, 3, 8, 64, 12, 260)
	eq(c.vertical, false)
	eq(c.width, 253)
	eq(c.height, 248)
	eq(c.width * 3 + 16 <= 800 - 24, true)
end)

test("cards never drop under the touch minimum", function()
	local c = UiSize.choiceCards(200, 100, 3, 8, 64, 12, 260)
	eq(c.height >= UiSize.BUTTON_MIN, true)
	local r = UiSize.choiceCards(100, 80, 3, 8, 64, 12, 260)
	eq(r.width >= UiSize.BUTTON_MIN and r.height >= UiSize.BUTTON_MIN, true)
end)

test("zero cars does not divide by zero", function()
	local c = UiSize.choiceCards(360, 640, 0, 8, 64, 12, 520)
	eq(c.height > 0, true)
end)
