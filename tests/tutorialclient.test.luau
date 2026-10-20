--!nocheck
-- The first-time tutorial from end to end on the fake Roblox: the real server part (TutorialService)
-- and the real screens (TutorialClient, TutorialUi, GuideTrail, TutorialPortal, PracticeClient) talk
-- to each other, with carter's menus played by a few fake buttons. A "player" here does what a person
-- does: walks, holds GAS, slides the stick, taps the machine, pulls, closes the menu, steps on a pad.
-- (carter's L1-L20 and L53-L60)
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, truthy = H.eq, H.truthy
local Bubble = require("../src/shared/BubbleLayout")
local V3, V2, Enum = Mock.V3, Mock.V2, Mock.Enum

print("Tutorial from start to coin gift")

local TICK = 0.05

-- A fresh world with a new player, the server part, the client part and the fake menus.
-- opts: touch (default true), seen (the saved hints), latency (seconds a message takes), busy,
-- freePull (default true), stubs (modules to replace: {"client/GuideTrail", fake})
local function rig(opts: any?)
	local o = opts or {}
	local phone = o.touch ~= false
	local world = Mock.new("./src", { fakeClock = true })
	world.quiet = true
	world.input.TouchEnabled = phone
	world.input.KeyboardEnabled = not phone
	for _, stub in o.stubs or {} do
		world.stub(stub[1], stub[2])
	end
	local player = world.newLocalPlayer("Dana", 7)
	local gui = player.PlayerGui
	local rs = world.service("ReplicatedStorage")
	local config = world.require("shared/TutorialConfig")
	local layout = world.require("shared/PracticeLayout")
	local Hints = world.require("shared/Hints")
	local origin = world.require("shared/LobbyConfig").Lobby.origin
	local e: any = {
		world = world,
		player = player,
		gui = gui,
		config = config,
		layout = layout,
		origin = origin,
		sent = {},
		profile = { coins = 5, hintsSeen = {} },
		busy = o.busy == true,
		freePull = o.freePull ~= false,
		latency = o.latency or 0,
		queue = {},
		parks = 0,
		spawns = 0,
		saves = 0,
		phone = phone,
	}
	for _, id in o.seen or {} do
		e.profile.hintsSeen[id] = true
	end

	-- carter's menus, reduced to the screens and buttons the lesson points at
	local namespace = world.instance("Folder")
	namespace.Name = "CVC_Champions"
	namespace.Parent = rs
	local function screen(name: string, enabled: boolean)
		local g = world.instance("ScreenGui")
		g.Name = name
		g.Enabled = enabled
		g.Parent = gui
		return g
	end
	local function button(
		parent: any,
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		shown: boolean
	)
		local b = world.instance("TextButton")
		b.Name = name
		b.AbsolutePosition = V2.new(x, y)
		b.AbsoluteSize = V2.new(w, h)
		b.Visible = shown
		b.Parent = parent
		return b
	end
	e.hud = screen("CVC_ChampionsHud", true)
	e.play = button(e.hud, "Play", 1000, 600, 200, 80, true)
	e.menu = screen("CVC_Champions", false)
	e.pull = button(e.menu, "PullClaw", 500, 560, 240, 90, true)
	e.confirm = button(e.menu, "ConfirmPurchase", 900, 560, 240, 90, false)
	e.revealDone = button(e.menu, "RevealDone", 520, 580, 240, 90, false)
	e.close = button(e.menu, "Close", 1100, 40, 70, 70, true)
	function e.openClaw()
		e.menu.Enabled = true
		e.pull.Visible, e.confirm.Visible, e.revealDone.Visible = true, false, false
		namespace:SetAttribute("MenuOpen", true)
	end
	function e.closeMenu()
		e.menu.Enabled = false
		namespace:SetAttribute("MenuOpen", false)
	end

	-- the character
	function e.moveTo(x: number, z: number)
		-- studs from the lobby origin; a standing character is 3 studs above the asphalt
		player.Character.HumanoidRootPart.Position =
			V3.new(origin.X + x, origin.Y + 3, origin.Z + z)
	end
	e.moveTo(0, 42)

	-- the messages between the two sides
	local client: any = nil
	local function later(fn: () -> ())
		if e.latency <= 0 then
			fn()
		else
			table.insert(e.queue, { at = world.now() + e.latency, fn = fn })
		end
	end
	function e.profileMessage()
		return {
			kind = "profile",
			hintsSeen = Hints.seenList(e.profile.hintsSeen),
			freePullAvailable = e.freePull,
			coins = e.profile.coins,
		}
	end
	function e.toClient(msg: any)
		later(function()
			client.handleLobby(msg)
		end)
	end
	local TutorialService = world.require("server/TutorialService")
	local service = TutorialService.start({
		remotes = {
			LobbyUpdate = {
				FireClient = function(_self: any, _player: any, msg: any)
					e.toClient(msg)
				end,
			},
		},
		sendProfile = function()
			e.toClient(e.profileMessage())
		end,
		profiles = {
			get = function()
				return e.profile
			end,
			markDirty = function() end,
			saveNow = function()
				e.saves += 1
			end,
		},
		addCoins = function(p: any, n: number)
			p.coins += n
		end,
		pads = {
			park = function()
				e.parks += 1
			end,
			toSpawn = function()
				e.spawns += 1
				e.moveTo(0, 42)
			end,
		},
		isBusy = function()
			return e.busy
		end,
		now = function()
			return 1000 + world.now()
		end,
	})
	function e.toServer(action: string, arg: any)
		table.insert(e.sent, action)
		later(function()
			service.action(player, action, arg)
		end)
	end
	local TutorialClient = world.requireClient("TutorialClient")
	client = TutorialClient.new({
		remotes = {
			LobbyAction = {
				FireServer = function(_self: any, action: string, arg: any)
					e.toServer(action, arg)
				end,
			},
		},
	})
	e.client = client

	-- time
	function e.tick()
		world.step(TICK)
		local due = true
		while due do
			due = false
			for i, item in e.queue do
				if item.at <= world.now() then
					table.remove(e.queue, i)
					item.fn()
					due = true
					break
				end
			end
		end
	end
	function e.seconds(s: number)
		for _ = 1, math.floor(s / TICK + 0.5) do
			e.tick()
		end
	end

	-- what the player sees
	function e.login()
		e.toClient(e.profileMessage())
	end
	function e.holder()
		return gui:FindFirstChild("TutorialBubbleHost", true)
	end
	function e.bubble(): string?
		local holder = e.holder()
		if holder == nil or not holder.Visible then
			return nil
		end
		return holder:FindFirstChild("Bubble"):FindFirstChild("Text").Text
	end
	function e.check(): boolean
		local holder = e.holder()
		return holder ~= nil and holder:FindFirstChild("Check").Visible == true
	end
	function e.skip()
		local own = gui:FindFirstChild("CVC_Tutorial")
		return if own then own:FindFirstChild("Skip") else nil
	end
	function e.hasPortal(): boolean
		return world.workspace:FindFirstChild("TutorialPortal") ~= nil
	end
	function e.hasTrail(): boolean
		return world.workspace:FindFirstChild("GuideTrail") ~= nil
	end
	function e.yard()
		return world.workspace:FindFirstChild("PracticeYard")
	end
	function e.carBody()
		local yard = e.yard()
		local car = if yard then yard:FindFirstChild("PracticeCar") else nil
		return if car then car:FindFirstChild("Body") else nil
	end
	function e.text(id: string): string
		return config.text[id][if phone then "phone" else "pc"]
	end

	-- the practice controls get a real size, like on a screen
	function e.sizeYardControls()
		local practice = gui:FindFirstChild("TutorialPractice")
		local gas = if practice then practice:FindFirstChild("PracticeGas") else nil
		if gas then
			gas.AbsolutePosition = V2.new(1040, 520)
			gas.AbsoluteSize = V2.new(180, 170)
		end
		local steerGui = gui:FindFirstChild("SteerGui")
		local stick = if steerGui then steerGui:FindFirstChild("Stick") else nil
		if stick then
			stick.AbsolutePosition = V2.new(40, 500)
			stick.AbsoluteSize = V2.new(160, 160)
		end
	end

	-- gestures in the yard
	function e.holdGas(on: boolean)
		if phone then
			local gas = gui:FindFirstChild("TutorialPractice"):FindFirstChild("PracticeGas")
			if on then
				e.gasTouch = { UserInputType = Enum.UserInputType.Touch }
				gas.InputBegan:Fire(e.gasTouch)
			else
				world.input.InputEnded:Fire(e.gasTouch)
			end
		else
			local input = { KeyCode = Enum.KeyCode.W, UserInputType = Enum.UserInputType.Keyboard }
			world.input[if on then "InputBegan" else "InputEnded"]:Fire(input, false)
		end
	end
	-- steer right (slide the stick, or hold D); a second call with `false` lets go
	function e.steerRight(on: boolean)
		if phone then
			local zone = gui:FindFirstChild("SteerGui"):FindFirstChild("SteerZone")
			if on then
				e.stickTouch =
					{ UserInputType = Enum.UserInputType.Touch, Position = V3.new(120, 580, 0) }
				zone.InputBegan:Fire(e.stickTouch)
				e.stickTouch.Position = V3.new(190, 580, 0)
				world.input.InputChanged:Fire(e.stickTouch)
			else
				world.input.InputEnded:Fire(e.stickTouch)
			end
		else
			local input = { KeyCode = Enum.KeyCode.D, UserInputType = Enum.UserInputType.Keyboard }
			world.input[if on then "InputBegan" else "InputEnded"]:Fire(input, false)
		end
	end
	-- the truck rolls through crate `i` at speed
	function e.crash(i: number)
		local c = layout.crates[i]
		local body = e.carBody()
		body.CFrame =
			Mock.CF.new(layout.origin.x + c.x, layout.origin.y + 0.5, layout.origin.z + c.z + 4)
		body.AssemblyLinearVelocity = V3.new(0, 0, -30)
		e.tick()
	end
	return e
end

-- From the "tap the machine" step to the PLAY step: tap, pull, the car, DONE, the red X.
local function pullAndFinish(e: any)
	e.client.promptTriggered("GachaPrompt")
	e.openClaw()
	e.seconds(1.5)
	e.confirm.Visible = true
	e.seconds(0.5)
	e.toClient({ kind = "gacha" })
	e.pull.Visible, e.confirm.Visible, e.revealDone.Visible = false, false, true
	e.seconds(1.5)
	e.revealDone.Visible = false
	e.seconds(0.5)
	e.closeMenu()
	e.seconds(1.5)
end

-- A quick way to the gumball machine: the server refuses the yard (rig({ busy = true })), so the
-- lesson goes from the portal straight to the machine.
local function reachMachine(e: any)
	e.login()
	e.moveTo(e.config.portal.x, e.config.portal.z)
	e.seconds(2.5)
	e.moveTo(0, -30)
	e.seconds(2)
end

-- Plays the whole lesson the way a person would, up to the PLAY step (the last one before the pad).
-- `again` is true for a replay: no new login.
local function playUntilPlay(e: any, again: boolean?)
	local cfg = e.config
	if not again then
		e.login()
	end
	e.moveTo(cfg.portal.x, cfg.portal.z)
	e.seconds(2)
	e.sizeYardControls()
	e.seconds(0.3)
	e.holdGas(true)
	e.seconds(1.5)
	e.steerRight(true)
	e.seconds(1.5)
	e.steerRight(false)
	e.holdGas(false)
	for i = 1, cfg.boxesNeeded do
		e.crash(i)
	end
	e.seconds(3) -- the check, the way out of the yard
	e.seconds(12) -- a walk to the machine takes a while (the coin gift needs 20 s in all)
	e.moveTo(0, -30)
	e.seconds(2)
	pullAndFinish(e)
end

-- ---------- the whole way through ----------

H.test("a new phone player: portal, yard, boxes, gumball machine, pad, coins", function()
	local e = rig()
	local cfg = e.config
	local client = e.client
	eq(client.active(), false, "nothing before the profile arrives")
	e.login()

	-- started: saved at once, SKIP on screen, the portal, the first words
	eq(client.active(), true)
	truthy(e.profile.hintsSeen.tutorial, "the flag is saved when it STARTS")
	eq(e.saves, 1)
	eq(e.sent[1], "tutorialStart")
	truthy(e.skip().Visible, "SKIP is there at once")
	truthy(e.hasPortal(), "the blue portal")
	eq(e.hasTrail(), false)
	e.seconds(0.3)
	eq(e.bubble(), e.text("portal"))

	-- walk into the portal: a check, then the yard
	e.moveTo(cfg.portal.x, cfg.portal.z)
	e.seconds(0.2)
	truthy(e.check(), "a green check for the first step")
	e.seconds(1.8)
	truthy(e.yard(), "the practice yard")
	eq(e.parks, 1, "the server parked the character")
	eq(e.hasPortal(), false, "the portal goes")
	truthy(e.carBody(), "the Ram Truck")
	e.sizeYardControls()
	e.seconds(0.3)
	eq(e.bubble(), e.text("gas"))
	eq(e.gui:FindFirstChild("TutorialPractice").PracticeGas.Text, "GAS")

	-- hold GAS: the next step
	e.holdGas(true)
	e.seconds(1.4)
	truthy(e.check(), "a check for GAS")
	e.seconds(1)
	eq(e.bubble(), e.text("steer"))
	e.steerRight(true)
	e.seconds(1.2)
	truthy(e.check(), "a check for steering")
	e.seconds(1)
	eq(e.bubble(), "Smash 3 boxes!  0 / 3")
	e.steerRight(false)
	e.holdGas(false)

	-- smash three boxes: the count goes up, the last one gets the check
	e.crash(1)
	e.seconds(0.2)
	eq(e.bubble(), "Smash 3 boxes!  1 / 3")
	e.crash(2)
	e.seconds(0.2)
	eq(e.bubble(), "Smash 3 boxes!  2 / 3")
	e.crash(3)
	e.seconds(0.2)
	truthy(e.check())
	eq(e.bubble(), "Smash 3 boxes!  3 / 3", "the last box shows 3 / 3 while the check is up")

	-- the yard closes by itself after the check; the character is back at the spawn
	e.seconds(3)
	eq(e.yard(), nil, "the yard is taken apart")
	eq(e.spawns, 1)
	eq(e.sent[#e.sent], "practiceExit")
	eq(e.world.camera.CameraType, Enum.CameraType.Custom)
	truthy(e.hud.Enabled, "the menu bar is back")
	truthy(e.hasTrail(), "the green line to the gumball machine")
	eq(e.bubble(), e.text("gumballWalk"))

	-- walk toward the machine (the coin gift needs a real run: 20 s)
	e.seconds(12)
	e.moveTo(0, -30)
	e.seconds(2)
	eq(e.bubble(), e.text("gumballTap"))
	eq(e.hasTrail(), false, "the line has done its job")

	-- tap the machine: the claw screen opens, the bubble stands next to PULL and says it is free
	e.client.promptTriggered("GachaPrompt")
	e.openClaw()
	e.seconds(1.5)
	eq(e.bubble(), e.text("gumballPullFree"))
	-- the bubble stands beside the PULL button: touching distance, off the button and off the middle
	local at = e.holder():FindFirstChild("Bubble").Position
	local box = { x = at.X.Offset, y = at.Y.Offset, w = 260, h = 70 }
	local pullButton = { x = 500, y = 560, w = 240, h = 90 }
	eq(Bubble.overlap(box, pullButton), 0, "not on the button")
	eq(Bubble.overlap(box, Bubble.centerBox({ w = 1280, h = 720 })), 0, "not in the middle")
	local gapX = math.max(pullButton.x - (box.x + box.w), box.x - (pullButton.x + pullButton.w), 0)
	local gapY = math.max(pullButton.y - (box.y + box.h), box.y - (pullButton.y + pullButton.h), 0)
	truthy(math.max(gapX, gapY) <= 40, "close to the button: " .. gapX .. ", " .. gapY)
	e.confirm.Visible = true
	e.seconds(0.5)
	eq(e.bubble(), e.text("gumballConfirm"))

	-- the car comes out: DONE, then the red X
	e.toClient({ kind = "gacha" })
	e.pull.Visible, e.confirm.Visible, e.revealDone.Visible = false, false, true
	e.seconds(1.5)
	eq(e.bubble(), e.text("gumballReveal"))
	e.revealDone.Visible = false
	e.seconds(0.5)
	eq(e.bubble(), e.text("gumballClose"))
	e.closeMenu()
	e.seconds(1.5)
	eq(e.bubble(), e.text("play"))
	truthy(e.hasTrail(), "the green line to a PLAY pad")

	-- step on a pad: the end, the coin gift
	e.toClient({ kind = "countdown", seconds = 3 })
	e.seconds(0.3)
	eq(e.sent[#e.sent], "tutorialDone")
	eq(e.profile.coins, 5 + cfg.giftCoins, "the gift was paid once")
	truthy(e.profile.hintsSeen.tutorialDone)
	eq(e.bubble(), "Great job! You got " .. cfg.giftCoins .. " coins!")
	eq(e.hasTrail(), false)
	eq(e.hasPortal(), false)
	eq(e.skip().Visible, false, "SKIP is not needed any more")
	e.seconds(cfg.finishSeconds + 1)
	eq(e.bubble(), nil, "the last bubble goes by itself")
	eq(client.active(), false)

	-- nothing was left running or left behind
	eq(e.hasTrail(), false)
	eq(e.hasPortal(), false)
	eq(e.yard(), nil)
	eq(e.gui:FindFirstChild("TutorialPractice"), nil)
	eq(e.gui:FindFirstChild("SteerGui"), nil)
end)

H.test("a PC player gets the key words and drives with W and D", function()
	local e = rig({ touch = false })
	local cfg = e.config
	e.login()
	e.seconds(0.3)
	eq(e.bubble(), cfg.text.portal.pc)
	e.moveTo(cfg.portal.x, cfg.portal.z)
	e.seconds(2)
	truthy(e.yard())
	eq(
		e.gui:FindFirstChild("TutorialPractice"):FindFirstChild("PracticeGas"),
		nil,
		"no GAS button on a PC"
	)
	eq(e.bubble(), cfg.text.gas.pc)
	-- the key hints stand low on the screen, under nothing
	local at = e.holder():FindFirstChild("Bubble").Position
	truthy(at.Y.Offset > 720 * 0.6, "low on the screen: " .. at.Y.Offset)
	e.holdGas(true)
	e.seconds(2.5)
	eq(e.bubble(), cfg.text.steer.pc)
	e.steerRight(true)
	e.seconds(2.5)
	eq(e.bubble(), "Smash 3 boxes!  0 / 3")
	e.steerRight(false)
	e.holdGas(false)
end)

-- ---------- ending early ----------

H.test("SKIP at the portal: everything goes, no gift, and it is never shown again", function()
	local e = rig()
	e.login()
	e.seconds(0.3)
	truthy(e.hasPortal())
	e.skip().Activated:Fire()
	e.seconds(0.2)
	eq(e.client.active(), false)
	eq(e.hasPortal(), false)
	eq(e.hasTrail(), false)
	eq(e.bubble(), nil)
	eq(e.skip().Visible, false)
	eq(table.concat(e.sent, ","), "tutorialStart", "the server heard nothing else: no gift")
	truthy(e.profile.hintsSeen.tutorial)
	eq(e.profile.coins, 5)
	-- the same player's next profile does not start it again
	e.toClient(e.profileMessage())
	eq(e.client.active(), false)
	eq(#e.sent, 1)
end)

H.test("SKIP in the yard: the truck is gone and the player is back at the spawn", function()
	local e = rig()
	e.login()
	e.moveTo(e.config.portal.x, e.config.portal.z)
	e.seconds(2)
	truthy(e.yard())
	e.skip().Activated:Fire()
	e.seconds(2)
	eq(e.client.active(), false)
	eq(e.yard(), nil)
	eq(e.spawns, 1, "back at the spawn")
	eq(e.gui:FindFirstChild("TutorialPractice"), nil)
	truthy(e.hud.Enabled)
	eq(e.world.camera.CameraType, Enum.CameraType.Custom)
	eq(e.bubble(), nil)
	eq(e.profile.coins, 5, "no gift for skipping")
end)

H.test("SKIP while the yard is still coming: it still ends cleanly", function()
	local e = rig({ latency = 0.4 })
	e.login()
	e.seconds(1)
	e.moveTo(e.config.portal.x, e.config.portal.z)
	e.seconds(0.5)
	e.skip().Activated:Fire()
	e.seconds(5)
	eq(e.client.active(), false)
	eq(e.yard(), nil)
	eq(e.hasPortal(), false)
	truthy(e.spawns >= 1, "the character was brought back")
	truthy(e.hud.Enabled)
end)

for _, ending in
	{
		{
			"stepping on a pad",
			function(e: any)
				e.toClient({ kind = "countdown", seconds = 3 })
			end,
		},
		{
			"tapping PLAY",
			function(e: any)
				e.client.handleBattle({ kind = "queue", searching = true })
			end,
		},
		{
			"the fight starting",
			function(e: any)
				e.client.handleBattle({ kind = "prep" })
			end,
		},
	}
do
	H.test("choosing to play early ends it without a gift: " .. ending[1], function()
		local e = rig()
		e.login()
		e.seconds(0.5)
		ending[2](e)
		e.seconds(0.3)
		eq(e.client.active(), false)
		eq(e.hasPortal(), false)
		eq(e.bubble(), nil)
		eq(e.profile.coins, 5)
		eq(table.concat(e.sent, ","), "tutorialStart")
	end)
end

-- ---------- people who should not see it ----------

H.test("a returning player (tutorial seen) gets nothing", function()
	local e = rig({ seen = { "tutorial" } })
	e.login()
	e.seconds(1)
	eq(e.client.active(), false)
	eq(e.gui:FindFirstChild("CVC_Tutorial"), nil, "no screen even made")
	eq(e.hasPortal(), false)
	eq(#e.sent, 0)
end)

H.test("a player who already knows PLAY (the old hint) gets nothing", function()
	local e = rig({ seen = { "pad" } })
	e.login()
	e.seconds(1)
	eq(e.client.active(), false)
	eq(#e.sent, 0)
end)

-- ---------- when things go wrong ----------

H.test(
	"the server will not open the yard (busy): the lesson goes on to the gumball machine",
	function()
		local e = rig({ busy = true })
		e.login()
		e.moveTo(e.config.portal.x, e.config.portal.z)
		e.seconds(2.5)
		eq(e.yard(), nil)
		eq(e.parks, 0)
		eq(e.client.active(), true, "still running")
		eq(e.hasPortal(), false)
		truthy(e.hasTrail(), "the green line")
		eq(e.bubble(), e.text("gumballWalk"))
		eq(e.world.camera.CameraType, Enum.CameraType.Custom)
	end
)

H.test("the yard cannot be built: the player is asked back and the lesson goes on", function()
	local e = rig({
		stubs = {
			{
				"shared/PracticeYard",
				{
					build = function()
						error("no yard today")
					end,
					burst = function() end,
				},
			},
		},
	})
	e.login()
	e.moveTo(e.config.portal.x, e.config.portal.z)
	e.seconds(3)
	eq(e.yard(), nil)
	eq(e.client.active(), true)
	eq(e.spawns, 1, "the character is back at the spawn")
	truthy(e.hasTrail())
	eq(e.bubble(), e.text("gumballWalk"))
	truthy(e.hud.Enabled)
end)

H.test("a slow connection: the bubble for the yard still appears when the yard is up", function()
	local e = rig({ latency = 0.6 })
	e.login()
	e.seconds(1)
	e.moveTo(e.config.portal.x, e.config.portal.z)
	e.seconds(6)
	truthy(e.yard())
	e.sizeYardControls()
	e.seconds(0.5)
	eq(e.bubble(), e.text("gas"), "the words are there before the first touch")
end)

H.test("a part that breaks stops the tutorial and gives the lobby back", function()
	local e = rig({
		stubs = {
			{
				"client/GuideTrail",
				{
					new = function()
						error("no line today")
					end,
				},
			},
		},
	})
	e.login()
	e.seconds(1)
	eq(e.client.active(), false)
	eq(e.hasPortal(), false)
	eq(e.bubble(), nil)
	e.seconds(1) -- and the lobby keeps running
end)

H.test("a bad message from the server does not break anything", function()
	local e = rig()
	e.login()
	e.client.handleLobby(nil)
	e.client.handleLobby("hello")
	e.client.handleLobby({ kind = "tutorial", event = 5 })
	e.client.handleLobby({ kind = "countdown", seconds = "x" })
	e.client.handleBattle(nil)
	e.client.handleBattle({ kind = "queue", searching = false })
	e.client.promptTriggered("SomethingElse")
	e.seconds(0.3)
	eq(e.client.active(), true)
	eq(e.bubble(), e.text("portal"))
end)

-- ---------- the machine's own words ----------

H.test("a player with no free pull is told to pull, not that it is free", function()
	local e = rig({ busy = true, freePull = false })
	reachMachine(e)
	eq(e.bubble(), e.text("gumballTap"))
	e.client.promptTriggered("GachaPrompt")
	e.openClaw()
	e.seconds(1.5)
	eq(e.bubble(), "Tap here to pull a new car!")
end)

H.test(
	"the profile can change the words, and closing the machine without a pull asks again",
	function()
		local e = rig({ busy = true })
		reachMachine(e)
		e.client.promptTriggered("GachaPrompt")
		e.openClaw()
		e.seconds(1.5)
		eq(e.bubble(), e.text("gumballPullFree"))
		-- a new profile says the free pull is used up: the words change
		e.freePull = false
		e.toClient(e.profileMessage())
		e.seconds(0.5)
		eq(e.bubble(), e.text("gumballPull"))
		-- the menu closes without a pull: tap the machine again
		e.closeMenu()
		e.seconds(1)
		eq(e.bubble(), e.text("gumballTap"))
		-- and the second try works
		pullAndFinish(e)
		eq(e.bubble(), e.text("play"))
	end
)

H.test("the bubble waits for the menu: nothing is drawn while the claw screen is closed", function()
	local e = rig({ busy = true })
	reachMachine(e)
	e.client.promptTriggered("GachaPrompt") -- the screen has not opened yet
	e.seconds(1.5)
	eq(e.bubble(), nil, "nothing to point at yet")
	e.openClaw()
	e.seconds(0.5)
	eq(e.bubble(), e.text("gumballPullFree"))
end)

-- ---------- replay from Settings ----------

H.test("replaying from Settings runs it again, with no second gift", function()
	local e = rig({ busy = true })
	reachMachine(e)
	e.seconds(10) -- the gift needs 20 s from the start
	pullAndFinish(e)
	e.toClient({ kind = "countdown", seconds = 3 })
	e.seconds(e.config.finishSeconds + 1)
	eq(e.profile.coins, 5 + e.config.giftCoins)
	eq(e.client.active(), false)
	eq(e.bubble(), nil)

	-- Settings -> SHOW THE TUTORIAL
	e.client.replay()
	e.seconds(0.5)
	eq(e.client.active(), true)
	eq(e.sent[#e.sent], "tutorialStart")
	truthy(e.hasPortal())
	truthy(e.skip().Visible)
	eq(e.bubble(), e.text("portal"))
	-- a second tap on the Settings row while it runs changes nothing
	local before = #e.sent
	e.client.replay()
	eq(#e.sent, before)

	-- play it again to the end, this time through the practice yard (the server lets it open now)
	e.busy = false
	playUntilPlay(e, true)
	eq(e.parks, 1, "the yard opened on the replay")
	eq(e.bubble(), e.text("play"))
	e.toClient({ kind = "countdown", seconds = 3 })
	e.seconds(0.3)
	eq(e.profile.coins, 5 + e.config.giftCoins, "still one gift")
	eq(e.bubble(), "Great job!", "no coin words when nothing was paid")
end)

H.test("replaying while it is already running changes nothing", function()
	local e = rig()
	e.login()
	e.seconds(0.5)
	e.client.replay()
	e.client.replay()
	eq(#e.sent, 1)
	eq(e.client.active(), true)
end)

H.test("replaying in the middle of a fight or before the profile is fine", function()
	local e = rig()
	e.client.replay() -- before any profile: it simply starts (the Settings screen is only reachable in the lobby)
	e.seconds(0.3)
	eq(e.client.active(), true)
end)
