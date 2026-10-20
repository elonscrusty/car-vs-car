--!nocheck
-- The server side of the tutorial: flags saved at the start, the coin gift once, the character
-- parked during the practice drive and brought back (carter's L3, L6, L10, L20).
local H = require("./harness")
local Mock = require("./robloxmock")
local Config = require("../src/shared/TutorialConfig")
local eq, truthy = H.eq, H.truthy

print("TutorialService")

local world = Mock.new("./src")
world.quiet = true
local TutorialService = world.require("server/TutorialService")

-- A service with fake players' profiles and a fake clock.
local function setup(opts: { [string]: any }?)
	local o = opts or {}
	local env: any =
		{ clock = 1000, log = {}, saves = 0, profiles = 0, parks = 0, spawns = 0, tracked = {} }
	env.busy = o.busy == true
	env.profile = { coins = 5, hintsSeen = {} }
	env.player = world.newPlayer("Dana", 7)
	env.service = TutorialService.start({
		remotes = {
			LobbyUpdate = {
				FireClient = function(_self: any, _player: any, msg: any)
					table.insert(env.log, msg)
				end,
			},
		},
		sendProfile = function()
			env.profiles += 1
		end,
		profiles = {
			get = function()
				return env.profile
			end,
			markDirty = function() end,
			saveNow = function()
				env.saves += 1
			end,
		},
		addCoins = function(p: any, n: number)
			p.coins += n
		end,
		pads = {
			park = function()
				env.parks += 1
			end,
			toSpawn = function()
				env.spawns += 1
			end,
		},
		isBusy = function()
			return env.busy
		end,
		now = function()
			return env.clock
		end,
		track = if o.noTrack
			then nil
			else function(_player: any, name: string, data: any)
				table.insert(env.tracked, { name = name, data = data })
			end,
	})
	function env.do_(action: any)
		return env.service.action(env.player, action, nil)
	end
	function env.last()
		return env.log[#env.log]
	end
	return env
end

H.test("starting marks the tutorial seen at once and saves", function()
	local e = setup()
	truthy(e.do_("tutorialStart"))
	truthy(e.profile.hintsSeen.tutorial)
	truthy(e.profile.hintsSeen.pad)
	truthy(e.profile.hintsSeen.claw)
	eq(e.saves, 1)
	eq(e.profiles, 1)
	-- starting again (a replay) changes nothing and saves nothing
	e.do_("tutorialStart")
	eq(e.saves, 1)
	eq(e.profiles, 1)
end)

H.test("the coin gift is paid once, and not before a real run could be over", function()
	local e = setup()
	-- never started: no gift
	e.do_("tutorialDone")
	eq(e.profile.coins, 5)
	eq(e.last().event, "gift")
	eq(e.last().coins, 0)
	e.do_("tutorialStart")
	e.clock += Config.minGiftSeconds - 1
	e.do_("tutorialDone")
	eq(e.profile.coins, 5, "too fast")
	eq(e.last().coins, 0)
	eq(e.profile.hintsSeen.tutorialDone, nil)
	e.clock += 2
	e.do_("tutorialDone")
	eq(e.profile.coins, 5 + Config.giftCoins)
	truthy(e.profile.hintsSeen.tutorialDone)
	eq(e.last().kind, "tutorial")
	eq(e.last().event, "gift")
	eq(e.last().coins, Config.giftCoins)
	local saves = e.saves
	-- again, and after a replay: nothing more
	e.do_("tutorialDone")
	e.do_("tutorialStart")
	e.clock += 500
	e.do_("tutorialDone")
	eq(e.profile.coins, 5 + Config.giftCoins)
	eq(e.last().coins, 0)
	eq(e.saves, saves)
end)

H.test("the practice yard: park, answer ready, bring back at the spawn", function()
	local e = setup()
	e.do_("practiceEnter")
	eq(e.last().event, "practiceRefused", "not started")
	eq(e.parks, 0)
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	eq(e.last().event, "practiceReady")
	eq(e.parks, 1)
	-- a second enter while away is refused and parks nobody again
	e.do_("practiceEnter")
	eq(e.last().event, "practiceRefused")
	eq(e.parks, 1)
	e.do_("practiceExit")
	eq(e.last().event, "practiceExited")
	eq(e.spawns, 1)
	-- exiting again answers but does not move anyone
	e.do_("practiceExit")
	eq(e.last().event, "practiceExited")
	eq(e.spawns, 1)
	-- and the yard can be entered again (a replay)
	e.do_("practiceEnter")
	eq(e.last().event, "practiceReady")
	eq(e.parks, 2)
end)

H.test("nobody is parked while queued or fighting", function()
	local e = setup({ busy = true })
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	eq(e.last().event, "practiceRefused")
	eq(e.parks, 0)
	e.busy = false
	e.player:SetAttribute("InBattle", true)
	e.do_("practiceEnter")
	eq(e.last().event, "practiceRefused")
	eq(e.parks, 0)
end)

H.test("a player who never comes back from the yard is brought back by the server", function()
	local e = setup()
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	eq(e.spawns, 0)
	world.step(Config.practiceMaxSeconds)
	eq(e.spawns, 0, "the device still has its own time")
	world.step(Config.serverPracticeGraceSeconds + 1)
	eq(e.spawns, 1)
	eq(e.last().event, "practiceExited")
end)

H.test("leaving the yard in time cancels the safety timer", function()
	local e = setup()
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	e.do_("practiceExit")
	eq(e.spawns, 1)
	-- a new visit later must not be cut short by the first visit's timer
	world.step(100)
	e.do_("practiceEnter")
	world.step(Config.practiceMaxSeconds + Config.serverPracticeGraceSeconds - 50)
	-- the first timer's moment has passed (170 s after the first visit); the new visit is still on
	eq(e.spawns, 1)
	eq(e.parks, 2)
	world.step(60)
	eq(e.spawns, 2, "the second visit's own timer ends it")
end)

H.test("a player who left is forgotten", function()
	local e = setup()
	e.do_("tutorialStart")
	e.service.remove(e.player)
	e.do_("practiceEnter")
	eq(e.last().event, "practiceRefused")
	e.do_("tutorialDone")
	eq(e.profile.coins, 5)
end)

H.test("other actions are not the tutorial's", function()
	local e = setup()
	eq(e.service.action(e.player, "play", nil), false)
	eq(e.service.action(e.player, 5, nil), false)
	eq(e.service.action(e.player, nil, nil), false)
	eq(#e.log, 0)
end)

H.test("a player with no profile yet gets nothing and breaks nothing", function()
	local e = setup()
	e.profile = nil
	e.do_("tutorialStart")
	e.do_("tutorialDone")
	eq(e.saves, 0)
	eq(e.profiles, 0)
end)

H.test("analytics: the start, the time in the yard and the end are counted", function()
	local e = setup()
	e.do_("tutorialStart")
	eq(#e.tracked, 1)
	eq(e.tracked[1].name, "tutorial_start")
	eq(e.tracked[1].data.first, true)
	e.clock += 5
	e.do_("practiceEnter")
	e.clock += 40
	e.do_("practiceExit")
	eq(e.tracked[2].name, "tutorial_practice")
	eq(e.tracked[2].data.seconds, 40)
	e.do_("practiceExit") -- already out: counted once
	eq(#e.tracked, 2)
	e.clock += 20
	e.do_("tutorialDone")
	eq(e.tracked[3].name, "tutorial_done")
	eq(e.tracked[3].data.seconds, 65, "seconds since the start")
	eq(e.tracked[3].data.gift, true)
	-- a replay from Settings: first = false, and no second gift
	e.do_("tutorialStart")
	eq(e.tracked[4].data.first, false)
	e.clock += 30
	e.do_("tutorialDone")
	eq(e.tracked[5].data.seconds, 30)
	eq(e.tracked[5].data.gift, false)
end)

H.test("analytics: a finish that was too fast or never started says no gift", function()
	local e = setup()
	e.do_("tutorialDone") -- never started
	eq(e.tracked[1].name, "tutorial_done")
	eq(e.tracked[1].data.seconds, 0)
	eq(e.tracked[1].data.gift, false)
	e.do_("tutorialStart")
	e.clock += 3
	e.do_("tutorialDone")
	eq(e.tracked[3].data.seconds, 3)
	eq(e.tracked[3].data.gift, false)
end)

H.test("analytics: a player who leaves while in the yard still counts the yard time", function()
	local e = setup()
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	e.clock += 12
	e.service.remove(e.player)
	eq(e.tracked[#e.tracked].name, "tutorial_practice")
	eq(e.tracked[#e.tracked].data.seconds, 12)
	local n = #e.tracked
	e.service.remove(e.player) -- leaving twice counts nothing more
	eq(#e.tracked, n)
end)

H.test("analytics: the service works with no hook", function()
	local e = setup({ noTrack = true })
	e.do_("tutorialStart")
	e.do_("practiceEnter")
	e.do_("practiceExit")
	e.clock += 30
	e.do_("tutorialDone")
	eq(e.profile.coins, 5 + Config.giftCoins)
	eq(#e.tracked, 0)
end)
