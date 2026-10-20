--!strict
local H = require("./harness")
local Bubble = require("../src/shared/BubbleLayout")

print("BubbleLayout")

local SCREENS: { Bubble.Size } = {
	{ w = 1200, h = 675 }, -- the menus' stage
	{ w = 844, h = 390 }, -- a phone held sideways
	{ w = 1920, h = 1080 },
	{ w = 640, h = 360 },
}
local BUBBLE: Bubble.Size = { w = 250, h = 64 }

-- The real bubble shrinks on a small screen (TutorialUi sizes it from the screen height).
local function bubbleFor(screen: Bubble.Size): Bubble.Size
	return { w = math.min(BUBBLE.w, screen.w * 0.29), h = math.min(BUBBLE.h, screen.h * 0.15) }
end

local function rectOf(p: Bubble.Placement, size: Bubble.Size): Bubble.Rect
	return { x = p.x, y = p.y, w = size.w, h = size.h }
end

H.test("a bubble always stays on the screen", function()
	for _, screen in SCREENS do
		for tx = 0, 10 do
			for ty = 0, 10 do
				local target: Bubble.Rect = {
					x = (screen.w - 80) * tx / 10,
					y = (screen.h - 60) * ty / 10,
					w = 80,
					h = 60,
				}
				local size = bubbleFor(screen)
				local p = Bubble.place(target, screen, size)
				local m = Bubble.margin
				H.truthy(p.x >= m - 1e-6 and p.y >= m - 1e-6, "inside left/top")
				H.truthy(p.x + size.w <= screen.w - m + 1e-6, "inside right")
				H.truthy(p.y + size.h <= screen.h - m + 1e-6, "inside bottom")
				H.truthy(p.tailX >= 0 and p.tailX <= size.w)
				H.truthy(p.tailY >= 0 and p.tailY <= size.h)
			end
		end
	end
end)

H.test("it never covers the button it talks about", function()
	for _, screen in SCREENS do
		for tx = 0, 10 do
			for ty = 0, 10 do
				local target: Bubble.Rect = {
					x = (screen.w - 80) * tx / 10,
					y = (screen.h - 60) * ty / 10,
					w = 80,
					h = 60,
				}
				local size = bubbleFor(screen)
				local p = Bubble.place(target, screen, size)
				H.eq(Bubble.overlap(rectOf(p, size), target), 0, "covers the button")
			end
		end
	end
end)

H.test("it keeps the middle of the screen clear when the button is at an edge", function()
	for _, screen in SCREENS do
		local center = Bubble.centerBox(screen)
		-- buttons on the left side, the right side and the bottom corners
		local targets: { Bubble.Rect } = {
			{ x = screen.w * 0.85, y = screen.h * 0.72, w = screen.w * 0.12, h = screen.h * 0.22 }, -- GAS
			{ x = screen.w * 0.03, y = screen.h * 0.6, w = screen.w * 0.2, h = screen.w * 0.2 }, -- stick
			{ x = screen.w - 90, y = 10, w = 80, h = 50 }, -- a top-right button
			{ x = 10, y = 10, w = 80, h = 50 },
		}
		for i, target in targets do
			local size = bubbleFor(screen)
			local p = Bubble.place(target, screen, size)
			H.eq(Bubble.overlap(rectOf(p, size), center), 0, `target {i} on {screen.w}x{screen.h}`)
		end
	end
end)

H.test(
	"a button on the right gets the bubble on its left, a button on the left on its right",
	function()
		local screen: Bubble.Size = { w = 1200, h = 675 }
		local gas: Bubble.Rect = { x = 1020, y = 500, w = 150, h = 150 }
		local p = Bubble.place(gas, screen, BUBBLE)
		H.eq(p.side, "left")
		H.truthy(p.x + BUBBLE.w <= gas.x)
		H.eq(p.tailX, BUBBLE.w)
		H.eq(p.pointsAt, gas)
		local stick: Bubble.Rect = { x = 30, y = 470, w = 190, h = 190 }
		p = Bubble.place(stick, screen, BUBBLE)
		H.eq(p.side, "right")
		H.truthy(p.x >= stick.x + stick.w)
		H.eq(p.tailX, 0)
	end
)

H.test("a button in the middle of the screen still gets a bubble that does not cover it", function()
	local screen: Bubble.Size = { w = 1200, h = 675 }
	local target: Bubble.Rect = { x = 560, y = 300, w = 80, h = 60 }
	local p = Bubble.place(target, screen, BUBBLE)
	H.eq(Bubble.overlap(rectOf(p, BUBBLE), target), 0)
end)

H.test("the pointer starts level with the button and stays on the bubble's edge", function()
	local screen: Bubble.Size = { w = 1200, h = 675 }
	local target: Bubble.Rect = { x = 1020, y = 560, w = 150, h = 90 }
	local p = Bubble.place(target, screen, BUBBLE)
	H.eq(p.side, "left")
	-- the bubble is pushed up from the target's level by the bottom margin: the tail follows the target
	local targetMidY = target.y + target.h / 2
	H.near(p.y + p.tailY, targetMidY, 1e-6)
end)

H.test("a bubble with no button stands at the top middle or the bottom middle", function()
	local screen: Bubble.Size = { w = 1200, h = 675 }
	local top = Bubble.top(screen, BUBBLE, 70)
	H.near(top.x, (screen.w - BUBBLE.w) / 2)
	H.eq(top.y, 70)
	H.eq(top.pointsAt, nil)
	H.eq(top.side, "top")
	local bottom = Bubble.bottom(screen, BUBBLE, 24)
	H.near(bottom.y, screen.h - BUBBLE.h - 24)
	H.eq(bottom.pointsAt, nil)
	-- too big for the screen: it still starts on the screen
	local huge = Bubble.top({ w = 200, h = 100 }, { w = 500, h = 300 }, 10)
	H.eq(huge.x, Bubble.margin)
	H.eq(huge.y, Bubble.margin)
	-- a top bubble stays out of the middle band of a phone screen
	local phone: Bubble.Size = { w = 844, h = 390 }
	local p = Bubble.top(phone, { w = 300, h = 56 }, 56)
	H.eq(Bubble.overlap(rectOf(p, { w = 300, h = 56 }), Bubble.centerBox(phone)), 0)
end)

H.test("overlap and centerBox", function()
	H.eq(Bubble.overlap({ x = 0, y = 0, w = 10, h = 10 }, { x = 5, y = 5, w = 10, h = 10 }), 25)
	H.eq(Bubble.overlap({ x = 0, y = 0, w = 10, h = 10 }, { x = 10, y = 0, w = 10, h = 10 }), 0)
	H.eq(Bubble.overlap({ x = 0, y = 0, w = 10, h = 10 }, { x = 20, y = 20, w = 5, h = 5 }), 0)
	local c = Bubble.centerBox({ w = 1000, h = 500 })
	H.eq(c.x, 300)
	H.eq(c.y, 150)
	H.eq(c.w, 400)
	H.eq(c.h, 200)
end)
