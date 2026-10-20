--!strict
local Harness = require("./harness")
local TelemetryConfig = require("../src/shared/TelemetryConfig")
local TelemetryRules = require("../src/shared/TelemetryRules")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")

local test, eq = Harness.test, Harness.eq

print("Telemetry rules")

test("funnel has the 7 steps in the agreed order", function()
	local want = {
		"joined",
		"stepped_on_pad",
		"launched",
		"first_hit",
		"finished_first_match",
		"started_second_match",
		"opened_gumball",
	}
	eq(#TelemetryConfig.Steps, 7)
	for i, name in want do
		eq(TelemetryRules.stepNumber(name), i)
	end
	eq(TelemetryRules.stepNumber("nope"), nil)
	eq(TelemetryRules.stepNumber("opened_claw"), nil)
end)

test("a step is claimed once per player", function()
	local s = TelemetryRules.new()
	eq(TelemetryRules.claimStep(s, 1, "launched"), 3)
	eq(TelemetryRules.claimStep(s, 1, "launched"), nil)
	eq(TelemetryRules.claimStep(s, 2, "launched"), 3)
	eq(TelemetryRules.claimStep(s, 1, "bogus"), nil)
end)

test("clear lets a player claim again", function()
	local s = TelemetryRules.new()
	TelemetryRules.claimStep(s, 1, "joined")
	TelemetryRules.clear(s, 1)
	eq(TelemetryRules.claimStep(s, 1, "joined"), 1)
end)

test("match counter reaches 2 on the second match", function()
	local s = TelemetryRules.new()
	eq(TelemetryRules.countMatch(s, 7), 1)
	eq(TelemetryRules.countMatch(s, 7), 2)
	eq(TelemetryRules.countMatch(s, 8), 1)
end)

test("sanitizeField strips odd characters and caps length", function()
	eq(TelemetryRules.sanitizeField("hill<>;!"), "hill")
	eq(TelemetryRules.sanitizeField(true), "true")
	eq(TelemetryRules.sanitizeField(12), "12")
	eq(#TelemetryRules.sanitizeField(string.rep("a", 500)), TelemetryConfig.MaxFieldLength)
end)

test("fight_end carries seconds and car, won, rounds", function()
	local ev = TelemetryRules.buildEvent(
		"fight_end",
		{ seconds = 42.5, car = "RamTruck", won = true, rounds = 3 }
	)
	assert(ev)
	eq(ev.value, 42.5)
	local f = assert(ev.fields)
	eq(f.CustomField01, "RamTruck")
	eq(f.CustomField02, "true")
	eq(f.CustomField03, "3")
end)

test("fight_start carries the car and whether the foe was a bot, with no value", function()
	local ev =
		assert(TelemetryRules.buildEvent("fight_start", { car = "CannonVan", vs_bot = false }))
	eq(ev.value, nil)
	eq(assert(ev.fields).CustomField01, "CannonVan")
	eq(assert(ev.fields).CustomField02, "false")
end)

test("values are clamped and bad numbers become 0", function()
	local a = assert(TelemetryRules.buildEvent("fight_end", { seconds = -5 }))
	eq(a.value, 0)
	local b = assert(TelemetryRules.buildEvent("fight_end", { seconds = 1e12 }))
	eq(b.value, TelemetryConfig.MaxValue)
	local c = assert(TelemetryRules.buildEvent("fight_end", { seconds = 0 / 0 }))
	eq(c.value, 0)
	local d = assert(TelemetryRules.buildEvent("fight_end", { seconds = "x" }))
	eq(d.value, 0)
end)

test("quit_during_fight carries seconds and an allowlisted phase", function()
	for _, p in TelemetryConfig.FightPhases do
		local ev =
			assert(TelemetryRules.buildEvent("quit_during_fight", { phase = p, seconds = 12 }))
		eq(ev.value, 12)
		eq(assert(ev.fields).CustomField01, p)
	end
	local bad = assert(
		TelemetryRules.buildEvent("quit_during_fight", { phase = "Bob<script>", seconds = 3 })
	)
	eq(assert(bad.fields).CustomField01, "other")
end)

test("time_to_first_hit has seconds and the car; gumball_pull has no fields", function()
	local ev =
		assert(TelemetryRules.buildEvent("time_to_first_hit", { seconds = 9, car = "SawBuggy" }))
	eq(ev.value, 9)
	eq(assert(ev.fields).CustomField01, "SawBuggy")
	local g = assert(TelemetryRules.buildEvent("gumball_pull", nil))
	eq(g.value, nil)
	eq(g.fields, nil)
end)

test("cars come from the gumball machine or the store; anything else is other", function()
	for _, src in TelemetryConfig.Sources do
		eq(
			assert(assert(TelemetryRules.buildEvent("car_acquired", { source = src })).fields).CustomField01,
			src
		)
	end
	eq(
		assert(assert(TelemetryRules.buildEvent("car_acquired", { source = "claw" })).fields).CustomField01,
		"other"
	)
end)

test("tutorial events: start says first or replay, practice and done carry seconds", function()
	local start = assert(TelemetryRules.buildEvent("tutorial_start", { first = true }))
	eq(start.value, nil)
	eq(assert(start.fields).CustomField01, "true")
	eq(
		assert(assert(TelemetryRules.buildEvent("tutorial_start", { first = false })).fields).CustomField01,
		"false"
	)
	-- anything else a client could influence becomes "other"
	eq(
		assert(assert(TelemetryRules.buildEvent("tutorial_start", { first = "maybe" })).fields).CustomField01,
		"other"
	)
	local practice = assert(TelemetryRules.buildEvent("tutorial_practice", { seconds = 41.5 }))
	eq(practice.value, 41.5)
	eq(practice.fields, nil)
	local done = assert(TelemetryRules.buildEvent("tutorial_done", { seconds = 73, gift = true }))
	eq(done.value, 73)
	eq(assert(done.fields).CustomField01, "true")
	local noGift =
		assert(TelemetryRules.buildEvent("tutorial_done", { seconds = 900000, gift = false }))
	eq(noGift.value, TelemetryConfig.MaxValue, "seconds are clamped")
	eq(assert(noGift.fields).CustomField01, "false")
end)

test("old mode events are gone", function()
	for _, name in
		{
			"match_end",
			"match_result",
			"first_score",
			"mode_picked",
			"left_match",
			"rematch_tapped",
			"claw_pull",
		}
	do
		eq(TelemetryRules.buildEvent(name, {}), nil)
	end
end)

test("unknown event names are rejected", function()
	eq(TelemetryRules.buildEvent("made_up", {}), nil)
end)

test("every schema has at most 3 fields and a known value or none", function()
	for name, schema in TelemetryConfig.Events do
		assert(#schema.fields <= 3, name)
		assert(TelemetryRules.buildEvent(name, {}) ~= nil, name)
	end
end)

test("global cap blocks after maxEvents and frees after the window", function()
	local s = TelemetryRules.new()
	local cfg = TelemetryConfig.RateLimit
	for _ = 1, cfg.maxEvents do
		eq(TelemetryRules.allow(s, 0), true)
	end
	eq(TelemetryRules.allow(s, 1), false)
	eq(TelemetryRules.allow(s, cfg.windowSeconds + 1), true)
end)

test("allowlists are short, clean and fit the field cap", function()
	for _, list in { TelemetryConfig.FightPhases, TelemetryConfig.Sources } do
		for _, v in list do
			eq(TelemetryRules.sanitizeField(v), v)
			assert(#v <= TelemetryConfig.MaxFieldLength)
		end
	end
end)

print("Claw double-pull protection (audit #104)")

test("exactly one claw price: a second pull right after the first is refused", function()
	local p = Inventory.default()
	p.freePullUsed = true
	if p.daily then
		p.daily.freePulls = 0
	end
	p.coins = LobbyConfig.Gacha.price
	local can = Gacha.canBuy(p)
	eq(can, true)
	Gacha.pull(p, function()
		return 0.99
	end)
	-- Whatever the prize (a duplicate refund is below the price), a second pull is not allowed.
	assert(p.coins < LobbyConfig.Gacha.price, "refund must stay below the price")
	eq((Gacha.canBuy(p)), false)
	local ok = pcall(Gacha.pull, p, function()
		return 0
	end)
	eq(ok, false)
	assert(p.coins >= 0, "coins never go negative")
end)
