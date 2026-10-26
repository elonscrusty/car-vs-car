--!strict
-- Car VS Car on the server (carter 10-26, rc-game/cvc-plan.md; who builds what:
-- rc-game/cvc/SPLIT.md). Only runs with Features.CVC on. Cars on your plot's stations train every
-- second while you're in the game (Training), and earn a few coins; COACH doubles it for 10 s once a
-- minute. The race runner calls TrainingServer.raceDone with each player's place.
-- RemoteEvent ReplicatedStorage.Garage, client -> server: ("pick", carId) the starter,
-- ("coach"), ("station", i, uid | "") put a car on station i (or take it off), ("racer", uid),
-- ("upgrade", i) a station, ("level") the plot (one more station), ("open") a free crate,
-- ("buy", crateKind) a crate from the crate shop for coins (Crates.SHOP).
-- Server -> client: ("cars", {garage, stations, racer, plotLevel, crates}), ("trained", uid, car)
-- every couple of seconds for cars that are training, ("crate", carId, rarity), ("race", place,
-- coins, trophy, league).
-- Player attributes: League (1..4), Trophies, RacerId, CoachAt (os.time, 0 = never), Coins,
-- BoostUntil, Picked.
-- The owner's plot model gets (for the plot looks): Stations = "kind:level:carId;..." in
-- Training.stationsFor order (carId "" = empty pad; pad i of the plot = station i), PlotLevel,
-- GarageLevel, Trophies, Garage = "carId,carId,..." (every car owned, for the car stands).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CvcRules = require(ReplicatedStorage.Shared.CvcRules)
local Forever = require(ReplicatedStorage.Shared.Forever)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Training = require(ReplicatedStorage.Shared.Training)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

local TrainingServer = {}

TrainingServer.SEND_EVERY = 2 -- seconds between ("trained", ...) updates

local remote = Instance.new("RemoteEvent")
remote.Name = "Garage"
remote.Parent = ReplicatedStorage

local ready: { [Player]: boolean } = {}
local lastAsk: { [Player]: number } = {}
local lastTouch: { [Player]: number } = {}
local coinBits: { [Player]: number } = {} -- coins earned but not yet whole

-- (the rules themselves live in CvcRules, so Lune can play them through)
TrainingServer.stats = CvcRules.stats

local function plotModel(player: Player): Instance?
	local slot = LobbyPlots.slotOf(player)
	local info = slot and LobbyLayout.slots()[slot]
	local plots = workspace:FindFirstChild("Plots")
	return if info and plots then plots:FindFirstChild(slot .. "_" .. info.id) else nil
end

local function showPlot(player: Player, data: Profile.Data)
	local m = plotModel(player)
	if not m then
		return
	end
	local pads = {}
	for _, st in data.stations do
		local car = st.uid ~= "" and Profile.findCar(data, st.uid)
		table.insert(pads, `{st.kind}:{st.level}:{if car then car.id else ""}`)
	end
	local ids = {}
	for _, c in data.garage do
		table.insert(ids, c.id)
	end
	m:SetAttribute("Stations", table.concat(pads, ";"))
	m:SetAttribute("PlotLevel", data.plotLevel)
	m:SetAttribute("GarageLevel", data.garageLevel)
	m:SetAttribute("Trophies", data.trophies)
	m:SetAttribute("Garage", table.concat(ids, ","))
end

local function show(player: Player, data: Profile.Data)
	local now = os.time()
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("League", data.league)
	player:SetAttribute("Trophies", data.trophies)
	player:SetAttribute("RacerId", if data.racer ~= "" then data.racer else nil)
	player:SetAttribute("BoostUntil", if data.boostUntil > now then data.boostUntil else 0)
	player:SetAttribute("Picked", data.picked)
end

local function sendAll(player: Player, data: Profile.Data)
	remote:FireClient(player, "cars", {
		garage = data.garage,
		stations = data.stations,
		racer = data.racer,
		plotLevel = data.plotLevel,
		crates = data.crates,
	})
end

local function setUp(player: Player, data: Profile.Data)
	ready[player] = true
	CvcRules.setUp(data)
	player:SetAttribute("Stage", data.stage) -- (an old save starts the new-player steps)
	player:SetAttribute("CoachAt", 0)
	show(player, data)
	showPlot(player, data)
	sendAll(player, data)
end

local function changed(player: Player, data: Profile.Data)
	PlayerData.touch(player)
	show(player, data)
	showPlot(player, data)
	sendAll(player, data)
end

-- A race is over for this player: coins by league and place, a trophy for the top 3, a win's
-- boost, and the first race ever gives a crate. (Race plot calls this; place 0 = didn't finish.)
function TrainingServer.raceDone(player: Player, place: number)
	local data = PlayerData.get(player)
	if not (data and ready[player]) then
		return
	end
	local got = CvcRules.raceDone(data, place, os.time())
	if got.firstCrate then
		PlayerData.raiseStage(player, Profile.STAGE.RACED)
	end
	changed(player, data)
	remote:FireClient(player, "race", place, got.coins, got.trophy, got.league)
end

-- Which car this player races with (nil = none yet).
function TrainingServer.racer(player: Player): (Profile.GarageCar?, Training.Stats?)
	local data = PlayerData.get(player)
	local car = data and Profile.findCar(data, data.racer)
	if not car then
		return nil, nil
	end
	return car, TrainingServer.stats(car.id)
end

local function onAsk(player: Player, kind: unknown, a: unknown, b: unknown)
	local data = PlayerData.get(player)
	if not (data and ready[player]) or type(kind) ~= "string" then
		return
	end
	local clock = os.clock()
	if clock - (lastAsk[player] or 0) < 0.2 then
		return
	end
	lastAsk[player] = clock
	local now = os.time()
	local did = false
	local gotCar: string? = nil
	if kind == "pick" then
		did = CvcRules.pick(data, a)
	elseif kind == "coach" then
		local at = player:GetAttribute("CoachAt")
		if Training.coachReady(if type(at) == "number" then at else 0, now) then
			player:SetAttribute("CoachAt", now)
		end
	elseif kind == "station" then
		did = CvcRules.station(data, a, b)
	elseif kind == "racer" then
		did = CvcRules.racer(data, a)
	elseif kind == "upgrade" then
		did = CvcRules.upgrade(data, a)
	elseif kind == "level" then
		did = CvcRules.levelUp(data)
	elseif kind == "open" then
		gotCar = CvcRules.open(data, Random.new())
	elseif kind == "buy" then
		gotCar = CvcRules.buy(data, a, Random.new())
	end
	if did or gotCar then
		-- the new lists first, so the crate screen already knows how many crates are left
		changed(player, data)
	end
	if gotCar then
		remote:FireClient(player, "crate", gotCar, CarCatalog.rarity(gotCar).id)
	end
end

-- One second of training for one player.
local function tick(player: Player, data: Profile.Data, dt: number, now: number, send: boolean)
	local at = player:GetAttribute("CoachAt")
	local coach = Training.coaching(if type(at) == "number" then at else 0, now)
	local bits, cars = CvcRules.tick(data, dt, coach, now, coinBits[player] or 0)
	coinBits[player] = bits
	if send then
		for _, car in cars do
			remote:FireClient(player, "trained", car.uid, car)
		end
	end
	show(player, data)
end

function TrainingServer.start()
	remote.OnServerEvent:Connect(onAsk)
	PlayerData.loaded:Connect(function(player: Player, data: any)
		setUp(player, data)
	end)
	PlayerData.synced:Connect(function(player: Player, data: any)
		if ready[player] then
			CvcRules.setUp(data) -- (a merged save is tidied the same way)
			show(player, data)
			showPlot(player, data)
			sendAll(player, data)
		end
	end)
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and not ready[p] then
			setUp(p, data)
		end
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		ready[p], lastAsk[p], lastTouch[p], coinBits[p] = nil, nil, nil, nil
	end)
	-- the plot changes hands on join: its looks follow the new owner
	LobbyPlots.changed:Connect(function(slot: number)
		local owner = LobbyPlots.ownerOf(slot)
		local data = owner and PlayerData.get(owner)
		if owner and data and ready[owner] then
			showPlot(owner, data)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		local sentAt = 0
		while true do
			task.wait(1)
			local clock = os.clock()
			local dt = math.min(clock - last, 5) -- (a long hitch doesn't count as training)
			last = clock
			local send = clock - sentAt >= TrainingServer.SEND_EVERY
			if send then
				sentAt = clock
			end
			Forever.step("Training", function()
				local now = os.time()
				for p in ready do
					local data = PlayerData.get(p)
					if data then
						tick(p, data, dt, now, send)
						if clock - (lastTouch[p] or 0) >= 10 then
							lastTouch[p] = clock
							PlayerData.touch(p)
						end
					end
				end
			end)
		end
	end)
end

return TrainingServer
