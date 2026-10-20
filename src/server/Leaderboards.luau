--!strict
-- Global leaderboards: wins this week (TOP DRIVERS, resets Monday) and wins of all time (WINS).
-- Scores go to OrderedDataStores (best only, throttled), the top 5 rows are read every
-- ProgressConfig.Board.refreshSeconds and drawn with avatar heads on the two physical boards of the
-- lobby (LobbyBoards makes the panels). Server only; every DataStore call is pcall + retry.
-- Boards fail quietly (they show "no scores yet"): a board outage never touches gameplay or saves.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local ProgressConfig = require(ReplicatedStorage.Shared.ProgressConfig)
local Retry = require(ReplicatedStorage.Shared.Retry)

type Profile = { wins: number, progress: { bestStreak: number } }

local RETRY = { attempts = 3, baseDelay = 1, maxDelay = 4 }
local PPS = 40 -- pixels per stud on the board
local TITLE_SIZE = 46
local ROW_SIZE = 30
local ORANGE = Color3.fromRGB(245, 130, 32)
local BLUE = Color3.fromRGB(37, 141, 221)
local PANEL = Color3.fromRGB(18, 24, 48) -- the navy of the other panels
local GOLD = Color3.fromRGB(255, 210, 70)
local WHITE = Color3.fromRGB(240, 244, 250)

local Leaderboards = {}

local stores: { [string]: OrderedDataStore } = {}
local lastSent: { [string]: { score: number, at: number } } = {} -- "<kind>_<userId>"
local names: { [number]: string } = {}
local rowGuis: { [string]: { Rows } } = {} -- per kind, the rows of each surface
local inited = false
local LOADING = "Loading..."
local EMPTY_TEXT = "NO DATA YET"
local ROWS = 5
local LOADING_TIMEOUT = 5 -- seconds before a board that got no data says "No scores yet"

local studioNoted = false -- Studio has no DataStore access: say so once, not on every retry

local function retryOpts(label: string): Retry.Options
	return {
		attempts = RETRY.attempts,
		baseDelay = RETRY.baseDelay,
		maxDelay = RETRY.maxDelay,
		wait = function(s)
			task.wait(s)
		end,
		onFail = function(attempt, err)
			if RunService:IsStudio() then
				if not studioNoted then
					studioNoted = true
					warn("[Leaderboards] no DataStore access in Studio; boards stay empty")
				end
				return
			end
			warn(`[Leaderboards] {label} attempt {attempt}/{RETRY.attempts} failed: {err}`)
		end,
	}
end

local function storeFor(name: string): OrderedDataStore?
	local cached = stores[name]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		stores[name] = result
		return result
	end
	warn("[Leaderboards] store unavailable: " .. tostring(result))
	return nil
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and type(name) == "string" then name else "Player"
	return names[userId]
end

-- Send this player's scores if they beat the last one this server sent. Never yields the caller.
function Leaderboards.submit(player: Player, profile: Profile)
	local now = os.time()
	for _, board in Leaderboard.Boards do
		local key = `{board.kind}_{player.UserId}`
		local score = Leaderboard.scoreFor(board.kind, profile)
		local last = lastSent[key]
		if
			Leaderboard.shouldSubmit(
				score,
				if last then last.score else nil,
				if last then last.at else nil,
				now,
				ProgressConfig.Board.minSubmitGap
			)
		then
			lastSent[key] = { score = score, at = now }
			task.spawn(function()
				local ds = storeFor(board.store)
				if ds == nil then
					lastSent[key] = last
					return
				end
				local ok = Retry.run(function()
					-- Keep the larger value: a stale server can never lower a record.
					ds:UpdateAsync(tostring(player.UserId), function(old: any)
						if type(old) == "number" and old >= score then
							return nil
						end
						return score
					end)
					return true
				end, retryOpts("submit " .. board.kind))
				if not ok then
					lastSent[key] = last -- try again on the next match
				end
			end)
		end
	end
end

-- A win just happened: add 1 to this player's weekly score (week taken from the server clock).
-- Wins are minutes apart, so one UpdateAsync per win is well inside the DataStore budget.
function Leaderboards.recordWin(player: Player)
	local userId = player.UserId
	local week = Leaderboard.weekIndex(os.time())
	task.spawn(function()
		local ds = storeFor(Leaderboard.weeklyStore(week))
		if ds == nil then
			return
		end
		Retry.run(function()
			ds:UpdateAsync(tostring(userId), function(old: any)
				return Leaderboard.addWins(old, 1)
			end)
			return true
		end, retryOpts("weekly win"))
	end)
end

-- Knock-outs just made: add them to this player's weekly smash score.
function Leaderboards.recordSmashes(player: Player, count: number)
	if count < 1 then
		return
	end
	local userId = player.UserId
	local week = Leaderboard.weekIndex(os.time())
	task.spawn(function()
		local ds = storeFor(Leaderboard.smashesStore(week))
		if ds == nil then
			return
		end
		Retry.run(function()
			ds:UpdateAsync(tostring(userId), function(old: any)
				return Leaderboard.addWins(old, count)
			end)
			return true
		end, retryOpts("weekly smashes"))
	end)
end

-- Last week's #1 in wins gets the gold paint. Asks the DataStore once per server (cached), then
-- calls `grant` on the main thread if this player was #1. Never yields the caller.
local championId: number? = nil
local championLoaded = false
local championWaiting: { () -> () } = {}

local function loadChampion()
	local week = Leaderboard.weekIndex(os.time()) - 1
	if week >= 0 then
		local ds = storeFor(Leaderboard.weeklyStore(week))
		if ds then
			local ok, pages = Retry.run(function()
				return ds:GetSortedAsync(false, 1):GetCurrentPage()
			end, retryOpts("read champion"))
			if ok then
				local rows = Leaderboard.rows(pages, 1)
				if rows[1] then
					championId = rows[1].userId
				end
			end
		end
	end
	championLoaded = true
	for _, fn in championWaiting do
		fn()
	end
	championWaiting = {}
end

local championStarted = false

function Leaderboards.checkChampion(player: Player, grant: () -> ())
	local userId = player.UserId
	local function decide()
		if championId == userId and player.Parent ~= nil then
			grant()
		end
	end
	if championLoaded then
		decide()
		return
	end
	table.insert(championWaiting, decide)
	if not championStarted then
		championStarted = true
		task.spawn(loadChampion)
	end
end

type Rows = {
	status: TextLabel, -- "NO DATA YET" / "Loading..." over the rows
	heads: { ImageLabel },
	names: { TextLabel },
	scores: { TextLabel },
	rowFrames: { Frame },
}

local onChampion: ((userId: number?, name: string) -> ())? = nil
local lastChampion: number? = nil

local function showStatus(r: Rows, text: string?)
	r.status.Visible = text ~= nil
	r.status.Text = text or ""
	for _, f in r.rowFrames do
		f.Visible = text == nil
	end
end

local function refreshBoard(board: { kind: Leaderboard.Kind, store: string, title: string })
	local storeName = board.store
	if board.kind == "weekly" then
		storeName = Leaderboard.weeklyStore(Leaderboard.weekIndex(os.time()))
	elseif board.kind == "smashes" then
		storeName = Leaderboard.smashesStore(Leaderboard.weekIndex(os.time()))
	end
	local ds = storeFor(storeName)
	if ds == nil then
		return
	end
	local ok, pages = Retry.run(function()
		return ds:GetSortedAsync(false, ROWS):GetCurrentPage()
	end, retryOpts("read " .. board.kind))
	if not ok then
		return
	end
	local rows = Leaderboard.rows(pages, ROWS)
	for _, r in rowGuis[board.kind] or {} do
		if #rows == 0 then
			showStatus(r, EMPTY_TEXT)
		else
			showStatus(r, nil)
			for i = 1, ROWS do
				local row = rows[i]
				r.rowFrames[i].Visible = row ~= nil
				if row then
					r.heads[i].Image = `rbxthumb://type=AvatarHeadShot&id={row.userId}&w=150&h=150`
					r.names[i].Text = nameOf(row.userId)
					r.scores[i].Text = tostring(row.score)
				end
			end
		end
	end
	if board.kind == "weekly" then
		local top = if rows[1] then rows[1].userId else nil
		if top ~= lastChampion and onChampion then
			lastChampion = top
			onChampion(top, if top then nameOf(top) else "")
		end
	end
end

local function label(
	parent: Instance,
	size: UDim2,
	pos: UDim2,
	text: string,
	px: number,
	color: Color3,
	align: Enum.TextXAlignment
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Enum.Font.FredokaOne
	l.TextSize = px
	l.Text = text
	l.TextColor3 = color
	l.TextXAlignment = align
	l.TextStrokeTransparency = 0.5
	l.TextStrokeColor3 = Color3.fromRGB(10, 14, 26)
	l.Parent = parent
	return l
end

-- One board face: a title and 5 rows (rank, avatar head, name, score). `face` is the side of the
-- panel that looks at the lobby's middle.
local function buildFace(
	panel: Part,
	board: { kind: Leaderboard.Kind, store: string, title: string },
	face: Enum.NormalId,
	accent: Color3
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Parent = panel
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 6
	stroke.Parent = frame
	label(
		frame,
		UDim2.fromScale(1, 0.15),
		UDim2.fromScale(0, 0.01),
		board.title,
		TITLE_SIZE,
		accent,
		Enum.TextXAlignment.Center
	)
	local r: Rows = {
		status = label(
			frame,
			UDim2.fromScale(0.9, 0.7),
			UDim2.fromScale(0.05, 0.2),
			LOADING,
			ROW_SIZE + 8,
			GOLD,
			Enum.TextXAlignment.Center
		),
		heads = {},
		names = {},
		scores = {},
		rowFrames = {},
	}
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(0.92, 0.15)
		row.Position = UDim2.fromScale(0.04, 0.17 + (i - 1) * 0.162)
		row.Visible = false
		row.Parent = frame
		label(
			row,
			UDim2.fromScale(0.1, 1),
			UDim2.fromScale(0, 0),
			tostring(i),
			ROW_SIZE,
			if i == 1 then GOLD else WHITE,
			Enum.TextXAlignment.Center
		)
		local head = Instance.new("ImageLabel")
		head.BackgroundColor3 = Color3.fromRGB(40, 48, 72)
		head.Size = UDim2.fromScale(0.15, 1)
		head.SizeConstraint = Enum.SizeConstraint.RelativeYY
		head.Position = UDim2.fromScale(0.11, 0)
		head.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = head
		table.insert(r.heads, head)
		table.insert(
			r.names,
			label(
				row,
				UDim2.fromScale(0.5, 1),
				UDim2.fromScale(0.3, 0),
				"",
				ROW_SIZE,
				WHITE,
				Enum.TextXAlignment.Left
			)
		)
		table.insert(
			r.scores,
			label(
				row,
				UDim2.fromScale(0.2, 1),
				UDim2.fromScale(0.8, 0),
				"",
				ROW_SIZE,
				GOLD,
				Enum.TextXAlignment.Right
			)
		)
		table.insert(r.rowFrames, row)
	end
	rowGuis[board.kind] = rowGuis[board.kind] or {}
	table.insert(rowGuis[board.kind], r)
end

-- Draw the two boards on the lobby's panels and start the refresh loop. Call once.
-- `faces` is the NormalId of each panel that looks at the lobby. `champion` is called when the
-- weekly #1 changes (userId nil = nobody yet).
function Leaderboards.init(
	panels: { weekly: Part, wins: Part },
	faces: Enum.NormalId,
	champion: ((userId: number?, name: string) -> ())?
)
	if inited then
		return
	end
	inited = true
	onChampion = champion
	local shown = {
		{
			board = Leaderboard.Weekly,
			panel = panels.weekly,
			accent = ORANGE,
			title = "TOP DRIVERS",
		},
		{ board = Leaderboard.Boards[1], panel = panels.wins, accent = BLUE, title = "WINS" },
	}
	for _, s in shown do
		local board = { kind = s.board.kind, store = s.board.store, title = s.title }
		buildFace(s.panel, board, faces, s.accent)
	end
	-- No data after a few seconds (no DataStore, outage, empty week): say so instead of "Loading...".
	task.delay(LOADING_TIMEOUT, function()
		for _, list in rowGuis do
			for _, r in list do
				if r.status.Text == LOADING then
					showStatus(r, EMPTY_TEXT)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			for _, s in shown do
				refreshBoard({ kind = s.board.kind, store = s.board.store, title = s.title })
			end
			task.wait(ProgressConfig.Board.refreshSeconds)
		end
	end)
end

return Leaderboards
