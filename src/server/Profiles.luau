--!strict
-- Player persistence: session-locked UpdateAsync (jobId + timestamp), retries with backoff, autosave,
-- release on leave, flush on shutdown. Gameplay mutates the in-memory profile and calls markDirty.
-- If loading fails the player plays an UNSAVED default profile: we never write over data we could not read.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Paint = require(ReplicatedStorage.Shared.Paint)
local Retry = require(ReplicatedStorage.Shared.Retry)
local SessionLock = require(ReplicatedStorage.Shared.SessionLock)

type Profile = Inventory.Profile

type State = {
	profile: Profile?,
	dirty: boolean,
	unsaved: boolean, -- load failed or lock lost: never write
	busy: boolean, -- a save/load call is in flight
	nextSave: number,
	released: boolean,
}

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_SECONDS = 60
local LOAD_LOCK_TRIES = 5 -- other server may still be releasing
local LOAD_LOCK_WAIT = 3
local SHUTDOWN_MAX_WAIT = 25
local RETRY = { attempts = 5, baseDelay = 1, maxDelay = 8 }

local Profiles = {}

local store: DataStore? = nil
local states: { [Player]: State } = {}
local inited = false

local function getStore(): DataStore?
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			warn("[Profiles] DataStore unavailable: " .. tostring(result))
		end
	end
	return store
end

local function keyFor(player: Player): string
	return "p_" .. player.UserId
end

local function retryOpts(label: string): Retry.Options
	return {
		attempts = RETRY.attempts,
		baseDelay = RETRY.baseDelay,
		maxDelay = RETRY.maxDelay,
		wait = function(s)
			task.wait(s)
		end,
		onFail = function(attempt, err)
			warn(`[Profiles] {label} attempt {attempt}/{RETRY.attempts} failed: {err}`)
		end,
	}
end

local function copyProfile(p: Profile): Profile
	local owned = table.clone(p.owned)
	return {
		version = p.version,
		coins = p.coins,
		wins = p.wins,
		owned = owned,
		freePullUsed = p.freePullUsed,
		hintsSeen = table.clone(p.hintsSeen),
		progress = Progress.copy(p.progress),
		botLevel = p.botLevel,
		quests = Quests.clean(p.quests), -- clean makes a fresh copy
		daily = table.clone(p.daily),
		paint = Paint.copy(p.paint),
	}
end

local function acquire(state: State)
	while state.busy do
		task.wait(0.05)
	end
	state.busy = true
end

-- Returns "ok", "locked" or "error".
local function tryLoad(player: Player, _state: State): (string, Profile?)
	local ds = getStore()
	if ds == nil then
		return "error", nil
	end
	local loaded: Profile? = nil
	local blocked = false
	local ok = Retry.run(function()
		blocked = false
		loaded = nil
		ds:UpdateAsync(keyFor(player), function(old: any)
			local now = os.time()
			local can = SessionLock.canClaim(old, game.JobId, now)
			if not can then
				blocked = true
				return nil -- abort, nothing written
			end
			local profile = Inventory.migrate(old ~= nil and old.data or nil)
			loaded = profile
			return SessionLock.claim(old, game.JobId, now, copyProfile(profile))
		end)
		return true
	end, retryOpts("load " .. player.Name))
	if not ok then
		return "error", nil
	end
	if blocked then
		return "locked", nil
	end
	return "ok", loaded
end

local function load(player: Player)
	local state = states[player]
	acquire(state)
	local profile: Profile? = nil
	local status = "error"
	for attempt = 1, LOAD_LOCK_TRIES do
		if states[player] ~= state then
			break
		end
		status, profile = tryLoad(player, state)
		if status ~= "locked" then
			break
		end
		warn(
			`[Profiles] {player.Name} still locked by another server ({attempt}/{LOAD_LOCK_TRIES})`
		)
		if attempt < LOAD_LOCK_TRIES then
			task.wait(LOAD_LOCK_WAIT)
		end
	end
	state.busy = false
	if states[player] ~= state then
		-- left mid-load: give the lock back without touching data
		if status == "ok" and profile ~= nil then
			state.profile = profile
			state.released = false
			Profiles.release(player, state)
		end
		return
	end
	if status == "ok" and profile ~= nil then
		state.profile = profile
	else
		warn(`[Profiles] {player.Name}: data failed to load ({status}); playing UNSAVED`)
		state.unsaved = true
		state.profile = Inventory.default()
		player:SetAttribute("ProfileUnsaved", true)
	end
	state.nextSave = os.clock() + AUTOSAVE_SECONDS + (player.UserId % 15)
end

-- Writes the profile (and lock). final = also clear the lock. Returns true when stored.
local function save(player: Player, state: State, final: boolean): boolean
	local ds = getStore()
	local profile = state.profile
	if ds == nil or profile == nil or state.unsaved then
		return false
	end
	acquire(state)
	local snapshot = copyProfile(profile)
	local wasDirty = state.dirty
	state.dirty = false
	local lost = false
	local ok = Retry.run(function()
		lost = false
		ds:UpdateAsync(keyFor(player), function(old: any)
			local rec: SessionLock.Record?
			if final then
				rec = SessionLock.release(old, game.JobId, snapshot)
			else
				rec = SessionLock.save(old, game.JobId, os.time(), snapshot)
			end
			if rec == nil then
				lost = true
			end
			return rec -- nil aborts the write
		end)
		return true
	end, retryOpts("save " .. player.Name))
	state.busy = false
	if lost then
		warn(`[Profiles] {player.Name}: session lock lost; no further saves`)
		state.unsaved = true
		player:SetAttribute("ProfileUnsaved", true)
		return false
	end
	if not ok then
		state.dirty = state.dirty or wasDirty -- try again at next autosave
	end
	return ok
end

function Profiles.get(player: Player): Profile?
	local state = states[player]
	return state and state.profile or nil
end

function Profiles.waitFor(player: Player, timeoutSeconds: number): Profile?
	local deadline = os.clock() + timeoutSeconds
	while player.Parent ~= nil do
		local p = Profiles.get(player)
		if p then
			return p
		end
		if os.clock() >= deadline then
			return nil
		end
		task.wait(0.1)
	end
	return Profiles.get(player)
end

function Profiles.markDirty(player: Player)
	local state = states[player]
	if state then
		state.dirty = true
	end
end

-- Save and unlock. Safe to call twice. (Second param is internal.)
function Profiles.release(player: Player, stateOverride: State?)
	local state = stateOverride or states[player]
	if state == nil or state.released then
		return
	end
	state.released = true
	if state.profile ~= nil then
		save(player, state, true)
	end
	if states[player] == state then
		states[player] = nil
	end
end

local function onAdded(player: Player)
	if states[player] then
		return
	end
	states[player] = {
		profile = nil,
		dirty = false,
		unsaved = false,
		busy = false,
		nextSave = math.huge,
		released = false,
	}
	task.spawn(load, player)
end

function Profiles.init()
	if inited then
		return
	end
	inited = true

	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Profiles.release(player)
	end)

	-- Autosave: refreshes the lock every interval even when clean; staggered per player.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, state in states do
				if
					state.profile ~= nil
					and not state.unsaved
					and not state.released
					and now >= state.nextSave
				then
					state.nextSave = now + AUTOSAVE_SECONDS
					task.spawn(save, player, state, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in states do
			pending += 1
			task.spawn(function()
				Profiles.release(player)
				pending -= 1
			end)
		end
		if RunService:IsStudio() then
			return
		end
		local deadline = os.clock() + SHUTDOWN_MAX_WAIT
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Profiles
