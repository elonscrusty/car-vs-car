--!strict
-- Watches every car on a lobby plot (RunCheck), so only real laps, climbs and slides count:
-- they feed the daily jobs and a new player's first-lap coins. Also the coins chip, daily gift,
-- weekend boost and the "next goal" line.
-- Server -> client (StarsEvent): ("coins", count), ("saving", true / false / "retry"), ("toast", text),
-- ("daily", coins, days in a row, boost), ("jobs", lines, secondsToNewJobs) and
-- ("goal", goal or nil) = Rewards.next (what to save up for). The client never sends.
-- workspace "CoinBoost" = 2 on weekends (every coin gift doubled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CvcRules = require(ReplicatedStorage.Shared.CvcRules)
local DailyJobs = require(ReplicatedStorage.Shared.DailyJobs)
local Features = require(ReplicatedStorage.Shared.Features)
local Forever = require(ReplicatedStorage.Shared.Forever)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Medals = require(ReplicatedStorage.Shared.Medals)
local Profile = require(ReplicatedStorage.Shared.Profile)
local RunCheck = require(ReplicatedStorage.Shared.RunCheck)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Jobs = require(script.Parent.Jobs)
local PlayerData = require(script.Parent.PlayerData)

DailyJobs.useCvc(Features.CVC) -- Car VS Car: train, race and crate jobs
if Features.SMASH then
	DailyJobs.useSmash() -- Smash: smash, match and crate jobs (old race progress starts over)
end

local LOOK = 0.1 -- seconds between looks at the cars

local remote = Instance.new("RemoteEvent")
remote.Name = "StarsEvent"
remote.Parent = ReplicatedStorage

local slots = LobbyLayout.slots()

local function plotModel(slotIndex: number): Instance?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, m in plots:GetChildren() do
		if m:GetAttribute("Slot") == slotIndex then
			return m
		end
	end
	return nil
end

local function plotType(slotIndex: number): string
	local m = plotModel(slotIndex)
	local kind = m and m:GetAttribute("PlotType")
	if type(kind) == "string" and Medals.target(kind) then
		return kind
	end
	return slots[slotIndex].id
end

-- The plot as a track (LobbyLayout.track), else the plot's kind.
local function trackOf(slotIndex: number): TrackData.Track
	local t: any = LobbyLayout.track(slotIndex)
	local kind = plotType(slotIndex)
	if t.id ~= kind then
		local slot = slots[slotIndex]
		t = TrackData.get(kind)
		t.rcX, t.rcZ, t.rcAngle = slot.plotX, slot.plotZ, slot.angle
	end
	return t
end

-- ===== daily jobs (DailyJobs): 3 a day, paid in coins =====

local function sendJobs(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local now = os.time()
	local day = Profile.day(now)
	DailyJobs.today(data, day)
	remote:FireClient(
		player,
		"jobs",
		DailyJobs.lines(data, player.UserId, day),
		(day + 1) * 86400 - now
	)
end

-- Something a job may want happened to `player`.
local function job(player: Player, event: string, n: number?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local day = Profile.day(os.time())
	local before = table.clone(data.jobs.have)
	local boost = Profile.boost(os.time()) -- double coins on weekends
	local done = DailyJobs.add(data, player.UserId, day, event, n, boost)
	local changed = data.jobs.day ~= day or #done > 0
	for i, v in data.jobs.have do
		changed = changed or before[i] ~= v
	end
	if not changed then
		return
	end
	PlayerData.touch(player)
	for _, j in done do
		remote:FireClient(player, "toast", `+{j.coins * boost} coins: job done! {j.text}`)
		print(`[Stars] job {j.id} done by {player.Name} +{j.coins * boost} coins`)
	end
	if #done > 0 then
		player:SetAttribute("Coins", data.coins) -- (the garage and lobby chips read this)
		remote:FireClient(player, "coins", data.coins)
	end
	sendJobs(player)
end
Jobs.setHandler(job)

-- ===== runs =====

-- The same run twice in a row (tour 7 saw one lap print RECORD twice): pay and count it once.
local lastRun: { [Player]: { key: string, at: number } } = {}
local REPEAT_WINDOW = 2

local function onRun(player: Player, slotIndex: number, mode: string, value: number)
	local key = `{slotIndex}/{mode}/{value}`
	local last = lastRun[player]
	local clock = os.clock()
	if last and last.key == key and clock - last.at < REPEAT_WINDOW then
		print(`[Stars] skipped a repeat {mode} run by {player.Name} on plot {slotIndex}`)
		return
	end
	lastRun[player] = { key = key, at = clock }
	if not Medals.valid(mode, value) then
		return
	end
	if mode == "race" then
		job(player, "lap")
	elseif mode == "rock" then
		job(player, "climb")
	elseif mode == "drift" then
		if value >= 500 then
			job(player, "slide500")
		end
		if value >= 1500 then
			job(player, "slide1500")
		end
	end
	local data = PlayerData.get(player)
	local boost = Profile.boost(os.time()) -- double coins on weekends
	-- a new player's first lap: their first coins, and the next part of the screen opens up
	if
		data
		and (mode == "race" or (mode == "drift" and value >= 500)) -- (a lap, or a real slide)
		and data.stage < Profile.STAGE.LAPPED
		and PlayerData.raiseStage(player, Profile.STAGE.LAPPED)
	then
		data.coins += Profile.FIRST_LAP_COINS * boost
		remote:FireClient(player, "coins", data.coins)
		remote:FireClient(player, "toast", `+{Profile.FIRST_LAP_COINS * boost} coins: first lap!`)
	end
	print(`[Stars] {mode} {Medals.format(mode, value)} by {player.Name} on plot {slotIndex}`)
end

type Watch = {
	car: Instance,
	slot: number,
	mode: string,
	gates: { any }, -- a rebuilt track starts a new run check
	run: RunCheck.State,
	touched: { [number]: boolean }, -- drift: glow spots slid through in this slide
	flag: number, -- rock: the last checkpoint flag reached on this climb
}
local watching: { [Player]: Watch } = {}
local tracks: { [number]: TrackData.Track } = {}

local function localSpot(s: any): RunCheck.Spot
	return { x = s.x, z = s.z }
end

local function slotAt(p: Vector3): (number?, number, number, number)
	for i in slots do
		local t = tracks[i]
		local lx, ly, lz = TrackData.toLocal(t, true, p.X, p.Y, p.Z)
		if TrackData.inPlot(lx, lz) then
			return i, lx, ly, lz
		end
	end
	return nil, 0, 0, 0
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local trackKeys: { [number]: string } = {}
local function look(now: number)
	for i in slots do
		-- only rebuilt when the plot's kind changes
		local key = plotType(i)
		if trackKeys[i] ~= key or tracks[i] == nil then
			trackKeys[i] = key
			tracks[i] = trackOf(i)
		end
	end
	for _, player in Players:GetPlayers() do
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and (car :: Model).PrimaryPart
		if not (car and body) then
			watching[player] = nil
			continue
		end
		local cf = body.CFrame
		local slotIndex, lx, ly, lz = slotAt(cf.Position)
		local w = watching[player]
		if slotIndex == nil then
			watching[player] = nil
			continue
		end
		local t = tracks[slotIndex]
		if
			not (
				w
				and w.car == car
				and w.slot == slotIndex
				and w.mode == t.id
				and w.gates == t.gates
			)
		then
			local cps: { RunCheck.Spot } = {}
			for _, cp in t.checkpoints or {} do
				table.insert(cps, localSpot(cp.spawn))
			end
			watching[player] = {
				car = car,
				slot = slotIndex,
				mode = t.id,
				gates = t.gates,
				run = RunCheck.new(t.gates, t.mode, t.id, localSpot(t.spawn), cps, now, lx, ly, lz),
				touched = {},
				flag = 0,
			}
			continue
		end
		-- nose direction, plot-local
		local ax, _, az = TrackData.toLocal(t, true, cf.Position.X, 0, cf.Position.Z)
		local tip = cf.Position + cf.LookVector
		local bx, _, bz = TrackData.toLocal(t, true, tip.X, 0, tip.Z)
		rayParams.FilterDescendantsInstances = { car }
		local hit = workspace:Raycast(cf.Position, Vector3.new(0, -3, 0), rayParams)
		for _, e in RunCheck.step(w.run, now, lx, ly, lz, bx - ax, bz - az, hit ~= nil) do
			if e.kind == "lap" or e.kind == "finish" or e.kind == "drift" then
				onRun(player, slotIndex, w.mode, e.value)
			elseif e.kind == "void" then
				w.flag = 0
			end
		end
		if w.mode == "drift" then
			-- a glow spot counts once per slide, only while sliding (like the client's bonus)
			if w.run.chain > 0 then
				local zone = TrackData.plot("drift").touchZone(lx, lz)
				if zone and not w.touched[zone] then
					w.touched[zone] = true
					job(player, "touch")
				end
			elseif next(w.touched) then
				w.touched = {}
			end
		elseif w.mode == "rock" then
			local cps = t.checkpoints or {}
			local dx, dz = lx - t.spawn.x, lz - t.spawn.z
			if dx * dx + dz * dz <= RunCheck.SNAP * RunCheck.SNAP then
				w.flag = 0 -- back at the start: a new climb
			end
			for k = w.flag + 1, #cps do
				if LapTimer.inside(cps[k].gate, lx, ly, lz) then
					w.flag = k
					job(player, "flag" .. k)
				end
			end
		end
	end
end

-- ===== daily gift and weekend coins =====

-- The daily gift, the first time each day (on join, or at midnight UTC if they're still here).
-- The client shows the 7-day strip with ("daily", coins, days in a row, boost, free crate).
-- Car VS Car adds a free crate every day (CvcRules.daily).
local function dailyGift(player: Player, data: Profile.Data)
	-- new players get it once they've bought their first car (Car VS Car: opened their first
	-- crate), one new thing at a time
	if data.stage < Profile.STAGE.SHOPPED then
		return
	end
	local now = os.time()
	local boost = Profile.boost(now)
	local coins, streak, crate = 0, 0, false
	if Features.CVC then
		coins, streak, crate = CvcRules.daily(data, Profile.day(now), boost)
	else
		coins, streak = Profile.daily(data, Profile.day(now), boost)
	end
	if coins > 0 then
		-- marked taken (Profile.daily) before paying; saved now, not at the next autosave, so a
		-- crash or a quick rejoin on another server can't give it twice
		PlayerData.touch(player)
		task.spawn(PlayerData.save, player, false)
		if crate then
			local mod = script.Parent:FindFirstChild("GarageServer")
			if mod and mod:IsA("ModuleScript") then
				(require(mod) :: any).refresh(player) -- the crate count on the screens
			end
		end
		remote:FireClient(player, "coins", data.coins)
		remote:FireClient(player, "daily", coins, streak, boost, crate)
		print(`[Stars] daily gift {player.Name} day {streak} +{coins} coins (x{boost})`)
	end
end

-- Double coins on weekends: the client's banner reads this.
task.spawn(function()
	while true do
		Forever.step("DailyGift", function()
			local now = os.time()
			workspace:SetAttribute("CoinBoost", Profile.boost(now))
			for _, p in Players:GetPlayers() do
				local data = PlayerData.get(p)
				if data and data.dailyDay ~= Profile.day(now) then
					dailyGift(p, data)
				end
			end
		end)
		task.wait(30)
	end
end)

-- the visit reached the real save: show the real numbers, and the "retrying" note goes away
PlayerData.synced:Connect(function(player: Player, data: Profile.Data)
	remote:FireClient(player, "saving", true)
	remote:FireClient(player, "coins", data.coins)
	remote:FireClient(player, "toast", "Saving is back on!")
	sendJobs(player)
end)

PlayerData.loaded:Connect(function(player: Player, data: Profile.Data, saving: boolean)
	-- saving: true / false, or "retry" (the DataStore was down: trying again in the background)
	remote:FireClient(player, "saving", if PlayerData.isRetrying(player) then "retry" else saving)
	remote:FireClient(player, "coins", data.coins)
	sendJobs(player)
	dailyGift(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	watching[player] = nil
	lastRun[player] = nil
end)

PlayerData.staged:Connect(function(player: Player, stage: number)
	local data = PlayerData.get(player)
	if data and stage >= Profile.STAGE.SHOPPED then
		dailyGift(player, data)
	end
end)

PlayerData.start()

-- a new day: new jobs on everyone's panel
task.spawn(function()
	local shownDay = Profile.day(os.time())
	while true do
		task.wait(30)
		local day = Profile.day(os.time())
		if day ~= shownDay then
			shownDay = day
			for _, p in Players:GetPlayers() do
				Forever.step("NewJobs", function()
					sendJobs(p)
				end)
			end
		end
	end
end)

-- ===== race prizes and the next unlock =====

-- The goal to save up for, sent again whenever coins, cars or the garage level change (from any shop).
local goalSeen: { [Player]: string } = {}
local function goalOf(data: Profile.Data): Rewards.Goal?
	return Rewards.next(data :: any)
end
local function sendGoal(player: Player, force: boolean?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local n = 0
	for _ in data.cars do
		n += 1
	end
	local key = `{data.coins}/{n}/{data.plotLevel}`
	if goalSeen[player] == key and not force then
		return
	end
	local first = goalSeen[player] == nil
	goalSeen[player] = key
	if not first then
		remote:FireClient(player, "coins", data.coins)
	end
	remote:FireClient(player, "goal", goalOf(data))
end
task.spawn(function()
	while true do
		Forever.step("Goals", function()
			for _, p in Players:GetPlayers() do
				sendGoal(p)
			end
		end)
		task.wait(1)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	goalSeen[p] = nil
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < LOOK then
		return
	end
	acc = 0
	look(os.clock())
end)
