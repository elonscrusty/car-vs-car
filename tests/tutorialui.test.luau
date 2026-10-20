--!nocheck
-- What the tutorial draws, run on the fake Roblox: the SKIP pill, the bubble that stands next to its
-- button (and never in the middle), the ring and the arrow, the green check with confetti and the
-- fade (carter's L11-L17).
local H = require("./harness")
local Mock = require("./robloxmock")
local Bubble = require("../src/shared/BubbleLayout")
local eq, near, truthy = H.eq, H.near, H.truthy
local V2 = Mock.V2

print("TutorialUi")

local SCREEN = { w = 1280, h = 720 } -- the fake ScreenGui size

local function setup()
	local world = Mock.new("./src")
	world.quiet = true
	local player = world.newLocalPlayer("Dana", 7)
	local env: any = { world = world, gui = player.PlayerGui, skips = 0 }
	local TutorialUi = world.requireClient("TutorialUi")
	env.ui = TutorialUi.new(function()
		env.skips += 1
	end)
	-- a screen with a button on it, like carter's menus: name, position and size in screen pixels
	function env.screen(
		screenName: string,
		buttons: { { name: string, x: number, y: number, w: number, h: number } },
		insetY: number?
	)
		local g = world.instance("ScreenGui")
		g.Name = screenName
		g.AbsolutePosition = V2.new(0, insetY or 0)
		g.Parent = env.gui
		for _, b in buttons do
			local btn = world.instance("TextButton")
			btn.Name = b.name
			btn.AbsolutePosition = V2.new(b.x, b.y + (insetY or 0))
			btn.AbsoluteSize = V2.new(b.w, b.h)
			btn.Parent = g
		end
		return g
	end
	function env.frames(n: number?)
		for _ = 1, n or 3 do
			world.step(0.05)
		end
	end
	function env.own()
		return env.gui:FindFirstChild("CVC_Tutorial")
	end
	function env.holder()
		return env.gui:FindFirstChild("TutorialBubbleHost", true)
	end
	-- the bubble's box in the pixels of the screen it stands in
	function env.bubbleRect(holder: any)
		local bubble = holder:FindFirstChild("Bubble")
		local at = bubble.Position
		return { x = at.X.Offset, y = at.Y.Offset, w = 260, h = 70 }, bubble
	end
	return env
end

local function view(id: string, text: string, anchor: string, extra: { [string]: any }?): any
	local v: any = { id = id, text = text, anchor = anchor, practice = false }
	for k, x in extra or {} do
		v[k] = x
	end
	return v
end

H.test("SKIP is on the screen at once, and it skips", function()
	local e = setup()
	local skip = e.own():FindFirstChild("Skip")
	truthy(skip, "a Skip button")
	truthy(skip.Visible)
	skip.Activated:Fire()
	eq(e.skips, 1)
	e.ui.setSkipShown(false)
	eq(skip.Visible, false)
	e.ui.setSkipShown(true)
	eq(skip.Visible, true)
end)

H.test("nothing is drawn before the first step", function()
	local e = setup()
	e.frames()
	eq(e.holder().Visible, false)
end)

H.test("the bubble stands inside the button's own screen, next to it, off the middle", function()
	local e = setup()
	local hud =
		e.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 200, h = 80 } })
	e.ui.setView(
		view(
			"play",
			"Click PLAY!",
			"Play",
			{ targets = { { find = "Play", text = "Click PLAY!" } } }
		)
	)
	e.frames()
	local holder = e.holder()
	truthy(holder.Parent == hud, "the bubble lives in the button's screen")
	truthy(holder.Visible)
	local rect, bubble = e.bubbleRect(holder)
	local button = { x = 1000, y = 600, w = 200, h = 80 }
	eq(Bubble.overlap(rect, button), 0, "never covers the button")
	eq(Bubble.overlap(rect, Bubble.centerBox(SCREEN)), 0, "the middle of the screen is clear")
	truthy(rect.x >= Bubble.margin and rect.x + rect.w <= SCREEN.w - Bubble.margin)
	truthy(rect.y >= Bubble.margin and rect.y + rect.h <= SCREEN.h - Bubble.margin)
	eq(bubble:FindFirstChild("Text").Text, "Click PLAY!")
	-- the ring is round the button, the arrow is shown
	local ring = holder:FindFirstChild("Ring")
	truthy(ring.Visible)
	local rx, ry = ring.Position.X.Offset, ring.Position.Y.Offset
	truthy(rx < 1000 and rx > 980, "the ring starts just left of the button: " .. rx)
	truthy(ry < 600 and ry > 580, "the ring starts just above the button: " .. ry)
	truthy(ring.Size.X.Offset > 200 and ring.Size.Y.Offset > 80)
	truthy(holder:FindFirstChild("Arrow").Visible)
end)

H.test("a screen with an inset (a top bar) gives the same place: the insets cancel", function()
	local plain = setup()
	plain.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 200, h = 80 } })
	local inset = setup()
	inset.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 200, h = 80 } }, 36)
	for _, e in { plain, inset } do
		e.ui.setView(
			view(
				"play",
				"Click PLAY!",
				"Play",
				{ targets = { { find = "Play", text = "Click PLAY!" } } }
			)
		)
		e.frames()
	end
	local a, b = plain.holder():FindFirstChild("Bubble"), inset.holder():FindFirstChild("Bubble")
	near(a.Position.X.Offset, b.Position.X.Offset, 0.001)
	near(a.Position.Y.Offset, b.Position.Y.Offset, 0.001)
end)

H.test(
	"no bubble until the screen with the button has opened, then the first button that shows wins",
	function()
		local e = setup()
		local pull = view("gumballPull", "unused", "top", {
			targets = {
				{ find = "ConfirmPurchase", text = "Tap again to spin!" },
				{ find = "PullClaw", text = "Tap here! Your first pull is FREE!" },
			},
		})
		e.ui.setView(pull)
		e.frames()
		eq(e.holder().Visible, false, "nothing to point at yet")
		-- the claw screen opens with only the pull button
		local claw = e.screen("CVC_Champions", {
			{ name = "PullClaw", x = 500, y = 560, w = 240, h = 90 },
			{ name = "ConfirmPurchase", x = 900, y = 560, w = 240, h = 90 },
		})
		local confirm = claw:FindFirstChild("ConfirmPurchase")
		confirm.Visible = false
		for _ = 1, 4 do
			e.world.step(0.2) -- the button is looked for again every 0.12 s
		end
		local holder = e.holder()
		truthy(holder.Visible)
		truthy(holder.Parent == claw)
		eq(
			holder:FindFirstChild("Bubble"):FindFirstChild("Text").Text,
			"Tap here! Your first pull is FREE!"
		)
		-- the confirm button appears (the price screen): its words replace the first ones
		confirm.Visible = true
		for _ = 1, 4 do
			e.world.step(0.2)
		end
		eq(holder:FindFirstChild("Bubble"):FindFirstChild("Text").Text, "Tap again to spin!")
		-- the whole screen closes: the bubble goes
		claw.Enabled = false
		for _ = 1, 4 do
			e.world.step(0.2)
		end
		eq(holder.Visible, false)
	end
)

H.test("a collapsed or hidden button does not count as on screen", function()
	local e = setup()
	local hud = e.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 0, h = 0 } })
	e.ui.setView(view("play", "Click PLAY!", "Play"))
	e.frames()
	-- no usable button: the words stand under SKIP instead
	local holder = e.holder()
	truthy(holder.Parent == e.own())
	local rect = e.bubbleRect(holder)
	truthy(rect.y < 120, "under SKIP: " .. rect.y)
	eq(holder:FindFirstChild("Ring").Visible, false)
	hud:FindFirstChild("Play").AbsoluteSize = V2.new(200, 80)
	hud:FindFirstChild("Play").Visible = false
	e.frames()
	eq(holder:FindFirstChild("Ring").Visible, false)
end)

H.test("a bubble with no button stands under SKIP; PC keys stand at the bottom", function()
	local e = setup()
	e.ui.setView(view("portal", "Walk into the blue portal!", "top"))
	e.frames()
	local holder = e.holder()
	truthy(holder.Visible)
	truthy(holder.Parent == e.own())
	local top = e.bubbleRect(holder)
	truthy(top.y >= 40 and top.y <= 120, "under SKIP: " .. top.y)
	eq(Bubble.overlap(top, Bubble.centerBox(SCREEN)), 0)
	e.ui.setView(view("gas", "Hold W to drive!", "keys", { practice = true }))
	e.frames()
	local keys = e.bubbleRect(holder)
	truthy(keys.y + keys.h <= SCREEN.h - 80, "above the bottom edge: " .. keys.y)
	truthy(keys.y > SCREEN.h * 0.6, "low on the screen: " .. keys.y)
	eq(Bubble.overlap(keys, Bubble.centerBox(SCREEN)), 0)
	eq(holder:FindFirstChild("Ring").Visible, false)
	eq(holder:FindFirstChild("Arrow").Visible, false)
end)

H.test("a practice control is found by its name (the GAS button, the stick)", function()
	local e = setup()
	local practice = e.screen(
		"TutorialPractice",
		{ { name = "PracticeGas", x = 1040, y = 520, w = 180, h = 170 } }
	)
	e.ui.setView(view("gas", "Hold GAS to drive!", "PracticeGas", { practice = true }))
	e.frames()
	local holder = e.holder()
	truthy(holder.Parent == practice)
	local rect = e.bubbleRect(holder)
	eq(Bubble.overlap(rect, { x = 1040, y = 520, w = 180, h = 170 }), 0)
	eq(Bubble.overlap(rect, Bubble.centerBox(SCREEN)), 0)
end)

H.test("a tiny screen draws nothing instead of a squashed bubble", function()
	local e = setup()
	e.ui.setView(view("portal", "Walk into the blue portal!", "top"))
	e.own().AbsoluteSize = V2.new(30, 30)
	e.frames()
	eq(e.holder().Visible, false)
end)

H.test("a finished step shows a green check and confetti, which go away", function()
	local e = setup()
	e.ui.setView(view("portal", "Walk into the blue portal!", "top"))
	e.frames()
	local holder = e.holder()
	e.ui.celebrate()
	local check = holder:FindFirstChild("Check")
	truthy(check.Visible, "the check")
	local confetti = 0
	for _, c in holder:GetChildren() do
		if c.Name == "Confetti" then
			confetti += 1
		end
	end
	eq(confetti, 18, "small confetti")
	e.world.step(1.5)
	eq(check.Visible, false, "the check goes after a moment")
end)

H.test("celebrating with no bubble on screen does nothing", function()
	local e = setup()
	e.ui.celebrate()
	eq(e.holder():FindFirstChild("Check").Visible, false)
end)

H.test("the black fade waits until it is over", function()
	local e = setup()
	local fade = e.own():FindFirstChild("Fade")
	local finished = false
	local co = coroutine.create(function()
		e.ui.fade(true, 0.3)
		finished = true
	end)
	assert(coroutine.resume(co))
	eq(finished, false)
	eq(fade.Visible, true)
	eq(fade.BackgroundTransparency, 0)
	e.world.step(0.35)
	eq(finished, true)
	finished = false
	co = coroutine.create(function()
		e.ui.fade(false, 0.4)
		finished = true
	end)
	assert(coroutine.resume(co))
	e.world.step(0.45)
	eq(finished, true)
	eq(fade.Visible, false, "clear again")
end)

H.test("a view without a bubble clears everything", function()
	local e = setup()
	e.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 200, h = 80 } })
	e.ui.setView(view("play", "Click PLAY!", "Play"))
	e.frames()
	truthy(e.holder().Visible)
	e.ui.setView(nil)
	e.frames()
	eq(e.holder().Visible, false)
	eq(e.own():GetAttribute("Step"), "")
end)

H.test("destroying leaves nothing behind", function()
	local e = setup()
	e.screen("CVC_ChampionsHud", { { name = "Play", x = 1000, y = 600, w = 200, h = 80 } })
	e.ui.setView(view("play", "Click PLAY!", "Play"))
	e.frames()
	e.ui.destroy()
	eq(e.own(), nil)
	eq(e.gui:FindFirstChild("TutorialBubbleHost", true), nil)
	e.frames() -- no listener is left to fail
end)
