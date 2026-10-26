--!strict
-- The tycoon on the server (carter 10-26, rc-game/tycoon/PLAN.md). Each player's parked cars make
-- coins every second into the pile in their plot; a tap collects it. A race win doubles the
-- income for a while (the race runner calls raceWon). The pile also fills while they're away, up
-- to the cap. The maths is Tycoon's; this keeps the save and the attributes in step.
-- Player attributes: PlotCoins (whole coins in the pile), Income (coins a minute, boost
-- included), BoostUntil (os.time, 0 = none), PlotLevel, Parked ("id,id,id"), Coins.
-- The owner's plot model gets Parked, PlotCoins and PlotLevel too (for the garage looks).
-- RemoteEvent ReplicatedStorage.Plot, client -> server: ("collect"), ("park", carId, on),
-- ("level"); server -> client: ("collected", n), ("boost", untilTime).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Forever = require(ReplicatedStorage.Shared.Forever)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Tycoon = require(ReplicatedStorage.Shared.Tycoon)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

local TycoonServer = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "Plot"
remote.Parent = ReplicatedStorage

local ready: { [Player]: boolean } = {} -- set up (offline coins counted, garage filled)
local lastAsk: { [Player]: number } = {}
local lastTouch: { [Player]: number } = {}

local function plotModel(player: Player): Instance?
	local slot = LobbyPlots.slotOf(player)
	local info = slot and LobbyLayout.slots()[slot]
	local plots = workspace:FindFirstChild("Plots")
	return if info and plots then plots:FindFirstChild(slot .. "_" .. info.id) else nil
end

-- The coin chip on screen is Stars' (StarsEvent "coins"); Coins is for the new screens.
local function showCoins(player: Player, coins: number)
	player:SetAttribute("Coins", coins)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "coins", coins)
	end
end

local function show(player: Player, data: any)
	local now = os.time()
	local income = Tycoon.income(data.parked, data.boostUntil, now)
	local parked = table.concat(data.parked, ",")
	local pile = math.floor(data.pile)
	player:SetAttribute("PlotCoins", pile)
	player:SetAttribute("Income", income)
	player:SetAttribute("BoostUntil", if data.boostUntil > now then data.boostUntil else 0)
	player:SetAttribute("PlotLevel", data.plotLevel)
	player:SetAttribute("Parked", parked)
	local m = plotModel(player)
	if m then
		m:SetAttribute("PlotCoins", pile)
		m:SetAttribute("PlotLevel", data.plotLevel)
		m:SetAttribute("Parked", parked)
	end
end

local function owns(data: any): (string) -> boolean
	return function(id: string): boolean
		return CarCatalog.owns(data, id)
	end
end

-- First time this session: the coins made while away, and a garage for a new player (their
-- free car parked, earning from the first second).
local function setUp(player: Player, data: any)
	local now = os.time()
	if #data.parked == 0 and data.lastSeen == 0 then
		data.parked = Tycoon.firstParked(data.plotLevel, owns(data))
	end
	if data.lastSeen > 0 then
		local away = now - data.lastSeen
		-- (no boost while away)
		data.pile = Tycoon.accrue(data.pile, Tycoon.income(data.parked, 0, 0), away)
	end
	data.lastSeen = now
	PlayerData.touch(player)
	ready[player] = true
	showCoins(player, data.coins)
	show(player, data)
end

-- A race win: double income for a while (a second win starts the time again).
function TycoonServer.raceWon(player: Player)
	local data = PlayerData.get(player) :: any
	if not data then
		return
	end
	data.boostUntil = os.time() + Tycoon.BOOST_SECS
	PlayerData.touch(player)
	show(player, data)
	remote:FireClient(player, "boost", data.boostUntil)
end

local function onAsk(player: Player, kind: unknown, id: unknown, on: unknown)
	local data = PlayerData.get(player) :: any
	if not (data and ready[player]) then
		return
	end
	local now = os.clock()
	if now - (lastAsk[player] or 0) < 0.25 then
		return
	end
	lastAsk[player] = now
	if kind == "collect" then
		local n = math.floor(data.pile)
		if n <= 0 then
			return
		end
		data.pile -= n
		data.coins += n
		PlayerData.touch(player)
		showCoins(player, data.coins)
		show(player, data)
		remote:FireClient(player, "collected", n)
	elseif kind == "park" and type(id) == "string" and type(on) == "boolean" then
		if Tycoon.park(data.parked, data.plotLevel, id, on, owns(data)) then
			PlayerData.touch(player)
			show(player, data)
		end
	elseif kind == "level" then
		local cost = Tycoon.levelCost(data.plotLevel)
		if cost and data.coins >= cost and data.plotLevel < Tycoon.MAX_LEVEL then
			data.coins -= cost
			data.plotLevel += 1
			PlayerData.touch(player)
			showCoins(player, data.coins)
			show(player, data)
		end
	end
end

function TycoonServer.start()
	remote.OnServerEvent:Connect(onAsk)
	PlayerData.loaded:Connect(function(player: Player, data: any)
		setUp(player, data)
	end)
	-- (anyone loaded before this ran)
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and not ready[p] then
			setUp(p, data)
		end
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		ready[p] = nil
		lastAsk[p] = nil
		lastTouch[p] = nil
	end)
	-- the plot changes hands on join: put the garage on the new owner's plot
	LobbyPlots.changed:Connect(function(slot: number)
		local owner = LobbyPlots.ownerOf(slot)
		local data = owner and PlayerData.get(owner)
		if owner and data and ready[owner] then
			show(owner, data)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local clock = os.clock()
			local dt = clock - last
			last = clock
			Forever.step("Tycoon", function()
				local now = os.time()
				for p, _ in ready do
					local data = PlayerData.get(p) :: any
					if data then
						data.pile = Tycoon.accrue(
							data.pile,
							Tycoon.income(data.parked, data.boostUntil, now),
							dt
						)
						data.lastSeen = now
						-- saved with the next autosave (once every 10 s is plenty)
						if clock - (lastTouch[p] or 0) >= 10 then
							lastTouch[p] = clock
							PlayerData.touch(p)
						end
						show(p, data)
					end
				end
			end)
		end
	end)
end

return TycoonServer
