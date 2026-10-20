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
	car: string,
	vsBot: boolean,
	hit: boolean,
}

local state = TelemetryRules.new()
local active: { [Player]: Active } = {} -- the fight this player is in (until its result)
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

-- A fight (a whole match) begins for these players: the first round just started. `car` = their car id.
function Telemetry.fightStarted(players: { { player: Player, car: string } }, vsBot: boolean)
	local now = os.clock()
	for _, part in players do
		local p = part.player
		active[p] = { startedAt = now, car = part.car, vsBot = vsBot, hit = false }
		if TelemetryRules.countMatch(state, p.UserId) == 2 then
			step(p, "started_second_match")
		end
		step(p, "launched")
		event(p, "fight_start", { car = part.car, vs_bot = vsBot })
	end
end

-- First damage of a fight, for the players in it.
function Telemetry.hit(players: { Player })
	local now = os.clock()
	for _, p in players do
		local a = active[p]
		if a and not a.hit then
			a.hit = true
			step(p, "first_hit")
			event(p, "time_to_first_hit", { seconds = now - a.startedAt, car = a.car })
		end
	end
end

-- The whole match is decided and the player stayed for the result.
function Telemetry.fightEnded(player: Player, won: boolean, rounds: number)
	local a = active[player]
	active[player] = nil
	if a == nil then
		return
	end
	step(player, "finished_first_match")
	event(player, "fight_end", {
		seconds = os.clock() - a.startedAt,
		car = a.car,
		won = won,
		rounds = rounds,
	})
end

-- The player left before the match finished. phase: where the match was (TelemetryConfig.FightPhases).
-- Only counts once a fight had started for them.
function Telemetry.fightQuit(player: Player, phase: string)
	local a = active[player]
	active[player] = nil
	if a then
		event(player, "quit_during_fight", { seconds = os.clock() - a.startedAt, phase = phase })
	end
end

-- A gumball pull. Only a pull counts as opening the gumball machine.
function Telemetry.gumballPull(player: Player)
	step(player, "opened_gumball")
	event(player, "gumball_pull", nil)
end

-- A car was obtained: from the gumball machine or bought in the store.
function Telemetry.carAcquired(player: Player, source: string)
	event(player, "car_acquired", { source = source })
end

-- Player leaves the server. Mid-fight counts as a quit. Frees their records.
function Telemetry.left(player: Player)
	Telemetry.fightQuit(player, "server")
	TelemetryRules.clear(state, player.UserId)
end

return Telemetry
