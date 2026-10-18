--!strict
-- The SPECIAL button: fires the car's ability (Dash, Shield, Slam, Ram, Magnet, Jump).
-- Which ability and how strong comes from the car's stats (ability + rarity) through
-- shared/Abilities. Match calls `use` when a human presses SPECIAL (bots press it too).
-- Server decides everything. State is keyed by car (weak), so every new match starts fresh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local AbilitiesConfig = require(ReplicatedStorage.Shared.AbilitiesConfig)
local SpecialLogic = require(ReplicatedStorage.Shared.SpecialLogic)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)

type State = {
	readyAt: number, -- os.clock() time the ability is ready again
	bonusUntil: number, -- Ram: extra-damage window end
	bonusMult: number,
}

local Specials = {}

local states: { [CarBuilder.Car]: State } = setmetatable({}, { __mode = "k" }) :: any

local COLORS: { [string]: Color3 } = {
	dash = Color3.fromRGB(255, 255, 255),
	shield = Color3.fromRGB(70, 220, 110),
	slam = Color3.fromRGB(255, 170, 60),
	ram = Color3.fromRGB(235, 60, 60),
	magnet = Color3.fromRGB(170, 90, 255),
	jump = Color3.fromRGB(80, 200, 255),
}

local function stateOf(car: CarBuilder.Car): State
	local s = states[car]
	if s == nil then
		s = { readyAt = 0, bonusUntil = 0, bonusMult = 1 }
		states[car] = s
	end
	return s
end

-- A short ring flash at the car so people see something happened.
local function cue(car: CarBuilder.Car, color: Color3, reach: number)
	local p = Instance.new("Part")
	p.Name = "SpecialCue"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.4
	p.Size = Vector3.one * 4
	p.Position = car.body.Position
	p.Parent = car.model.Parent or workspace
	local grow = 4 + (math.max(reach, 3) * 2)
	game:GetService("TweenService")
		:Create(p, TweenInfo.new(0.35), { Size = Vector3.one * grow, Transparency = 1 })
		:Play()
	game:GetService("Debris"):AddItem(p, 0.5)
end

local function massScale(enemy: CarBuilder.Car): number
	return SpecialLogic.massScale(
		enemy.body.AssemblyMass,
		AbilitiesConfig.refMass,
		AbilitiesConfig.minMassScale,
		AbilitiesConfig.maxMassScale
	)
end

-- Gives the enemy a mass-aware shove along `dir` (flat), with optional lift.
local function shove(
	enemy: CarBuilder.Car,
	dir: Vector3,
	push: number,
	lift: number,
	amount: number
)
	local body = enemy.body
	local scale = massScale(enemy) * amount
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local unit = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	Impulse.linear(body, (unit * push + Vector3.yAxis * lift) * scale * body.AssemblyMass)
end

-- The ability this car has (rarity applied), or nil. For the HUD and tests.
function Specials.abilityOf(car: CarBuilder.Car): Abilities.Ability?
	return Abilities.forCar(car.stats)
end

-- Tries to fire `car`'s ability at `enemy`. `now` is os.clock(). Returns true if it fired
-- (so the caller can start the cooldown UI). Cooldown handling lives in here.
function Specials.use(car: CarBuilder.Car, enemy: CarBuilder.Car, now: number): boolean
	local ab = Abilities.forCar(car.stats)
	if ab == nil or car.dead then
		return false
	end
	local s = stateOf(car)
	if SpecialLogic.cooldownLeft(s.readyAt, now) > 0 then
		return false
	end
	s.readyAt = now + ab.cooldown

	local enemyAlive = not enemy.dead
	local offset = enemy.body.Position - car.body.Position
	local dist = offset.Magnitude
	local reach = 0

	if ab.kind == "dash" then
		Impulse.linear(
			car.body,
			car.body.CFrame.LookVector * ab.dashForward * car.body.AssemblyMass
		)
	elseif ab.kind == "shield" then
		Buffs.applyFor(car, "shield", ab.seconds)
	elseif ab.kind == "slam" then
		reach = ab.radius
		local f = SpecialLogic.falloff(dist, ab.radius)
		if enemyAlive and f > 0 then
			shove(enemy, offset, ab.push, ab.lift, f)
		end
	elseif ab.kind == "ram" then
		s.bonusUntil = now + ab.seconds
		s.bonusMult = ab.damageMult
	elseif ab.kind == "magnet" then
		reach = ab.radius
		local f = SpecialLogic.falloff(dist, ab.radius)
		if enemyAlive and f > 0 then
			shove(enemy, -offset, ab.push, 0, f)
		end
	else -- "jump"
		Impulse.linear(car.body, Vector3.yAxis * ab.jumpSpeed * car.body.AssemblyMass)
	end
	cue(car, COLORS[ab.kind] or Color3.new(1, 1, 1), reach)
	return true
end

-- Seconds until `car` can use its ability again (0 = ready). For the HUD.
function Specials.cooldownLeft(car: CarBuilder.Car, now: number): number
	local s = states[car]
	if s == nil then
		return 0
	end
	return SpecialLogic.cooldownLeft(s.readyAt, now)
end

-- Damage multiplier for hits dealt by `car` right now (Ram). Match multiplies by it.
function Specials.damageMult(car: CarBuilder.Car): number
	local s = states[car]
	if s == nil then
		return 1
	end
	return SpecialLogic.damageMult(s.bonusUntil, os.clock(), s.bonusMult)
end

-- Forgets cooldown and bonuses for `car` (a new match makes new cars, so this is optional).
function Specials.reset(car: CarBuilder.Car)
	states[car] = nil
end

return Specials
