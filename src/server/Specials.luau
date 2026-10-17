--!strict
-- One special move per car (Tank smash, Rocket dash, Ramp flip, ...). Owned by the specials worker.
-- Match calls `use` when a human presses SPECIAL during the fight. Server decides everything.
-- State is keyed by car (weak), so every new match (new cars) starts fresh with no cooldown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpecialLogic = require(ReplicatedStorage.Shared.SpecialLogic)
local SpecialsConfig = require(ReplicatedStorage.Shared.SpecialsConfig)
local CarBuilder = require(script.Parent.CarBuilder)

type State = {
	readyAt: number, -- os.clock() time the special is ready again
	bonusUntil: number, -- Spike: double-damage window end
	bonusMult: number,
	flip: number, -- alternates the Light dodge side
}

local Specials = {}

local states: { [CarBuilder.Car]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(car: CarBuilder.Car): State
	local s = states[car]
	if s == nil then
		s = { readyAt = 0, bonusUntil = 0, bonusMult = 1, flip = 1 }
		states[car] = s
	end
	return s
end

-- A short ring flash at the car so people see something happened.
local function cue(car: CarBuilder.Car, color: Color3)
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
	local grow = 4 + (SpecialsConfig.ByCar[car.id].radius * 2)
	game:GetService("TweenService")
		:Create(p, TweenInfo.new(0.35), { Size = Vector3.one * grow, Transparency = 1 })
		:Play()
	game:GetService("Debris"):AddItem(p, 0.5)
end

local function massScale(enemy: CarBuilder.Car): number
	return SpecialLogic.massScale(
		enemy.body.AssemblyMass,
		SpecialsConfig.refMass,
		SpecialsConfig.minMassScale,
		SpecialsConfig.maxMassScale
	)
end

-- Knocks the enemy away from `from` (mass-aware impulse), with optional lift and spin.
local function knock(
	enemy: CarBuilder.Car,
	away: Vector3,
	push: number,
	lift: number,
	spin: number,
	amount: number
)
	local body = enemy.body
	local scale = massScale(enemy) * amount
	local flat = Vector3.new(away.X, 0, away.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	body:ApplyImpulse((dir * push + Vector3.yAxis * lift) * scale * body.AssemblyMass)
	if spin > 0 then
		body:ApplyAngularImpulse(Vector3.yAxis * spin * scale * body.AssemblyMass * 4)
	end
end

local function dash(car: CarBuilder.Car, sp: SpecialsConfig.Special, s: State)
	local cf = car.body.CFrame
	local fwd = cf.LookVector
	local right = cf.RightVector
	local v = fwd * sp.dashForward
	if sp.dashSide > 0 then
		s.flip = -s.flip
		v += right * sp.dashSide * s.flip
	end
	car.body:ApplyImpulse(v * car.body.AssemblyMass)
end

-- Tries to fire `car`'s special at `enemy`. `now` is os.clock(). Returns true if it fired
-- (so the caller can start the cooldown UI). Cooldown handling lives in here.
function Specials.use(car: CarBuilder.Car, enemy: CarBuilder.Car, now: number): boolean
	local sp = SpecialsConfig.ByCar[car.id]
	if sp == nil or car.dead then
		return false
	end
	local s = stateOf(car)
	if SpecialLogic.cooldownLeft(s.readyAt, now) > 0 then
		return false
	end
	s.readyAt = now + sp.cooldown

	local enemyAlive = not enemy.dead
	local offset = enemy.body.Position - car.body.Position
	local dist = offset.Magnitude

	if sp.kind == "slam" then
		if enemyAlive then
			local f = SpecialLogic.falloff(dist, sp.radius)
			if f > 0 then
				knock(enemy, offset, sp.push, sp.lift, 0, f)
			end
		end
		cue(car, Color3.fromRGB(255, 170, 60))
	elseif sp.kind == "cone" then
		local look = car.body.CFrame.LookVector
		if
			enemyAlive
			and SpecialLogic.inCone(look.X, look.Z, offset.X, offset.Z, sp.radius, sp.coneDeg)
		then
			knock(enemy, offset, sp.push, sp.lift, sp.spin, 1)
		end
		cue(car, Color3.fromRGB(90, 160, 255))
	elseif sp.kind == "dash" then
		dash(car, sp, s)
		cue(car, Color3.fromRGB(255, 255, 255))
	else -- "spin"
		s.bonusUntil = now + sp.duration
		s.bonusMult = sp.damageMult
		cue(car, Color3.fromRGB(190, 110, 255))
	end
	return true
end

-- Seconds until `car` can use its special again (0 = ready). For the HUD.
function Specials.cooldownLeft(car: CarBuilder.Car, now: number): number
	local s = states[car]
	if s == nil then
		return 0
	end
	return SpecialLogic.cooldownLeft(s.readyAt, now)
end

-- Damage multiplier for hits dealt by `car` right now (Spike's spin attack). Match multiplies by it.
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
