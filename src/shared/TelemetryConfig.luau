--!strict
-- Analytics numbers and names. Funnel order and custom-event schema live here; logic is in
-- TelemetryRules. Funnel names show on the Creator Dashboard, so renaming one starts a new step.

local TelemetryConfig = {}

-- Funnel steps, in order. Step number = position in this list.
TelemetryConfig.Steps = {
	"joined",
	"first_input", -- first steer/move input (audit G: time from join to first input)
	"stepped_on_pad",
	"launched",
	"first_hit",
	"first_score", -- first goal (soccer), first tag (tag) or finish line (race) of the visit
	"finished_first_match",
	"saw_end_screen",
	"started_second_match",
	"opened_claw",
} :: { string }

-- Fixed lists for the mode_picked / left_match fields. Mode names match the lobby MODE button.
TelemetryConfig.Modes = {
	"auto",
	"duel",
	"hill",
	"ice",
	"soccer",
	"tag",
	"race",
	"lastStanding",
} :: { string }
-- Where LOBBY was tapped: waiting at the pad, picking a car, aiming/countdown, mid-fight, end screen.
TelemetryConfig.LeavePhases = { "pad", "pick", "aim", "fight", "end" } :: { string }
-- Where a car came from: the claw machine or the car store.
TelemetryConfig.Sources = { "claw", "store" } :: { string }
-- What counted as the first score: soccer goal, a tag, a race finish.
TelemetryConfig.ScoreKinds = { "goal", "tag", "finish" } :: { string }

-- Custom events (Roblox allows 100 per game). `value` names the numeric data field (or nil);
-- `fields` lists up to 3 string fields, mapped in order to CustomField01..03.
-- `allowed` (optional) maps a field name to the only values it may carry; anything else becomes
-- "other", so player-influenced text can never reach analytics.
export type EventSchema = {
	value: string?,
	fields: { string },
	allowed: { [string]: { string } }?,
}
TelemetryConfig.Events = {
	match_end = { value = "seconds", fields = { "mode", "won", "vs_bot" } },
	-- Per-mode result (audit #108/#111): place 1..6 ("" if unknown), score = goals (soccer) or
	-- tags (tag). Group modes only; fields come from the match result and may be missing.
	match_result = { value = "seconds", fields = { "mode", "place", "score" } },
	tag_survived = { value = "seconds", fields = { "mode" } },
	-- claw_pull = a pull; car_acquired = a car obtained from the claw or bought in the store.
	claw_pull = {
		value = nil,
		fields = { "source" },
		allowed = { source = TelemetryConfig.Sources },
	},
	car_acquired = {
		value = nil,
		fields = { "source" },
		allowed = { source = TelemetryConfig.Sources },
	},
	-- mode = the mode that was just played (so a per-mode rematch rate can be read).
	rematch_tapped = { value = nil, fields = { "mode" } },
	-- first goal / tag / finish: seconds since the match started.
	first_score = {
		value = "seconds",
		fields = { "mode", "kind" },
		allowed = { kind = TelemetryConfig.ScoreKinds },
	},
	-- seconds from joining the server to the first steer/move input.
	first_input = { value = "seconds", fields = {} },
	quit_during_match = { value = "seconds", fields = { "mode" } },
	-- player left after being eliminated and before the match ended; seconds = time since the
	-- elimination (dead time that lost them).
	quit_after_elimination = { value = "seconds", fields = { "mode" } },
	time_to_first_hit = { value = "seconds", fields = { "mode" } },
	mode_picked = {
		value = nil,
		fields = { "mode" },
		allowed = { mode = TelemetryConfig.Modes },
	},
	left_match = {
		value = "seconds",
		fields = { "phase" },
		allowed = { phase = TelemetryConfig.LeavePhases },
	},
} :: { [string]: EventSchema }

TelemetryConfig.MaxFieldLength = 40 -- characters kept per custom field value
TelemetryConfig.MaxValue = 86400 -- numeric values are clamped to 0..this
-- Global send cap (PLACEHOLDER; Roblox does not publish its limit): events per window, per server.
TelemetryConfig.RateLimit = { maxEvents = 200, windowSeconds = 60 }

return TelemetryConfig
