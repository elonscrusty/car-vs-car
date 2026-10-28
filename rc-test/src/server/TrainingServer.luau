--!strict
-- Car VS Car training on the server (carter 10-26, rc-game/cvc-plan.md; who builds what:
-- rc-game/cvc/SPLIT.md). Only runs with Features.CVC on and Features.SMASH off (the Smash game has
-- no training: this goes at its phase 3). Cars on your plot's stations train every second while
-- you're in the game (Training), and earn a few coins; COACH doubles it for 10 s once a minute.
-- The race runner calls TrainingServer.raceDone with each player's place.
-- The garage itself (the Garage remote, the starter, the car you race with, crates, the screens'
-- attributes) is GarageServer's; this adds the training asks to its remote: ("coach"),
-- ("station", i, uid | "") put a car on station i (or take it off), ("upgrade", i) a station,
-- ("level") the plot (one more station). Server -> client on the same remote: ("trained", uid,
-- car) every couple of seconds for cars that are training, ("race", place, coins, trophy, league).
-- Player attribute: CoachAt (os.time, 0 = never).
-- The owner's plot model gets (for the plot looks): Stations = "kind:level:carId;..." in
-- Training.stationsFor order (carId "" = empty pad; pad i of the plot = station i), PlotLevel,
-- GarageLevel, Trophies, NextOpen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CvcRules = require(ReplicatedStorage.Shared.CvcRules)
local Forever = require(ReplicatedStorage.Shared.Forever)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Training = require(ReplicatedStorage.Shared.Training)
local GarageServer = require(script.Parent.GarageServer)
local Jobs = require(script.Parent.Jobs)
local PlayerData = require(script.Parent.PlayerData)

local TrainingServer = {}

TrainingServer.SEND_EVERY = 2 -- seconds between ("trained", ...) updates

local remote = GarageServer.remote

local lastTouch: { [Player]: number } = {}
local coinBits: { [Player]: number } = {} -- coins earned but not yet whole
local trainSecs: { [Player]: number } = {} -- seconds with a car training, toward the next minute

-- (kept for the callers that still look here: the race runner, the daily gift)
TrainingServer.stats = GarageServer.stats
TrainingServer.refresh = GarageServer.refresh
TrainingServer.racer = GarageServer.racer

-- Can the owner pay for the next station? The plot shows that pad only then (game audit B10).
local function showNext(player: Player, data: Profile.Data)
	local m = GarageServer.plotModel(player)
	if m then
		local cost = Training.plotCost(data.plotLevel)
		m:SetAttribute("NextOpen", cost ~= nil and data.coins >= cost)
	end
end

local function showPlot(player: Player, data: Profile.Data, m: Instance)
	local pads = {}
	for _, st in data.stations do
		local car = st.uid ~= "" and Profile.findCar(data, st.uid)
		table.insert(pads, `{st.kind}:{st.level}:{if car then car.id else ""}`)
	end
	m:SetAttribute("Stations", table.concat(pads, ";"))
	m:SetAttribute("PlotLevel", data.plotLevel)
	m:SetAttribute("GarageLevel", data.garageLevel)
	m:SetAttribute("Trophies", data.trophies)
	showNext(player, data)
end

-- A race is over for this player: coins by league and place, a trophy for the top 3, a win's
-- boost, and the first race ever gives a crate. (Race plot calls this; place 0 = didn't finish.)
function TrainingServer.raceDone(player: Player, place: number, tried: boolean?)
	local data = PlayerData.get(player)
	if not (data and GarageServer.isReady(player)) then
		return
	end
	local got = CvcRules.raceDone(data, place, os.time(), tried)
	if got.firstCrate then
		PlayerData.raiseStage(player, Profile.STAGE.RACED)
	end
	GarageServer.changed(player, data)
	remote:FireClient(player, "race", place, got.coins, got.trophy, got.league)
end

-- One second of training for one player.
local function tick(player: Player, data: Profile.Data, dt: number, now: number, send: boolean)
	local at = player:GetAttribute("CoachAt")
	local coach = Training.coaching(if type(at) == "number" then at else 0, now)
	local bits, cars = CvcRules.tick(data, dt, coach, now, coinBits[player] or 0)
	coinBits[player] = bits
	local busy = false
	for _, st in data.stations do
		busy = busy or st.uid ~= ""
	end
	if busy then
		-- a daily job counts whole minutes with a car on a station
		local secs = (trainSecs[player] or 0) + dt
		if secs >= 60 then
			secs -= 60
			Jobs.fire(player, "train")
		end
		trainSecs[player] = secs
	end
	if send then
		for _, car in cars do
			remote:FireClient(player, "trained", car.uid, car)
		end
	end
	GarageServer.show(player, data)
end

-- (before GarageServer.start: Main starts this first, so the asks are there for the first player)
function TrainingServer.start()
	GarageServer.handle("coach", function(player)
		local tapped = CvcRules.coach(player:GetAttribute("CoachAt") or 0, os.time())
		if tapped then
			player:SetAttribute("CoachAt", tapped)
			Jobs.fire(player, "coach")
		end
		return false, nil
	end)
	GarageServer.handle("station", function(_, data, a, b)
		return CvcRules.station(data, a, b), nil
	end)
	GarageServer.handle("upgrade", function(player, data, a)
		local did = CvcRules.upgrade(data, a)
		if did then
			Jobs.fire(player, "upgrade")
		end
		return did, nil
	end)
	GarageServer.handle("level", function(player, data)
		local did = CvcRules.levelUp(data)
		if did then
			Jobs.fire(player, "upgrade")
		end
		return did, nil
	end)
	GarageServer.onReady(function(player)
		player:SetAttribute("CoachAt", 0)
	end)
	GarageServer.onShow(showNext)
	GarageServer.onPlot(showPlot)
	Players.PlayerRemoving:Connect(function(p: Player)
		lastTouch[p], coinBits[p], trainSecs[p] = nil, nil, nil
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
			local now = os.time()
			for _, p in Players:GetPlayers() do
				if not GarageServer.isReady(p) then
					continue
				end
				-- (one player per step: one odd save can't stop everyone else's training)
				Forever.step("Training", function()
					local data = PlayerData.get(p)
					if data then
						tick(p, data, dt, now, send)
						if clock - (lastTouch[p] or 0) >= 10 then
							lastTouch[p] = clock
							PlayerData.touch(p)
						end
					end
				end)
			end
		end
	end)
end

return TrainingServer
