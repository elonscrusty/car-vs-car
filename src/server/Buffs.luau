--!strict
-- Temporary power-up effects on cars (shield, big hit, speed). Owned by the power-ups worker.
-- Other code only READS buffs through these functions, so it stays simple:
--   Autopilot multiplies max speed by speedMult; resolveHit multiplies damage by damageMult
--   (call it ONCE per hit: a big hit is used up by it) and passes incoming damage through absorb.
-- State lives here (weak table keyed by car), the rules are in PickupLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickupLogic = require(ReplicatedStorage.Shared.PickupLogic)
local PickupsConfig = require(ReplicatedStorage.Shared.PickupsConfig)
local CarBuilder = require(script.Parent.CarBuilder)

type Listener = (kind: string, seconds: number) -> () -- seconds 0 = the buff ended

local states: { [CarBuilder.Car]: PickupLogic.Buffs } = setmetatable({}, { __mode = "k" }) :: any
local listeners: { [CarBuilder.Car]: Listener } = setmetatable({}, { __mode = "k" }) :: any

local Buffs = {}

local function stateOf(car: CarBuilder.Car): PickupLogic.Buffs
	local s = states[car]
	if s == nil then
		s = PickupLogic.newBuffs()
		states[car] = s
	end
	return s
end

local function notify(car: CarBuilder.Car, kind: string, seconds: number)
	local l = listeners[car]
	if l then
		l(kind, seconds)
	end
end

function Buffs.speedMult(car: CarBuilder.Car): number
	local s = states[car]
	if s == nil then
		return 1
	end
	return PickupLogic.speedMult(s, PickupsConfig)
end

-- Multiplier on damage this car deals right now (big hit). Uses the big hit up.
function Buffs.damageMult(car: CarBuilder.Car): number
	local s = states[car]
	if s == nil or not s.bighit then
		return 1
	end
	local m = PickupLogic.takeDamageMult(s, PickupsConfig)
	notify(car, "bighit", 0)
	return m
end

-- Damage the car takes after its shield; may consume the shield.
function Buffs.absorb(car: CarBuilder.Car, damage: number): number
	local s = states[car]
	if s == nil or not s.shield then
		return damage
	end
	local out = PickupLogic.absorb(s, damage)
	if not s.shield then
		notify(car, "shield", 0)
	end
	return out
end

-- Called every Heartbeat with dt so timed buffs run out.
function Buffs.tick(car: CarBuilder.Car, dt: number)
	local s = states[car]
	if s == nil or next(s) == nil then
		return
	end
	local before: { string } = {}
	for kind in s do
		table.insert(before, kind)
	end
	PickupLogic.tick(s, dt)
	for _, kind in before do
		if not s[kind] then
			notify(car, kind, 0)
		end
	end
end

-- Gives the car a buff (refreshes it if it already has one of that kind).
function Buffs.apply(car: CarBuilder.Car, kind: string)
	local seconds = PickupLogic.apply(stateOf(car), kind, PickupsConfig)
	if seconds > 0 then
		notify(car, kind, seconds)
	end
end

-- Who to tell when a buff starts or ends (nil to stop).
function Buffs.setListener(car: CarBuilder.Car, listener: Listener?)
	listeners[car] = listener
end

-- Removes all buffs from a car (new match / car destroyed).
function Buffs.clear(car: CarBuilder.Car)
	states[car] = nil
end

return Buffs
