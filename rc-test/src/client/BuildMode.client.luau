--!strict
-- Opens the build screen during the 5-min break (workspace.BuildEndsAt, set by the server race
-- clock) and talks to the server over TrackBuildEvent: ("path", {{c, r}, ...}),
-- ("drop", c, r, piece), ("remove", c, r), ("done") out; ("state", {cols, rows, cells, ready,
-- why}) back. The tiles come from Shared.TrackTiles (Build your own track thread).
-- Studio picture check without a server: set workspace attribute BuildDemo = true.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildLayout = require(ReplicatedStorage.Shared.BuildLayout)
local BuildScreen = require(script.Parent:WaitForChild("BuildScreen"))

local player = Players.LocalPlayer

-- the mark drawn on special tiles
local ICONS: { [string]: string } =
	{ start = "▲", boost = "▲▲", oil = "≈", sharp = "!", chicane = "~" }
local COLORS: { [string]: Color3 } = {
	boost = Color3.fromRGB(235, 120, 40),
	oil = Color3.fromRGB(60, 40, 90),
}
-- plain road comes from drawing; these go in the drag bar
local PLAIN = { start = true, straight = true, turn = true }

local function toPiece(p: any): BuildScreen.Piece
	return {
		id = p.id,
		name = string.upper(p.name),
		ends = p.ends,
		icon = ICONS[p.id],
		color = COLORS[p.id],
	}
end

local function specialsOf(list: { BuildScreen.Piece }): { string }
	local out = {}
	for _, p in list do
		if not PLAIN[p.id] then
			table.insert(out, p.id)
		end
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
		toPiece({ id = "boost", name = "boost", ends = E(true, false, true, false) }),
		toPiece({ id = "oil", name = "oil", ends = E(true, false, true, false) }),
		toPiece({ id = "chicane", name = "wiggle", ends = E(true, false, true, false) }),
		toPiece({ id = "sharp", name = "sharp", ends = E(true, true, false, false) }),
	}
	local start = { c = 2, r = 2 }
	local cells: { BuildScreen.Cell } = { { c = 2, r = 2, piece = "start", rot = 0 } }
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
		screen.setState({
			cols = 8,
			rows = 8,
			cells = cells,
			pieces = pieces,
			specials = specialsOf(pieces),
			ready = ready,
			why = "Road has a gap",
			secondsLeft = endsAt - now(),
		})
	end
	screen = BuildScreen.new({
		onPath = function(path)
			local closes = #path >= 4
				and path[#path].c == start.c
				and path[#path].r == start.r
				and path[1].c == start.c
				and path[1].r == start.r
			for i, p in path do
				local e = E(false, false, false, false)
				local prev = path[i - 1] or (if closes then path[#path - 1] else nil)
				local nxt = path[i + 1] or (if closes then path[2] else nil)
				for _, other in { prev, nxt } do
					local side = other and BuildLayout.side(p, other)
					if side then
						(e :: any)[side] = true
					end
				end
				local piece, rot = BuildLayout.roadFor(e)
				local isStart = p.c == start.c and p.r == start.r
				if piece then
					local id = if isStart then "start" else piece
					local turnRot = if isStart then rot % 2 else rot
					local j = find(p.c, p.r)
					local cell = { c = p.c, r = p.r, piece = id, rot = turnRot }
					if j then
						cells[j] = cell
					else
						table.insert(cells, cell)
					end
				end
			end
			ready = closes
			push()
		end,
		onDrop = function(c, r, id)
			local j = find(c, r)
			if j and cells[j].piece ~= "start" then
				cells[j] = { c = c, r = r, piece = id, rot = cells[j].rot }
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
local specials = specialsOf(pieces)

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
