--!strict
-- Audit fixes: rewards by effort, claw pity, next goal, session summary, xp view, first matches.
local H = require("./harness")
local BotLevels = require("../src/shared/BotLevels")
local CarConfig = require("../src/shared/CarConfig")
local Daily = require("../src/shared/Daily")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local LobbyText = require("../src/shared/LobbyText")
local MenuRules = require("../src/shared/MenuRules")
local NextGoal = require("../src/shared/NextGoal")
local PadLogic = require("../src/shared/PadLogic")
local Progress = require("../src/shared/Progress")
local ProgressConfig = require("../src/shared/ProgressConfig")
local QuestsConfig = require("../src/shared/QuestsConfig")
local ResultRewards = require("../src/shared/ResultRewards")
local SessionSummary = require("../src/shared/SessionSummary")
local Store = require("../src/shared/Store")

print("Audit fixes: rewards and lobby")

local R = LobbyConfig.ResultRewards

H.test("result rewards: old modes keep the old win / lose coins and no special line", function()
	local win = ResultRewards.compute({ mode = "duel", won = true })
	H.eq(win.coins, LobbyConfig.Rewards.winCoins)
	H.eq(win.resultText, "")
	H.eq(ResultRewards.compute({ mode = "hill", won = false }).coins, LobbyConfig.Rewards.loseCoins)
	-- nothing reported at all (old callers): same as before
	H.eq(ResultRewards.compute({ won = true }).coins, 60)
	H.eq(ResultRewards.compute({ won = false }).coins, 20)
	H.eq(R.baseWin, LobbyConfig.Rewards.winCoins)
	H.eq(R.baseOther, LobbyConfig.Rewards.loseCoins)
end)

H.test("result rewards: race pays by place and never says lose", function()
	local expected = { 60, 45, 35, 25, 20, 20 }
	local ordinals = { "1st", "2nd", "3rd", "4th", "5th", "6th" }
	for place = 1, 6 do
		local r = ResultRewards.compute({ mode = "race", won = place == 1, place = place })
		H.eq(r.coins, expected[place], `place {place}`)
		H.eq(r.resultText, `{ordinals[place]} place`)
		H.eq(string.find(string.lower(r.resultText), "lose"), nil)
	end
	H.eq(ResultRewards.compute({ mode = "race", won = false, place = 9 }).coins, 20) -- past the list
	-- a winner with no place reported is first
	H.eq(ResultRewards.compute({ mode = "race", won = true }).resultText, "1st place")
	-- did not finish: base coins, friendly text
	local dnf = ResultRewards.compute({ mode = "race", won = false })
	H.eq(dnf.coins, 20)
	H.eq(dnf.resultText, "Good race")
end)

H.test("result rewards: soccer pays 5 per goal on top of the base", function()
	local r = ResultRewards.compute({ mode = "soccer", won = false, goals = 2 })
	H.eq(r.coins, 20 + 10)
	H.eq(r.resultText, "2 goals")
	H.eq(ResultRewards.compute({ mode = "soccer", won = false, goals = 1 }).resultText, "1 goal")
	local w = ResultRewards.compute({ mode = "soccer", won = true, goals = 3 })
	H.eq(w.coins, 60 + 15)
	H.eq(w.resultText, "Team win, 3 goals")
	H.eq(ResultRewards.compute({ mode = "soccer", won = false }).resultText, "Good game")
	H.eq(ResultRewards.compute({ mode = "soccer", won = true }).resultText, "Team win")
	-- junk numbers are ignored or capped
	H.eq(ResultRewards.compute({ mode = "soccer", won = false, goals = -4 }).coins, 20)
	H.eq(
		ResultRewards.compute({ mode = "soccer", won = false, goals = 1e6 }).coins,
		20 + 5 * R.maxGoalsPaid
	)
	H.eq(ResultRewards.compute({ mode = "soccer", won = false, goals = 0 / 0 }).coins, 20)
end)

H.test("result rewards: tag pays for surviving and tagging, text says how long", function()
	local r = ResultRewards.compute({ mode = "tag", won = false, survivedSeconds = 70 })
	H.eq(r.resultText, "Survived 1:10")
	H.eq(r.coins, 20 + 7 * R.tagSurvivePerStep)
	H.eq(
		ResultRewards.compute({ mode = "tag", won = false, survivedSeconds = 5 }).resultText,
		"Survived 0:05"
	)
	-- the survive bonus is capped
	H.eq(
		ResultRewards.compute({ mode = "tag", won = false, survivedSeconds = 9999 }).coins,
		20 + R.tagSurviveMax
	)
	local t = ResultRewards.compute({ mode = "tag", won = false, survivedSeconds = 30, tags = 2 })
	H.eq(t.resultText, "Survived 0:30, 2 tags")
	H.eq(t.coins, 20 + 3 * R.tagSurvivePerStep + 2 * R.perTag)
	H.eq(ResultRewards.compute({ mode = "tag", won = false, tags = 1 }).resultText, "1 tag")
	local win = ResultRewards.compute({ mode = "tag", won = true, survivedSeconds = 200, tags = 1 })
	H.eq(win.coins, 60 + R.perTag) -- winners get the base, not the survive bonus
	H.eq(win.resultText, "Last car, 1 tag")
	H.eq(ResultRewards.compute({ mode = "tag", won = true }).resultText, "Last car standing")
end)

H.test("result rewards: no 'lose' wording in any multi-car result", function()
	for _, mode in { "soccer", "tag", "race" } do
		for _, won in { true, false } do
			for place = 1, 6 do
				local r = ResultRewards.compute({
					mode = mode,
					won = won,
					place = place,
					goals = place - 1,
					tags = place - 1,
					survivedSeconds = place * 15,
				})
				H.eq(string.find(string.lower(r.resultText), "los"), nil, r.resultText)
				H.truthy(r.coins >= 20)
			end
		end
	end
end)

H.test("result rewards: mode is guessed from the fields when not reported", function()
	H.eq(ResultRewards.modeOf({ won = false, place = 3 }), "race")
	H.eq(ResultRewards.modeOf({ won = false, goals = 0 }), "soccer")
	H.eq(ResultRewards.modeOf({ won = false, tags = 2 }), "tag")
	H.eq(ResultRewards.modeOf({ won = false, survivedSeconds = 9 }), "tag")
	H.eq(ResultRewards.modeOf({ won = false }), nil)
	H.eq(ResultRewards.modeOf({ won = false, mode = "auto" }), nil)
	H.eq(ResultRewards.modeOf({ won = false, mode = "soccer", place = 2 }), "soccer")
	H.truthy(ResultRewards.isGroupMode("race"))
	H.truthy(not ResultRewards.isGroupMode("duel"))
end)

H.test("result rewards: ordinals and clock", function()
	H.eq(ResultRewards.ordinal(11), "11th")
	H.eq(ResultRewards.ordinal(12), "12th")
	H.eq(ResultRewards.ordinal(13), "13th")
	H.eq(ResultRewards.ordinal(21), "21st")
	H.eq(ResultRewards.ordinal(22), "22nd")
	H.eq(ResultRewards.ordinal(103), "103rd")
	H.eq(ResultRewards.clock(0), "0:00")
	H.eq(ResultRewards.clock(70), "1:10")
	H.eq(ResultRewards.clock(600), "10:00")
end)

H.test("streak: a top-half finish in tag/race keeps it, a win is not special-cased", function()
	H.truthy(ResultRewards.keepsStreak({ mode = "race", won = false, place = 3 }))
	H.truthy(not ResultRewards.keepsStreak({ mode = "race", won = false, place = 4 }))
	H.truthy(ResultRewards.keepsStreak({ mode = "tag", won = false, place = 2 }))
	H.truthy(not ResultRewards.keepsStreak({ mode = "tag", won = false })) -- no place reported
	H.truthy(not ResultRewards.keepsStreak({ mode = "soccer", won = false, place = 1 }))
	H.truthy(not ResultRewards.keepsStreak({ mode = "duel", won = false, place = 1 }))

	local p = Inventory.default()
	p.progress.streak = 4
	Progress.applyMatchResult(p, "Sedan", false, ProgressConfig, true)
	H.eq(p.progress.streak, 4) -- kept, no XP skipped
	Progress.applyMatchResult(p, "Sedan", false, ProgressConfig, false)
	H.eq(p.progress.streak, 0)
	p.progress.streak = 2
	Progress.applyMatchResult(p, "Sedan", false, ProgressConfig) -- old call shape
	H.eq(p.progress.streak, 0)
	p.progress.streak = 2
	Progress.applyMatchResult(p, "Sedan", true, ProgressConfig, true)
	H.eq(p.progress.streak, 3)
end)

H.test("invite prompt: after a goal or any 2nd+ match, not only wins", function()
	H.truthy(not ResultRewards.invitePrompt({ won = false }, 1))
	H.truthy(ResultRewards.invitePrompt({ won = false }, 2))
	H.truthy(ResultRewards.invitePrompt({ won = false, mode = "soccer", goals = 1 }, 1))
	H.truthy(not ResultRewards.invitePrompt({ won = true }, 1))
end)

H.test("end screen config: longer than before, with a hard maximum", function()
	H.truthy(LobbyConfig.Rewards.endScreenSeconds > 4)
	H.eq(LobbyConfig.Rewards.endScreenMaxSeconds, 20)
	H.truthy(LobbyConfig.Rewards.endScreenSeconds <= LobbyConfig.Rewards.endScreenMaxSeconds)
end)

-- Claw pity -----------------------------------------------------------------------------

local function fixed(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

local function commonPull(p: Inventory.Profile): Gacha.PullResult
	return Gacha.pull(p :: any, fixed(0, 0)) -- roll 0 = first row (Common), first car
end

H.test("claw pity: the Nth pull without an Epic is an Epic or better", function()
	local every = LobbyConfig.Gacha.pityEvery
	H.eq(every, 10)
	local p = Inventory.default()
	p.coins = 100000
	p.freePullUsed = true
	for i = 1, every - 1 do
		local r = commonPull(p)
		H.eq(LobbyConfig.Rarity[r.carId], "Common", `pull {i}`)
		H.eq(r.pity, i)
		H.eq(r.pityForced, false)
	end
	H.eq(p.progress.gachaPity, every - 1)
	-- the same "lucky Common" roll now cannot land on a Common
	local r = commonPull(p)
	local rarity = LobbyConfig.Rarity[r.carId]
	H.truthy(rarity == "Epic" or rarity == "Legendary", rarity)
	H.truthy(r.pityForced)
	H.eq(r.pity, 0)
	H.eq(p.progress.gachaPity, 0)
end)

H.test("claw pity: a natural Epic resets the counter; odds shown are unchanged", function()
	local p = Inventory.default()
	p.coins = 100000
	p.freePullUsed = true
	for _ = 1, 5 do
		commonPull(p)
	end
	H.eq(p.progress.gachaPity, 5)
	local r = Gacha.pull(p :: any, fixed(0.9, 0)) -- Epic
	H.eq(LobbyConfig.Rarity[r.carId], "Epic")
	H.eq(r.pityForced, false)
	H.eq(p.progress.gachaPity, 0)
	local sum = 0
	for _, row in Gacha.oddsTable() do
		sum += row.percent
	end
	H.eq(sum, 100)
end)

H.test("claw pity: free and gift pulls count; a profile without the counter still works", function()
	local p = { coins = 0, freePullUsed = false, owned = { Sedan = true } }
	local r = Gacha.pull(p :: any, fixed(0, 0))
	H.eq(r.pity, 1)
	local view = Gacha.pityView(p :: any)
	H.eq(view.every, LobbyConfig.Gacha.pityEvery)
	H.eq(view.left, view.every)
	local q = Inventory.default()
	q.progress.gachaPity = 4
	local v = Gacha.pityView(q)
	H.eq(v.count, 4)
	H.eq(v.left, LobbyConfig.Gacha.pityEvery - 4)
end)

H.test("claw pity: saved in the profile and migrated from old saves", function()
	H.eq(Inventory.default().progress.gachaPity, 0)
	H.eq(Inventory.migrate({}).progress.gachaPity, 0) -- old save: no field
	H.eq(Inventory.migrate({ progress = { gachaPity = 7 } }).progress.gachaPity, 7)
	H.eq(Inventory.migrate({ progress = { gachaPity = -3 } }).progress.gachaPity, 0)
	H.eq(Inventory.migrate({ progress = { gachaPity = "x" } }).progress.gachaPity, 0)
	H.eq(Inventory.migrate({ progress = { gachaPity = 1e12 } }).progress.gachaPity, 1000)
	local d = Progress.default()
	d.gachaPity = 6
	H.eq(Progress.copy(d).gachaPity, 6)
end)

H.test("claw odds view: owned cars marked, duplicate refund per rarity", function()
	local p = Inventory.default() -- owns the starter
	local rows = Gacha.oddsView(p)
	H.truthy(#rows >= 1)
	local sawOwned, sawNotOwned = false, false
	for _, row in rows do
		H.eq(row.refund, LobbyConfig.Gacha.duplicateRefunds[row.rarity])
		for _, car in row.cars do
			H.eq(car.owned, p.owned[car.id] == true)
			if car.owned then
				sawOwned = true
			else
				sawNotOwned = true
			end
		end
	end
	H.truthy(sawOwned and sawNotOwned)
	H.eq(LobbyText.refundText(25), "Duplicate = 25 coins back")
	H.eq(LobbyText.pityText(4, "Epic"), "Epic or better in 4 pulls")
	H.eq(LobbyText.pityText(1, "Epic"), "Next pull: Epic or better!")
end)

H.test("labels are text keys: claw = surprise car, store = choose your car", function()
	H.eq(LobbyConfig.Labels.claw, "clawSurprise")
	H.eq(LobbyConfig.Labels.store, "storeChoose")
	H.eq(LobbyText.keyText(LobbyConfig.Labels.claw), "SPIN BOX")
	H.eq(LobbyText.keyText(LobbyConfig.Labels.store), "CHOOSE YOUR CAR")
	H.eq(LobbyText.keyText("nope"), "")
	H.eq(LobbyText.keyText(5), "")
end)

-- Progress / profile data ----------------------------------------------------------------

H.test("xp view: xp into the level and needed for the next", function()
	local d = Progress.default()
	local v = Progress.xpView(d, "Sedan")
	H.eq(v.level, 1)
	H.eq(v.into, 0)
	H.eq(v.needed, ProgressConfig.LevelXp[2])
	d.carXp.Sedan = 20
	v = Progress.xpView(d, "Sedan")
	H.eq(v.into, 20)
	H.eq(v.needed, 50)
	d.carXp.Sedan = 50 -- exactly level 2
	v = Progress.xpView(d, "Sedan")
	H.eq(v.level, 2)
	H.eq(v.into, 0)
	H.eq(v.needed, ProgressConfig.LevelXp[3] - ProgressConfig.LevelXp[2])
	d.carXp.Sedan = 99999
	v = Progress.xpView(d, "Sedan")
	H.truthy(v.maxed)
	H.eq(v.needed, 0)
	H.eq(v.level, #ProgressConfig.LevelXp)
end)

H.test("level bonus text", function()
	local function pct(level: number): string
		return `+{math.floor((level - 1) * ProgressConfig.LevelStatBonus * 100 + 0.5)}% HP and damage`
	end
	H.eq(Progress.bonusText(1), "")
	H.eq(Progress.bonusText(2), pct(2))
	H.eq(Progress.bonusText(3), pct(3))
	H.eq(Progress.bonusText(10), pct(10))
	H.eq(Progress.bonusText(99), pct(10)) -- clamped to the top level
	H.eq(Progress.bonusText(-4), "")
end)

H.test("last played mode and modes played are remembered and cleaned", function()
	local d = Progress.default()
	H.eq(d.lastMode, nil)
	Progress.recordMode(d, "soccer")
	Progress.recordMode(d, "tag")
	Progress.recordMode(d, "nope")
	Progress.recordMode(d, 5)
	H.eq(d.lastMode, "tag")
	H.truthy(d.modesPlayed.soccer and d.modesPlayed.tag)
	H.eq(d.modesPlayed.nope, nil)
	local unplayed = Progress.unplayedModes(d, { "soccer", "tag", "race" })
	H.eq(#unplayed, 1)
	H.eq(unplayed[1], "race")
	-- survives save + load, junk is dropped
	local back = Inventory.migrate({ progress = d }).progress
	H.eq(back.lastMode, "tag")
	H.truthy(back.modesPlayed.soccer)
	local bad = Inventory.migrate({
		progress = { lastMode = "hax", modesPlayed = { hax = true, race = true } },
	})
	H.eq(bad.progress.lastMode, nil)
	H.eq(bad.progress.modesPlayed.hax, nil)
	H.truthy(bad.progress.modesPlayed.race)
	H.eq(Inventory.migrate({}).progress.lastMode, nil)
	H.eq(Progress.copy(d).lastMode, "tag")
	H.truthy(Progress.copy(d).modesPlayed ~= d.modesPlayed) -- a real copy
end)

H.test("daily gift: seconds until the next one", function()
	local d = Daily.default()
	local day = 86400
	local now = 100 * day + 3600
	H.eq(Daily.secondsUntilNext(d, now), 0) -- waiting to be claimed
	Daily.claim(d, now)
	H.eq(Daily.secondsUntilNext(d, now), day - 3600)
	H.eq(Daily.secondsUntilNext(d, 101 * day - 1), 1)
	H.eq(Daily.secondsUntilNext(d, 101 * day), 0)
end)

H.test("menu unlock notice shows once QUESTS and GARAGE appear", function()
	H.truthy(not MenuRules.unlockNotice({ matches = 0 }, {}))
	H.truthy(not MenuRules.unlockNotice({ matches = 1 }, {}))
	H.truthy(MenuRules.unlockNotice({ matches = 2 }, {}))
	H.truthy(MenuRules.unlockNotice({ matches = 2 }, nil))
	H.truthy(not MenuRules.unlockNotice({ matches = 2 }, { unlock = true }))
	H.truthy(not MenuRules.unlockNotice({ matches = 9 }, { unlock = true }))
	H.truthy(MenuRules.unlockNotice({ matches = 9 }, { soccer = true }))
end)

-- Bots and pick step ----------------------------------------------------------------------

H.test("bot level: first 2 matches are always easy, then by wins / choice", function()
	H.eq(BotLevels.levelForPlayer(0, 0, nil, false), "easy")
	H.eq(BotLevels.levelForPlayer(1, 50, "hard", true), "easy") -- even if they picked hard
	H.eq(BotLevels.levelForPlayer(2, 0, nil, false), "easy") -- 0 wins -> easy by wins
	H.eq(BotLevels.levelForPlayer(2, 5, nil, false), "medium")
	H.eq(BotLevels.levelForPlayer(30, 50, nil, false), "hard")
	H.eq(BotLevels.levelForPlayer(30, 50, "easy", true), "easy")
	H.eq(BotLevels.levelForPlayer("x", 50, nil, false), "easy") -- junk matches count as 0
end)

H.test("bot level: the weakest level of the humans wins", function()
	H.eq(BotLevels.weakest({ "hard", "easy" }), "easy")
	H.eq(BotLevels.weakest({ "hard", "medium" }), "medium")
	H.eq(BotLevels.weakest({ "hard" }), "hard")
	H.eq(BotLevels.weakest({}), "medium")
	H.eq(BotLevels.weakest({ "nope" }), "medium")
end)

H.test("pick step is skipped when fewer than 2 cars are owned", function()
	H.truthy(PadLogic.shouldSkipPick(0))
	H.truthy(PadLogic.shouldSkipPick(1))
	H.truthy(not PadLogic.shouldSkipPick(2))
	H.truthy(not PadLogic.shouldSkipPick(12))
	local p = Inventory.default()
	H.eq(#Inventory.ownedList(p), 1) -- a new player: the pick screen is skipped
end)

-- Next goal and session summary -------------------------------------------------------------

local function cheapestUnowned(owned: { [string]: boolean }): string
	local best: string? = nil
	for _, id in CarConfig.Order do
		if not owned[id] and (best == nil or Store.price(id) < Store.price(best)) then
			best = id
		end
	end
	return best :: string
end

H.test("next goal: first match, then closest car or an unplayed mode", function()
	local owned = { Sedan = true }
	local g = NextGoal.compute({ matches = 0, coins = 0, owned = owned, modesPlayed = {} })
	H.eq(g.kind, "firstMatch")
	H.eq(g.text, "Step on a blue pad to play")

	local car = cheapestUnowned(owned)
	local price = Store.price(car)
	local name = CarConfig.Cars[car].name
	-- close to a car: the car goal with the coins missing
	g = NextGoal.compute({ matches = 3, coins = price - 40, owned = owned, modesPlayed = {} })
	H.eq(g.kind, "car")
	H.eq(g.text, `Next: {name} - 40 coins away`)
	H.eq(g.missing, 40)
	-- can afford it now
	g = NextGoal.compute({ matches = 3, coins = price + 5, owned = owned, modesPlayed = {} })
	H.eq(g.text, `Next: {name} - you can buy it now!`)
	-- far from any car and a mode not played yet: suggest the mode
	g = NextGoal.compute(
		{ matches = 3, coins = 0, owned = owned, modesPlayed = { soccer = true } },
		nil,
		{ "soccer", "tag" }
	)
	H.eq(g.kind, "mode")
	H.eq(g.text, "Try Car Tag (not played yet)")
	-- every mode played: back to the car
	g = NextGoal.compute(
		{ matches = 3, coins = 0, owned = owned, modesPlayed = { soccer = true, tag = true } },
		nil,
		{ "soccer", "tag" }
	)
	H.eq(g.kind, "car")
	-- owns everything and played everything
	local all: { [string]: boolean } = {}
	for _, id in CarConfig.Order do
		all[id] = true
	end
	g = NextGoal.compute(
		{ matches = 9, coins = 0, owned = all, modesPlayed = { soccer = true } },
		nil,
		{ "soccer" }
	)
	H.eq(g.kind, "done")
end)

H.test("session summary adds up matches, coins and goals", function()
	local s = SessionSummary.new()
	H.eq(s.matches, 0)
	SessionSummary.record(s, true, 80, 2)
	SessionSummary.record(s, false, 25, nil)
	SessionSummary.record(s, false, "x", -3)
	local v = SessionSummary.view(s, "Next: Kart - 10 coins away")
	H.eq(v.matches, 3)
	H.eq(v.coinsEarned, 105)
	H.eq(v.goals, 2)
	H.eq(v.wins, 1)
	H.eq(v.nextGoal, "Next: Kart - 10 coins away")
	H.eq(SessionSummary.view(s, nil).nextGoal, "")
end)

H.test("quest rewards stay small compared to a win", function()
	for _, def in QuestsConfig.Catalog do
		H.truthy(def.reward <= LobbyConfig.Rewards.winCoins, def.id)
	end
end)

H.test("bots get harder as the player level rises", function()
	H.eq(BotLevels.forPlayerLevel(1), "easy")
	H.eq(BotLevels.forPlayerLevel(5), "medium")
	H.eq(BotLevels.forPlayerLevel(20), "hard")
	H.eq(BotLevels.forPlayerLevel("x"), "easy")
	H.eq(BotLevels.levelForPlayer(10, 0, nil, false, 20), "hard")
	H.eq(BotLevels.levelForPlayer(1, 0, nil, false, 20), "easy") -- first matches stay easy
	H.eq(BotLevels.levelForPlayer(10, 0, "easy", true, 20), "easy") -- button choice wins
end)
