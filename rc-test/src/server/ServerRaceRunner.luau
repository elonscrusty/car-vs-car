--!strict
-- The server race (carter's loop): every 15 minutes, on the clock. A sign over the top of the
-- street counts down; for the last minute a JOIN button shows on every screen. At the start,
-- everyone who joined is put on the grid of one race plot and the start lights run (their
-- screens). The server counts each car's laps from where its car is (the same gates as the lap
-- timer): first to finish ServerRace.LAPS laps wins, and everyone sees who won. Then the racers
-- walk again. Driving is not touched: the cars are the players' own.
-- Plain maths (times, grid, order) is ServerRace's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local LobbyPlots = require(script.Parent.LobbyPlots)

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
}

local ServerRaceRunner = {}

-- Client -> server: ("join") / ("leave") while the join window is open.
-- Server -> client: ("state", phase, startAt, count, joined) with phase "wait" | "call" | "racing"
-- (startAt = workspace:GetServerTimeNow() time of the start), ("result", rows) when a race ends:
-- rows = { { name, time?, laps } } best first.
local event = Instance.new("RemoteEvent")
event.Name = "ServerRace"
event.Parent = ReplicatedStorage

local joined: { Player } = {}
local phase = "wait"
local startAt = 0
local lastAsk: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function sendState(to: Player?)
	local list = if to then { to } else Players:GetPlayers()
	for _, p in list do
		event:FireClient(p, "state", phase, startAt, #joined, table.find(joined, p) ~= nil)
	end
end

-- Join the race whose JOIN window is open now (QUICK RACE uses it too). False when no window
-- is open or the grid is full.
function ServerRaceRunner.joinOpen(player: Player): boolean
	if phase ~= "call" then
		return false
	end
	if table.find(joined, player) then
		return true
	end
	if #joined >= ServerRace.MAX then
		return false
	end
	table.insert(joined, player)
	sendState()
	return true
end

local function leave(player: Player)
	local i = table.find(joined, player)
	if i then
		table.remove(joined, i)
		sendState()
	end
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

-- The race plot the server race uses: the first race plot on the street.
local function raceSlot(): number?
	for _, s in LobbyLayout.slots() do
		if s.id == "race" then
			return s.index
		end
	end
	return nil
end

local function carBody(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local body = car and (car :: Model).PrimaryPart
	return body
end

local function runRace(hooks: Hooks, slot: number)
	local list = joined
	joined = {}
	phase = "racing"
	sendState()
	local t: TrackData.Track = LobbyLayout.track(slot)
	-- whoever is on that plot and didn't join gets off it first
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
			hooks.remote:FireClient(p, "drive", slot, k)
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
			})
		end
	end
	-- GO: when the lights on their screens go green (plus a little for the message to arrive)
	local goAt = os.clock() + ServerRace.GO_DELAY + 0.3
	local firstAt: number? = nil
	local gate1 = t.gates[1]
	while true do
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
						firstAt = firstAt or (clock - goAt)
					end
				end
			end
			if p.Parent then
				table.insert(entries, { name = r.name, laps = r.laps, time = r.time })
			end
		end
		-- nobody left racing, or the race is done
		local anyIn = false
		for _, r in racers do
			anyIn = anyIn or (not r.out and r.time == nil)
		end
		local since = clock - goAt
		if (not anyIn and since > 0) or ServerRace.over(entries, since, firstAt) then
			local rows = {}
			for _, e in ServerRace.rank(entries) do
				table.insert(rows, { name = e.name, time = e.time, laps = e.laps })
			end
			event:FireAllClients("result", rows)
			break
		end
	end
	task.wait(ServerRace.SHOW)
	for _, r in racers do
		if r.player.Parent and LobbyPlots.drivingOf(r.player) == slot then
			hooks.walk(r.player)
		end
	end
	phase = "wait"
	startAt = ServerRace.nextStart(now())
	sendState()
end

function ServerRaceRunner.start(hooks: Hooks)
	local signs = buildSign()
	startAt = ServerRace.nextStart(now())

	event.OnServerEvent:Connect(function(player: Player, kind: unknown)
		local t = os.clock()
		if t - (lastAsk[player] or 0) < 0.3 then
			return
		end
		lastAsk[player] = t
		if kind == "join" then
			ServerRaceRunner.joinOpen(player)
		elseif kind == "leave" then
			leave(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		sendState(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		leave(player)
		lastAsk[player] = nil
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
				end
			end
			local left = startAt - now()
			for _, s in signs do
				s.Text = ServerRace.signText(left, phase == "racing")
			end
			if phase == "wait" and left <= ServerRace.CALL then
				phase = "call"
				sendState()
			elseif phase == "call" and left <= 0 then
				local slot = raceSlot()
				if #joined == 0 or slot == nil then
					-- nobody joined: on to the next one
					joined = {}
					phase = "wait"
					startAt = ServerRace.nextStart(now())
					sendState()
				else
					local ok, err = pcall(runRace, hooks, slot)
					if not ok then
						warn("server race: " .. tostring(err))
						phase = "wait"
						startAt = ServerRace.nextStart(now())
						sendState()
					end
				end
			end
		end
	end)
end

return ServerRaceRunner
