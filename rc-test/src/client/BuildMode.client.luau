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
	barrels = "■ ■", -- (▮ has no glyph in Roblox fonts: it draws as an empty box)
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
	local kind = "race"
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
			kind = kind,
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
		onKind = function(k)
			kind = k
			push()
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
local last: any = nil -- the server's latest build state
local screen = BuildScreen.new({
	onDrop = function(c, r, id)
		event:FireServer("drop", c, r, id)
	end,
	onPlace = function(c, r, id, rot)
		event:FireServer("place", c, r, id, rot)
	end,
	onRemove = function(c, r)
		event:FireServer("remove", c, r)
	end,
	onDone = function()
		closed = true
		event:FireServer("done")
	end,
	onKind = function(kind)
		event:FireServer("kind", kind)
	end,
	-- the drag blink: the same check the server makes on the drop, on a copy of the track
	preview = function(c, r, id)
		if type(last) ~= "table" or type(last.cells) ~= "table" then
			return true, true, nil
		end
		local grid = { cols = last.cols, rows = last.rows, tiles = {} }
		for _, t in last.cells do
			table.insert(grid.tiles, { c = t.c, r = t.r, piece = t.piece, rot = t.rot })
		end
		local ok, allowed, ready, why = pcall(TrackTiles.preview, grid, c, r, id)
		if not ok then
			return true, true, nil -- (an old tile module: no blink rather than a wrong one)
		end
		return allowed == true, ready == true, if type(why) == "string" then why else nil
	end,
})

local function endsAt(): number
	local t = workspace:GetAttribute("BuildEndsAt")
	return if type(t) == "number" then t else 0
end
-- the tiles you don't own yet, and what opens each: stars first, then its coin price
local TileShop = require(shared:WaitForChild("TileShop") :: ModuleScript) :: any
local function locksFor(owned: unknown): { [string]: string }?
	if type(owned) ~= "table" then
		return nil -- an older server: everything is yours
	end
	local stars = player:GetAttribute("Stars")
	local have = if type(stars) == "number" then stars else 0
	local out: { [string]: string } = {}
	for _, id in bar do
		if (owned :: any)[id] ~= true then
			local need = TileShop.unlockAt(id)
			local t = TileShop.get(id)
			out[id] = if have < need then `WIN {need} STARS` elseif t then `{t.price} COINS` else "?"
		end
	end
	return out
end

-- the server's { {c, r} } of tiles the loop skips, as "c,r" keys
local function strayOf(list: unknown): { [string]: boolean }?
	if type(list) ~= "table" then
		return nil
	end
	local out: { [string]: boolean } = {}
	for _, p in list :: { any } do
		local c = if type(p) == "table" then (p.c or p[1]) else nil
		local r = if type(p) == "table" then (p.r or p[2]) else nil
		if type(c) == "number" and type(r) == "number" then
			out[`{c},{r}`] = true
		end
	end
	return out
end

-- the server's {c, r}: the square a new player should swap first
local function hintOf(h: unknown): { number }?
	if type(h) ~= "table" then
		return nil
	end
	local c, r = (h :: any)[1], (h :: any)[2]
	if type(c) == "number" and type(r) == "number" then
		return { c, r }
	end
	return nil
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
		specials = bar,
		locks = locksFor(last.owned),
		stray = strayOf(last.stray),
		ready = last.ready == true,
		why = if type(last.why) == "string" then last.why else nil,
		secondsLeft = endsAt() - now(),
		kind = if last.kind == "drift" then "drift" else "race",
		hint = hintOf(last.hint),
	})
end

player:GetAttributeChangedSignal("Stars"):Connect(push) -- a star can open a tile

event.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if kind == "state" and type(data) == "table" then
		last = data
		push()
	elseif kind == "done" then
		closed = true
	end
end)

-- BUILD on foot in the break: opens the screen again after DONE (or before your first drive)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local buildGui = Instance.new("ScreenGui")
buildGui.Name = "BuildButton"
buildGui.ResetOnSpawn = false
buildGui.IgnoreGuiInset = true
buildGui.DisplayOrder = HudLayout.HUD
buildGui.Parent = player:WaitForChild("PlayerGui")
local buildBtn = Instance.new("TextButton")
buildBtn.Name = "Build"
HudLayout.place(buildBtn, "Build", "walk")
-- dark with yellow words: DRIVE (yellow) stays the main button on your pad
buildBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
buildBtn.TextColor3 = Color3.fromRGB(230, 190, 80)
buildBtn.Font = Enum.Font.GothamBlack
buildBtn.TextScaled = true
buildBtn.Text = "BUILD!"
buildBtn.Visible = false
buildBtn.Parent = buildGui
local buildCorner = Instance.new("UICorner")
buildCorner.CornerRadius = UDim.new(0.3, 0)
buildCorner.Parent = buildBtn
local buildPad = Instance.new("UIPadding")
buildPad.PaddingTop = UDim.new(0.3, 0)
buildPad.PaddingBottom = UDim.new(0.3, 0)
buildPad.Parent = buildBtn
local buildSize = Instance.new("UITextSizeConstraint")
buildSize.MaxTextSize = 20 -- no louder than DRIVE (E)
buildSize.Parent = buildBtn
local asked = false -- tapped BUILD this break
buildBtn.Activated:Connect(function()
	closed, asked = false, true
end)
-- the spawn's BUILD pad (the server walked you to your plot): the same as tapping BUILD!
player:GetAttributeChangedSignal("BuildAsk"):Connect(function()
	closed, asked = false, true
end)

local open = false
local lastEnd = 0
local autoUsed = false -- it opened by itself once this break: after that, BUILD! opens it
local pg = player:WaitForChild("PlayerGui")
-- the race card, the prize card and the coins flying in come first (tour 2: it covered them)
local race: Instance? = nil
local prizeCard: Instance? = nil
local function cardsUp(): boolean
	-- found once and kept (a deep search of the PlayerGui every frame is slow on a phone)
	if not (race and race.Parent) then
		race = pg:FindFirstChild("ServerRace")
	end
	if not (prizeCard and prizeCard.Parent) then
		prizeCard = pg:FindFirstChild("RacePrize", true)
	end
	return (race ~= nil and race:GetAttribute("Busy") == true)
		or (prizeCard ~= nil and (prizeCard :: GuiObject).Visible)
end
RunService.Heartbeat:Connect(function()
	local e = endsAt()
	if e ~= lastEnd then
		lastEnd, closed, asked, autoUsed = e, false, false, false -- a new break
	end
	local inBreak = e > now() and last ~= nil
	local walking = player:GetAttribute("Driving") ~= true
	-- by itself only once you've driven your plot (PlotGuide sets HasDriven): a brand new player
	-- follows the arrows first, and BUILD! is there when they want it. And only once a break:
	-- getting out of the car again doesn't pop it back up.
	local auto = player:GetAttribute("HasDriven") == true and not autoUsed and not cardsUp()
	local want = inBreak and not closed and walking and (auto or asked or open)
	-- (not before your first drive: a brand new player's one button is DRIVE)
	buildBtn.Visible = inBreak and walking and not want and player:GetAttribute("DroveOnce") == true
	if want ~= open then
		open = want
		screen.show(want)
		if want and not asked then
			autoUsed = true
		end
		if not want then
			asked = false -- (closed by driving off: BUILD! brings it back)
		end
	end
	if open then
		screen.setSeconds(e - now())
	end
end)
