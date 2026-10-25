--!strict
-- The server race (carter's loop, rc-game/build-track/PLAN.md): a 5 minute break, then the
-- whole server races on one random player's plot. A sign over the top of the street and a chip
-- on every screen count the break down; 10 s before the start the plot is picked and named. At
-- the start everyone (up to ServerRace.MAX) is put on that plot's grid and the start lights run
-- (their screens). The server counts each car's laps from where its car is (the same gates as the lap
-- timer): first to finish ServerRace.LAPS laps wins, and everyone sees who won. Then the racers
-- walk again. Driving is not touched: the cars are the players' own.
-- Plain maths (times, grid, order) is ServerRace's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Profile = require(ReplicatedStorage.Shared.Profile)
local RunCheck = require(ReplicatedStorage.Shared.RunCheck)
local Jobs = require(script.Parent.Jobs)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

-- The track builder's traced tracks (built plots): loop(), lineSample() like Plots/Race.
local function tracedFor(slot: number): any?
	local mod = script.Parent:FindFirstChild("TrackBuild")
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	local ok, res = pcall(function(): any
		return (require(mod) :: any).trackFor(slot)
	end)
	return if ok then res else nil
end

-- Grid spot k on this plot, plot-local: lined up behind its start line (a built track's, else
-- the street race plot's), or the plot's own start spot when it has neither.
local function gridSpot(slot: number, t: TrackData.Track, k: number): ServerRace.Spawn
	local src = tracedFor(slot)
	if
		src == nil
		and LobbyLayout.slots()[slot].id == "race"
		and LobbyLayout.custom[slot] == nil
	then
		src = TrackData.plot("race")
	end
	if src then
		local ok, spot = pcall(ServerRace.gridOn, src, k, t.spawn.y)
		if ok then
			return spot
		end
	end
	return t.spawn
end

export type Hooks = {
	remote: RemoteEvent, -- RCControl: ("drive", slot, grid) puts a player on the grid
	walk: (player: Player) -> (), -- off the plot, back to walking
}

type Racer = {
	player: Player,
	name: string,
	timer: LapTimer.State,
	laps: number,
	time: number?,
	jumped: boolean, -- over the line before GO: the clock waits for a full lap
	waitLeave: boolean, -- jumped and still on the line
	started: boolean,
	out: boolean, -- walked off or left the game
	place: number, -- live place (1 = in front)
	finishedNow: boolean?, -- crossed the line for the last time this frame
	run: RunCheck.State?, -- a drift round: the server's own drift count (from GO)
	score: number, -- a drift round: points from slides that are over
}

local ServerRaceRunner = {}

-- Server -> client: ("state", phase, startAt, count, kind, where) with phase "wait" | "call" |
-- "racing" (startAt = workspace:GetServerTimeNow() time of the start, count = unused now that
-- everyone races, kind = "race" | "drift" (the picked plot's), where = "MIA'S TRACK" once
-- picked), ("result", rows) when a race ends: rows = { { name, time?, score?, laps, coins?,
-- stars? } } best first (what that racer was paid; score = a drift round's points). To one
-- racer: ("finished", place) when its car crosses the line for the last time, ("ends", endsAt)
-- when the winner is in (the others have until endsAt), or ("ends", endsAt, "drift") at the
-- start of a drift round (when it ends). Live places: the racer's attributes RacePlace /
-- RaceCars (nil = no race).
local event = Instance.new("RemoteEvent")
event.Name = "ServerRace"
event.Parent = ReplicatedStorage

local phase = "wait"
local startAt = 0
local picked: number? = nil -- the plot this round is on (from CALL seconds before the start)
local where = "" -- its name for the sign and the screens
local random = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

-- For the track builder (TrackBuild): BuildOpen = true while the break is on (plots may be
-- edited), false from the moment the round's plot is picked until the race is over;
-- BuildEndsAt = os.time() when building closes.
local function setBuild()
	workspace:SetAttribute("BuildOpen", phase == "wait")
	workspace:SetAttribute("BuildEndsAt", math.floor(startAt - ServerRace.CALL))
end

local function sendState(to: Player?)
	if to == nil then
		setBuild()
	end
	local kind = if picked and LobbyLayout.track(picked).id == "drift" then "drift" else "race"
	local list = if to then { to } else Players:GetPlayers()
	for _, p in list do
		event:FireClient(p, "state", phase, startAt, 0, kind, where)
	end
end

-- QUICK RACE asks this first. Everyone races in the server race now (no join window), so it
-- never takes them: QUICK RACE goes on to a free race plot for the break.
function ServerRaceRunner.joinOpen(_player: Player): boolean
	return false
end

-- Can this plot hold the server race? A built track says so with TrackReady on its plot model
-- (TrackBuild: a closed loop through the start); until a plot has that, the street's race
-- plots are.
function ServerRaceRunner.isReady(slot: number): boolean
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, m in plots:GetChildren() do
			if m:GetAttribute("Slot") == slot and m:GetAttribute("TrackReady") ~= nil then
				-- (a drift plot, the owner's pick, holds a drift round)
				return m:GetAttribute("TrackReady") == true
			end
		end
	end
	local s = LobbyLayout.slots()[slot]
	return s ~= nil and s.id == "race"
end

-- The sign over the top of the street (the spawn lobby end), readable from both sides.
local function buildSign(): { TextLabel }
	local road = LobbyLayout.road()
	local z = road.minZ + 5
	local folder = Instance.new("Model")
	folder.Name = "ServerRaceSign"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	local postX = LobbyLayout.ROAD_W / 2 + 0.6
	for _, s in { -1, 1 } do
		part(
			"Post",
			Vector3.new(0.8, 13, 0.8),
			CFrame.new(s * postX, 6.5, z),
			Color3.fromRGB(40, 40, 46)
		)
	end
	local board = part(
		"Board",
		Vector3.new(2 * postX + 0.8, 4.6, 0.6),
		CFrame.new(0, 11, z),
		Color3.fromRGB(22, 22, 26)
	)
	-- checkered strip on top
	for i = 0, 9 do
		part(
			"Checker",
			Vector3.new((2 * postX + 0.8) / 10, 0.7, 0.7),
			CFrame.new(-(postX + 0.4) + (i + 0.5) * (2 * postX + 0.8) / 10, 13.65, z),
			if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(30, 30, 34)
		)
	end
	folder.Parent = workspace
	local labels: { TextLabel } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(0.94, 0.86)
		text.Position = UDim2.fromScale(0.03, 0.07)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 213, 79)
		text.Parent = gui
		table.insert(labels, text)
	end
	return labels
end

-- This round's plot: a random race-ready plot someone owns, else one of the street's own.
local function pickSlot(): number?
	local owned, spare = {}, {}
	for _, s in LobbyLayout.slots() do
		if ServerRaceRunner.isReady(s.index) then
			table.insert(if LobbyPlots.ownerOf(s.index) then owned else spare, s.index)
		end
	end
	return ServerRace.pick(owned, spare, random:NextNumber())
end

local function nameOf(slot: number): string
	local owner = LobbyPlots.ownerOf(slot)
	return ServerRace.trackName(if owner then owner.DisplayName else "the street")
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function carBody(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local body = car and (car :: Model).PrimaryPart
	return body
end

-- Pay a player coins and tell their screen (the coin chip and a toast, Stars.server's remote).
-- the car a racer drove, for the result card (cars get shown off): their pick in this mode
local function carName(uid: number?, mode: string): string?
	local p = if uid then Players:GetPlayerByUserId(uid) else nil
	local data = if p then PlayerData.get(p) else nil
	if not data then
		return nil
	end
	local ok, car = pcall(CarCatalog.equipped, data :: any, mode)
	return if ok and car then car.name else nil
end

local function pay(player: Player, coins: number, why: string)
	local data = PlayerData.get(player)
	if not data or coins <= 0 then
		return
	end
	coins *= Profile.boost(os.time()) -- double coins on weekends
	data.coins += coins
	PlayerData.touch(player)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "coins", data.coins)
		stars:FireClient(player, "toast", `+{coins} coins: {why}`)
	end
end

-- Stars for a race (ServerRace.starsFor): saved, then the star chip and the car hear of it.
local function giveStars(player: Player, n: number)
	local data = PlayerData.get(player)
	if not data or n <= 0 or Profile.addRaceStars(data, n) <= 0 then
		return
	end
	PlayerData.touch(player)
	Jobs.fire(player, "stars", n)
	player:SetAttribute("Stars", data.stars)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "stars", data.stars)
		stars:FireClient(player, "toast", `+{n} ⭐ for the race`)
	end
end

-- Every racer gets coins (and finishers stars) by place; the plot's owner gets a bonus for a
-- picked track. Returns uid -> coins (all of it, bonus too) and uid -> stars for the result card.
local function payRace(
	ranked: { ServerRace.Entry },
	racers: { Racer },
	slot: number
): ({ [number]: number }, { [number]: number })
	local byId: { [number]: Player } = {}
	for _, r in racers do
		byId[r.player.UserId] = r.player
	end
	local paid: { [number]: number } = {}
	local starred: { [number]: number } = {}
	for place, e in ranked do
		local p = if e.uid then byId[e.uid] else nil
		if p and p.Parent then
			local done = ServerRace.finished(e)
			local coins = ServerRace.payFor(place, done)
			paid[p.UserId] = coins * Profile.boost(os.time())
			local nth = ({ "1st", "2nd", "3rd" })[place] or `{place}th`
			pay(p, coins, if place == 1 and done then "you WON!" else `{nth} place`)
			if done then
				Jobs.fire(p, "raceDone")
				if place <= 3 then
					Jobs.fire(p, "raceTop3")
				end
				if place == 1 then
					Jobs.fire(p, "raceWin")
				end
			end
			local n = ServerRace.starsFor(place, done, #ranked)
			starred[p.UserId] = n
			giveStars(p, n)
		end
	end
	local owner = LobbyPlots.ownerOf(slot)
	if owner and owner.Parent then
		pay(owner, ServerRace.PAY_OWNER, "your track was picked!")
		-- one number per row: the owner's row counts the bonus too
		if paid[owner.UserId] then
			paid[owner.UserId] += ServerRace.PAY_OWNER * Profile.boost(os.time())
		end
	end
	return paid, starred
end

local function runRace(hooks: Hooks, slot: number)
	-- everyone in the server (the first MAX)
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if #list < ServerRace.MAX then
			table.insert(list, p)
		end
	end
	phase = "racing"
	sendState()
	local t: TrackData.Track = LobbyLayout.track(slot)
	-- whoever is on that plot and isn't racing gets off it first
	local other = LobbyPlots.driverOf(slot)
	if other and not table.find(list, other) then
		hooks.walk(other)
	end
	local racers: { Racer } = {}
	for k, p in list do
		if p.Parent then
			if LobbyPlots.drivingOf(p) ~= nil then
				hooks.walk(p)
			end
			LobbyPlots.claim(p, slot)
			hooks.remote:FireClient(p, "drive", slot, gridSpot(slot, t, k))
			table.insert(racers, {
				player = p,
				name = p.DisplayName,
				timer = LapTimer.new(t.gates, t.mode),
				laps = 0,
				time = nil,
				jumped = false,
				waitLeave = false,
				started = false,
				out = false,
				place = k,
				score = 0,
			})
		end
	end
	-- GO: when the lights on their screens go green (plus a little for the message to arrive)
	local goAt = os.clock() + ServerRace.GO_DELAY + 0.3
	local firstAt: number? = nil
	local gate1 = t.gates[1]
	local gates = #t.gates
	local placesAt = 0
	local drift = t.id == "drift"
	if drift then
		-- a drift round: everyone has DRIFT_TIME from GO, the screens count it down
		local endsAt = now() + (goAt - os.clock()) + ServerRace.DRIFT_TIME
		for _, r in racers do
			event:FireClient(r.player, "ends", endsAt, "drift")
		end
	end
	while drift do
		RunService.Heartbeat:Wait()
		local clock = os.clock()
		local entries: { ServerRace.Entry } = {}
		local runs: { ServerRace.Run } = {}
		for _, r in racers do
			local p = r.player
			if not r.out and (p.Parent == nil or LobbyPlots.drivingOf(p) ~= slot) then
				r.out = true -- walked off or left: keeps the points so far
			end
			local body = if r.out then nil else carBody(p)
			if body and clock >= goAt then
				local cf = body.CFrame
				local pos = cf.Position
				local lx, ly, lz = TrackData.toLocal(t, true, pos.X, pos.Y, pos.Z)
				local run = r.run
				if run == nil then
					r.run = RunCheck.new(
						t.gates,
						t.mode,
						"drift",
						{ x = t.spawn.x, z = t.spawn.z },
						{},
						clock,
						lx,
						ly,
						lz
					)
				else
					local ax, _, az = TrackData.toLocal(t, true, pos.X, 0, pos.Z)
					local tip = pos + cf.LookVector
					local bx, _, bz = TrackData.toLocal(t, true, tip.X, 0, tip.Z)
					rayParams.FilterDescendantsInstances = { body.Parent :: Instance }
					local hit = workspace:Raycast(pos, Vector3.new(0, -3, 0), rayParams)
					for _, e in RunCheck.step(run, clock, lx, ly, lz, bx - ax, bz - az, hit ~= nil) do
						if e.kind == "drift" then
							r.score += e.value
						end
					end
				end
			end
			local run = r.run
			local live = r.score + (if run and not r.out then run.chain else 0)
			table.insert(runs, { progress = if r.out then -1 else live })
			if p.Parent then
				table.insert(entries, {
					name = r.name,
					uid = p.UserId,
					laps = 0,
					score = math.floor(live),
				})
			end
		end
		if clock >= placesAt then
			placesAt = clock + 0.25
			local place = ServerRace.places(runs)
			for i, r in racers do
				r.place = place[i]
				if r.player.Parent then
					r.player:SetAttribute("RacePlace", r.place)
					r.player:SetAttribute("RaceCars", #racers)
				end
			end
		end
		local anyIn = false
		for _, r in racers do
			anyIn = anyIn or not r.out
		end
		local since = clock - goAt
		if (not anyIn and since > 0) or since >= ServerRace.DRIFT_TIME then
			local ranked = ServerRace.rankDrift(entries)
			local paid, starred = payRace(ranked, racers, slot)
			local rows = {}
			for _, e in ranked do
				local coins = if e.uid then paid[e.uid] else nil
				local stars = if e.uid then starred[e.uid] else nil
				table.insert(rows, {
					name = e.name,
					score = e.score,
					laps = 0,
					coins = coins,
					stars = stars,
					car = carName(e.uid, "drift"),
				})
			end
			event:FireAllClients("result", rows)
			break
		end
	end
	while not drift do
		RunService.Heartbeat:Wait()
		local clock = os.clock()
		local entries: { ServerRace.Entry } = {}
		for _, r in racers do
			local p = r.player
			if not r.out and (p.Parent == nil or LobbyPlots.drivingOf(p) ~= slot) then
				r.out = true -- walked off or left: keeps the laps done so far
			end
			local body = if r.out then nil else carBody(p)
			if body and r.time == nil then
				local pos = body.Position
				local lx, ly, lz = TrackData.toLocal(t, true, pos.X, pos.Y, pos.Z)
				local onLine = LapTimer.inside(gate1, lx, ly, lz)
				if clock < goAt then
					if onLine then
						r.jumped, r.waitLeave = true, true
					end
				elseif not r.started then
					r.started = true
					if not r.jumped then
						LapTimer.go(r.timer, goAt)
					end
				elseif r.waitLeave then
					r.waitLeave = onLine
				elseif LapTimer.update(r.timer, clock, lx, ly, lz) == "lap" then
					r.laps += 1
					if r.laps >= ServerRace.LAPS then
						r.time = clock - goAt
						if firstAt == nil then
							firstAt = clock - goAt
							-- the others now race the clock
							local endsAt = now()
								+ math.min(
									ServerRace.AFTER_WIN,
									ServerRace.TIME_LIMIT - (clock - goAt)
								)
							for _, o in racers do
								if o ~= r and o.player.Parent then
									event:FireClient(o.player, "ends", endsAt)
								end
							end
						end
						r.finishedNow = true
					end
				end
			end
			if p.Parent then
				table.insert(
					entries,
					{ name = r.name, uid = p.UserId, laps = r.laps, time = r.time }
				)
			end
		end
		-- live places, a few times a second (finishers by time, then how far round)
		if clock >= placesAt then
			placesAt = clock + 0.25
			local runs: { ServerRace.Run } = {}
			for _, r in racers do
				local s = r.timer
				local passed = if s.running then s.next - 1 else 0
				local g = t.gates[((s.next - 1) % math.max(gates, 1)) + 1]
				local dist = 0
				local body = if r.out then nil else carBody(r.player)
				if body and g then
					local pos = body.Position
					local lx, _, lz = TrackData.toLocal(t, true, pos.X, pos.Y, pos.Z)
					dist = math.sqrt((lx - g.x) ^ 2 + (lz - g.z) ^ 2)
				end
				local out = r.out and r.time == nil
				table.insert(runs, {
					time = r.time,
					-- walked off: behind everyone still in
					progress = if out then -1 else ServerRace.progress(r.laps, passed, gates, dist),
				})
			end
			local place = ServerRace.places(runs)
			for i, r in racers do
				r.place = place[i]
				if r.player.Parent then
					r.player:SetAttribute("RacePlace", r.place)
					r.player:SetAttribute("RaceCars", #racers)
				end
			end
		end
		for _, r in racers do
			if r.finishedNow then
				r.finishedNow = nil
				-- its place among the finishers (all faster ones are in already)
				local ahead = 1
				for _, o in racers do
					local ot, rt = o.time, r.time
					if o ~= r and ot and rt and ot < rt then
						ahead += 1
					end
				end
				if r.player.Parent then
					event:FireClient(r.player, "finished", ahead)
				end
			end
		end
		-- nobody left racing, or the race is done
		local anyIn = false
		for _, r in racers do
			anyIn = anyIn or (not r.out and r.time == nil)
		end
		local since = clock - goAt
		if (not anyIn and since > 0) or ServerRace.over(entries, since, firstAt) then
			local ranked = ServerRace.rank(entries)
			local paid, starred = payRace(ranked, racers, slot)
			local rows = {}
			for _, e in ranked do
				local coins = if e.uid then paid[e.uid] else nil
				local stars = if e.uid then starred[e.uid] else nil
				table.insert(rows, {
					name = e.name,
					time = e.time,
					laps = e.laps,
					coins = coins,
					stars = stars,
					car = carName(e.uid, "race"),
				})
			end
			event:FireAllClients("result", rows)
			break
		end
	end
	for _, r in racers do
		if r.player.Parent then
			r.player:SetAttribute("RacePlace", nil)
			r.player:SetAttribute("RaceCars", nil)
		end
	end
	task.wait(ServerRace.SHOW)
	for _, r in racers do
		if r.player.Parent and LobbyPlots.drivingOf(r.player) == slot then
			hooks.walk(r.player)
		end
	end
	phase = "wait"
	picked, where = nil, ""
	startAt = now() + ServerRace.BREAK
	sendState()
end

function ServerRaceRunner.start(hooks: Hooks)
	local signs = buildSign()
	startAt = now() + ServerRace.BREAK
	setBuild()

	Players.PlayerAdded:Connect(function(player: Player)
		sendState(player)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			-- Studio test: workspace:SetAttribute("ServerRaceSoon", true) = a race in 20 s
			if RunService:IsStudio() and workspace:GetAttribute("ServerRaceSoon") then
				workspace:SetAttribute("ServerRaceSoon", nil)
				if phase ~= "racing" then
					startAt = now() + 20
					phase = "wait"
					sendState()
				end
			end
			local left = startAt - now()
			for _, sign in signs do
				sign.Text = ServerRace.signText(left, phase == "racing", where)
			end
			if phase == "wait" and left <= ServerRace.CALL then
				phase = "call"
				picked = pickSlot()
				where = if picked then nameOf(picked) else ""
				sendState()
			elseif phase == "call" and left <= 0 then
				local slot = picked
				if slot == nil or #Players:GetPlayers() == 0 then
					-- no plot can hold it (or nobody here): next break
					phase, picked, where = "wait", nil, ""
					startAt = now() + ServerRace.BREAK
					sendState()
				else
					local ok, err = pcall(runRace, hooks, slot)
					if not ok then
						warn("server race: " .. tostring(err))
						phase, picked, where = "wait", nil, ""
						startAt = now() + ServerRace.BREAK
						sendState()
					end
				end
			end
		end
	end)
end

return ServerRaceRunner
