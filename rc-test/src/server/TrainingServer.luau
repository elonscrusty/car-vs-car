--!strict
-- Car VS Car on the server (carter 10-26, rc-game/cvc-plan.md; who builds what:
-- rc-game/cvc/SPLIT.md). Only runs with Features.CVC on. Cars on your plot's stations train every
-- second while you're in the game (Training), and earn a few coins; COACH doubles it for 10 s once a
-- minute. The race runner calls TrainingServer.raceDone with each player's place.
-- RemoteEvent ReplicatedStorage.Garage, client -> server: ("pick", carId) the starter,
-- ("coach"), ("station", i, uid | "") put a car on station i (or take it off), ("racer", uid),
-- ("upgrade", i) a station, ("level") the plot (one more station), ("open") a free crate.
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

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Forever = require(ReplicatedStorage.Shared.Forever)
local League = require(ReplicatedStorage.Shared.League)
local Profile = require(ReplicatedStorage.Shared.Profile)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Training = require(ReplicatedStorage.Shared.Training)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

local TrainingServer = {}

-- (stand-ins until Economy has them; Economy.luau takes these over)
TrainingServer.COINS_PER_MIN = 3 -- each training car, a win's boost doubles it
TrainingServer.WIN_BOOST_SECS = 600
TrainingServer.SEND_EVERY = 2 -- seconds between ("trained", ...) updates

local remote = Instance.new("RemoteEvent")
remote.Name = "Garage"
remote.Parent = ReplicatedStorage

local ready: { [Player]: boolean } = {}
local lastAsk: { [Player]: number } = {}
local lastTouch: { [Player]: number } = {}
local coinBits: { [Player]: number } = {} -- coins earned but not yet whole

-- CarStats (the car names thread) once it lands; until then a guess by rarity
local tierGuess = {
	common = { 20, 60, 1 },
	rare = { 30, 75, 1.25 },
	epic = { 40, 90, 1.5 },
	legend = { 50, 100, 2 },
}
local carStats: any = nil
do
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local m = shared and shared:FindFirstChild("CarStats")
	if m and m:IsA("ModuleScript") then
		local ok, got = pcall(require, m)
		carStats = if ok then got else nil
	end
end
function TrainingServer.stats(id: string): Training.Stats
	if carStats then
		return { base = carStats.base(id), cap = carStats.cap(id), rate = carStats.rate(id) }
	end
	local g = tierGuess[CarCatalog.rarity(id).id] or tierGuess.common
	return { base = { speed = g[1], turn = g[1], boost = g[1] }, cap = g[2], rate = g[3] }
end

local function starters(): { string }
	if carStats and carStats.STARTERS then
		return carStats.STARTERS
	end
	local out = {}
	for _, list in CarCatalog.SHOP do
		for _, c in list do
			if CarCatalog.rarity(c.id).id == "common" and #out < 3 then
				table.insert(out, c.id)
			end
		end
	end
	return out
end

-- the stations the plot level gives (new ones added empty; levels and cars kept)
local function fitStations(data: Profile.Data)
	local kinds = Training.stationsFor(data.plotLevel)
	for i, kind in kinds do
		if data.stations[i] == nil then
			data.stations[i] = { kind = kind, level = 1, uid = "" }
		end
	end
end

local function best(data: Profile.Data): number
	local top = 0
	for _, c in data.garage do
		top = math.max(top, Training.strength(c, TrainingServer.stats(c.id)))
	end
	return top
end

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
	fitStations(data)
	if data.racer == "" and data.garage[1] then
		data.racer = data.garage[1].uid
	end
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
	local coins = League.prize(data.league, place)
	data.coins = math.min(data.coins + coins, Profile.MAX_COINS)
	local trophy = League.trophy(place)
	if trophy then
		data.trophies += 1
	end
	if place == 1 then
		data.raceWins += 1
		data.boostUntil = os.time() + TrainingServer.WIN_BOOST_SECS
	end
	if data.stage < Profile.STAGE.RACED then
		data.crates += 1 -- the first race's crate
		PlayerData.raiseStage(player, Profile.STAGE.RACED)
	end
	data.league = League.next(best(data), data.raceWins, data.league)
	remote:FireClient(player, "race", place, coins, trophy, data.league)
	changed(player, data)
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
	if kind == "pick" then
		if data.picked or type(a) ~= "string" or not table.find(starters(), a) then
			return
		end
		local car = Profile.addCar(data, a)
		if car then
			data.picked = true
			data.racer = car.uid
			-- the free car trains at once
			fitStations(data)
			data.stations[1].uid = car.uid
			changed(player, data)
		end
	elseif kind == "coach" then
		local at = player:GetAttribute("CoachAt")
		if Training.coachReady(if type(at) == "number" then at else 0, now) then
			player:SetAttribute("CoachAt", now)
		end
	elseif kind == "station" then
		local st = type(a) == "number" and data.stations[a]
		if not st or type(b) ~= "string" then
			return
		end
		if b ~= "" then
			if not Profile.findCar(data, b) then
				return
			end
			-- one station per car: moving it takes it off the old one
			for _, other in data.stations do
				if other.uid == b then
					other.uid = ""
				end
			end
		end
		st.uid = b
		changed(player, data)
	elseif kind == "racer" then
		if type(a) == "string" and Profile.findCar(data, a) then
			data.racer = a
			changed(player, data)
		end
	elseif kind == "upgrade" then
		local st = type(a) == "number" and data.stations[a]
		local cost = st and Training.upgradeCost(st.level)
		if st and cost and st.level < Training.MAX_STATION_LEVEL and data.coins >= cost then
			data.coins -= cost
			st.level += 1
			changed(player, data)
		end
	elseif kind == "level" then
		local cost = Training.plotCost(data.plotLevel)
		if cost and data.plotLevel < Training.MAX_PLOT_LEVEL and data.coins >= cost then
			data.coins -= cost
			data.plotLevel += 1
			fitStations(data)
			changed(player, data)
		end
	elseif kind == "open" then
		-- Crates (the spawn lobby thread) rolls the car; until it lands, a free crate waits
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local m = shared and shared:FindFirstChild("Crates")
		if data.crates <= 0 or not (m and m:IsA("ModuleScript")) then
			return
		end
		local Crates: any = require(m) :: any
		local id = Crates.roll("free", Random.new())
		if type(id) == "string" and CarCatalog.get(id) then
			local car = Profile.addCar(data, id)
			if car then
				data.crates -= 1
				remote:FireClient(player, "crate", id, CarCatalog.rarity(id).id)
				changed(player, data)
			end
		end
	end
end

-- One second of training for one player.
local function tick(player: Player, data: Profile.Data, dt: number, now: number, send: boolean)
	local at = player:GetAttribute("CoachAt")
	local coach = Training.coaching(if type(at) == "number" then at else 0, now)
	local training = 0
	for _, st in data.stations do
		local car = st.uid ~= "" and Profile.findCar(data, st.uid)
		if car then
			local stats = TrainingServer.stats(car.id)
			if not Training.full(car, stats) then
				local after = Training.gain(car, st.kind, st.level, dt, coach, stats)
				car.speed, car.turn, car.boost = after.speed, after.turn, after.boost
				if send then
					remote:FireClient(player, "trained", car.uid, car)
				end
			end
			training += 1
		end
	end
	local boost = if data.boostUntil > now then 2 else 1
	local bits = (coinBits[player] or 0) + training * TrainingServer.COINS_PER_MIN * boost * dt / 60
	local whole = math.floor(bits)
	coinBits[player] = bits - whole
	if whole > 0 then
		data.coins = math.min(data.coins + whole, Profile.MAX_COINS)
	end
	data.league = League.next(best(data), data.raceWins, data.league)
	show(player, data)
end

function TrainingServer.start()
	remote.OnServerEvent:Connect(onAsk)
	PlayerData.loaded:Connect(function(player: Player, data: any)
		setUp(player, data)
	end)
	PlayerData.synced:Connect(function(player: Player, data: any)
		if ready[player] then
			show(player, data)
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
