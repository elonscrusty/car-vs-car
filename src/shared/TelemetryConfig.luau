--!strict
-- Analytics numbers and names. Funnel order and custom-event schema live here; logic is in
-- TelemetryRules. Funnel names show on the Creator Dashboard, so renaming one starts a new step.

local TelemetryConfig = {}

-- Funnel steps, in order. Step number = position in this list.
TelemetryConfig.Steps = {
	"joined",
	"stepped_on_pad",
	"launched",
	"first_hit",
	"finished_first_match",
	"saw_end_screen",
	"started_second_match",
	"opened_claw",
} :: { string }

-- Custom events (Roblox allows 100 per game). `value` names the numeric data field (or nil);
-- `fields` lists up to 3 string fields, mapped in order to CustomField01..03.
export type EventSchema = { value: string?, fields: { string } }
TelemetryConfig.Events = {
	match_end = { value = "seconds", fields = { "mode", "won", "vs_bot" } },
	claw_pull = { value = nil, fields = {} },
	rematch_tapped = { value = nil, fields = {} },
	quit_during_match = { value = "seconds", fields = { "mode" } },
	time_to_first_hit = { value = "seconds", fields = { "mode" } },
} :: { [string]: EventSchema }

TelemetryConfig.MaxFieldLength = 40 -- characters kept per custom field value
TelemetryConfig.MaxValue = 86400 -- numeric values are clamped to 0..this
-- Global send cap (PLACEHOLDER; Roblox does not publish its limit): events per window, per server.
TelemetryConfig.RateLimit = { maxEvents = 200, windowSeconds = 60 }

return TelemetryConfig
