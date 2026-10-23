--!strict
-- Carter's stars loop, phase 1: plot records, medals and stars.
-- The server watches every car on a lobby plot (RunCheck), so only real laps, climbs and slides
-- count. A run can set the plot's record (shown on a board over the plot's sign, saved in the
-- owner's save) and win bronze / silver / gold = 1 / 2 / 3 stars, but only on SOMEONE ELSE's plot,
-- once per medal per owner. Owners come from the lobby plots (attribute OwnerId on each
-- workspace.Plots model). In Studio an unowned plot counts as a test owner, so one person can
-- try the stars.
-- Server -> client (StarsEvent): ("stars", count, saving) and ("run", info). The client never sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Medals = require(ReplicatedStorage.Shared.Medals)
local Profile = require(ReplicatedStorage.Shared.Profile)
local RunCheck = require(ReplicatedStorage.Shared.RunCheck)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local PlayerData = require(script.Parent.PlayerData)
local PlotLooks = require(ReplicatedStorage.Shared.PlotLooks)
local PlotLooksBuilder = require(script.Parent.PlotLooksBuilder)

local LOOK = 0.1 -- seconds between looks at the cars
local TEST_OWNER = -1 -- Studio only: who owns an empty plot
local MEDAL_ICONS = { "🥉", "🥈", "🥇" }

local remote = Instance.new("RemoteEvent")
remote.Name = "StarsEvent"
remote.Parent = ReplicatedStorage

local slots = LobbyLayout.slots()
local studio = RunService:IsStudio()

-- records of plots nobody owns (not saved)
local looseRecords: { [number]: { [string]: Profile.Record } } = {}

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

-- The owner's user id, TEST_OWNER (Studio, nobody) or nil.
local function ownerId(slotIndex: number): number?
	local m = plotModel(slotIndex)
	local id = m and m:GetAttribute("OwnerId")
	if type(id) == "number" and id ~= 0 then
		return id
	end
	return if studio then TEST_OWNER else nil
end

local function ownerPlayer(slotIndex: number): Player?
	local id = ownerId(slotIndex)
	return if id and id > 0 then Players:GetPlayerByUserId(id) else nil
end

-- the slot this player owns (OwnerId on the plot models), or nil
local function ownedSlot(player: Player): number?
	for i in slots do
		local m = plotModel(i)
		if m and m:GetAttribute("OwnerId") == player.UserId then
			return i
		end
	end
	return nil
end

-- this plot's record list: the owner's save, or the loose list
local function recordsOf(slotIndex: number): ({ [string]: Profile.Record }?, Player?)
	local owner = ownerPlayer(slotIndex)
	if owner then
		local data = PlayerData.get(owner)
		return if data then data.plotRecords else nil, owner
	end
	looseRecords[slotIndex] = looseRecords[slotIndex] or {}
	return looseRecords[slotIndex], nil
end

local function trackOf(slotIndex: number): TrackData.Track
	local slot = slots[slotIndex]
	local t: any = TrackData.get(plotType(slotIndex))
	t.rcX, t.rcZ, t.rcAngle = slot.plotX, slot.plotZ, slot.angle
	return t
end

-- ===== record boards: a floating card over each plot's sign =====

local boardFolder = Instance.new("Folder")
boardFolder.Name = "StarBoards"
boardFolder.Parent = workspace

local boards: { [number]: TextLabel } = {}
for i, slot in slots do
	local anchor = Instance.new("Part")
	anchor.Name = "Board_" .. i
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(slot.signX, 9.5, slot.signZ)
	anchor.Parent = boardFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 5)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	text.BackgroundTransparency = 0.25
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.RichText = true
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = text
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = text
	boards[i] = text
end

local function showBoard(slotIndex: number)
	local mode = plotType(slotIndex)
	local t = Medals.target(mode)
	if not t then
		return
	end
	local owner = ownerPlayer(slotIndex)
	local title = if owner then string.upper(owner.DisplayName) .. "'S PLOT" else "OPEN PLOT"
	local records = recordsOf(slotIndex)
	local r = records and records[mode]
	local best = if r then `BEST {Medals.format(mode, r.value)}  {r.name}` else "BEST  none yet"
	local goals = `{MEDAL_ICONS[3]} {Medals.format(mode, t.gold)}   {MEDAL_ICONS[2]} {Medals.format(
		mode,
		t.silver
	)}   {MEDAL_ICONS[1]} {Medals.format(mode, t.bronze)}`
	boards[slotIndex].Text = `{title}\n<font color="#FFD54F">{best}</font>\n{goals}`
end

-- ===== plot looks: the owner's stars grow their plot (phase 2) =====

local function starsOf(slotIndex: number): number
	local m = plotModel(slotIndex)
	-- Studio only: TestStars on a plot model shows that look without playing for it
	local test = m and m:GetAttribute("TestStars")
	if studio and type(test) == "number" then
		return test
	end
	local owner = ownerPlayer(slotIndex)
	local data = owner and PlayerData.get(owner)
	return if data then data.stars else 0
end

local function showLooks(slotIndex: number)
	local m = plotModel(slotIndex)
	if not (m and m:IsA("Model")) then
		return
	end
	local stars = starsOf(slotIndex)
	m:SetAttribute("OwnerStars", stars)
	local slot = slots[slotIndex]
	local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
	PlotLooksBuilder.apply(m, pivot, PlotLooks.tier(stars))
end

local function showAll()
	for i in slots do
		showBoard(i)
		showLooks(i)
	end
end

-- ===== runs =====

local function onRun(player: Player, slotIndex: number, mode: string, value: number)
	if not Medals.valid(mode, value) then
		return
	end
	local records, owner = recordsOf(slotIndex)
	local record = false
	if records and Medals.better(mode, value, records[mode] and records[mode].value) then
		records[mode] = { value = value, name = player.DisplayName, userId = player.UserId }
		record = true
		if owner then
			PlayerData.touch(owner)
		end
		showBoard(slotIndex)
	end
	local medal = Medals.medal(mode, value)
	local oid = ownerId(slotIndex)
	local own = oid == player.UserId
	local gained = 0
	local data = PlayerData.get(player)
	if data and oid and not own then
		gained = Profile.award(data, player.UserId, oid, mode, medal)
		if gained > 0 then
			PlayerData.touch(player)
			-- their own plot may reach a new look
			local mine = ownedSlot(player)
			if mine then
				showLooks(mine)
			end
		end
	end
	print(
		`[Stars] {mode} {Medals.format(mode, value)} by {player.Name} on plot {slotIndex}`
			.. ` medal {medal} +{gained} stars{if record then " RECORD" else ""}`
	)
	-- small slides are not worth a pop
	if mode == "drift" and medal == 0 and not record then
		return
	end
	remote:FireClient(player, "run", {
		mode = mode,
		text = Medals.format(mode, value),
		medal = medal,
		gained = gained,
		stars = if data then data.stars else 0,
		record = record,
		own = own,
	})
end

type Watch = { car: Instance, slot: number, mode: string, run: RunCheck.State }
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

local function look(now: number)
	for i in slots do
		tracks[i] = trackOf(i)
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
		if not (w and w.car == car and w.slot == slotIndex and w.mode == t.id) then
			local cps: { RunCheck.Spot } = {}
			for _, cp in t.checkpoints or {} do
				table.insert(cps, localSpot(cp.spawn))
			end
			watching[player] = {
				car = car,
				slot = slotIndex,
				mode = t.id,
				run = RunCheck.new(t.gates, t.mode, t.id, localSpot(t.spawn), cps, now, lx, ly, lz),
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
			end
		end
	end
end

PlayerData.loaded:Connect(function(player: Player, data: Profile.Data, saving: boolean)
	remote:FireClient(player, "stars", data.stars, saving)
	showAll() -- their plot's board shows their saved record
end)

Players.PlayerRemoving:Connect(function(player)
	watching[player] = nil
	task.defer(showAll)
end)

PlayerData.start()

-- the lobby plots fill in their owners as people join: keep the boards in step
task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 30)
	if plots then
		for _, m in plots:GetChildren() do
			m:GetAttributeChangedSignal("OwnerId"):Connect(showAll)
			m:GetAttributeChangedSignal("PlotType"):Connect(showAll)
			m:GetAttributeChangedSignal("TestStars"):Connect(showAll)
		end
	end
	showAll()
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
