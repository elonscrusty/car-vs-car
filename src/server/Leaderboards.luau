--!strict
-- Global leaderboards: most wins and best win streak. Scores go to OrderedDataStores (best only,
-- throttled), the top rows are read every ProgressConfig.Board.refreshSeconds and drawn on two
-- boards beside the lobby's top racers sign. Server only; every DataStore call is pcall + retry.
-- Boards fail quietly (they show "no scores yet"): a board outage never touches gameplay or saves.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local ProgressConfig = require(ReplicatedStorage.Shared.ProgressConfig)
local Retry = require(ReplicatedStorage.Shared.Retry)

type Profile = { wins: number, progress: { bestStreak: number } }

local RETRY = { attempts = 3, baseDelay = 1, maxDelay = 4 }
local BOARD_SIZE = Vector3.new(14, 11, 0.4)
local PANEL = Color3.fromRGB(18, 24, 48) -- the navy of the other panels
local GOLD = Color3.fromRGB(255, 210, 70)
local WHITE = Color3.fromRGB(240, 244, 250)

local Leaderboards = {}

local stores: { [string]: OrderedDataStore } = {}
local lastSent: { [string]: { score: number, at: number } } = {} -- "<kind>_<userId>"
local names: { [number]: string } = {}
local labels: { [string]: { TextLabel } } = {} -- per kind, one label per surface
local inited = false

local function retryOpts(label: string): Retry.Options
	return {
		attempts = RETRY.attempts,
		baseDelay = RETRY.baseDelay,
		maxDelay = RETRY.maxDelay,
		wait = function(s)
			task.wait(s)
		end,
		onFail = function(attempt, err)
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

local function refreshBoard(board: { kind: Leaderboard.Kind, store: string, title: string })
	local storeName = board.store
	if board.kind == "weekly" then
		storeName = Leaderboard.weeklyStore(Leaderboard.weekIndex(os.time()))
	end
	local ds = storeFor(storeName)
	if ds == nil then
		return
	end
	local ok, pages = Retry.run(function()
		return ds:GetSortedAsync(false, ProgressConfig.Board.rows):GetCurrentPage()
	end, retryOpts("read " .. board.kind))
	if not ok then
		return
	end
	local rows = Leaderboard.rows(pages, ProgressConfig.Board.rows)
	local lines: { string } = {}
	for _, row in rows do
		table.insert(lines, Leaderboard.line(row, nameOf(row.userId)))
	end
	local text = if #lines > 0 then table.concat(lines, "\n") else "No scores yet.\nWin a match!"
	for _, label in labels[board.kind] or {} do
		label.Text = text
	end
end

-- One board: a panel with a title and 10 lines, readable from both sides.
local function buildBoard(
	folder: Folder,
	board: { kind: Leaderboard.Kind, store: string, title: string },
	pos: Vector3,
	yaw: number
)
	local part = Instance.new("Part")
	part.Name = "Board_" .. board.kind
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = BOARD_SIZE
	part.Color = PANEL
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part.Parent = folder
	labels[board.kind] = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = part
		local frame = Instance.new("Frame") -- gold outline like the other panels
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = gui
		local outline = Instance.new("UIStroke")
		outline.Color = GOLD
		outline.Thickness = 4
		outline.Parent = frame
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.14)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = GOLD
		title.Text = board.title
		title.Parent = gui
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromScale(0.08, 0.16)
		body.Size = UDim2.fromScale(0.84, 0.8)
		body.Font = Enum.Font.FredokaOne
		body.TextScaled = true
		body.TextColor3 = WHITE
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = "Loading..."
		body.Parent = gui
		table.insert(labels[board.kind], body)
	end
end

-- Build both boards at `center` (world position of the middle of the pair, boards stand on the floor
-- facing +Z) and start the refresh loop. Call once.
function Leaderboards.init(folder: Folder, center: Vector3)
	if inited then
		return
	end
	inited = true
	local step = BOARD_SIZE.X + 2
	-- Left to right: all-time wins, this week's wins, best streak.
	local shown = { Leaderboard.Boards[1], Leaderboard.Weekly, Leaderboard.Boards[2] }
	for i, board in shown do
		buildBoard(folder, board, center + Vector3.new((i - 2) * step, BOARD_SIZE.Y / 2 + 1, 0), 0)
	end
	task.spawn(function()
		while true do
			for _, board in shown do
				refreshBoard(board)
			end
			task.wait(ProgressConfig.Board.refreshSeconds)
		end
	end)
end

return Leaderboards
