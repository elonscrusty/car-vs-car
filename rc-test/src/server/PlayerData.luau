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

local STORE = "RCPlayerData_v1"
local AUTOSAVE = 60
local TRIES = 4

local PlayerData = {}

type Entry = { data: Profile.Data, canSave: boolean, dirty: boolean, gone: boolean }

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
local function update(userId: number, fn: (any) -> any): (boolean, any)
	local s = store
	if s == nil then
		return false, nil
	end
	for i = 1, TRIES do
		local ok, result = pcall(function()
			return s:UpdateAsync(key(userId), fn)
		end)
		if ok then
			return true, result
		end
		warn(`[PlayerData] {userId} try {i}:`, result)
		-- Studio with API access off: trying again only makes the player wait ~14 s for nothing
		if string.find(tostring(result), "403", 1, true) then
			break
		end
		if i < TRIES then
			task.wait(2 ^ i)
		end
	end
	return false, nil
end

function PlayerData.get(player: Player): Profile.Data?
	local e = entries[player]
	return if e then e.data else nil
end

-- Something in the data changed: save it on the next autosave.
function PlayerData.touch(player: Player)
	local e = entries[player]
	if e then
		e.dirty = true
	end
end

function PlayerData.load(player: Player)
	-- PlayerAdded can come after the GetPlayers() loop already started loading this player
	-- (deferred events): load once, or `loaded` fires twice (two daily gifts)
	if entries[player] or loading[player] then
		return
	end
	loading[player] = true
	local data: Profile.Data? = nil
	local canSave = false
	if store then
		-- take the lock; another server may still be letting go of it, so wait a little, then
		-- take it anyway (a server that crashed or was stopped never lets go)
		local TAKE_TRIES = 4
		for attempt = 1, TAKE_TRIES do
			local blocked = false
			local readOnly = false
			local force = attempt == TAKE_TRIES
			local ok = update(player.UserId, function(old: any): any
				local now = os.time()
				if type(old) == "table" and not Profile.canTake(old.lock, job, now, force) then
					blocked = true
					return nil
				end
				blocked = false
				local plan = Profile.loadPlan(old)
				readOnly = plan == "readOnly"
				local d = Profile.migrate(if plan ~= "fresh" then old.data else nil)
				data = d
				if readOnly then
					return nil -- never write over a save this server can't read right
				end
				return { data = d, lock = { job = job, at = now } }
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
	entries[player] = { data = final, canSave = canSave, dirty = false, gone = false }
	for _, fn in listeners do
		task.spawn(fn, player, final, canSave)
	end
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
		if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= job then
			lost = true -- another server took over: never write over it
			return nil
		end
		lost = false
		if e.gone and not letGo then
			return nil -- the leave save already let the lock go: a late autosave mustn't take it back
		end
		return { data = e.data, lock = if letGo then nil else { job = job, at = os.time() } }
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
