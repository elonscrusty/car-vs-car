--!strict
-- Analytics numbers and names. Funnel order and custom-event schema live here; logic is in
-- TelemetryRules. Funnel names show on the Creator Dashboard, so renaming one starts a new step.

local TelemetryConfig = {}

-- Funnel steps, in order. Step number = position in this list. "launched" = the first fight starts.
TelemetryConfig.Steps = {
	"joined",
	"stepped_on_pad",
	"launched", -- a fight starts (3-2-1 over, the first round begins)
	"first_hit", -- first damage in a fight
	"finished_first_match", -- stayed through to the result of a whole match
	"started_second_match",
	"opened_gumball", -- first gumball pull
} :: { string }

-- Where the match was when a player left: car pick, 3-2-1, a round running, between rounds, the result screen,
-- or they left the server without the match noticing ("server").
TelemetryConfig.FightPhases =
	{ "select", "prep", "fight", "result", "matchResult", "server" } :: { string }
-- Where a car came from: the gumball machine or the car store.
TelemetryConfig.Sources = { "gumball", "store" } :: { string }

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
	-- a fight (a whole match, rounds included) begins: car = the player's car id
	fight_start = { value = nil, fields = { "car", "vs_bot" } },
	-- a fight finished: seconds = time since fight_start, rounds = rounds played
	fight_end = { value = "seconds", fields = { "car", "won", "rounds" } },
	-- the player left before the match finished: seconds since fight_start, phase = where it was
	quit_during_fight = {
		value = "seconds",
		fields = { "phase" },
		allowed = { phase = TelemetryConfig.FightPhases },
	},
	-- seconds from the first round starting to the first damage
	time_to_first_hit = { value = "seconds", fields = { "car" } },
	-- a gumball pull; car_acquired = a car obtained from the gumball machine or bought in the store
	gumball_pull = { value = nil, fields = {} },
	car_acquired = {
		value = nil,
		fields = { "source" },
		allowed = { source = TelemetryConfig.Sources },
	},
	-- the first-time tutorial (docs/LOBBY_POLISH.md): it started (first = true for a new player,
	-- false for a replay from Settings), the seconds a player spent in the practice yard, and it was
	-- played to the end (seconds since it started; gift = the coin gift was paid)
	tutorial_start = {
		value = nil,
		fields = { "first" },
		allowed = { first = { "true", "false" } },
	},
	tutorial_practice = { value = "seconds", fields = {} },
	tutorial_done = {
		value = "seconds",
		fields = { "gift" },
		allowed = { gift = { "true", "false" } },
	},
} :: { [string]: EventSchema }

TelemetryConfig.MaxFieldLength = 40 -- characters kept per custom field value
TelemetryConfig.MaxValue = 86400 -- numeric values are clamped to 0..this
-- Global send cap (PLACEHOLDER; Roblox does not publish its limit): events per window, per server.
TelemetryConfig.RateLimit = { maxEvents = 200, windowSeconds = 60 }

return TelemetryConfig
