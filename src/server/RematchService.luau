--!strict
-- Server state for "REMATCH" on the end screen (rules live in the pure module Rematch).
-- init.server calls: begin (match starts), open (end screen up), tap (client request),
-- settle (a player's end screen is over), finish (that player left the old match), remove (left game).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rematch = require(ReplicatedStorage.Shared.Rematch)

export type Handle = {
	begin: (parts: { any }) -> (),
	open: (player: Player) -> (),
	tap: (player: Player) -> boolean,
	-- Closes the window (first call per match) and says if this player stays for a rematch.
	settle: (player: Player) -> boolean,
	-- The player is out of the old match; the last one out gets back the participants to restart.
	finish: (player: Player) -> { any }?,
	-- The player left the game; may hand back the participants to restart (stayers already told).
	remove: (player: Player) -> { any }?,
}

type Record = {
	state: Rematch.State,
	parts: { any },
	pending: { [Player]: boolean }, -- humans whose end screen is not settled yet
	decision: Rematch.Decision?,
}

local RematchService = {}

function RematchService.new(): Handle
	local records: { [Player]: Record } = {}

	local function drop(rec: Record)
		for _, key in rec.state.players do
			if records[key :: Player] == rec then
				records[key :: Player] = nil
			end
		end
	end

	local function restartParts(rec: Record): { any }?
		if next(rec.pending) ~= nil then
			return nil
		end
		drop(rec)
		if rec.decision == "start" then
			return rec.parts
		end
		return nil
	end

	local handle: Handle = {
		begin = function(parts: { any })
			local players: { any } = {}
			local pending: { [Player]: boolean } = {}
			for _, part in parts do
				table.insert(players, part.player)
				pending[part.player] = true
			end
			local rec: Record =
				{ state = Rematch.new(players), parts = parts, pending = pending, decision = nil }
			for _, player in players do
				records[player :: Player] = rec
			end
		end,
		open = function(player: Player)
			local rec = records[player]
			if rec and rec.decision == nil then
				Rematch.openWindow(rec.state)
			end
		end,
		tap = function(player: Player): boolean
			local rec = records[player]
			if rec == nil or rec.decision ~= nil then
				return false
			end
			return Rematch.tap(rec.state, player)
		end,
		settle = function(player: Player): boolean
			local rec = records[player]
			if rec == nil then
				return false
			end
			if rec.decision == nil then
				Rematch.closeWindow(rec.state)
				rec.decision = Rematch.decide(rec.state)
			end
			return rec.decision == "start" and player.Parent ~= nil
		end,
		finish = function(player: Player): { any }?
			local rec = records[player]
			if rec == nil then
				return nil
			end
			rec.pending[player] = nil
			return restartParts(rec)
		end,
		remove = function(player: Player): { any }?
			local rec = records[player]
			if rec == nil then
				return nil
			end
			Rematch.playerLeft(rec.state, player)
			rec.pending[player] = nil
			records[player] = nil
			return restartParts(rec)
		end,
	}
	return handle
end

return RematchService
