--!strict
local H = require("./harness")
local Adapter = require("../src/shared/ChampionsAdapter")
local Assets = require("../src/champions/shared/Assets")
local CarConfig = require("../src/shared/CarConfig")
local Daily = require("../src/shared/Daily")
local ModesConfig = require("../src/shared/ModesConfig")

print("Champions UI adapter")

local function newModel(): Adapter.Model
	return Adapter.new({
		maxSeconds = ModesConfig.LastStanding.maxSeconds,
		cars = ModesConfig.LastStanding.cars,
		isLive = function(id: string): boolean
			return CarConfig.isLive(id)
		end,
	})
end

local function profile(extra: any?): any
	local p: any = {
		kind = "profile",
		coins = 250,
		owned = { "Sedan" },
		build = { carId = "Sedan" },
		freePullAvailable = false,
		daily = { ready = true, secondsToNext = 0, coins = 20 },
	}
	for k, v in (extra or {}) :: any do
		p[k] = v
	end
	return p
end

H.test("every live car has a picture", function()
	for _, id in CarConfig.Order do
		local image = (Assets.Vehicles :: any)[id]
		H.truthy(
			type(image) == "string" and string.find(image, "rbxassetid://", 1, true) ~= nil,
			id
		)
	end
end)

H.test("profile becomes a snapshot", function()
	local m = newModel()
	m.level(3, 40, 100)
	m.profile(profile({ owned = { "Sedan", "Muscle" } }), 1000)
	local s = m.snapshot()
	H.eq(s.ready, true)
	H.eq(s.coins, 250)
	H.eq(s.level, 3)
	H.eq(s.xpGoal, 100)
	H.eq(s.equipped, "Sedan")
	H.eq(s.owned.Muscle, true)
	H.eq(s.dailyReady, true)
	H.eq(s.dailyGift, 20)
	H.eq(s.mode, "DUEL")
	H.eq(s.clawPrice, nil)
end)

H.test("not ready until the first profile", function()
	H.eq(newModel().snapshot().ready, false)
end)

H.test("free claw try shows price 0", function()
	local m = newModel()
	m.profile(profile({ freePullAvailable = true }), 0)
	H.eq(m.snapshot().clawPrice, 0)
end)

H.test("gift timer counts to the server's seconds", function()
	local m = newModel()
	m.profile(profile({ daily = { ready = false, secondsToNext = 600, coins = 30 } }), 1000)
	local s = m.snapshot()
	H.eq(s.dailyReady, false)
	H.eq(s.dailyNextAt, 1600)
end)

H.test("hidden cars are never the equipped car", function()
	local m = newModel()
	m.profile(profile({ owned = { "Sedan" }, build = { carId = "NotALiveCar" } }), 0)
	H.eq(m.snapshot().equipped, "Sedan")
end)

H.test("starter pick opens once, picks with pickStarter", function()
	local m = newModel()
	local fx = m.profile(
		profile({ starterPicked = false, starterChoices = { "Sedan", "DuneBuggy", "BoxTruck" } }),
		0
	)
	H.eq(fx.open, "PICKER")
	H.eq(#m.snapshot().pickerOptions, 3)
	local fx2 = m.profile(
		profile({ starterPicked = false, starterChoices = { "Sedan", "DuneBuggy", "BoxTruck" } }),
		0
	)
	H.eq(fx2.open, nil)
	local call = m.intent("ChooseCar", { vehicleId = "DuneBuggy" })
	H.eq((call :: any).name, "pickStarter")
	H.eq((call :: any).arg, "DuneBuggy")
	m.profile(profile({ starterPicked = true }), 0)
	H.eq(#m.snapshot().pickerOptions, 0)
end)

H.test("pad choices open the picker and use pickCar", function()
	local m = newModel()
	local fx = m.lobby({ kind = "choices", cars = { "Sedan", "Muscle", "Compact" }, seconds = 10 })
	H.eq(fx.open, "PICKER")
	local call = m.intent("ChooseCar", { vehicleId = "Muscle" })
	H.eq((call :: any).name, "pickCar")
	m.ui({ kind = "ready", round = 1 }, 0)
	H.eq(#m.snapshot().pickerOptions, 0)
end)

H.test("buttons map to the existing remotes", function()
	local m = newModel()
	local function call(action: string, payload: any?): any
		local c = m.intent(action, payload or {})
		return c
	end
	H.eq(call("BuyCar", { vehicleId = "Muscle" }).name, "buyCar")
	H.eq(call("EquipCar", { vehicleId = "Muscle" }).name, "buildCar")
	H.eq(call("PullClaw").name, "buyGacha")
	H.eq(call("ClaimGift").name, "claimDaily")
	H.eq(call("Play").name, "play")
	H.eq(call("CancelPlay").name, "cancelPlay")
	H.eq(call("Boost").remote, "Action")
	H.eq(call("Boost").name, "boost")
	H.eq(call("Ability").name, "special")
	H.eq(call("SetMode", { mode = "DUEL" }), nil)
	H.eq(call("ResetCar"), nil)
end)

H.test("PLAY line: countdown shows, zero clears, busy says so", function()
	local m = newModel()
	m.lobby({ kind = "countdown", seconds = 12, alone = true })
	H.eq(m.snapshot().queue.status, "FIGHT IN 12")
	local fx = m.lobby({ kind = "countdown", seconds = 0, busy = true })
	H.eq(m.snapshot().queue, nil)
	H.eq(fx.notifyOk, false)
end)

H.test("claw result becomes a reveal; errors clear pending", function()
	local m = newModel()
	m.lobby({
		kind = "gacha",
		carId = "Semi",
		isNew = false,
		refund = 60,
		free = false,
		coins = 90,
	})
	local s = m.snapshot()
	H.eq(s.reveal.vehicleId, "Semi")
	H.eq(s.reveal.duplicate, true)
	H.eq(s.reveal.refund, 60)
	H.eq(s.coins, 90)
	local fx = m.lobby({ kind = "gachaError", reason = "coins" })
	H.eq(fx.notifyOk, false)
	H.eq(fx.notify, "NOT ENOUGH COINS")
	local fx2 =
		m.lobby({ kind = "storeResult", ok = false, carId = "Semi", reason = "owned", coins = 90 })
	H.eq(fx2.notifyOk, false)
end)

H.test("a whole fight: ready, fight, cooldowns, hud, end, lobby", function()
	local m = newModel()
	m.ui({ kind = "ready", round = 1 }, 100)
	H.eq(m.snapshot().match.phase, "READY")
	H.eq(m.inMatch(), true)
	m.ui({ kind = "fight", round = 1, wins = 0, carsLeft = 4 }, 105)
	local match = m.snapshot().match
	H.eq(match.phase, "ACTIVE")
	H.eq(match.endsAt, 105 + ModesConfig.LastStanding.maxSeconds)
	m.ui({ kind = "move", move = "boost", seconds = 5 }, 110)
	m.ui({ kind = "move", move = "special", seconds = 8 }, 111)
	m.ui({ kind = "fightHud", carsLeft = 2, wins = 1, round = 1 }, 112)
	match = m.snapshot().match
	H.eq(match.boostEndsAt, 115)
	H.eq(match.abilityEndsAt, 119)
	H.eq(match.carsLeft, 2)
	H.eq(match.youScore, 1)
	m.ui({ kind = "matchEnd", youWon = true }, 130, { place = 1 })
	match = m.snapshot().match
	H.eq(match.phase, "RESULTS")
	H.eq(match.result.won, true)
	H.eq(match.result.place, 1)
	local fx = m.lobby({
		kind = "toLobby",
		coinsEarned = 90,
		won = true,
		resultText = "1st place",
		levelUp = { coins = 25 },
	})
	H.eq(fx.open, "RESULTS")
	local s = m.snapshot()
	H.eq(s.match, nil)
	H.eq(s.result.total, 115)
	H.eq(s.result.place, 1)
	H.eq(#s.result.rewards, 2)
	H.eq(s.result.rewards[1].label, "1ST PLACE")
end)

H.test("round 2 keeps your round wins; round 1 resets them", function()
	local m = newModel()
	m.ui({ kind = "ready", round = 1 }, 0)
	m.ui({ kind = "fightHud", carsLeft = 1, wins = 1, round = 1 }, 1)
	m.ui({ kind = "ready", round = 2 }, 5)
	H.eq(m.snapshot().match.youScore, 1)
	m.ui({ kind = "ready", round = 1 }, 99)
	H.eq(m.snapshot().match.youScore, 0)
end)

H.test("rematch: vote on the end screen, PLAY from the lobby", function()
	local m = newModel()
	m.ui({ kind = "ready", round = 1 }, 0)
	m.ui({ kind = "matchEnd", youWon = false }, 1)
	H.eq((m.intent("Rematch", {}) :: any).name, "rematch")
	m.lobby({ kind = "toLobby", coinsEarned = 5, won = false })
	local call, fx = m.intent("Rematch", {})
	H.eq((call :: any).name, "play")
	H.eq(fx.open, "LOBBY")
	H.eq(m.snapshot().result, nil)
end)

H.test("leaving: server call in a match, local close after", function()
	local m = newModel()
	m.ui({ kind = "ready", round = 1 }, 0)
	H.eq((m.intent("LeaveMatch", {}) :: any).name, "leaveMatch")
	local fx = m.lobby({ kind = "toLobby", coinsEarned = 0, won = false, left = true })
	H.eq(fx.open, "LOBBY")
	H.eq(m.snapshot().result, nil)
	local call, fx2 = m.intent("LeaveMatch", {})
	H.eq(call, nil)
	H.eq(fx2.open, "LOBBY")
end)

H.test("settings are kept and handed back", function()
	local m = newModel()
	local call, fx = m.intent("SaveSettings", { music = false })
	H.eq(call, nil)
	H.eq((fx.settings :: any).music, false)
	H.eq(m.snapshot().settings.music, false)
	H.eq(m.snapshot().settings.sfx, true)
end)

H.test("next gift coins follow the streak", function()
	local d = Daily.default()
	local day = 86400
	local first = Daily.nextCoins(d, day * 10)
	H.truthy(first > 0)
	Daily.claim(d, day * 10)
	H.eq(
		Daily.nextCoins(d, day * 11),
		Daily.streakCoins({ lastDay = d.lastDay, freePulls = 0, streak = 2 })
	)
	H.eq(Daily.nextCoins(d, day * 20), first) -- a gap starts again at day 1
end)
