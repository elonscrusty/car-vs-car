--!strict
-- Car VS Car: your cars on the server (RemoteEvent ReplicatedStorage.Garage). Only with
-- Features.CVC on (Smash plan, 10-28: training is gone, the plot is your garage): picking the
-- starter, the car you play with, crates, the player attributes the
-- screens read, the "cars" list each phone keeps (CvcState) and the owner's plot attribute
-- Garage (every car owned, for the garage stands).
-- Client -> server: ("pick", carId) the starter, ("racer", uid) the car you play with, ("open") a
-- free crate, ("buy", crateKind) a crate for coins (Crates.SHOP). Other asks are handed to
-- whoever said they take them (GarageServer.handle). Server -> client: ("cars", {garage, stations, racer, plotLevel, crates}),
-- ("crate", carId, rarity).
-- Player attributes: Coins, League, Trophies, RacerId, RacerCar, BoostUntil, Picked, Stage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local CarStats = require(ReplicatedStorage.Shared.CarStats)
local CvcRules = require(ReplicatedStorage.Shared.CvcRules)
local Features = require(ReplicatedStorage.Shared.Features)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Training = require(ReplicatedStorage.Shared.Training)
local Jobs = require(script.Parent.Jobs)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

local GarageServer = {}

-- An ask's answer: did it change the save, and the car a crate gave (nil = none).
export type Handler = (
	player: Player,
	data: Profile.Data,
	a: unknown,
	b: unknown
) -> (boolean, string?)

local remote = Instance.new("RemoteEvent")
remote.Name = "Garage"
remote.Parent = ReplicatedStorage
GarageServer.remote = remote

-- (the rules themselves live in CvcRules, so Lune can play them through)
GarageServer.stats = CvcRules.stats

local ready: { [Player]: boolean } = {}
local lastAsk: { [Player]: number } = {}
local handlers: { [string]: Handler } = {}
local onReady: { (Player, Profile.Data) -> () } = {}
local onShow: { (Player, Profile.Data) -> () } = {}
local onPlot: { (Player, Profile.Data, Instance) -> () } = {}

function GarageServer.isReady(player: Player): boolean
	return ready[player] == true
end

-- Someone else takes this ask (kind) from the remote. The rate limit and the save check are
-- done first; `fn` gets only a loaded player.
function GarageServer.handle(kind: string, fn: Handler)
	handlers[kind] = fn
end

-- Run `fn` when a player's save is set up / their attributes are shown / their plot is shown.
function GarageServer.onReady(fn: (Player, Profile.Data) -> ())
	table.insert(onReady, fn)
end
function GarageServer.onShow(fn: (Player, Profile.Data) -> ())
	table.insert(onShow, fn)
end
function GarageServer.onPlot(fn: (Player, Profile.Data, Instance) -> ())
	table.insert(onPlot, fn)
end

-- The player's plot model (workspace.Plots.<slot>_<id>), nil while they have none.
function GarageServer.plotModel(player: Player): Instance?
	local slot = LobbyPlots.slotOf(player)
	local info = slot and LobbyLayout.slots()[slot]
	local plots = workspace:FindFirstChild("Plots")
	return if slot and info and plots then plots:FindFirstChild(slot .. "_" .. info.id) else nil
end

local function showPlot(player: Player, data: Profile.Data)
	local m = GarageServer.plotModel(player)
	if not m then
		return
	end
	local ids = {}
	for _, c in data.garage do
		table.insert(ids, c.id)
	end
	m:SetAttribute("Garage", table.concat(ids, ","))
	-- which of them you play with (the garage's turntable)
	local racer = if data.racer ~= "" then Profile.findCar(data, data.racer) else nil
	m:SetAttribute("RacerCar", if racer then racer.id else nil)
	for _, fn in onPlot do
		fn(player, data, m)
	end
end

-- The player attributes the screens read (also every second while training runs).
function GarageServer.show(player: Player, data: Profile.Data)
	local now = os.time()
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("League", data.league)
	player:SetAttribute("Trophies", data.trophies)
	player:SetAttribute("RacerId", if data.racer ~= "" then data.racer else nil)
	-- which car that is (the race car is painted its colour: it was always the plain red); no racer
	-- yet = the free starter, so a new kid drives a toy car too
	local racer = if data.racer ~= "" then Profile.findCar(data, data.racer) else nil
	player:SetAttribute("RacerCar", if racer then racer.id else CarCatalog.starter("race").id)
	player:SetAttribute("BoostUntil", if data.boostUntil > now then data.boostUntil else 0)
	player:SetAttribute("Picked", data.picked)
	for _, fn in onShow do
		fn(player, data)
	end
end

local function sendAll(player: Player, data: Profile.Data)
	remote:FireClient(player, "cars", {
		garage = data.garage,
		-- (training's two, while the save still has them: CvcState reads them)
		stations = data.stations,
		plotLevel = data.plotLevel,
		racer = data.racer,
		crates = data.crates,
	})
end

local function setUp(player: Player, data: Profile.Data)
	ready[player] = true
	-- Smash: no starter pick screen, a new player owns the first starter from the first second
	-- (Lead 10-28: CUSTOMIZE said "No karts yet")
	if Features.SMASH and not data.picked and CvcRules.pick(data, CarStats.STARTERS[1]) then
		PlayerData.touch(player)
	end
	CvcRules.setUp(data)
	player:SetAttribute("Stage", data.stage) -- (an old save starts the new-player steps)
	for _, fn in onReady do
		fn(player, data)
	end
	GarageServer.show(player, data)
	showPlot(player, data)
	sendAll(player, data)
end

-- The save changed: mark it for saving and show it everywhere.
function GarageServer.changed(player: Player, data: Profile.Data)
	PlayerData.touch(player)
	GarageServer.show(player, data)
	showPlot(player, data)
	sendAll(player, data)
end

-- Send the lists again after a change made elsewhere (the daily gift's crate).
function GarageServer.refresh(player: Player)
	local data = PlayerData.get(player)
	if data and ready[player] then
		GarageServer.changed(player, data)
	end
end

-- Which car this player plays with (nil = none yet).
function GarageServer.racer(player: Player): (Profile.GarageCar?, Training.Stats?)
	local data = PlayerData.get(player)
	local car = data and Profile.findCar(data, data.racer)
	if not car then
		return nil, nil
	end
	return car, GarageServer.stats(car.id)
end

handlers.pick = function(_, data, a)
	return CvcRules.pick(data, a), nil
end
handlers.racer = function(_, data, a)
	return CvcRules.racer(data, a), nil
end
handlers.open = function(_, data)
	return false, CvcRules.open(data, Random.new())
end
handlers.buy = function(_, data, a)
	return false, CvcRules.buy(data, a, Random.new())
end

local function onAsk(player: Player, kind: unknown, a: unknown, b: unknown)
	local data = PlayerData.get(player)
	if not (data and ready[player]) or type(kind) ~= "string" then
		return
	end
	-- (an ask nobody takes doesn't use up the next one's turn)
	local fn = handlers[kind]
	if not fn then
		return
	end
	local clock = os.clock()
	if clock - (lastAsk[player] or 0) < 0.2 then
		return
	end
	lastAsk[player] = clock
	local did, gotCar = fn(player, data, a, b)
	if did or gotCar then
		-- the new lists first, so the crate screen already knows how many crates are left
		GarageServer.changed(player, data)
	end
	if gotCar then
		remote:FireClient(player, "crate", gotCar, CarCatalog.rarity(gotCar).id)
		Jobs.fire(player, "crate")
		-- the first crate opens the rest of the screen: daily gift, jobs (JoinStage "shopped")
		PlayerData.raiseStage(player, Profile.STAGE.SHOPPED)
	end
end

function GarageServer.start()
	remote.OnServerEvent:Connect(onAsk)
	PlayerData.loaded:Connect(function(player: Player, data: any)
		setUp(player, data)
	end)
	PlayerData.synced:Connect(function(player: Player, data: any)
		if ready[player] then
			CvcRules.setUp(data) -- (a merged save is tidied the same way)
			GarageServer.show(player, data)
			showPlot(player, data)
			sendAll(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		ready[p], lastAsk[p] = nil, nil
	end)
	-- the plot changes hands on join: its looks follow the new owner
	LobbyPlots.changed:Connect(function(slot: number)
		local owner = LobbyPlots.ownerOf(slot)
		local data = owner and PlayerData.get(owner)
		if owner and data and ready[owner] then
			showPlot(owner, data)
			return
		end
		-- not set up yet (or nobody): no one else's karts on it meanwhile
		local info = LobbyLayout.slots()[slot]
		local plots = workspace:FindFirstChild("Plots")
		local m = if info and plots then plots:FindFirstChild(slot .. "_" .. info.id) else nil
		if m then
			m:SetAttribute("Garage", nil)
			m:SetAttribute("RacerCar", nil)
		end
	end)
	-- (after the others have said what they take: Main starts them first)
	task.defer(function()
		for _, p in Players:GetPlayers() do
			local data = PlayerData.get(p)
			if data and not ready[p] then
				setUp(p, data)
			end
		end
	end)
end

return GarageServer
