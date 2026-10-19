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
}

local state = TelemetryRules.new()
local active: { [Player]: Active } = {} -- the match this player is in (until the end screen)
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
	step(player, "joined")
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
		}
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
function Telemetry.matchEnded(player: Player, won: boolean)
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
end

function Telemetry.rematchTapped(player: Player)
	event(player, "rematch_tapped")
end

function Telemetry.clawPull(player: Player)
	step(player, "opened_claw")
	event(player, "claw_pull")
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
	if a then
		event(player, "quit_during_match", { seconds = os.clock() - a.startedAt, mode = a.mode })
	end
	TelemetryRules.clear(state, player.UserId)
end

return Telemetry
