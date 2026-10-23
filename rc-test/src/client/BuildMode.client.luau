--!strict
-- Opens the build screen during the 5-min break (workspace.BuildEndsAt, set by the server race
-- clock) and talks to the server over TrackBuildEvent: ("drop", c, r, piece) (swap in, turned to
-- fit), ("place", c, r, piece, rot), ("remove", c, r), ("done") out; ("state", {cols, rows, cells, ready,
-- why}) back. The tiles come from Shared.TrackTiles (Build your own track thread).
-- Studio picture check without a server: set workspace attribute BuildDemo = true.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildLayout = require(ReplicatedStorage.Shared.BuildLayout)
local BuildScreen = require(script.Parent:WaitForChild("BuildScreen"))

local player = Players.LocalPlayer

-- the mark drawn on tiles, and the road colour of the messy ones (a new tile with no mark here
-- shows none)
local ICONS: { [string]: string } = {
	start = "▲",
	boost = "»",
	jump = "UP",
	oil = "●",
	sharp = "!",
	chicane = "~",
	split = "| |",
	narrow = "><",
	cones = "▲ ▲",
	barrels = "▮ ▮",
	bumps = "≡",
	mud = "≈",
	puddle = "≈",
	sand = "∴",
}
local COLORS: { [string]: Color3 } = {
	boost = Color3.fromRGB(235, 120, 40),
	jump = Color3.fromRGB(240, 190, 40),
	oil = Color3.fromRGB(25, 20, 30),
	mud = Color3.fromRGB(110, 80, 50),
	puddle = Color3.fromRGB(70, 140, 215),
	sand = Color3.fromRGB(220, 195, 130),
}
-- the bar's order: road shapes, then hazards, then powerups
local KIND_ORDER: { [string]: number } = { road = 1, hazard = 2, power = 3 }
-- every tile goes in the bar but the start line (one per track, it's already there)
local PLAIN = { start = true }

local function toPiece(p: any): BuildScreen.Piece
	return {
		id = p.id,
		name = string.upper(p.name),
		ends = p.ends,
		icon = ICONS[p.id],
		color = COLORS[p.id],
		kind = p.kind,
	}
end

local function barOf(list: { BuildScreen.Piece }): { string }
	local keep = {}
	for i, p in list do
		if not PLAIN[p.id] then
			table.insert(keep, { i = i, p = p })
		end
	end
	table.sort(keep, function(a, b)
		local ka, kb = KIND_ORDER[a.p.kind or "road"] or 1, KIND_ORDER[b.p.kind or "road"] or 1
		if ka ~= kb then
			return ka < kb
		end
		return a.i < b.i
	end)
	local out = {}
	for _, k in keep do
		table.insert(out, k.p.id)
	end
	return out
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ===== Studio demo: a local grid, no server =====
local function demo()
	local function E(n: boolean, e: boolean, s: boolean, w: boolean): BuildLayout.Ends
		return { N = n, E = e, S = s, W = w }
	end
	local pieces: { BuildScreen.Piece } = {
		toPiece({ id = "start", name = "start", ends = E(true, false, true, false) }),
		toPiece({ id = "straight", name = "straight", ends = E(true, false, true, false) }),
		toPiece({ id = "turn", name = "turn", ends = E(true, true, false, false) }),
		toPiece({
			id = "boost",
			name = "boost",
			kind = "power",
			ends = E(true, false, true, false),
		}),
		toPiece({ id = "oil", name = "oil", kind = "hazard", ends = E(true, false, true, false) }),
		toPiece({
			id = "cones",
			name = "cones",
			kind = "hazard",
			ends = E(true, false, true, false),
		}),
		toPiece({ id = "jump", name = "jump", kind = "power", ends = E(true, false, true, false) }),
		toPiece({ id = "chicane", name = "wiggle", ends = E(true, false, true, false) }),
		toPiece({ id = "sharp", name = "sharp", ends = E(true, true, false, false) }),
	}
	-- the starter circle round a 5x5 grid, one square missing
	local cells: { BuildScreen.Cell } = {
		{ c = 1, r = 1, piece = "turn", rot = 0 },
		{ c = 1, r = 2, piece = "start", rot = 0 },
		{ c = 1, r = 4, piece = "straight", rot = 0 },
		{ c = 1, r = 5, piece = "turn", rot = 1 },
		{ c = 5, r = 5, piece = "turn", rot = 2 },
		{ c = 5, r = 1, piece = "turn", rot = 3 },
	}
	for i = 2, 4 do
		table.insert(cells, { c = i, r = 5, piece = "straight", rot = 1 })
		table.insert(cells, { c = i, r = 1, piece = "straight", rot = 1 })
		table.insert(cells, { c = 5, r = i, piece = "straight", rot = 0 })
	end
	local ready = false
	local endsAt = now() + 300
	local screen: BuildScreen.BuildScreen
	local function find(c: number, r: number): number?
		for i, cell in cells do
			if cell.c == c and cell.r == r then
				return i
			end
		end
		return nil
	end
	local function push()
		ready = #cells >= 16 -- the demo's loop is 16 squares
		screen.setState({
			cols = 8,
			rows = 8,
			cells = cells,
			pieces = pieces,
			specials = barOf(pieces),
			ready = ready,
			why = "Road has a gap",
			secondsLeft = endsAt - now(),
		})
	end
	screen = BuildScreen.new({
		onDrop = function(c, r, id)
			local j = find(c, r)
			if j == nil then
				table.insert(cells, { c = c, r = r, piece = id, rot = 0 })
			elseif cells[j].piece ~= "start" then
				cells[j] = { c = c, r = r, piece = id, rot = cells[j].rot }
			end
			push()
		end,
		onPlace = function(c, r, id, rot)
			local j = find(c, r)
			if j and cells[j].piece ~= "start" then
				cells[j] = { c = c, r = r, piece = id, rot = rot }
			end
			push()
		end,
		onRemove = function(c, r)
			local j = find(c, r)
			if j and cells[j].piece ~= "start" then
				table.remove(cells, j)
				ready = false
			end
			push()
		end,
		onDone = function()
			screen.show(false)
		end,
	})
	push()
	screen.show(true)
	RunService.Heartbeat:Connect(function()
		screen.setSeconds(endsAt - now())
	end)
end

if workspace:GetAttribute("BuildDemo") == true then
	demo()
	return
end

-- ===== live: wait for the tile data and the remote =====
local shared = ReplicatedStorage:WaitForChild("Shared")
local tilesModule = shared:WaitForChild("TrackTiles", 30)
local remote = ReplicatedStorage:WaitForChild("TrackBuildEvent", 30)
if not (tilesModule and remote and remote:IsA("RemoteEvent")) then
	return -- build mode is not in this place yet
end
local TrackTiles = require(tilesModule :: ModuleScript) :: any
local event = remote :: RemoteEvent

-- every tile is free for now (carter), so the bar shows them all
local pieces: { BuildScreen.Piece } = {}
for _, p in TrackTiles.PIECES do
	table.insert(pieces, toPiece(p))
end
local bar = barOf(pieces)

local closed = false -- DONE hides the screen until the next break
local screen = BuildScreen.new({
	onPath = function(path)
		local list = {}
		for i, p in path do
			if i > 64 then
				break -- the server takes up to 64 squares a drag
			end
			table.insert(list, { p.c, p.r })
		end
		event:FireServer("path", list)
	end,
	onDrop = function(c, r, id)
		event:FireServer("drop", c, r, id)
	end,
	onRemove = function(c, r)
		event:FireServer("remove", c, r)
	end,
	onDone = function()
		closed = true
		event:FireServer("done")
	end,
})

local last: any = nil
local function endsAt(): number
	local t = workspace:GetAttribute("BuildEndsAt")
	return if type(t) == "number" then t else 0
end
local function push()
	if last == nil then
		return
	end
	screen.setState({
		cols = last.cols,
		rows = last.rows,
		cells = last.cells,
		pieces = pieces,
		specials = specials,
		ready = last.ready == true,
		why = if type(last.why) == "string" then last.why else nil,
		secondsLeft = endsAt() - now(),
	})
end

event.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if kind == "state" and type(data) == "table" then
		last = data
		push()
	elseif kind == "done" then
		closed = true
	end
end)

local open = false
local lastEnd = 0
RunService.Heartbeat:Connect(function()
	local e = endsAt()
	if e ~= lastEnd then
		lastEnd, closed = e, false -- a new break
	end
	local want = e > now() and last ~= nil and not closed and player:GetAttribute("Driving") ~= true
	if want ~= open then
		open = want
		screen.show(want)
	end
	if open then
		screen.setSeconds(e - now())
	end
end)
