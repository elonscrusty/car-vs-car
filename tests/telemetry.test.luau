--!strict
local Harness = require("./harness")
local TelemetryConfig = require("../src/shared/TelemetryConfig")
local TelemetryRules = require("../src/shared/TelemetryRules")

local test, eq = Harness.test, Harness.eq

print("Telemetry rules")

test("funnel has the 8 steps in the agreed order", function()
	local want = {
		"joined",
		"stepped_on_pad",
		"launched",
		"first_hit",
		"finished_first_match",
		"saw_end_screen",
		"started_second_match",
		"opened_claw",
	}
	eq(#TelemetryConfig.Steps, 8)
	for i, name in want do
		eq(TelemetryRules.stepNumber(name), i)
	end
	eq(TelemetryRules.stepNumber("nope"), nil)
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

test("match_end carries seconds and 3 string fields", function()
	local ev = TelemetryRules.buildEvent(
		"match_end",
		{ seconds = 42.5, mode = "ice", won = true, vs_bot = false }
	)
	assert(ev)
	eq(ev.value, 42.5)
	local f = assert(ev.fields)
	eq(f.CustomField01, "ice")
	eq(f.CustomField02, "true")
	eq(f.CustomField03, "false")
end)

test("values are clamped and bad numbers become 0", function()
	local a = assert(TelemetryRules.buildEvent("match_end", { seconds = -5 }))
	eq(a.value, 0)
	local b = assert(TelemetryRules.buildEvent("match_end", { seconds = 1e12 }))
	eq(b.value, TelemetryConfig.MaxValue)
	local c = assert(TelemetryRules.buildEvent("match_end", { seconds = 0 / 0 }))
	eq(c.value, 0)
	local d = assert(TelemetryRules.buildEvent("match_end", { seconds = "x" }))
	eq(d.value, 0)
end)

test("counter events have no value and no fields", function()
	local ev = assert(TelemetryRules.buildEvent("claw_pull", {}))
	eq(ev.value, nil)
	eq(ev.fields, nil)
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

test("mode_picked keeps only allowlisted mode names", function()
	for _, m in TelemetryConfig.Modes do
		local ev = assert(TelemetryRules.buildEvent("mode_picked", { mode = m }))
		eq(ev.value, nil)
		eq(assert(ev.fields).CustomField01, m)
	end
	local bad = assert(TelemetryRules.buildEvent("mode_picked", { mode = "my secret room" }))
	eq(assert(bad.fields).CustomField01, "other")
	local missing = assert(TelemetryRules.buildEvent("mode_picked", {}))
	eq(assert(missing.fields).CustomField01, "other")
end)

test("left_match carries seconds and an allowlisted phase", function()
	for _, p in TelemetryConfig.LeavePhases do
		local ev = assert(TelemetryRules.buildEvent("left_match", { phase = p, seconds = 12 }))
		eq(ev.value, 12)
		eq(assert(ev.fields).CustomField01, p)
	end
	local bad =
		assert(TelemetryRules.buildEvent("left_match", { phase = "Bob<script>", seconds = 3 }))
	eq(assert(bad.fields).CustomField01, "other")
	local huge =
		assert(TelemetryRules.buildEvent("left_match", { phase = "fight", seconds = 1e12 }))
	eq(huge.value, TelemetryConfig.MaxValue)
end)

test("allowlists are short, clean and fit the field cap", function()
	for _, list in { TelemetryConfig.Modes, TelemetryConfig.LeavePhases } do
		for _, v in list do
			eq(TelemetryRules.sanitizeField(v), v)
			assert(#v <= TelemetryConfig.MaxFieldLength)
		end
	end
	assert(table.find(TelemetryConfig.Modes, "soccer") ~= nil)
end)
