--!strict
-- Roblox analytics (review item M3). Server only. Every call is wrapped in pcall, deferred so it
-- can never hold up the game, skipped in Studio (Roblox only accepts events from published
-- games), and capped by TelemetryRules.allow. Funnel: AnalyticsService:LogOnboardingFunnelStepEvent
-- (player, step, name). Custom events: AnalyticsService:LogCustomEvent(player, name, value?,
-- customFields?) with fields keyed CustomField01..03 and string values.
-- Table of events and what a bad number means: docs/analytics.md

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TelemetryRules = require(ReplicatedStorage.Shared.TelemetryRules)

type Active = {
	startedAt: number,
	mode: string,
	vsBot: boolean,
	launchedAt: number?,
	hit: boolean,
	scored: boolean,
	eliminatedAt: number?,
}

local state = TelemetryRules.new()
local active: { [Player]: Active } = {} -- the match this player is in (until the end screen)
local joinedAt: { [Player]: number } = {}
local lastMode: { [Player]: string } = {} -- mode of the player's latest match (for rematch_tapped)
local enabled = not RunService:IsStudio()

local Telemetry = {}

local function send(fn: () -> ())
	if not enabled or not TelemetryRules.allow(state, os.clock()) then
		return
	end
	task.defer(function()
		pcall(fn)
	end)
end

local function step(player: Player, name: string)
	local n = TelemetryRules.claimStep(state, player.UserId, name)
	if n then
		send(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, n, name)
		end)
	end
end

local function event(player: Player, name: string, data: { [string]: any }?)
	local ev = TelemetryRules.buildEvent(name, data)
	if ev == nil then
		return
	end
	send(function()
		AnalyticsService:LogCustomEvent(player, ev.name, ev.value, ev.fields)
	end)
end

function Telemetry.joined(player: Player)
	joinedAt[player] = os.clock()
	step(player, "joined")
end

-- First steer/move input of the visit (call on every input; only the first one logs).
function Telemetry.firstInput(player: Player)
	local t = joinedAt[player]
	if t == nil then
		return
	end
	local n = TelemetryRules.claimStep(state, player.UserId, "first_input")
	if n then
		send(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, n, "first_input")
		end)
		event(player, "first_input", { seconds = os.clock() - t })
	end
end

-- First goal (soccer), tag (tag) or finish (race) of the visit. kind: goal, tag or finish.
function Telemetry.firstScore(player: Player, kind: string)
	local a = active[player]
	if a and not a.scored then
		a.scored = true
		step(player, "first_score")
		event(player, "first_score", {
			seconds = os.clock() - a.startedAt,
			mode = a.mode,
			kind = kind,
		})
	end
end

-- The player was eliminated (tag, last standing) but the match goes on without them.
function Telemetry.eliminated(player: Player)
	local a = active[player]
	if a and a.eliminatedAt == nil then
		a.eliminatedAt = os.clock()
	end
end

function Telemetry.padStepped(player: Player)
	step(player, "stepped_on_pad")
end

-- A match begins for these players. Group modes have no aiming, so they count as launched now.
function Telemetry.matchStarted(players: { { player: Player } }, mode: string, isGroup: boolean)
	local now = os.clock()
	for _, part in players do
		local p = part.player
		active[p] = {
			startedAt = now,
			mode = mode,
			vsBot = #players == 1,
			launchedAt = if isGroup then now else nil,
			hit = false,
			scored = false,
		}
		lastMode[p] = mode
		if TelemetryRules.countMatch(state, p.UserId) == 2 then
			step(p, "started_second_match")
		end
		if isGroup then
			step(p, "launched")
		end
	end
end

function Telemetry.launched(player: Player)
	local a = active[player]
	if a and a.launchedAt == nil then
		a.launchedAt = os.clock()
	end
	step(player, "launched")
end

-- First damage of a match, for the players in it.
function Telemetry.hit(players: { { player: Player } })
	local now = os.clock()
	for _, part in players do
		local a = active[part.player]
		if a and not a.hit then
			a.hit = true
			step(part.player, "first_hit")
			event(part.player, "time_to_first_hit", {
				seconds = now - (a.launchedAt or a.startedAt),
				mode = a.mode,
			})
		end
	end
end

-- The win/lose screen went up.
function Telemetry.endScreen(player: Player)
	step(player, "saw_end_screen")
end

-- The player stayed through the end screen: the match is finished.
-- `result` is optional and read defensively: place, goals, tags, survivedSeconds (group modes).
function Telemetry.matchEnded(player: Player, won: boolean, result: any?)
	local a = active[player]
	active[player] = nil
	if a == nil then
		return
	end
	step(player, "finished_first_match")
	event(player, "match_end", {
		seconds = os.clock() - a.startedAt,
		mode = a.mode,
		won = won,
		vs_bot = a.vsBot,
	})
	if result ~= nil then
		local r = TelemetryRules.readResult(result)
		event(player, "match_result", {
			seconds = os.clock() - a.startedAt,
			mode = a.mode,
			place = if r.place then math.floor(r.place) else "",
			score = if r.score then math.floor(r.score) else "",
		})
		if r.survivedSeconds then
			event(player, "tag_survived", { seconds = r.survivedSeconds, mode = a.mode })
		end
	end
end

function Telemetry.rematchTapped(player: Player)
	local a = active[player]
	event(player, "rematch_tapped", { mode = if a then a.mode else lastMode[player] })
end

-- source: "claw" (default) or "store". Only a claw pull counts as opening the claw.
function Telemetry.clawPull(player: Player, source: string?)
	step(player, "opened_claw")
	event(player, "claw_pull", { source = source or "claw" })
end

-- A car was obtained: from the claw or bought in the store.
function Telemetry.carAcquired(player: Player, source: string)
	event(player, "car_acquired", { source = source })
end

-- The player picked a lobby mode with the MODE button (name is checked against a fixed list).
function Telemetry.modePicked(player: Player, mode: string)
	event(player, "mode_picked", { mode = mode })
end

-- The player tapped LOBBY to leave a match. phase: pad, pick, aim, fight or end (fixed list).
-- seconds = time since their match started (0 when no match is running yet).
function Telemetry.leftMatch(player: Player, phase: string)
	local a = active[player]
	event(player, "left_match", {
		phase = phase,
		seconds = if a then os.clock() - a.startedAt else 0,
	})
end

-- Player leaves the server. Mid-match counts as a quit. Frees their records.
function Telemetry.left(player: Player)
	local a = active[player]
	active[player] = nil
	joinedAt[player] = nil
	lastMode[player] = nil
	if a then
		local now = os.clock()
		event(player, "quit_during_match", { seconds = now - a.startedAt, mode = a.mode })
		if a.eliminatedAt then
			event(
				player,
				"quit_after_elimination",
				{ seconds = now - a.eliminatedAt, mode = a.mode }
			)
		end
	end
	TelemetryRules.clear(state, player.UserId)
end

return Telemetry
