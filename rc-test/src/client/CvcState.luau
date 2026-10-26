--!strict
-- Car VS Car on this screen (carter 10-26, rc-game/cvc-plan.md): what the server last said about
-- your cars, stations and crates (RemoteEvent Garage, TrainingServer), kept in one place for the
-- Car VS Car screens. Also each car's bars (Training + CarStats), so the screens and the server
-- show the same numbers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Training = require(Shared:WaitForChild("Training"))

export type Car = Training.Car
export type Station = { kind: string, level: number, uid: string }

local CvcState = {}

CvcState.garage = {} :: { Car }
CvcState.stations = {} :: { Station }
CvcState.racer = ""
CvcState.plotLevel = 0
CvcState.crates = 0
CvcState.loaded = false -- the first ("cars", ...) is in

local changedEvent = Instance.new("BindableEvent")
-- fires after any change (the whole list, or one car's training)
CvcState.changed = changedEvent.Event
local serverEvent = Instance.new("BindableEvent")
-- every other message from the server, as is: ("crate", id, rarity), ("race", place, coins, ...)
CvcState.event = serverEvent.Event

-- CarStats (the car names thread) once it lands; until then the server's guess by rarity
-- (TrainingServer.stats: the same numbers, so both sides agree)
local TIER_GUESS = {
	common = { 20, 60, 1 },
	rare = { 30, 75, 1.25 },
	epic = { 40, 90, 1.5 },
	legend = { 50, 100, 2 },
}
local carStats: any = nil
do
	local m = Shared:FindFirstChild("CarStats")
	if m and m:IsA("ModuleScript") then
		local ok, got = pcall(require, m)
		carStats = if ok then got else nil
	end
end

function CvcState.stats(id: string): Training.Stats
	if carStats then
		return { base = carStats.base(id), cap = carStats.cap(id), rate = carStats.rate(id) }
	end
	local g = TIER_GUESS[CarCatalog.rarity(id).id] or TIER_GUESS.common
	return { base = { speed = g[1], turn = g[1], boost = g[1] }, cap = g[2], rate = g[3] }
end

-- The 3 cars a new player picks from (the server checks the same list).
function CvcState.starters(): { string }
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

-- A car's name for the screens (CarStats' fun name once it's in).
function CvcState.name(id: string): string
	if carStats and carStats.name then
		local ok, n = pcall(carStats.name, id)
		if ok and type(n) == "string" then
			return string.upper(n)
		end
	end
	local c = CarCatalog.get(id)
	return string.upper(if c then c.name else id)
end

-- One bar now (base + trained, up to the car's top), and that top.
function CvcState.bar(car: Car, bar: string): (number, number)
	local stats = CvcState.stats(car.id)
	return Training.bar(car, bar, stats), math.min(stats.cap, Training.MAX_BAR)
end

-- A car at its starting bars (for the pick screen: nothing trained yet).
function CvcState.fresh(id: string): Car
	return { uid = "", id = id, speed = 0, turn = 0, boost = 0 }
end

function CvcState.find(uid: string): Car?
	for _, c in CvcState.garage do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- Which station this car is on (nil = none).
function CvcState.stationOf(uid: string): number?
	for i, st in CvcState.stations do
		if st.uid == uid and uid ~= "" then
			return i
		end
	end
	return nil
end

local remote: RemoteEvent? = nil
function CvcState.ask(...: any)
	if remote then
		remote:FireServer(...)
	end
end

local started = false
function CvcState.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local e = ReplicatedStorage:WaitForChild("Garage", 120)
		if not (e and e:IsA("RemoteEvent")) then
			return
		end
		remote = e
		e.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, ...: any)
			if kind == "cars" and type(a) == "table" then
				local t = a :: any
				CvcState.garage = if type(t.garage) == "table" then t.garage else {}
				CvcState.stations = if type(t.stations) == "table" then t.stations else {}
				CvcState.racer = if type(t.racer) == "string" then t.racer else ""
				CvcState.plotLevel = if type(t.plotLevel) == "number" then t.plotLevel else 0
				CvcState.crates = if type(t.crates) == "number" then t.crates else 0
				CvcState.loaded = true
				changedEvent:Fire()
			elseif kind == "trained" and type(a) == "string" and type(b) == "table" then
				for i, c in CvcState.garage do
					if c.uid == a then
						CvcState.garage[i] = b :: any
					end
				end
				changedEvent:Fire()
			else
				serverEvent:Fire(kind, a, b, ...)
			end
		end)
	end)
end

return CvcState
