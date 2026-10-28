--!strict
-- The lobby leaderboards: most trophies and fastest lap on each race map (Car VS Car Smash: the
-- trophies board only), on boards by the spawn.
-- Also the league badge over each player's head. Each board is an OrderedDataStore (key = UserId). Writes are gentle:
-- a score is only sent when it beats the player's own best, a board is written at most every
-- WRITE_GAP seconds per player, and the boards are read every REFRESH seconds. Every call retries
-- with backoff; a failed write waits for the next round. Lap times come from the server's own race
-- clock (ServerRaceRunner calls Leaderboards.lap). No DataStore (Studio without API access): the
-- boards still show this session's scores.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Forever = require(ReplicatedStorage.Shared.Forever)
local Features = require(ReplicatedStorage.Shared.Features)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Lb = require(ReplicatedStorage.Shared.Leaderboards)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local PlayerData = require(script.Parent.PlayerData)

local WRITE_GAP = 60 -- seconds between writes to one board for one player
local FLUSH = 15 -- how often the pending scores are looked at
local MAX_WRITES = 6 -- most writes in one look
local SAMPLE = 60 -- how often every trophy count is looked at
local REFRESH = 90 -- how often the boards are read again
local TRIES = 3

local Leaderboards = {}

type Pending = { [string]: number } -- board id -> best score waiting to be written

local boards: { Lb.Board } = {}
local byId: { [string]: Lb.Board } = {}
local stores: { [string]: OrderedDataStore } = {}
local rows: { [string]: { Lb.Row } } = {}
local views: {
	[string]: {
		title: TextLabel,
		rows: { { rank: TextLabel, name: TextLabel, score: TextLabel } },
		empty: TextLabel,
	},
} =
	{}
local known: { [Player]: { [string]: number } } = {} -- their best on each board, as read / written
local loaded: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}
local lastWrite: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}
local studio = RunService:IsStudio()
local storeDown = false -- Studio only: a call failed (API access off gives 403 or 502), so no more tries

-- ===== the store, with retries =====

-- (ok, result). A 403 (Studio with API access off) is not retried.
local function call(what: string, fn: () -> any): (boolean, any)
	for i = 1, TRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Leaderboards] {what} try {i}:`, result)
		if studio then
			storeDown = true
			break
		end
		if string.find(tostring(result), "403", 1, true) then
			break
		end
		if i < TRIES then
			task.wait(2 ^ i)
		end
	end
	return false, nil
end

local function nameOf(uid: number): string
	local n = names[uid]
	if n then
		return n
	end
	local p = Players:GetPlayerByUserId(uid)
	if p then
		names[uid] = p.DisplayName
		return p.DisplayName
	end
	local ok, got = pcall(function()
		return Players:GetNameFromUserIdAsync(uid)
	end)
	names[uid] = if ok and type(got) == "string" then got else "PLAYER"
	return names[uid]
end

-- ===== drawing =====

local INK = Color3.fromRGB(27, 27, 47)
local YELLOW = Color3.fromRGB(255, 199, 44)
local BLUE = Color3.fromRGB(30, 123, 224)
local WHITE = Color3.new(1, 1, 1)
local RANK_COLORS =
	{ Color3.fromRGB(255, 199, 44), Color3.fromRGB(190, 200, 214), Color3.fromRGB(217, 140, 72) }
local SEE = 90 -- studs: the board's pictures stop being drawn past this

local function text(parent: Instance, size: UDim2, pos: UDim2, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = ""
	t.Parent = parent
	return t
end

local function ink(t: TextLabel)
	t.TextStrokeColor3 = INK
	t.TextStrokeTransparency = 0
end

local function build(board: Lb.Board, folder: Instance, originZ: number)
	local x, y, z = Lb.world(board, originZ)
	local w, h = Lb.BOARD_W, Lb.BOARD_H
	local anchor = Instance.new("Part")
	anchor.Name = "Board_" .. board.id
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(w, h, 0.3)
	-- facing back at the spawn (-z), or where its slot turns it
	local fx, fz = Lb.facing(board)
	anchor.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + fx * 10, y, z + fz * 10))
	anchor.Parent = folder
	-- a blue plate just behind the (rounded) panel: past the words' MaxDistance it still shows
	-- as a board, not two black posts sticking out of the plaza (phone playtest u19)
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = BLUE
	plate.Size = Vector3.new(w - 0.8, h - 0.8, 0.2)
	plate.CFrame = anchor.CFrame * CFrame.new(0, 0, 0.3)
	plate.Parent = anchor
	-- two posts under it
	for _, dx in { -w / 2 + 1, w / 2 - 1 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.CanCollide = false
		post.CanQuery = false
		post.CanTouch = false
		post.Material = Enum.Material.Metal
		post.Color = INK
		local ph = y - h / 2
		post.Size = Vector3.new(0.5, ph, 0.5)
		post.CFrame = anchor.CFrame * CFrame.new(dx, ph / 2 - y, 0.3)
		post.Parent = anchor
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = SEE
	gui.LightInfluence = 0
	gui.Parent = anchor
	-- Kart Party: a blue panel with an ink rim, a yellow title pill, white row cards
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = BLUE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.07, 0)
	corner.Parent = panel
	local rim = Instance.new("UIStroke")
	rim.Color = INK
	rim.Thickness = 10
	rim.Parent = panel
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(0.86, 0.17)
	pill.Position = UDim2.fromScale(0.07, 0.03)
	pill.BackgroundColor3 = YELLOW
	pill.BorderSizePixel = 0
	pill.Parent = panel
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.3, 0)
	pc.Parent = pill
	local ps = Instance.new("UIStroke")
	ps.Color = INK
	ps.Thickness = 6
	ps.Parent = pill
	-- ink words on the yellow pill (white on yellow vanished from the spawn)
	local title = text(pill, UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.12), INK)
	title.Text = board.title
	local sub = text(panel, UDim2.fromScale(0.86, 0.085), UDim2.fromScale(0.07, 0.205), WHITE)
	sub.Text = board.sub
	ink(sub)
	local view = {
		title = title,
		rows = {} :: { { rank: TextLabel, name: TextLabel, score: TextLabel } },
		empty = text(panel, UDim2.fromScale(0.7, 0.12), UDim2.fromScale(0.15, 0.5), WHITE),
	}
	view.empty.Text = "BE THE FIRST!"
	ink(view.empty)
	for i = 1, Lb.SHOWN do
		local card = Instance.new("Frame")
		card.Name = "Row" .. i
		card.Size = UDim2.fromScale(0.9, 0.1)
		card.Position = UDim2.fromScale(0.05, 0.3 + (i - 1) * 0.134)
		card.BackgroundColor3 = WHITE
		card.BorderSizePixel = 0
		card.Visible = false
		card.Parent = panel
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0.3, 0)
		cc.Parent = card
		local cs = Instance.new("UIStroke")
		cs.Color = INK
		cs.Thickness = 4
		cs.Parent = card
		local rank = text(card, UDim2.fromScale(0.1, 0.8), UDim2.fromScale(0.02, 0.1), WHITE)
		rank.Text = tostring(i)
		rank.TextColor3 = RANK_COLORS[i] or WHITE
		ink(rank)
		local name = text(card, UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.14, 0.15), INK)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local score = text(card, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.68, 0.15), BLUE)
		score.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(view.rows, { rank = rank, name = name, score = score })
	end
	views[board.id] = view
end

local function draw(board: Lb.Board)
	local view = views[board.id]
	if not view then
		return
	end
	local list = rows[board.id] or {}
	view.empty.Visible = #list == 0
	for i, v in view.rows do
		local r = list[i]
		local card = v.name.Parent :: Frame
		card.Visible = r ~= nil
		if r then
			v.name.Text = string.upper(r.name)
			v.score.Text = Lb.format(board, r.score)
		end
	end
end

-- ===== reading the boards =====

local function refresh(board: Lb.Board)
	local s = stores[board.id]
	if not s or storeDown then
		return
	end
	local ok, pages = call("read " .. board.id, function()
		return s:GetSortedAsync(board.low, Lb.FETCH)
	end)
	if not ok then
		return
	end
	local list: { Lb.Row } = {}
	for _, e in (pages :: any):GetCurrentPage() do
		local uid = tonumber(e.key)
		local score = Lb.score(board, if board.low then e.value / 1000 else e.value)
		if uid and score then
			table.insert(list, { uid = uid, name = nameOf(uid), score = score })
		end
	end
	rows[board.id] = list
	draw(board)
end

-- ===== writing =====

-- Write `score` for `uid` when it still beats what the store holds. True when the store answered.
local function write(board: Lb.Board, uid: number, score: number): boolean
	local s = stores[board.id]
	if not s then
		return false
	end
	local ok = call("write " .. board.id, function()
		return s:UpdateAsync(tostring(uid), function(old: any): any
			if type(old) == "number" and not Lb.better(board, old, score) then
				return old
			end
			return score
		end)
	end)
	return ok
end

local function bump(player: Player, board: Lb.Board, score: number)
	local k = known[player]
	if not (k and loaded[player]) then
		-- not read yet: keep it, the flush looks again
		local p = pending[player] or {}
		pending[player] = p
		local old = p[board.id]
		if old == nil or Lb.better(board, old, score) then
			p[board.id] = score
		end
		return
	end
	if not Lb.better(board, k[board.id], score) then
		return
	end
	local p = pending[player] or {}
	pending[player] = p
	p[board.id] = score
end

-- Send what is waiting for this player (only past WRITE_GAP unless `force`). Returns writes made.
local function flushPlayer(player: Player, uid: number, force: boolean, budget: number): number
	local p = pending[player]
	local k = known[player]
	if not (p and k and loaded[player]) then
		return 0
	end
	local made = 0
	local lw = lastWrite[player] or {}
	lastWrite[player] = lw
	for id, score in p do
		local board = byId[id]
		if board == nil or not Lb.better(board, k[id], score) then
			p[id] = nil
		elseif made < budget and (force or Lb.due(lw[id], os.clock(), WRITE_GAP)) then
			lw[id] = os.clock()
			if write(board, uid, score) then
				k[id] = score
				p[id] = nil
				made += 1
				-- show it at once, the next read confirms it
				names[uid] = player.DisplayName
				rows[id] = Lb.merge(board, rows[id] or {}, uid, player.DisplayName, score, Lb.SHOWN)
				draw(board)
			end
		end
	end
	return made
end

local function loadMine(player: Player)
	local k: { [string]: number } = {}
	known[player] = k
	for _, b in boards do
		local s = stores[b.id]
		if s then
			local ok, v = call("read mine " .. b.id, function()
				return s:GetAsync(tostring(player.UserId))
			end)
			if ok and type(v) == "number" then
				k[b.id] = v
			end
		end
	end
	loaded[player] = true
end

-- A lap time in seconds (a finished lap on a map). Server clock only.
function Leaderboards.lap(player: Player, mapId: string?, seconds: number)
	local board = if mapId then byId["lap_" .. mapId] else nil
	if not board then
		return
	end
	local score = Lb.score(board, seconds)
	if score then
		bump(player, board, score)
	end
end

local function sample()
	local board = byId.trophies
	if not board then
		return
	end
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p) :: any
		if data and type(data.trophies) == "number" then
			local score = Lb.score(board, data.trophies)
			if score then
				bump(p, board, score)
			end
		end
	end
end

-- ===== league badge over the head =====

local function paintBadge(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local old = head:FindFirstChild("LeagueBadge")
	local league = player:GetAttribute("League")
	if type(league) ~= "number" then
		if old then
			old:Destroy()
		end
		return
	end
	local word, c = Lb.badge(league)
	local gui = old :: BillboardGui?
	local label: TextLabel
	if gui then
		label = gui:FindFirstChildWhichIsA("TextLabel") :: TextLabel
	else
		gui = Instance.new("BillboardGui")
		local g = gui :: BillboardGui
		g.Name = "LeagueBadge"
		g.Size = UDim2.fromOffset(86, 26)
		g.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0) -- over the name tag
		g.AlwaysOnTop = false
		g.MaxDistance = 70
		g.LightInfluence = 0
		g.Adornee = head
		g.Parent = head
		label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.TextStrokeColor3 = INK
		label.TextStrokeTransparency = 0
		label.BorderSizePixel = 0
		label.Parent = g
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
		local rim = Instance.new("UIStroke")
		rim.Color = INK
		rim.Thickness = 3
		rim.Parent = label
	end
	label.Text = word
	label.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
end

local function watchBadge(player: Player)
	player:GetAttributeChangedSignal("League"):Connect(function()
		paintBadge(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(paintBadge, player)
	end)
	paintBadge(player)
end

function Leaderboards.start()
	local originZ = LobbyLayout.PLAZA.maxZ - 36 -- the same origin LobbyBuilder gives the spawn lobby
	local maps: { { id: string, label: string } } = {}
	-- Car VS Car Smash has no race tracks: only the trophies board, no fastest-lap boards
	if not (Features.CVC and (Features :: any).SMASH == true) then
		for _, m in RaceMaps.list() do
			table.insert(maps, { id = m.id, label = m.label })
		end
	end
	boards = Lb.boards(maps)
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	local ok = pcall(function()
		for _, b in boards do
			stores[b.id] = DataStoreService:GetOrderedDataStore(b.store)
		end
	end)
	if not ok then
		warn("[Leaderboards] no DataStore: the boards only show this session")
		table.clear(stores)
	end
	for i, b in boards do
		byId[b.id] = b
		if Lb.placed(b, i) then
			build(b, folder, originZ)
			draw(b)
		else
			warn(`[Leaderboards] no spot for the {b.id} board (Leaderboards.SLOTS)`)
		end
	end
	-- no DataStore: keep this session's scores on the boards ourselves
	local function noStore(): boolean
		return next(stores) == nil or storeDown
	end

	local function join(p: Player)
		task.spawn(function()
			if not noStore() then
				loadMine(p)
			end
			if not loaded[p] then
				known[p], loaded[p] = known[p] or {}, true
			end
		end)
	end
	Players.PlayerAdded:Connect(function(p: Player)
		join(p)
		watchBadge(p)
	end)
	for _, p in Players:GetPlayers() do
		join(p)
		watchBadge(p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		-- their last scores go now (nothing waits for the gap)
		task.spawn(function()
			flushPlayer(p, p.UserId, true, 99)
			known[p], loaded[p], pending[p], lastWrite[p] = nil, nil, nil, nil
		end)
	end)
	game:BindToClose(function()
		if studio then
			return
		end
		for _, p in Players:GetPlayers() do
			task.spawn(flushPlayer, p, p.UserId, true, 99)
		end
		task.wait(3)
	end)

	task.spawn(function()
		while true do
			Forever.step("Leaderboards.sample", sample)
			task.wait(SAMPLE)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH)
			Forever.step("Leaderboards.flush", function()
				local budget = MAX_WRITES
				for p, _ in pending do
					if budget <= 0 then
						break
					end
					if not noStore() then
						budget -= flushPlayer(p, p.UserId, false, budget)
					end
				end
				-- no store: scores still show on this server's boards
				if noStore() then
					for p, list in pending do
						for id, score in list do
							local b = byId[id]
							if b then
								rows[id] = Lb.merge(
									b,
									rows[id] or {},
									p.UserId,
									p.DisplayName,
									score,
									Lb.SHOWN
								)
								local k = known[p]
								if k then
									k[id] = score
								end
								list[id] = nil
								draw(b)
							end
						end
					end
				end
			end)
		end
	end)
	task.spawn(function()
		while true do
			for _, b in boards do
				Forever.step("Leaderboards.read", function()
					refresh(b)
				end)
				task.wait(2) -- one board at a time
			end
			task.wait(REFRESH)
		end
	end)
end

return Leaderboards
