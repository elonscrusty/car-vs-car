--!strict
-- Carter's stars loop, phase 1: plot records, medals and stars.
-- The server watches every car on a lobby plot (RunCheck), so only real laps, climbs and slides
-- count. A run can set the plot's record (shown on a board over the plot's sign, saved in the
-- owner's save) and win bronze / silver / gold = 1 / 2 / 3 stars, but only on SOMEONE ELSE's plot,
-- once per medal per owner. Owners come from the lobby plots (attribute OwnerId on each
-- workspace.Plots model). In Studio an unowned plot counts as a test owner, so one person can
-- try the stars.
-- Server -> client (StarsEvent): ("stars", count, saving), ("run", info), ("coins", count),
-- ("toast", text), ("bolts", found, total, onRock), ("bolt", id), ("boltsFound", ids) and
-- ("daily", coins, days in a row, boost). The client never sends. workspace "CoinBoost" = 2 on
-- weekends (every coin gift doubled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Medals = require(ReplicatedStorage.Shared.Medals)
local Profile = require(ReplicatedStorage.Shared.Profile)
local RunCheck = require(ReplicatedStorage.Shared.RunCheck)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local PlayerData = require(script.Parent.PlayerData)

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

-- ===== record boards: a small flat card just above each plot's sign, facing the road =====
-- Flat (SurfaceGui on an invisible part) and sized in studs, so it never grows to fill the
-- screen up close or covers the street view, and hidden past BOARD_SEE studs.

local BOARD_W, BOARD_H = 7, 2.6
local BOARD_Y = 7.4 -- just above the sign (its top is at about 5.5)
local BOARD_SEE = 60

local boardFolder = Instance.new("Folder")
boardFolder.Name = "StarBoards"
boardFolder.Parent = workspace

local boards: { [number]: TextLabel } = {}
local likePrompts: { [number]: ProximityPrompt } = {}
for i, slot in slots do
	local anchor = Instance.new("Part")
	anchor.Name = "Board_" .. i
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(BOARD_W, BOARD_H, 0.1)
	-- over the sign, its front facing the road (x = 0)
	local at = Vector3.new(slot.signX, BOARD_Y, slot.signZ)
	anchor.CFrame = CFrame.lookAt(at, Vector3.new(0, BOARD_Y, slot.signZ))
	anchor.Parent = boardFolder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = BOARD_SEE
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
	-- the like button: walk up to the board
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Like"
	prompt.ObjectText = "❤"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = anchor
	likePrompts[i] = prompt
end

local function showBoard(slotIndex: number)
	local mode = plotType(slotIndex)
	local t = Medals.target(mode)
	if not t then
		return
	end
	local owner = ownerPlayer(slotIndex)
	local title = if owner then string.upper(owner.DisplayName) .. "'S PLOT" else "OPEN PLOT"
	local ownerData = owner and PlayerData.get(owner)
	if ownerData then
		title ..= `  ❤ {ownerData.likes}`
	end
	local records = recordsOf(slotIndex)
	local r = records and records[mode]
	local best = if r then `BEST {Medals.format(mode, r.value)}  {r.name}` else "BEST  none yet"
	local goals = `{MEDAL_ICONS[3]} {Medals.format(mode, t.gold)}   {MEDAL_ICONS[2]} {Medals.format(
		mode,
		t.silver
	)}   {MEDAL_ICONS[1]} {Medals.format(mode, t.bronze)}`
	boards[slotIndex].Text = `{title}\n<font color="#FFD54F">{best}</font>\n{goals}`
end

-- ===== plot looks: the owner's stars grow their plot (PlotLooksBuilder reads OwnerStars) =====

local function showLooks(slotIndex: number)
	local m = plotModel(slotIndex)
	if not m then
		return
	end
	local owner = ownerPlayer(slotIndex)
	local data = owner and PlayerData.get(owner)
	local stars = if data then data.stars else 0
	if m:GetAttribute("OwnerStars") ~= stars then
		m:SetAttribute("OwnerStars", stars)
	end
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
			player:SetAttribute("Stars", data.stars) -- read by the car (smoke colours open with stars)
			-- their own plot may reach a new look
			local mine = ownedSlot(player)
			if mine then
				showLooks(mine)
			end
		end
	end
	-- the visit gift: driving someone else's plot pays you both, once per owner per day
	local boost = Profile.boost(os.time()) -- double coins on weekends
	if
		data
		and oid
		and not own
		and Profile.visit(data, player.UserId, oid, Profile.day(os.time()), boost)
	then
		PlayerData.touch(player)
		remote:FireClient(player, "coins", data.coins)
		remote:FireClient(player, "toast", `+{Profile.VISIT_COINS * boost} coins: visit gift`)
		local host = ownerPlayer(slotIndex)
		local hostData = host and PlayerData.get(host)
		if host and hostData then
			hostData.coins += Profile.HOST_COINS * boost
			PlayerData.touch(host)
			remote:FireClient(host, "coins", hostData.coins)
			remote:FireClient(
				host,
				"toast",
				`+{Profile.HOST_COINS * boost} coins: {player.DisplayName} visited your plot!`
			)
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

-- ===== gold bolts on the rock climb =====
-- The Rock plot puts them in: any BasePart under a plot with a number attribute BoltId (1..5).
-- Drive the car right up to one to pick it up; found ones stay found (saved) and are hidden on
-- the finder's screen.

local BOLT_REACH = 3.5 -- studs from the car's middle
local boltCache: { [number]: { { id: number, part: BasePart } } } = {}
local boltWatch: { [number]: boolean } = {}
local onRock: { [Player]: boolean } = {}

local function boltsOf(slotIndex: number): { { id: number, part: BasePart } }
	local cached = boltCache[slotIndex]
	if cached then
		return cached
	end
	local out = {}
	local m = plotModel(slotIndex)
	if m then
		for _, d in m:GetDescendants() do
			local id = d:GetAttribute("BoltId")
			if d:IsA("BasePart") and type(id) == "number" then
				table.insert(out, { id = id, part = d })
			end
		end
		-- the plot can change (bolts added later): look again then
		if not boltWatch[slotIndex] then
			boltWatch[slotIndex] = true
			m.DescendantAdded:Connect(function(d)
				if d:GetAttribute("BoltId") ~= nil then
					boltCache[slotIndex] = nil
				end
			end)
		end
	end
	boltCache[slotIndex] = out
	return out
end

local function sendBolts(player: Player, rock: boolean)
	local data = PlayerData.get(player)
	local found = if data then #Profile.boltList(data) else 0
	remote:FireClient(player, "bolts", found, Profile.BOLTS, rock)
end

local function setRock(player: Player, rock: boolean)
	if (onRock[player] or false) ~= rock then
		onRock[player] = rock
		sendBolts(player, rock)
	end
end

local function checkBolts(player: Player, slotIndex: number, pos: Vector3)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	for _, b in boltsOf(slotIndex) do
		if b.part.Parent and (b.part.Position - pos).Magnitude <= BOLT_REACH then
			if Profile.findBolt(data, b.id) then
				PlayerData.touch(player)
				local n = #Profile.boltList(data)
				remote:FireClient(player, "bolt", b.id)
				remote:FireClient(player, "toast", `gold bolt! {n}/{Profile.BOLTS}`)
				sendBolts(player, true)
				print(`[Stars] bolt {b.id} by {player.Name} ({n}/{Profile.BOLTS})`)
			end
		end
	end
end

local function look(now: number)
	for i in slots do
		tracks[i] = trackOf(i)
	end
	for _, player in Players:GetPlayers() do
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and (car :: Model).PrimaryPart
		if not (car and body) then
			watching[player] = nil
			setRock(player, false)
			continue
		end
		local cf = body.CFrame
		local slotIndex, lx, ly, lz = slotAt(cf.Position)
		local w = watching[player]
		if slotIndex == nil then
			watching[player] = nil
			setRock(player, false)
			continue
		end
		local t = tracks[slotIndex]
		setRock(player, t.id == "rock")
		if t.id == "rock" then
			checkBolts(player, slotIndex, cf.Position)
		end
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

-- ===== likes =====

local lastLike: { [Player]: number } = {}
for i, prompt in likePrompts do
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastLike[player] or 0) < 0.5 then
			return
		end
		lastLike[player] = now
		local owner = ownerPlayer(i)
		if owner == nil then
			remote:FireClient(player, "toast", "nobody owns this plot yet")
			return
		end
		if owner == player then
			remote:FireClient(player, "toast", "that's your plot!")
			return
		end
		local data, ownerData = PlayerData.get(player), PlayerData.get(owner)
		if not (data and ownerData) then
			return
		end
		if not Profile.like(data, player.UserId, owner.UserId) then
			remote:FireClient(player, "toast", "you liked this plot already ❤")
			return
		end
		ownerData.likes += 1
		PlayerData.touch(player)
		PlayerData.touch(owner)
		showBoard(i)
		remote:FireClient(player, "toast", `❤ you liked {owner.DisplayName}'s plot`)
		remote:FireClient(owner, "toast", `❤ {player.DisplayName} liked your plot!`)
	end)
end

-- ===== daily gift and weekend coins =====

-- The daily gift, the first time each day (on join, or at midnight UTC if they're still here).
-- The client shows the 7-day strip with ("daily", coins, days in a row, boost).
local function dailyGift(player: Player, data: Profile.Data)
	local now = os.time()
	local boost = Profile.boost(now)
	local coins, streak = Profile.daily(data, Profile.day(now), boost)
	if coins > 0 then
		PlayerData.touch(player)
		remote:FireClient(player, "coins", data.coins)
		remote:FireClient(player, "daily", coins, streak, boost)
		print(`[Stars] daily gift {player.Name} day {streak} +{coins} coins (x{boost})`)
	end
end

-- Double coins on weekends: the client's banner reads this.
task.spawn(function()
	while true do
		local now = os.time()
		workspace:SetAttribute("CoinBoost", Profile.boost(now))
		for _, p in Players:GetPlayers() do
			local data = PlayerData.get(p)
			if data and data.dailyDay ~= Profile.day(now) then
				dailyGift(p, data)
			end
		end
		task.wait(30)
	end
end)

PlayerData.loaded:Connect(function(player: Player, data: Profile.Data, saving: boolean)
	player:SetAttribute("Stars", data.stars) -- read by the car (smoke colours open with stars)
	remote:FireClient(player, "stars", data.stars, saving)
	remote:FireClient(player, "coins", data.coins)
	remote:FireClient(player, "boltsFound", Profile.boltList(data))
	showAll() -- their plot's board shows their saved record
	dailyGift(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	watching[player] = nil
	lastLike[player] = nil
	onRock[player] = nil
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
