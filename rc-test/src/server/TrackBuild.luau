--!strict
-- Build your own track, server side (carter 2026-10-23, rc-game/build-track/PLAN.md).
-- Every race plot starts as the starter circle. Its owner swaps tiles during the server race
-- break (workspace.BuildOpen, set by ServerRaceRunner). The client only asks; this checks the
-- owner, the break, the cell, the piece and TileShop, then saves (Profile.setTrack), rebuilds the
-- plot's track (TrackBuilder.rebuild) and hands the driving data to PlotTracks. The plot model
-- gets TrackReady = true/false, which the server race uses to pick a plot.
--
-- Remote ReplicatedStorage.TrackBuildEvent:
--   client -> ("path", { {c, r}, ... }) finger drag lays road | ("drop", c, r, pieceId) special
--             tile onto road | ("kind", "race" | "drift") what the plot is | ("rotate", c, r) quarter turn | ("place", c, r, pieceId, rot) | ("remove", c, r) | ("done")
--   server -> ("state", { cols, rows, cells = { {c, r, piece, rot} }, ready, why, kind, owned = {[id]=bool},
--             stray = { {c, r} } tiles the loop skips (not ready), hint = {c, r}? first square to swap })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotTracks = require(ReplicatedStorage.Shared.PlotTracks)
local Profile = require(ReplicatedStorage.Shared.Profile)
local TrackTiles = require(ReplicatedStorage.Shared.TrackTiles)
local LobbyPlots = require(script.Parent.LobbyPlots)
local Jobs = require(script.Parent.Jobs)
local PlayerData = require(script.Parent.PlayerData)
local TrackBuilder = require(script.Parent.TrackBuilder)

-- TileShop (Spawn lobby thread) says which pieces a save owns; until it ships, free ones only.
local function owns(d: any, id: string): boolean
	-- test switch: TrackTiles.ALL_FREE, workspace attribute AllTilesFree = true, or playing in
	-- Studio (carter tests there with every tile; set AllTilesFree = false to try the unlocks)
	local free = workspace:GetAttribute("AllTilesFree")
	if TrackTiles.ALL_FREE or free == true or (free ~= false and RunService:IsStudio()) then
		return true
	end
	local mod = ReplicatedStorage.Shared:FindFirstChild("TileShop")
	if mod then
		return (require(mod) :: any).owns(d, id)
	end
	local p = TrackTiles.piece(id)
	return p ~= nil and p.tier == "free"
end

local TrackBuild = {}

local RATE = 12 -- requests a second per player
local RACE = "race" -- only race plots are built from tiles for now

local remote = Instance.new("RemoteEvent")
remote.Name = "TrackBuildEvent"
remote.Parent = ReplicatedStorage

local grids: { [number]: TrackTiles.Grid } = {} -- slot -> grid now on that plot
local results: { [number]: TrackTiles.Result } = {}
local kinds: { [number]: string } = {} -- slot -> "race" | "drift" (the owner's pick)
local pending: { [number]: boolean } = {}
local budget: { [Player]: { t: number, n: number } } = {}

local function plotModel(slot: number): Instance?
	local s = LobbyLayout.slots()[slot]
	local plots = workspace:FindFirstChild("Plots")
	return if s and plots then plots:FindFirstChild(slot .. "_" .. s.id) else nil
end

local function isRace(slot: number): boolean
	local s = LobbyLayout.slots()[slot]
	return s ~= nil and s.id == RACE
end

-- The grid a player should have: their save, sized by their stars (tiles past the edge drop).
local function gridFor(player: Player?): TrackTiles.Grid
	local d = if player then PlayerData.get(player) else nil
	local cols, rows = TrackTiles.sizeFor(if d then d.stars else 0)
	local saved = if d then Profile.getTrack(d) else nil
	if not saved then
		return TrackTiles.circle(cols, rows)
	end
	local grid: TrackTiles.Grid = { cols = cols, rows = rows, tiles = {} }
	for _, t in saved.tiles do
		if t.c <= cols and t.r <= rows and TrackTiles.piece(t.piece) then
			table.insert(grid.tiles, { c = t.c, r = t.r, piece = t.piece, rot = t.rot })
		end
	end
	return grid
end

local function stateOf(slot: number): { [string]: any }
	local g = grids[slot]
	local res = results[slot]
	-- which tiles the owner can put down (the tray shows the rest locked)
	local owner = LobbyPlots.ownerOf(slot)
	local d = if owner then PlayerData.get(owner) else nil
	local owned: { [string]: boolean } = {}
	for _, p in TrackTiles.PIECES do
		owned[p.id] = d ~= nil and owns(d, p.id)
	end
	-- tiles not on the loop (the track isn't ready until they're joined in; the screen dims them)
	local stray = if res and res.stray then res.stray else {}
	-- the square to show a new player first (glows: "swap a tile in here")
	local hc, hr = TrackTiles.hint(g)
	return {
		kind = kinds[slot] or "race",
		stray = stray,
		hint = if hc and hr then { hc, hr } else nil,
		owned = owned,
		cols = g.cols,
		rows = g.rows,
		cells = TrackTiles.copy(g).tiles,
		ready = res ~= nil and res.ok,
		why = if res then res.why else nil,
	}
end

local function sendState(slot: number)
	local owner = LobbyPlots.ownerOf(slot)
	if owner and grids[slot] then
		remote:FireClient(owner, "state", stateOf(slot))
	end
end

-- Rebuild the plot from its grid (batched: many taps in a row = one rebuild).
local function rebuild(slot: number)
	if pending[slot] then
		return
	end
	pending[slot] = true
	task.delay(0.25, function()
		pending[slot] = nil
		local grid = grids[slot]
		if not grid then
			return
		end
		local res = TrackTiles.trace(grid)
		results[slot] = res
		TrackBuilder.rebuild(slot, function(parent: Instance, origin: CFrame)
			TrackTiles.build(parent, origin, grid)
		end)
		local kind = kinds[slot] or "race"
		PlotTracks.set(slot, TrackTiles.track(res, kind))
		local m = plotModel(slot)
		if m then
			m:SetAttribute("TrackReady", res.ok)
			m:SetAttribute("TrackKind", kind)
		end
		sendState(slot)
	end)
end

-- Put the right grid on a race plot (owner's save, or the starter circle when nobody owns it).
local function load(slot: number)
	if not isRace(slot) then
		return
	end
	local owner = LobbyPlots.ownerOf(slot)
	local d = if owner then PlayerData.get(owner) else nil
	grids[slot] = gridFor(owner)
	kinds[slot] = if d and d.trackKind == "drift" then "drift" else "race"
	rebuild(slot)
end

local function allowed(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.t >= 1 then
		budget[player] = { t = now, n = 1 }
		return true
	end
	b.n += 1
	return b.n <= RATE
end

local function onRequest(player: Player, kind: any, c: any, r: any, piece: any, rot: any)
	if not allowed(player) or type(kind) ~= "string" then
		return
	end
	local slot = LobbyPlots.slotOf(player)
	if not slot or not isRace(slot) or not grids[slot] then
		return
	end
	if kind == "done" then
		sendState(slot)
		return
	end
	if workspace:GetAttribute("BuildOpen") ~= true then
		sendState(slot)
		return
	end
	local d = PlayerData.get(player)
	if not d then
		return
	end
	local grid = grids[slot]
	local ok = false
	local placed = 0 -- road tiles laid this time (the daily "place tiles" job)
	if kind == "kind" then
		-- race or drift: the same road, a different way to drive it
		if c ~= "race" and c ~= "drift" then
			return
		end
		if Profile.setTrackKind(d, c) then
			kinds[slot] = c
			PlayerData.touch(player)
			rebuild(slot)
		else
			sendState(slot)
		end
		return
	elseif kind == "path" then
		-- c = { {c, r}, ... } from a finger drag
		if type(c) ~= "table" or #c > 64 then
			return
		end
		local cells = {}
		for _, cell in c do
			if type(cell) ~= "table" or type(cell[1]) ~= "number" or type(cell[2]) ~= "number" then
				return
			end
			table.insert(cells, { cell[1], cell[2] })
		end
		ok = TrackTiles.drawPath(grid, cells)
		placed = #cells
	elseif type(c) ~= "number" or type(r) ~= "number" then
		return
	elseif kind == "drop" then
		if type(piece) ~= "string" or not TrackTiles.piece(piece) or not owns(d, piece) then
			sendState(slot)
			return
		end
		ok = TrackTiles.drop(grid, c, r, piece)
		placed = 1
	elseif kind == "place" then
		if type(piece) ~= "string" or type(rot) ~= "number" or not TrackTiles.piece(piece) then
			return
		end
		if not owns(d, piece) then
			sendState(slot)
			return
		end
		ok = TrackTiles.place(grid, c, r, piece, rot)
		placed = 1
	elseif kind == "remove" then
		ok = TrackTiles.remove(grid, c, r)
	elseif kind == "rotate" then
		ok = TrackTiles.rotate(grid, c, r)
	end
	if ok then
		Profile.setTrack(d, TrackTiles.copy(grid).tiles)
		if placed > 0 then
			Jobs.fire(player, "tiles", placed)
		end
		PlayerData.touch(player)
		rebuild(slot)
	else
		sendState(slot)
	end
end

-- The traced track on a plot (loop, gates, spawn, lineSample), or nil if it isn't ready.
function TrackBuild.trackFor(slot: number): TrackTiles.Result?
	local res = results[slot]
	return if res and res.ok then res else nil
end

function TrackBuild.start()
	-- (the tycoon plan: no tile building; saved tracks stay in the save)
	if Features.TILES then
		remote.OnServerEvent:Connect(onRequest)
	end
	for slot in LobbyLayout.slots() do
		load(slot)
	end
	-- owner changed (claim, leave): show their track, or the circle again. Never under a car:
	-- while the server race is on that plot, or someone is still driving it (a friend on the
	-- plot of someone who just left), the swap waits until they're off it.
	local owners: { [number]: number } = {}
	local waiting: { [number]: boolean } = {}
	local function inUse(slot: number): boolean
		return workspace:GetAttribute("RaceSlot") == slot or LobbyPlots.driverOf(slot) ~= nil
	end
	local function check(slot: number)
		local owner = LobbyPlots.ownerOf(slot)
		local id = if owner then owner.UserId else 0
		if owners[slot] ~= id then
			if inUse(slot) then
				waiting[slot] = true
				return
			end
			owners[slot] = id
			waiting[slot] = nil
			load(slot)
		end
	end
	for slot in LobbyLayout.slots() do
		local owner = LobbyPlots.ownerOf(slot)
		owners[slot] = if owner then owner.UserId else 0
	end
	LobbyPlots.changed:Connect(check)
	workspace:GetAttributeChangedSignal("RaceSlot"):Connect(function()
		for slot in waiting do
			check(slot)
		end
	end)
	-- a save that loads after the claim
	PlayerData.loaded:Connect(function(player: Player)
		local slot = LobbyPlots.slotOf(player)
		if slot then
			owners[slot] = -1 -- reload it (now, or once nobody is driving it)
			check(slot)
		end
	end)
	-- break starts: hand every owner their grid so the build screen opens
	workspace:GetAttributeChangedSignal("BuildOpen"):Connect(function()
		if workspace:GetAttribute("BuildOpen") == true then
			for slot in grids do
				sendState(slot)
			end
		end
	end)
	-- stars won mid-session (Stars attribute, set by Stars.server): grow the owner's grid in place
	local function watchStars(player: Player)
		player:GetAttributeChangedSignal("Stars"):Connect(function()
			local slot = LobbyPlots.slotOf(player)
			local grid = if slot then grids[slot] else nil
			local stars = player:GetAttribute("Stars")
			if not slot or not grid or type(stars) ~= "number" then
				return
			end
			local cols, rows = TrackTiles.sizeFor(stars)
			if cols > grid.cols or rows > grid.rows then
				grid.cols, grid.rows = math.max(cols, grid.cols), math.max(rows, grid.rows)
				rebuild(slot)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchStars)
	for _, player in Players:GetPlayers() do
		watchStars(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
	end)
end

return TrackBuild
