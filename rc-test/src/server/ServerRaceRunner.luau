--!strict
-- The server race (carter's loop, rc-game/build-track/PLAN.md): a 5 minute break, then the
-- whole server races on one random player's plot. A sign over the top of the street and a chip
-- on every screen count the break down; 10 s before the start the plot is picked and named. At
-- the start everyone (up to ServerRace.MAX) is put on that plot's grid and the start lights run
-- (their screens). The server counts each car's laps from where its car is (the same gates as the lap
-- timer): first to finish the race's laps (ServerRace.lapsFor) wins, and everyone sees who won. Then the racers
-- walk again. Driving is not touched: the cars are the players' own.
-- Plain maths (times, grid, order) is ServerRace's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Features = require(ReplicatedStorage.Shared.Features)
local Forever = require(ReplicatedStorage.Shared.Forever)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local Leaderboards = require(script.Parent.Leaderboards)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Profile = require(ReplicatedStorage.Shared.Profile)
local RunCheck = require(ReplicatedStorage.Shared.RunCheck)
local Jobs = require(script.Parent.Jobs)
local RaceBots = require(ReplicatedStorage.Shared.RaceBots)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local RaceStats = require(ReplicatedStorage.Shared.RaceStats)
local League = require(ReplicatedStorage.Shared.League)
local RaceBotCars = require(script.Parent.RaceBotCars)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)
local FriendBonus = require(script.Parent.FriendBonus)

-- Grid spot k on this plot, plot-local: lined up behind its start line (the map's, else the street
-- race plot's), or the plot's own start spot when it has neither.
local function gridSpot(slot: number, t: TrackData.Track, k: number): ServerRace.Spawn
	local src = LobbyLayout.mapAt(slot)
	if src == nil and LobbyLayout.slots()[slot].id == "race" then
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
	leg: { x: number, z: number, t: number }?, -- where and when it crossed its last gate
	new: boolean?, -- never raced: an easy race's bots stay behind them (RaceBots.follow)
}

local ServerRaceRunner = {}

-- Server -> client: ("state", phase, startAt, count, kind, where) with phase "wait" | "call" |
-- "racing" (startAt = workspace:GetServerTimeNow() time of the start, count = unused now that
-- everyone races, kind = "race" | "drift" (the picked plot's), where = "KITCHEN" (the map) once
-- picked), ("result", rows) when a race ends: rows = { { name, time?, score?, laps, coins?,
-- stars?, bot? } } best first (what that racer was paid; score = a drift round's points). To one
-- racer: ("finished", place) when its car crosses the line for the last time, ("ends", endsAt)
-- when the winner is in (the others have until endsAt), or ("ends", endsAt, "drift") at the
-- start of a drift round (when it ends). Live places: the racer's attributes RacePlace /
-- RaceCars (nil = no race). Map races: ("vote", {mapIds}, endsAt) when the vote opens and
-- ("votes", {mapId = count}) on each vote; client -> server ("vote", mapId). RaceJoined (player
-- attribute) = on the list for the next map race (the JOIN NEXT RACE pad).
local event = Instance.new("RemoteEvent")
event.Name = "ServerRace"
event.Parent = ReplicatedStorage

local phase = "wait"
local startAt = 0
local picked: number? = nil -- the plot this round is on (from CALL seconds before the start)
local where = "" -- its name for the sign and the screens
local random = Random.new()
-- the bot cars of the race that is on (map races, RaceBotCars; Car VS Car: one fleet a league)
local fleets: { RaceBotCars.Fleet } = {}
local function clearFleets()
	for _, f in fleets do
		RaceBotCars.clear(f)
	end
	fleets = {}
end

-- Car VS Car: the leagues race at once on the same track, each in its own race. A league's cars
-- (players' and bots') are in collision group RaceGroup<n>, which doesn't touch the other leagues'
-- groups, and the model says RaceGroup = n so the screens hide the other leagues' cars.
local function groupName(gi: number): string
	return "RaceGroup" .. gi
end
local function setupGroups()
	for i = 1, ServerRace.GROUPS do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(groupName(i))
		end)
	end
	for i = 1, ServerRace.GROUPS do
		for j = i + 1, ServerRace.GROUPS do
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(groupName(i), groupName(j), false)
			end)
		end
	end
end
-- (gi nil = back to normal)
local function setCarGroup(model: Instance, gi: number?)
	local want = if gi then groupName(math.clamp(gi, 1, ServerRace.GROUPS)) else "Default"
	model:SetAttribute("RaceGroup", gi)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CollisionGroup ~= want then
			d.CollisionGroup = want
		end
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- carter's tycoon plan (rc-game/tycoon/PLAN.md, 10-26): races on the big maps (RaceMaps) instead
-- of on players' plots, as soon as a map exists. Who races: the
-- players who walked onto the JOIN NEXT RACE pad (join). Before the start everyone votes a map.
local function mapMode(): boolean
	return RaceMaps.live()
end

local function breakLen(): number
	return if mapMode() then ServerRace.MAP_BREAK else ServerRace.BREAK
end

-- Car VS Car: a race every 3 min, start to start (ServerRace.nextStart)
local lastStart = -math.huge
local mapRaces = 0 -- big races so far: the maps take turns
local function nextStart(): number
	if Features.CVC and mapMode() then
		return ServerRace.nextStart(lastStart, now())
	end
	return now() + breakLen()
end

local joined: { [Player]: boolean } = {}
local waiting: { [Player]: boolean } = {} -- walked onto the pad during a race: the next one
local votes: { [Player]: string } = {}
local voteOpen = false
local lastVote: { [Player]: number } = {}
local lastJoin: { [Player]: number } = {} -- (the CVC JOIN button: once in a while)

local function mapIds(): { string }
	local ids = {}
	for _, m in RaceMaps.list() do
		table.insert(ids, m.id)
	end
	return ids
end

-- after a race (or a skip): the pad has to be walked onto again for the next one
-- (and the ones who walked onto the pad while it ran are on the list for this next one)
local function clearJoined()
	for p in joined do
		if p.Parent then
			p:SetAttribute("RaceJoined", nil)
		end
	end
	joined = {}
	for p in waiting do
		if p.Parent then
			joined[p] = true
			p:SetAttribute("RaceJoined", true)
		end
	end
	waiting = {}
end

local function voteCounts(): { [string]: number }
	local count: { [string]: number } = {}
	for _, id in votes do
		count[id] = (count[id] or 0) + 1
	end
	return count
end

-- BuildOpen = true while the break is on (plots may be
-- edited), false from the moment the round's plot is picked until the race is over;
-- BuildEndsAt = os.time() when building closes.
local function setBuild()
	local open, ends = ServerRace.build(phase, startAt)
	workspace:SetAttribute("BuildOpen", open)
	workspace:SetAttribute("BuildEndsAt", ends)
end

local function sendState(to: Player?)
	if to == nil then
		setBuild()
	end
	workspace:SetAttribute("NextRaceAt", if phase == "racing" then nil else startAt) -- (the JOIN button's clock)
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

-- The JOIN NEXT RACE pad (map races): this player races in the next one. False when no map race
-- is on (the old plot race takes everyone) or one is already running.
function ServerRaceRunner.join(player: Player): boolean
	if not mapMode() then
		return false
	end
	if phase == "racing" then
		-- a race is on: they're first in for the next one
		if not joined[player] and not waiting[player] then
			waiting[player] = true
			player:SetAttribute("RaceJoined", true)
		end
		return true
	end
	if not joined[player] then
		joined[player] = true
		player:SetAttribute("RaceJoined", true)
	end
	-- Car VS Car: a new kid's first race starts soon after their tap (easy bots, then a crate)
	local data = PlayerData.get(player)
	if
		Features.CVC
		and (phase == "wait" or phase == "call") -- (in the last 10 s too)
		and data
		and data.stage < Profile.STAGE.RACED
		and startAt - now() > ServerRace.CVC_FIRST
	then
		startAt = now() + ServerRace.CVC_FIRST
		sendState()
	end
	return true
end

-- Can this plot hold the server race? A built track says so with TrackReady on its plot model
-- (a closed loop through the start); until a plot has that, the street's race
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
-- the race signs (built at start); the round clock writes them, and the race itself while it
-- runs (the clock waits for the race, so they sat on "RACE IN 0:00" the whole race)
local signs: { TextLabel } = {}
local function writeSigns(text: string)
	for _, sign in signs do
		sign.Text = text
	end
end

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
			-- a brand new owner (still on their first lap) isn't pulled off their own plot
			-- for the race unless nothing else can hold it
			local owner = LobbyPlots.ownerOf(s.index)
			local stage = owner and owner:GetAttribute("Stage")
			local settled = type(stage) == "number" and stage >= Profile.STAGE.LAPPED
			table.insert(if owner and settled then owned else spare, s.index)
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
	local tried: { [number]: boolean } = {}
	for _, r in racers do
		byId[r.player.UserId] = r.player
		-- (no try pay for JOIN-and-walk-off: drove over the line, still on the stand. Studio
		-- after-810: "past one gate" left a kid stuck on the first bend with 0 coins)
		tried[r.player.UserId] = not r.out and (r.laps > 0 or r.timer.next >= 2)
	end
	local paid: { [number]: number } = {}
	local starred: { [number]: number } = {}
	for place, e in ranked do
		local p = if e.uid then byId[e.uid] else nil
		if p and p.Parent and Features.CVC then
			-- Car VS Car: coins by league and place, a trophy for the top 3, a win's boost and the
			-- first race's crate all come from TrainingServer (place 0 = didn't finish). A new kid
			-- in a first race that ran out of time still won it: the bots wait for them.
			local done = ServerRace.finished(e) or (e.kid == true and tried[p.UserId] == true)
			local at = if done then place else 0
			local data = PlayerData.get(p)
			paid[p.UserId] = if data and (done or tried[p.UserId])
				then League.prize(data.league, at)
				else 0
			starred[p.UserId] = 0
			local mod = script.Parent:FindFirstChild("TrainingServer")
			if mod and mod:IsA("ModuleScript") then
				local ok, err = pcall(function()
					(require(mod) :: any).raceDone(p, at, done or tried[p.UserId])
				end)
				if not ok then
					warn("raceDone: " .. tostring(err))
				end
			end
			if done then
				Jobs.fire(p, "raceDone")
				if place <= 3 then
					Jobs.fire(p, "raceTop3")
				end
				if place == 1 then
					Jobs.fire(p, "raceWin")
				end
			end
		elseif p and p.Parent then
			local done = ServerRace.finished(e)
			local coins = ServerRace.payFor(place, done)
			paid[p.UserId] = coins * Profile.boost(os.time())
			PlayerData.raiseStage(p, Profile.STAGE.RACED) -- the shop opens up next
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
			if place == 1 and done then
				-- the tycoon: a win doubles the winner's plot income for a while
				local mod = script.Parent:FindFirstChild("TycoonServer")
				if mod and mod:IsA("ModuleScript") then
					local ok, err = pcall(function()
						(require(mod) :: any).raceWon(p)
					end)
					if not ok then
						warn("raceWon: " .. tostring(err))
					end
				end
			end
			-- (no stars in the tycoon plan: Features.STARS)
			local n = if Features.STARS then ServerRace.starsFor(place, done, #ranked) else 0
			starred[p.UserId] = n
			giveStars(p, n)
		end
	end
	local owner: Player? = nil -- (the tycoon plan has no player tracks to pick: no owner bonus)
	if owner and owner.Parent then
		pay(owner, ServerRace.PAY_OWNER, "your track was picked!")
		-- one number per row: the owner's row counts the bonus too
		if paid[owner.UserId] then
			paid[owner.UserId] += ServerRace.PAY_OWNER * Profile.boost(os.time())
		end
	end
	return paid, starred
end

-- Who races: everyone in the server (the first MAX) who has driven one lap. A brand new player
-- sits the race out until then (carter 10-25: one thing at a time when you join).
local function racersHere(): { Player }
	local list: { Player } = {}
	if mapMode() then
		-- a map race: the ones who walked onto the pad (a new player too: it's their first goal)
		-- (Car VS Car: up to MAX in each league's race)
		local most = if Features.CVC then ServerRace.MAX * ServerRace.GROUPS else ServerRace.MAX
		for _, p in Players:GetPlayers() do
			if joined[p] and #list < most then
				table.insert(list, p)
			end
		end
		return list
	end
	for _, p in Players:GetPlayers() do
		-- (tycoon plan: no plot to lap on first, so the race IS a new kid's first drive)
		if #list < ServerRace.MAX then
			table.insert(list, p)
		end
	end
	return list
end

-- Car VS Car: the racer's trained bars go on the player for their car's screen (RaceStats); off
-- (nil) = today's numbers. Set before "drive", so the car is right from the grid. `cap` = the
-- most strength the car races with (racing a friend's lower league: League.top).
local function setDrive(p: Player, on: boolean, cap: number?)
	local d: RaceStats.Drive? = nil
	if on and Features.CVC then
		local mod = script.Parent:FindFirstChild("TrainingServer")
		if mod and mod:IsA("ModuleScript") then
			local ok, car, stats = pcall(function()
				return (require(mod) :: any).racer(p)
			end)
			d = RaceStats.drive(if ok then car else nil, if ok then stats else nil, cap)
		end
	end
	p:SetAttribute("RaceTop", d and d.top)
	p:SetAttribute("RaceStart", d and d.start)
	p:SetAttribute("RaceTurn", d and d.turn)
	p:SetAttribute("RaceBoost", d and d.boostSecs)
end

local function runRace(hooks: Hooks, slot: number)
	clearFleets()
	local list = racersHere()
	phase = "racing"
	writeSigns(ServerRace.signText(0, true, where))
	workspace:SetAttribute("RaceSlot", slot)
	local t: TrackData.Track = LobbyLayout.track(slot)
	local mapsFolder = workspace:FindFirstChild("RaceMaps")
	local mapModel = if t.map and mapsFolder then mapsFolder:FindFirstChild(t.map) else nil
	if mapModel then
		mapModel:SetAttribute("Slot", slot) -- the start lamps' screens find them by it (StartLights)
	end
	sendState()
	-- whoever is on that plot and isn't racing gets off it first
	local other = LobbyPlots.driverOf(slot)
	if other and not table.find(list, other) then
		hooks.walk(other)
	end
	-- Car VS Car: each league on its own (ServerRace.groups); before, all in one race
	local leagues: { number } = {}
	-- (Car VS Car: a map race where nobody has raced yet is a first race: easy bots, fewer laps,
	-- and a new kid races alone with the bots, audit B1)
	local firstRace = Features.CVC and t.map ~= nil and t.id ~= "drift"
	local solo: { boolean } = {}
	for _, p in list do
		local lg = p:GetAttribute("League")
		table.insert(leagues, if Features.CVC and type(lg) == "number" then lg else 1)
		local stage = p:GetAttribute("Stage")
		table.insert(
			solo,
			firstRace and not (type(stage) == "number" and stage >= Profile.STAGE.RACED)
		)
	end
	-- friends always race together, in the lower league (audit C2)
	local friends: { { number } } = {}
	if Features.CVC then
		for i = 1, #list do
			for j = i + 1, #list do
				if FriendBonus.areFriends(list[i], list[j]) then
					table.insert(friends, { i, j })
				end
			end
		end
	end
	local groups: { { Racer } } = {}
	local groupEasy: { boolean } = {}
	local groupLaps: { number } = {}
	local groupLeague: { number } = {}
	for gi, idx in ServerRace.groups(leagues, ServerRace.MAX, solo, friends) do
		local racers: { Racer } = {}
		groups[gi] = racers
		-- (easy when anyone here hasn't raced yet: a new kid racing a friend still beats every bot)
		local easy = false
		local league = math.huge
		for _, i in idx do
			easy = easy or solo[i]
			league = math.min(league, leagues[i])
		end
		groupLeague[gi] = if league == math.huge then 1 else league
		-- (a stronger car here for a friend is held to this league's top; prizes stay its own)
		local cap = League.top(groupLeague[gi])
		groupEasy[gi] = easy
		groupLaps[gi] = ServerRace.lapsFor(easy)
		for k, i in idx do
			local p = list[i]
			if not p.Parent then
				continue
			end
			p:SetAttribute("RaceLaps", groupLaps[gi]) -- (the LAP 1/2 on their screen)
			-- (a first race: their put-back keeps AUTO GAS on)
			p:SetAttribute("EasyRace", if groupEasy[gi] then true else nil)
			if LobbyPlots.drivingOf(p) ~= nil then
				hooks.walk(p)
			end
			LobbyPlots.claim(p, slot)
			setDrive(p, true, if leagues[i] > groupLeague[gi] then cap else nil)
			p:SetAttribute("RaceGroup", if Features.CVC then gi else nil)
			p:SetAttribute("StandSpot", if Features.CVC then k else nil) -- (RaceStand: your spot)
			local body = carBody(p)
			if Features.CVC and body and body.Parent then
				setCarGroup(body.Parent, gi) -- (before the grid: each league's pole is the same spot)
			end
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
				new = solo[i],
			})
		end
	end
	-- GO: when the lights on their screens go green (plus a little for the message to arrive)
	local goAt = os.clock() + ServerRace.GO_DELAY + 0.3
	-- one league's race (all of them run at once, same GO)
	local function runGroup(gi: number, racers: { Racer })
		-- (the result card goes to this league's racers; one race = everyone, as before)
		local function sendResult(rows: { any })
			if not Features.CVC then
				event:FireAllClients("result", rows)
				return
			end
			for _, r in racers do
				if r.player.Parent then
					event:FireClient(r.player, "result", rows)
				end
			end
		end
		-- this league's cars: their own collision group (a few times a second: a car can respawn)
		local function tagCars()
			if not Features.CVC then
				return
			end
			for _, r in racers do
				local body = if r.out then nil else carBody(r.player)
				if body and body.Parent and body.CollisionGroup ~= groupName(gi) then
					setCarGroup(body.Parent, gi)
				end
			end
		end
		local firstAt: number? = nil
		local gate1 = t.gates[1]
		local gates = #t.gates
		local placesAt = 0
		local drift = t.id == "drift"
		-- a map race with fewer than 4 cars gets bots (the grid spots after the players')
		local bots: RaceBotCars.Fleet? = nil
		if not drift and t.map then
			-- (Car VS Car: bots as good as the race's league, easy ones when nobody here has raced
			-- yet; with friends from two leagues, the lower one)
			local league = groupLeague[gi]
			bots = RaceBotCars.spawn(
				t,
				#racers,
				mapModel,
				{ league = league, easy = groupEasy[gi], laps = groupLaps[gi] }
			)
			if bots then
				table.insert(fleets, bots)
				if Features.CVC then
					for n, car in bots.cars do
						car.model.Name = `Car_-{(gi - 1) * ServerRace.MAX + n}` -- (one name per bot)
						setCarGroup(car.model, gi)
					end
				end
			end
		end
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
						for _, e in
							RunCheck.step(run, clock, lx, ly, lz, bx - ax, bz - az, hit ~= nil)
						do
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
				sendResult(rows)
				break
			end
		end
		-- the first one is in: the others race the clock (their screens count it down, the winner's too)
		local afterWin = if Features.CVC and t.map
			then ServerRace.MAP_AFTER_WIN
			else ServerRace.AFTER_WIN
		local function startCountdown(took: number)
			if firstAt ~= nil then
				return
			end
			firstAt = took
			local limit = if t.map then ServerRace.MAP_TIME_LIMIT else ServerRace.TIME_LIMIT
			local endsAt = now() + math.min(afterWin, limit - took)
			for _, o in racers do
				if o.player.Parent then
					event:FireClient(o.player, "ends", endsAt)
				end
			end
		end
		local lead: number? = nil -- the leading player's progress, for the bots' catch-up
		local kidLead: number? = nil -- how far round the furthest new kid is, for easy bots
		-- (a new kid who sits still after GO doesn't hold the bots: Studio after-810 waited 2:47)
		local kidFrom: { [Racer]: number } = {}
		local kidMoved = false
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
						-- (a new kid's first race never has a jump start: the clock is theirs)
						if
							ServerRace.overLine(gate1, lx, ly, lz)
							and not (groupEasy[gi] and r.new)
						then
							r.jumped, r.waitLeave = true, true
						end
					elseif not r.started then
						r.started = true
						r.leg = { x = lx, z = lz, t = clock }
						if not r.jumped then
							LapTimer.go(r.timer, goAt)
						end
					elseif r.waitLeave then
						r.waitLeave = onLine
						r.leg = { x = lx, z = lz, t = clock }
					else
						local ev = LapTimer.update(r.timer, clock, lx, ly, lz)
						local leg = r.leg
						if ev and leg then
							if not RunCheck.legOk(leg.x, leg.z, leg.t, lx, lz, clock) then
								-- faster than any car drives (speed hack, teleport): out
								warn(`server race: {p.Name} moved too fast between gates, out`)
								r.out = true
								ev = nil
							end
							r.leg = { x = lx, z = lz, t = clock }
						end
						if ev == "lap" then
							r.laps += 1
							if r.timer.last then
								Leaderboards.lap(p, t.map, r.timer.last) -- fastest-lap boards (server clock)
							end
							if r.laps >= groupLaps[gi] then
								r.time = clock - goAt
								startCountdown(clock - goAt)
								r.finishedNow = true
							end
						end
					end
				end
				if p.Parent then
					table.insert(entries, {
						name = r.name,
						uid = p.UserId,
						laps = r.laps,
						time = r.time,
						-- (only one who drove over the line: an idle kid isn't put 1st with a
						-- trophy and then paid nothing, Studio after-810)
						kid = if groupEasy[gi]
								and r.new
								and (r.laps > 0 or r.timer.next >= 2)
							then true
							else nil,
					})
				end
			end
			if bots then
				local held = kidMoved or clock - goAt < ServerRace.IDLE_KID
				RaceBotCars.step(bots, clock, goAt, lead, if held then kidLead else nil)
				for _, car in bots.cars do
					local b = car.bot
					table.insert(
						entries,
						{ name = b.name, laps = RaceBots.laps(bots.route, b), time = b.time }
					)
					if b.time then
						startCountdown(b.time)
					end
				end
			end
			-- live places, a few times a second (finishers by time, then how far round)
			if clock >= placesAt then
				placesAt = clock + 0.25
				tagCars()
				local runs: { ServerRace.Run } = {}
				kidLead = nil
				for _, r in racers do
					local s = r.timer
					local passed = if s.running then s.next - 1 else 0
					local g = t.gates[((s.next - 1) % math.max(gates, 1)) + 1]
					local dist = 0
					local lx: number?, lz: number? = nil, nil
					local body = if r.out then nil else carBody(r.player)
					if body and g then
						local pos = body.Position
						local x, _, z = TrackData.toLocal(t, true, pos.X, pos.Y, pos.Z)
						lx, lz = x, z
						dist = math.sqrt((x - g.x) ^ 2 + (z - g.z) ^ 2)
					end
					local out = r.out and r.time == nil
					local progress = if out
						then -1
						else ServerRace.progress(r.laps, passed, gates, dist)
					table.insert(runs, {
						time = r.time,
						-- walked off: behind everyone still in
						progress = progress,
					})
					if not out and (lead == nil or progress > lead) then
						lead = progress
					end
					if not out and r.new and bots then
						-- (how far along the road: the easy bots stay behind the furthest new kid)
						local at = if lx and lz
							then RaceBots.roadAt(bots.route, progress, lx, lz)
							else RaceBots.distOf(bots.route, progress)
						if kidLead == nil or at > kidLead then
							kidLead = at
						end
						kidFrom[r] = kidFrom[r] or at
						kidMoved = kidMoved or at - kidFrom[r] > ServerRace.IDLE_MOVE
					end
				end
				local cars = #racers
				if bots then
					for _, car in bots.cars do
						table.insert(runs, {
							time = car.bot.time,
							progress = RaceBots.progress(bots.route, car.bot),
						})
						cars += 1
					end
				end
				local place = ServerRace.places(runs)
				for i, r in racers do
					r.place = place[i]
					if r.player.Parent then
						r.player:SetAttribute("RacePlace", r.place)
						r.player:SetAttribute("RaceCars", cars)
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
			-- (a first race is over the moment its new kids are in: they won, the bots waited for
			-- them; carter's phone run drove on 20 s after FINISH! with nothing to tap)
			local kidsIn, kidsLeft = false, false
			for _, r in racers do
				anyIn = anyIn or (not r.out and r.time == nil)
				if r.new and not r.out then
					kidsIn = true
					kidsLeft = kidsLeft or r.time == nil
				end
			end
			local since = clock - goAt
			local limit = if t.map then ServerRace.MAP_TIME_LIMIT else nil
			if
				(not anyIn and since > 0)
				or (groupEasy[gi] and kidsIn and not kidsLeft and since > 0)
				or ServerRace.over(entries, since, firstAt, limit, afterWin)
			then
				-- (a first race on the time limit: the new kid who drove is in, at the end's time,
				-- so the podium, the card and the pay all say they won; the bots waited for them)
				for _, e in entries do
					if e.kid and e.time == nil then
						e.time = since
					end
				end
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
						bot = e.uid == nil or nil, -- a race bot (RaceBotCars): no prize
						uid = e.uid, -- (RaceWin: whose avatar gets the trophy)
					})
				end
				sendResult(rows)
				break
			end
		end
	end
	local running = 0
	for gi, racers in groups do
		if #racers > 0 then
			running += 1
			task.spawn(function()
				local ok, err = pcall(runGroup, gi, racers)
				if not ok then
					warn("server race (league race " .. gi .. "): " .. tostring(err))
				end
				running -= 1
			end)
		end
	end
	while running > 0 do
		RunService.Heartbeat:Wait()
	end
	writeSigns("RACE OVER!")
	-- Car VS Car: the next start is fixed now and told to every screen (the result card's NEXT RACE
	-- IN reads it; it used to guess its own and ran ~15 s long)
	local nextAt = ServerRace.nextAfterRace(lastStart, now())
	if Features.CVC and mapMode() then
		-- a new kid who tapped JOIN while this race ran gets their first race soon after the
		-- walk back, not a whole 3 min later (Studio polish 3: they waited 1 to 2 min)
		for p in waiting do
			local data = PlayerData.get(p)
			if p.Parent and data and data.stage < Profile.STAGE.RACED then
				nextAt = math.min(nextAt, now() + ServerRace.SHOW + ServerRace.CVC_FIRST)
				break
			end
		end
		event:FireAllClients("next", nextAt)
	end
	local racers: { Racer } = {}
	for _, g in groups do
		for _, r in g do
			table.insert(racers, r)
		end
	end
	for _, r in racers do
		if r.player.Parent then
			r.player:SetAttribute("RacePlace", nil)
			r.player:SetAttribute("RaceCars", nil)
			r.player:SetAttribute("RaceGroup", nil)
			r.player:SetAttribute("EasyRace", nil)
			r.player:SetAttribute("StandSpot", nil)
			setDrive(r.player, false)
			local body = carBody(r.player)
			if body and body.Parent and body.Parent:GetAttribute("RaceGroup") ~= nil then
				setCarGroup(body.Parent, nil)
			end
		end
	end
	task.wait(ServerRace.SHOW)
	clearFleets()
	for _, r in racers do
		if r.player.Parent and LobbyPlots.drivingOf(r.player) == slot then
			hooks.walk(r.player)
		end
	end
	phase = "wait"
	picked, where = nil, ""
	clearJoined()
	workspace:SetAttribute("RaceSlot", 0)
	startAt = if Features.CVC and mapMode() then nextAt else nextStart()
	sendState()
end

-- A race that threw part-way: nobody stays pinned on the stand. Same clean-up as a race's end.
local function rescue(hooks: Hooks, slot: number)
	for _, p in Players:GetPlayers() do
		if
			p:GetAttribute("RaceGroup") ~= nil
			or p:GetAttribute("StandSpot") ~= nil
			or LobbyPlots.drivingOf(p) == slot
		then
			pcall(function()
				p:SetAttribute("RacePlace", nil)
				p:SetAttribute("RaceCars", nil)
				p:SetAttribute("RaceGroup", nil)
				p:SetAttribute("EasyRace", nil)
				p:SetAttribute("StandSpot", nil)
				setDrive(p, false)
				local body = carBody(p)
				if body and body.Parent then
					setCarGroup(body.Parent, nil)
				end
				if LobbyPlots.drivingOf(p) == slot then
					hooks.walk(p)
				end
			end)
		end
	end
end

function ServerRaceRunner.start(hooks: Hooks)
	signs = buildSign()
	if Features.CVC then
		setupGroups()
	end
	startAt = nextStart()
	setBuild()

	Players.PlayerAdded:Connect(function(player: Player)
		sendState(player)
		if voteOpen then
			event:FireClient(player, "vote", mapIds(), startAt - ServerRace.CALL)
			event:FireClient(player, "votes", voteCounts())
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		joined[player], votes[player], lastVote[player], lastJoin[player] = nil, nil, nil, nil
		waiting[player] = nil
	end)
	-- the map vote: ("vote", mapId) from a screen, at most twice a second; everyone sees the count
	-- (a vote also joins the next race)
	event.OnServerEvent:Connect(function(player: Player, kind: unknown, id: unknown)
		-- Car VS Car's big JOIN button (UI): the same as the JOIN pad
		if kind == "join" and Features.CVC then
			local t = os.clock()
			if t - (lastJoin[player] or 0) >= 0.5 then
				lastJoin[player] = t
				ServerRaceRunner.join(player)
			end
			return
		end
		if kind ~= "vote" or type(id) ~= "string" or not voteOpen then
			return
		end
		local t = os.clock()
		if t - (lastVote[player] or 0) < 0.5 or not table.find(mapIds(), id) then
			return
		end
		lastVote[player] = t
		votes[player] = id
		-- a new kid taps a map to say "I want to race": the vote puts them in it too
		ServerRaceRunner.join(player)
		event:FireAllClients("votes", voteCounts())
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			Forever.step("ServerRace", function()
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
				writeSigns(ServerRace.signText(left, phase == "racing", where))
				-- a map race: the vote opens VOTE seconds before the map is picked
				if
					mapMode()
					and not Features.CVC
					and phase == "wait"
					and not voteOpen
					and left <= ServerRace.CALL + ServerRace.VOTE
				then
					voteOpen, votes = true, {}
					event:FireAllClients("vote", mapIds(), startAt - ServerRace.CALL)
				end
				local todo = ServerRace.step(phase, left, picked, #racersHere())
				if todo == "pick" then
					phase = "call"
					if mapMode() then
						voteOpen = false
						local values = {}
						for p, id in votes do
							if p.Parent then
								values[p] = id
							end
						end
						local id = if Features.CVC
							then ServerRace.mapTurn(mapIds(), mapRaces + 1)
							else ServerRace.tally(values, mapIds(), random:NextNumber())
						picked, where = nil, ""
						for k, m in RaceMaps.list() do
							if m.id == id then
								picked, where = LobbyLayout.mapIndex(k), m.label
							end
						end
					else
						picked = pickSlot()
						where = if picked then nameOf(picked) else ""
					end
					sendState()
				elseif todo == "skip" or todo == "race" then
					local slot = picked
					if todo == "skip" or slot == nil then
						-- no plot can hold it (or nobody here): next break
						phase, picked, where = "wait", nil, ""
						clearJoined()
						startAt = nextStart()
						sendState()
					else
						lastStart = startAt
						if mapMode() then
							mapRaces += 1
						end
						local ok, err = pcall(runRace, hooks, slot)
						if not ok then
							warn("server race: " .. tostring(err))
							rescue(hooks, slot)
							clearFleets()
							workspace:SetAttribute("RaceSlot", 0)
							phase, picked, where = "wait", nil, ""
							startAt = nextStart()
							sendState()
						end
					end
				end
			end)
		end
	end)
end

return ServerRaceRunner
