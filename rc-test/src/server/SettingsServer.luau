--!strict
-- Smash SETTINGS (WINDOWS): each player's music / sound volume, shadows and name tags, kept in
-- their own small DataStore key (not the profile: a lost write only resets a slider).
--   * join: the saved ones are read (retries) and shown once on the player's attributes SetMusic,
--     SetSfx, SetShadows, SetNames, SetCamera, then SetLoaded = true (defaults when there are none)
--   * RemoteEvent SaveSettings: the client's whole settings table, cleaned (shared/GameSettings);
--     the newest is kept in memory (asks closer than MIN_GAP are dropped), never echoed back
--   * written at the next flush or when they leave, only when changed, one write at a time per
--     player; a load that failed never writes (it would put defaults over a real save)
-- No DataStore (Studio): this session only.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Forever = require(ReplicatedStorage.Shared.Forever)
local GameSettings = require(ReplicatedStorage.Shared.GameSettings)

local FLUSH = 60
local TRIES = 3
local MIN_GAP = 0.25 -- (the client sends at most one each SAVE_GAP s: this only stops a flood)
local CLOSE_WAIT = 25

local SettingsServer = {}

local store: DataStore? = nil
local now: { [Player]: GameSettings.Settings } = {}
local dirty: { [Player]: boolean } = {}
local canSave: { [Player]: boolean } = {} -- the load answered (a save, or none yet)
local saving: { [Player]: boolean } = {}
local lastAsk: { [Player]: number } = {}
local inFlight = 0

local function call(what: string, fn: () -> any): (boolean, any)
	for i = 1, TRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Settings] {what} try {i}:`, result)
		if string.find(tostring(result), "403", 1, true) then
			break
		end
		if i < TRIES then
			task.wait(2 ^ i)
		end
	end
	return false, nil
end

-- Write this player's settings if they changed (waits for a write already going out).
local function save(player: Player, uid: number)
	while saving[player] do
		task.wait(0.2)
	end
	local s = now[player]
	local ds = store
	if not (s and ds and dirty[player] and canSave[player]) then
		return
	end
	dirty[player] = nil
	saving[player] = true
	inFlight += 1
	local ok = call("save", function()
		return ds:SetAsync(
			tostring(uid),
			{
				music = s.music,
				sfx = s.sfx,
				shadows = s.shadows,
				names = s.names,
				camera = s.camera,
			},
			{ uid }
		)
	end)
	inFlight -= 1
	saving[player] = nil
	if not ok and player.Parent ~= nil then
		dirty[player] = true -- (the next flush tries again)
	end
end

local function join(player: Player)
	local s = GameSettings.DEFAULTS
	local ds = store
	if ds then
		local ok, got = call("load", function()
			return ds:GetAsync(tostring(player.UserId))
		end)
		if ok then
			s = GameSettings.clean(got)
			canSave[player] = true
		end
	end
	if player.Parent == nil then
		return
	end
	-- (a change sent while the load was out wins)
	local use = now[player] or s
	now[player] = use
	player:SetAttribute("SetMusic", use.music)
	player:SetAttribute("SetSfx", use.sfx)
	player:SetAttribute("SetShadows", use.shadows)
	player:SetAttribute("SetNames", use.names)
	player:SetAttribute("SetCamera", use.camera)
	player:SetAttribute("SetLoaded", true)
end

function SettingsServer.start()
	local ok, got = pcall(function()
		return DataStoreService:GetDataStore("CvcSettings_v1")
	end)
	store = if ok then got else nil
	local remote = Instance.new("RemoteEvent")
	remote.Name = "SaveSettings"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player: Player, sent: any)
		local t = os.clock()
		local last = lastAsk[player]
		if (last and t - last < MIN_GAP) or player.Parent == nil then
			return
		end
		lastAsk[player] = t
		local s = GameSettings.clean(sent)
		local was = now[player]
		if was and GameSettings.same(was, s) then
			return
		end
		now[player] = s
		dirty[player] = true
	end)
	Players.PlayerAdded:Connect(function(p: Player)
		task.spawn(join, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(join, p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		save(p, p.UserId)
		now[p], dirty[p], canSave[p], lastAsk[p] = nil, nil, nil, nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			task.spawn(save, p, p.UserId)
		end
		local t = os.clock()
		task.wait(0.1)
		while inFlight > 0 and os.clock() - t < CLOSE_WAIT do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH)
			Forever.step("Settings.flush", function()
				-- (the list first: a save yields, and asks change `dirty` meanwhile)
				local list: { Player } = {}
				for p in dirty do
					table.insert(list, p)
				end
				for _, p in list do
					save(p, p.UserId)
				end
			end)
		end
	end)
end

return SettingsServer
