--!strict
-- Saves each player's stars and plot records (carter's stars loop, phase 1). Session-locked: a
-- save holds the id of the server using it, so two servers never write over each other; a lock
-- nobody refreshed for Profile.LOCK_TIMEOUT is stale and may be taken. Every call retries with
-- backoff. Autosave every minute, and a last save (lock let go) on leave and on shutdown.
-- No DataStore (Studio without API access): plays on with an unsaved profile and says so once.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(ReplicatedStorage.Shared.Profile)
local SaveRetry = require(ReplicatedStorage.Shared.SaveRetry)

local STORE = "RCPlayerData_v1"
local AUTOSAVE = 60
local LEAVE_RETRIES = 3 -- more leave-saves after a failed one, LEAVE_RETRY_WAIT s apart
local LEAVE_RETRY_WAIT = 10

local PlayerData = {}

type Entry = {
	data: Profile.Data,
	canSave: boolean,
	dirty: boolean,
	gone: boolean,
	retrying: boolean, -- the DataStore was down at join: still trying to reach the real save
}

local job = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local entries: { [Player]: Entry } = {}
local loading: { [Player]: true } = {}
-- `loaded` (player, data, saving). Not a BindableEvent: Fire would hand each listener a COPY of
-- `data`, so changes made there (the daily gift, pings) never reached the saved table.
type Listener = (Player, Profile.Data, boolean) -> ()
local listeners: { Listener } = {}
PlayerData.loaded = {
	Connect = function(_self: any, fn: Listener)
		table.insert(listeners, fn)
	end,
}

-- `synced` (player, data): a visit that started unsaved reached the real save; `data` (the same
-- table as before) now holds the real save plus what the visit earned. Show it again.
local syncedListeners: { Listener } = {}
PlayerData.synced = {
	Connect = function(_self: any, fn: (Player, Profile.Data) -> ())
		table.insert(syncedListeners, fn :: any)
	end,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] no DataStore, nothing will save (Studio: turn on API access):", result)
	end
end

local function key(userId: number): string
	return "p_" .. userId
end

-- UpdateAsync with retries. `fn` may return nil to leave the save alone.
local function update(userId: number, fn: (any) -> any): (boolean, any, string?)
	local s = store
	if s == nil then
		return false, nil, nil
	end
	return SaveRetry.run(
		function()
			return s:UpdateAsync(key(userId), fn)
		end,
		task.wait,
		function(i, err)
			warn(`[PlayerData] {userId} try {i}:`, err)
		end
	)
end

function PlayerData.get(player: Player): Profile.Data?
	local e = entries[player]
	return if e then e.data else nil
end

-- True while this player's visit is unsaved but still trying to reach their real save.
function PlayerData.isRetrying(player: Player): boolean
	local e = entries[player]
	return e ~= nil and e.retrying
end

-- Something in the data changed: save it on the next autosave.
function PlayerData.touch(player: Player)
	local e = entries[player]
	if e then
		e.dirty = true
	end
end

-- `staged` (player, stage): a player moved up a stage (Profile.STAGE).
type StageListener = (Player, number) -> ()
local stageListeners: { StageListener } = {}
PlayerData.staged = {
	Connect = function(_self: any, fn: StageListener)
		table.insert(stageListeners, fn)
	end,
}

-- Move a player up to stage n (never down): saved, and the Stage attribute their screen reads.
function PlayerData.raiseStage(player: Player, n: number): boolean
	local e = entries[player]
	if not (e and Profile.raiseStage(e.data, n)) then
		return false
	end
	e.dirty = true
	player:SetAttribute("Stage", e.data.stage)
	for _, fn in stageListeners do
		task.spawn(fn, player, e.data.stage)
	end
	return true
end

local reconnect: (Player, Entry) -> ()

function PlayerData.load(player: Player)
	-- PlayerAdded can come after the GetPlayers() loop already started loading this player
	-- (deferred events): load once, or `loaded` fires twice (two daily gifts)
	if entries[player] or loading[player] then
		return
	end
	loading[player] = true
	local data: Profile.Data? = nil
	local canSave = false
	local retry = false
	if store then
		-- take the lock; another server may still be letting go of it, so wait a little, then
		-- take it anyway (a server that crashed or was stopped never lets go)
		-- (6 tries = up to 45 s: the old server's leave-save may retry for ~15 s; taking
		-- the lock sooner loads an older save and that server's last minute is lost)
		local TAKE_TRIES = 6
		for attempt = 1, TAKE_TRIES do
			local blocked = false
			local readOnly = false
			local force = attempt == TAKE_TRIES
			local ok, _, err = update(player.UserId, function(old: any): any
				local step = Profile.loadStep(old, job, os.time(), force)
				blocked = step.kind == "blocked"
				readOnly = step.kind == "readOnly"
				if step.kind ~= "blocked" then
					data = step.data
				end
				return if step.kind == "write" then step.record else nil
			end)
			if ok and readOnly then
				warn(
					`[PlayerData] {player.Name}: save is broken or from a newer version, not saving`
				)
				break
			end
			if ok and not blocked then
				canSave = data ~= nil
				break
			end
			if not ok then
				-- 403 = API access off (Studio): retrying later would not help either
				retry = not string.find(err or "", "403", 1, true)
				break
			end
			task.wait(attempt * 3)
		end
		if not canSave then
			warn(`[PlayerData] {player.Name}: DataStore is down, playing without saving`)
		end
	end
	loading[player] = nil
	if player.Parent == nil then
		-- left while loading: let the lock go again
		if canSave then
			update(player.UserId, function(old: any): any
				if type(old) == "table" and type(old.lock) == "table" and old.lock.job == job then
					return { data = old.data }
				end
				return nil
			end)
		end
		return
	end
	local final = data or Profile.new()
	local entry: Entry =
		{ data = final, canSave = canSave, dirty = false, gone = false, retrying = retry }
	entries[player] = entry
	player:SetAttribute("Stage", final.stage) -- what the screen shows (JoinStage)
	for _, fn in listeners do
		task.spawn(fn, player, final, canSave)
	end
	if retry then
		task.spawn(reconnect, player, entry)
	end
end

-- The DataStore was down at join: keep trying, and once it answers, add what this visit earned
-- to the real save (never replace it). Waits 15 s, then 30 s, then a minute between rounds.
function reconnect(player: Player, e: Entry)
	local base = Profile.new()
	local round = 0
	while e.retrying and not e.gone and player.Parent ~= nil do
		task.wait(math.min(15 * 2 ^ round, 60))
		round += 1
		if e.gone or player.Parent == nil then
			break
		end
		local coinsSeen = e.data.coins
		local merged: Profile.Data? = nil
		local readOnly = false
		-- the first rounds are polite about another server's lock; later ones take it
		local force = round >= 3
		local ok, _, err = update(player.UserId, function(old: any): any
			local step = Profile.loadStep(old, job, os.time(), force)
			coinsSeen = e.data.coins
			if step.kind == "blocked" then
				merged = nil
				return nil
			end
			readOnly = step.kind == "readOnly"
			if step.kind == "readOnly" or step.data == nil then
				return nil
			end
			merged = Profile.mergeVisit(step.data, e.data, base)
			return { data = merged, lock = { job = job, at = os.time() } }
		end)
		if ok and readOnly then
			warn(`[PlayerData] {player.Name}: save is broken or from a newer version, not saving`)
			e.retrying = false
			break
		elseif ok and merged then
			-- earned while the write was on its way: keep it
			merged.coins = math.clamp(
				merged.coins + math.max(e.data.coins - coinsSeen, 0),
				0,
				Profile.MAX_COINS
			)
			-- same table as before, so everything that kept `data` sees the real save
			for k in e.data :: any do
				(e.data :: any)[k] = nil
			end
			for k, v in merged :: any do
				(e.data :: any)[k] = v
			end
			e.canSave = true
			e.retrying = false
			e.dirty = true
			print(`[PlayerData] {player.Name}: reached the real save, visit coins added`)
			player:SetAttribute("Stage", e.data.stage)
			for _, fn in syncedListeners do
				task.spawn(fn :: any, player, e.data)
			end
			return
		elseif not ok and string.find(err or "", "403", 1, true) then
			e.retrying = false
		end
	end
	e.retrying = false
end

function PlayerData.save(player: Player, letGo: boolean)
	local e = entries[player]
	if not (e and e.canSave) then
		return
	end
	if not (e.dirty or letGo) then
		return
	end
	e.dirty = false
	local lost = false
	local ok = update(player.UserId, function(old: any): any
		local step = Profile.saveStep(old, job, e.data, letGo, e.gone, os.time())
		lost = step.kind == "lost"
		return if step.kind == "write" then step.record else nil
	end)
	if lost then
		e.canSave = false
		warn(`[PlayerData] {player.Name}: another server has this save now, stopped saving`)
	elseif not ok then
		e.dirty = true
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(function(p)
		PlayerData.load(p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(PlayerData.load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local e = entries[p]
		if e then
			e.gone = true
		end
		PlayerData.save(p, true)
		-- the leave-save failed (DataStore trouble): keep trying a while before letting go, so
		-- the minutes since the last autosave aren't lost (BindToClose still sees the entry)
		local round = 0
		while e and e.canSave and e.dirty and round < LEAVE_RETRIES do
			round += 1
			task.wait(LEAVE_RETRY_WAIT)
			PlayerData.save(p, true)
		end
		entries[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for p, e in entries do
				-- refresh the lock even when nothing changed, so it never looks stale
				e.dirty = true
				task.spawn(PlayerData.save, p, false)
			end
		end
	end)
	game:BindToClose(function()
		local left = 0
		for p in entries do
			left += 1
			task.spawn(function()
				PlayerData.save(p, true)
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return PlayerData
