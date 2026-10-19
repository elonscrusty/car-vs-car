--!strict
-- The SPECIAL button: fires the car's ability (Dash, Shield, Slam, Ram, Magnet, Jump).
-- Which ability and how strong comes from the car's stats (ability + rarity) through
-- shared/Abilities. Match calls `use` when a human presses SPECIAL (bots press it too).
-- Server decides everything. State is keyed by car (weak), so every new match starts fresh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local AbilitiesConfig = require(ReplicatedStorage.Shared.AbilitiesConfig)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
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

-- The mode GroupMatch tagged the arena with (attribute `GameMode` on the Arena folder/model:
-- "soccer", "tag", "race"), found by walking up from the car. Returns the mode and the instance
-- that carries it. nil = attribute missing = old behaviour.
local function modeOf(car: CarBuilder.Car): (string?, Instance?)
	local inst: Instance? = car.model
	while inst do
		local m = inst:GetAttribute("GameMode")
		if type(m) == "string" and m ~= "" then
			return m, inst
		end
		inst = inst.Parent
	end
	return nil, nil
end

-- The soccer ball inside the arena that carries the GameMode attribute (or nil).
local function findBall(container: Instance): BasePart?
	local b = container:FindFirstChild("Ball", true)
	if b and b:IsA("BasePart") and not b.Anchored then
		return b
	end
	return nil
end

-- Soccer: Slam shoves the ball, Magnet pulls it (same reach and falloff as for cars).
local function moveBall(
	car: CarBuilder.Car,
	ab: Abilities.Ability,
	how: string,
	container: Instance
)
	local ball = findBall(container)
	if ball == nil then
		return
	end
	local offset = ball.Position - car.body.Position
	local f = SpecialLogic.falloff(offset.Magnitude, ab.radius)
	if f <= 0 then
		return
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local unit = if flat.Magnitude > 0.01 then flat.Unit else car.body.CFrame.LookVector
	local dir = if how == "pull" then -unit else unit
	local lift = if how == "push" then ab.lift else 0
	Impulse.linear(ball, (dir * ab.push + Vector3.yAxis * lift) * f * ball.AssemblyMass)
end

-- Tag: until this server time the car cannot be tagged (set by Shield). Read it with
-- Specials.tagImmune(car) from the tag rules. Also an attribute: `TagImmuneUntil`.
function Specials.tagImmune(car: CarBuilder.Car): boolean
	local untilT = car.model:GetAttribute("TagImmuneUntil")
	return type(untilT) == "number" and workspace:GetServerTimeNow() < untilT
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
	-- cooldown picture for the UI (server time, same clock on every client)
	car.model:SetAttribute("AbilityCooldown", ab.cooldown)
	car.model:SetAttribute("AbilityReadyAt", workspace:GetServerTimeNow() + ab.cooldown)
	local mode, modeRoot = modeOf(car)
	local use = Abilities.modeUse(ab.id, mode)

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
		if use and use.tagImmune then
			car.model:SetAttribute("TagImmuneUntil", workspace:GetServerTimeNow() + use.tagImmune)
		end
	elseif ab.kind == "slam" then
		reach = ab.radius
		local f = SpecialLogic.falloff(dist, ab.radius)
		if enemyAlive and f > 0 then
			shove(enemy, offset, ab.push, ab.lift, f)
		end
		if use and use.ball and modeRoot then
			moveBall(car, ab, use.ball, modeRoot)
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
		if use and use.ball and modeRoot then
			moveBall(car, ab, use.ball, modeRoot)
		end
	else -- "jump"
		Impulse.linear(car.body, Vector3.yAxis * ab.jumpSpeed * car.body.AssemblyMass)
	end
	-- Rare and up flash in their rarity color (identity, not power; audit #45/#49); Common keeps
	-- the per-ability color. CosmeticRarity is the real rarity even in a fair match.
	local cosmetic = car.model:GetAttribute("CosmeticRarity")
	local color = COLORS[ab.kind] or Color3.new(1, 1, 1)
	if type(cosmetic) == "string" and cosmetic ~= "Common" then
		local rgb = CarCatalog.styleFor(cosmetic).effectRgb
		color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	cue(car, color, reach)
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
	car.model:SetAttribute("AbilityReadyAt", 0)
	car.model:SetAttribute("TagImmuneUntil", nil)
end

return Specials
