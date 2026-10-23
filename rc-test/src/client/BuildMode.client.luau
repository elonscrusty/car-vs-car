--!strict
-- Opens the build screen during the 5-min break (workspace.BuildEndsAt, set by the server race
-- clock) and talks to the server over TrackBuildEvent: ("place", c, r, piece, rot),
-- ("remove", c, r), ("done") out, ("state", {cols, rows, cells, ready, why}) back.
-- The tiles come from Shared.TrackTiles (Build your own track thread).
-- Studio picture check without a server: set workspace attribute BuildDemo = true.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildScreen = require(script.Parent:WaitForChild("BuildScreen"))

local player = Players.LocalPlayer

-- the mark drawn on special tiles
local ICONS: { [string]: string } = { start = "▲", boost = "▲▲", oil = "≈", sharp = "!" }
local COLORS: { [string]: Color3 } = {
	boost = Color3.fromRGB(235, 120, 40),
	oil = Color3.fromRGB(60, 40, 90),
}

local function toPiece(p: any, owned: boolean, price: number?): BuildScreen.Piece
	return {
		id = p.id,
		name = string.upper(p.name),
		ends = p.ends,
		owned = owned,
		price = price,
		icon = ICONS[p.id],
		color = COLORS[p.id],
	}
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ===== Studio demo: a local grid, no server =====
local function demo()
	local E = function(n: boolean, e: boolean, s: boolean, w: boolean)
		return { N = n, E = e, S = s, W = w }
	end
	local pieces: { BuildScreen.Piece } = {
		toPiece({ id = "start", name = "start", ends = E(true, false, true, false) }, true),
		toPiece({ id = "straight", name = "straight", ends = E(true, false, true, false) }, true),
		toPiece({ id = "turn", name = "turn", ends = E(true, true, false, false) }, true),
		toPiece(
			{ id = "chicane", name = "chicane", ends = E(true, false, true, false) },
			false,
			150
		),
		toPiece({ id = "cross", name = "cross", ends = E(true, true, true, true) }, false, 200),
		toPiece({ id = "boost", name = "boost", ends = E(true, false, true, false) }, false, 400),
		toPiece({ id = "oil", name = "oil", ends = E(true, false, true, false) }, false, 400),
	}
	local cells: { BuildScreen.Cell } = { { c = 1, r = 2, piece = "start", rot = 0 } }
	local endsAt = now() + 300
	local screen: BuildScreen.BuildScreen
	local function push()
		screen.setState({
			cols = 8,
			rows = 8,
			cells = cells,
			pieces = pieces,
			ready = #cells >= 12,
			why = if #cells >= 12 then nil else "Road has a gap",
			secondsLeft = endsAt - now(),
		})
	end
	local function find(c: number, r: number): number?
		for i, cell in cells do
			if cell.c == c and cell.r == r then
				return i
			end
		end
		return nil
	end
	screen = BuildScreen.new({
		onPlace = function(c, r, piece, rot)
			local i = find(c, r)
			if i then
				cells[i] = { c = c, r = r, piece = piece, rot = rot }
			else
				table.insert(cells, { c = c, r = r, piece = piece, rot = rot })
			end
			push()
		end,
		onRemove = function(c, r)
			local i = find(c, r)
			if i and cells[i].piece ~= "start" then
				table.remove(cells, i)
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

-- ===== live: wait for the tile data and the remote (they ship in their own PR) =====
local shared = ReplicatedStorage:WaitForChild("Shared")
local tilesModule = shared:WaitForChild("TrackTiles", 30)
local remote = ReplicatedStorage:WaitForChild("TrackBuildEvent", 30)
if not (tilesModule and remote and remote:IsA("RemoteEvent")) then
	return -- build mode is not in this place yet
end
local TrackTiles = require(tilesModule :: ModuleScript) :: any
local event = remote :: RemoteEvent

local pieces: { BuildScreen.Piece } = {}
for _, p in TrackTiles.PIECES do
	-- coin and legendary tiles stay locked until the tile shop says you own them
	table.insert(pieces, toPiece(p, p.tier == "free", nil))
end

local closed = false -- DONE hides the screen until the next break
local screen = BuildScreen.new({
	onPlace = function(c, r, piece, rot)
		event:FireServer("place", c, r, piece, rot)
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
