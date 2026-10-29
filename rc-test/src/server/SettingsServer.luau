--!strict
-- Smash SETTINGS (WINDOWS): each player's music / sound volume, shadows and name tags, kept in
-- their own small DataStore key (not the profile: a lost write only resets a slider).
-- The client sends its whole settings table on RemoteEvent SaveSettings; the server cleans it
-- (shared/GameSettings), takes at most one each SAVE_GAP s per player, shows it back on the
-- player's attributes (SetMusic, SetSfx, SetShadows, SetNames) and writes it when they leave
-- or at the next flush (only when it changed). No DataStore (Studio): this session only.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Forever = require(ReplicatedStorage.Shared.Forever)
local GameSettings = require(ReplicatedStorage.Shared.GameSettings)

local FLUSH = 60
local TRIES = 3

local SettingsServer = {}

local store: DataStore? = nil
local now: { [Player]: GameSettings.Settings } = {}
local dirty: { [Player]: boolean } = {}
local lastAsk: { [Player]: number } = {}

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

local function show(player: Player, s: GameSettings.Settings)
	player:SetAttribute("SetMusic", s.music)
	player:SetAttribute("SetSfx", s.sfx)
	player:SetAttribute("SetShadows", s.shadows)
	player:SetAttribute("SetNames", s.names)
end

local function save(player: Player)
	local s = now[player]
	local ds = store
	if not (s and ds and dirty[player]) then
		return
	end
	dirty[player] = nil
	local key = tostring(player.UserId)
	local ok = call("save", function()
		return ds:SetAsync(
			key,
			{ music = s.music, sfx = s.sfx, shadows = s.shadows, names = s.names }
		)
	end)
	if not ok and now[player] then
		dirty[player] = true -- (the next flush tries again)
	end
end

local function join(player: Player)
	local s = GameSettings.DEFAULTS
	local ds = store
	if ds then
		local key = tostring(player.UserId)
		local ok, got = call("load", function()
			return ds:GetAsync(key)
		end)
		if ok then
			s = GameSettings.clean(got)
		end
	end
	if player.Parent == nil then
		return
	end
	-- (a change sent while the load was out wins)
	now[player] = now[player] or s
	show(player, now[player])
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
		if last and t - last < GameSettings.SAVE_GAP then
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
		show(player, s)
	end)
	Players.PlayerAdded:Connect(function(p: Player)
		task.spawn(join, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(join, p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		save(p)
		now[p], dirty[p], lastAsk[p] = nil, nil, nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			task.spawn(save, p)
		end
		task.wait(2)
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH)
			Forever.step("Settings.flush", function()
				for p in dirty do
					save(p)
				end
			end)
		end
	end)
end

return SettingsServer
