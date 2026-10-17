--!strict
-- Car weapons at fight time. Every car wears one weapon (players: the one they picked in the
-- menu; the bot gets a random one). Numbers live in shared/WeaponsConfig. The server decides all
-- hits and damage: it never trusts the client. Match calls `attach` when it builds a car, `tick`
-- every fight frame, `press` when a player taps WEAPON, and `clear` when the match is over.
--   passive: Saw (ram bonus), Axe (orbits the car), Shock (pulse when someone is close)
--   active:  Bomb, Rocket, Hammer, Magnet, Flame (WEAPON button, cooldown)
-- The weapon looks are gray-ish named placeholder blocks ("Weapon_<Id>") so real models can
-- swap in by name later.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SpecialLogic = require(ReplicatedStorage.Shared.SpecialLogic)
local SpecialsConfig = require(ReplicatedStorage.Shared.SpecialsConfig)
local WeaponsConfig = require(ReplicatedStorage.Shared.WeaponsConfig)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)

-- What Match gives us: how to hurt a car (HP, shield, hit message, K.O.) and where the arena is.
export type Context = {
	deal: (
		attacker: CarBuilder.Car,
		defender: CarBuilder.Car,
		amount: number,
		pos: Vector3,
		tag: string
	) -> (),
	origin: Vector3, -- middle of the arena
	rimRadius: number, -- projectiles die past this
}

type Bomb = { part: Part, explodeAt: number }
type Rocket = { part: Part, dir: Vector3, expireAt: number }

type State = {
	def: WeaponsConfig.WeaponDef,
	folder: Instance, -- where free-flying parts (axe, bombs, rockets) live
	readyAt: number, -- active: ready again at this os.clock(); passive Shock: next pulse
	activeUntil: number, -- Magnet / Flame running until
	nextTickAt: number, -- Magnet / Flame next tick
	smashAt: number, -- Hammer: smash happens at this time (0 = none pending)
	angle: number, -- Axe orbit angle
	axe: Part?,
	axeHitAt: number,
	nozzle: Part?, -- Flame: where the fire comes from
	fire: ParticleEmitter?,
	bombs: { Bomb },
	rockets: { Rocket },
}

local Weapon = {}

local states: { [CarBuilder.Car]: State } = setmetatable({}, { __mode = "k" }) :: any

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lookOf(car: CarBuilder.Car): Vector3
	local f = flat(car.body.CFrame.LookVector)
	return if f.Magnitude > 0.05 then f.Unit else Vector3.zAxis
end

-- How far from its middle a car's hit box reaches sideways (for "is the axe touching it").
local function reachOf(car: CarBuilder.Car): number
	return math.max(car.stats.size[1], car.stats.size[3]) / 2
end

-- Mass-aware shove away from `from`, with optional lift (same feel as the specials).
local function knock(
	enemy: CarBuilder.Car,
	from: Vector3,
	push: number,
	lift: number,
	scale: number
)
	local body = enemy.body
	local away = flat(body.Position - from)
	local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.zAxis
	local mass = SpecialLogic.massScale(
		body.AssemblyMass,
		SpecialsConfig.refMass,
		SpecialsConfig.minMassScale,
		SpecialsConfig.maxMassScale
	)
	Impulse.linear(body, (dir * push + Vector3.yAxis * lift) * mass * scale * body.AssemblyMass)
end

local function color3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A flat expanding ring so people see where a weapon hit.
local function ring(parent: Instance, pos: Vector3, radius: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = "WeaponCue"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Size = Vector3.new(0.4, 2, 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = parent
	TweenService:Create(
		p,
		TweenInfo.new(0.4),
		{ Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.6)
end

-- A massless welded block on the car, named "Weapon_<Id>" (a placeholder for a real model).
local function block(
	car: CarBuilder.Car,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = true -- Match unanchors the whole car model at the launch
	p.CFrame = car.body.CFrame * offset
	p.Parent = car.model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = car.body
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- A loose part that the server moves by hand (axe, bomb, rocket).
local function loose(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Weapon id for a bot's random pick, or the given one if it is real; nil when unknown.
function Weapon.valid(id: any): string?
	if WeaponsConfig.get(id) then
		return id :: string
	end
	return nil
end

-- True when the weapon works without a button.
function Weapon.isPassive(id: string): boolean
	local def = WeaponsConfig.get(id)
	return def ~= nil and def.kind == "passive"
end

-- Gives `car` its weapon and builds its look. `folder` is where free parts go (the arena model).
function Weapon.attach(car: CarBuilder.Car, weaponId: string?, folder: Instance)
	local def = WeaponsConfig.get(weaponId)
	if def == nil then
		return
	end
	local sx, sy, sz = car.stats.size[1], car.stats.size[2], car.stats.size[3]
	local color = color3(def.color)
	local s: State = {
		def = def,
		folder = folder,
		readyAt = 0,
		activeUntil = 0,
		nextTickAt = 0,
		smashAt = 0,
		angle = 0,
		axe = nil,
		axeHitAt = -math.huge,
		nozzle = nil,
		fire = nil,
		bombs = {},
		rockets = {},
	}
	states[car] = s
	local top = sy / 2
	if def.id == "Saw" then
		block(
			car,
			"Weapon_Saw",
			Vector3.new(sx * 0.9, 1.2, 1.6),
			CFrame.new(0, -sy * 0.1, -sz / 2 - 0.7),
			color,
			Enum.Material.Metal
		)
	elseif def.id == "Axe" then
		s.axe = loose(folder, "Weapon_Axe", Vector3.new(2, 2, 5), color)
	elseif def.id == "Bomb" then
		block(
			car,
			"Weapon_Bomb",
			Vector3.new(sx * 0.7, 1.2, 1.6),
			CFrame.new(0, top + 0.6, sz / 2 - 1),
			color
		)
	elseif def.id == "Rocket" then
		block(car, "Weapon_Rocket", Vector3.new(1.4, 1.4, 4), CFrame.new(0, top + 1, 0), color)
	elseif def.id == "Hammer" then
		block(car, "Weapon_Hammer", Vector3.new(4, 2, 2), CFrame.new(0, top + 3.5, 0), color)
		block(
			car,
			"Weapon_HammerHandle",
			Vector3.new(0.8, 3, 0.8),
			CFrame.new(0, top + 1.5, 0),
			color
		)
	elseif def.id == "Shock" then
		local coil = block(
			car,
			"Weapon_Shock",
			Vector3.new(2.4, 1.2, 2.4),
			CFrame.new(0, top + 0.8, 0),
			color,
			Enum.Material.Neon
		)
		coil.Shape = Enum.PartType.Cylinder
	elseif def.id == "Magnet" then
		block(
			car,
			"Weapon_Magnet",
			Vector3.new(sx * 0.8, 1.6, 1.6),
			CFrame.new(0, top + 0.8, -sz / 2 + 1),
			color
		)
	elseif def.id == "Flame" then
		local nozzle = block(
			car,
			"Weapon_Flame",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(0, 0, sz / 2 + 0.8),
			color
		)
		local fire = Instance.new("ParticleEmitter")
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 20))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 4),
		})
		fire.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		fire.Lifetime = NumberRange.new(0.4, 0.7)
		fire.Speed = NumberRange.new(18, 26)
		fire.Rate = 60
		fire.EmissionDirection = Enum.NormalId.Back
		fire.SpreadAngle = Vector2.new(15, 15)
		fire.Enabled = false
		fire.Parent = nozzle
		s.nozzle = nozzle
		s.fire = fire
	end
end

-- The weapon id `car` wears (nil = none).
function Weapon.idOf(car: CarBuilder.Car): string?
	local s = states[car]
	return if s then s.def.id else nil
end

-- Ram damage multiplier for hits dealt by `car` (the Saw).
function Weapon.damageMult(car: CarBuilder.Car): number
	local s = states[car]
	if s == nil then
		return 1
	end
	return s.def.damageMult
end

-- Seconds until the button works again (0 = ready, or a passive weapon).
function Weapon.cooldownLeft(car: CarBuilder.Car, now: number): number
	local s = states[car]
	if s == nil or s.def.kind ~= "active" then
		return 0
	end
	return SpecialLogic.cooldownLeft(s.readyAt, now)
end

local function enemyInReach(car: CarBuilder.Car, enemy: CarBuilder.Car, radius: number): boolean
	return not enemy.dead
		and (enemy.body.Position - car.body.Position).Magnitude <= radius + reachOf(enemy)
end

-- Taps the WEAPON button. Returns the cooldown to show (seconds) when it fired, else nil.
function Weapon.press(car: CarBuilder.Car, _enemy: CarBuilder.Car, now: number): number?
	local s = states[car]
	if s == nil or car.dead or s.def.kind ~= "active" then
		return nil
	end
	local def = s.def
	if SpecialLogic.cooldownLeft(s.readyAt, now) > 0 then
		return nil
	end
	if def.id == "Bomb" then
		if #s.bombs >= def.maxActive then
			return nil
		end
		local pos = car.body.Position + lookOf(car) * (car.stats.size[3] / 2 + 4) -- tossed ahead
		local ground = Vector3.new(pos.X, car.body.Position.Y - car.stats.size[2] / 2 + 1.2, pos.Z)
		local part = loose(
			s.folder,
			"Weapon_BombDrop",
			Vector3.one * 2.4,
			color3(def.color),
			Enum.PartType.Ball
		)
		part.Position = ground
		table.insert(s.bombs, { part = part, explodeAt = now + def.duration })
	elseif def.id == "Rocket" then
		local dir = lookOf(car)
		local start = car.body.Position + dir * (car.stats.size[3] / 2 + 3)
		local part =
			loose(s.folder, "Weapon_RocketShot", Vector3.new(1.2, 1.2, 4), color3(def.color))
		part.Material = Enum.Material.Neon
		part.CFrame = CFrame.lookAt(start, start + dir)
		table.insert(s.rockets, { part = part, dir = dir, expireAt = now + def.duration })
	elseif def.id == "Hammer" then
		s.smashAt = now + def.duration
	elseif def.id == "Magnet" or def.id == "Flame" then
		s.activeUntil = now + def.duration
		s.nextTickAt = now
		if s.fire then
			s.fire.Enabled = true
		end
	end
	s.readyAt = now + def.cooldown
	return def.cooldown
end

local function explodeBomb(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	pos: Vector3,
	ctx: Context
)
	local def = s.def
	ring(s.folder, pos, def.radius, Color3.fromRGB(255, 150, 40))
	if enemy.dead then
		return
	end
	local dist = (flat(enemy.body.Position) - flat(pos)).Magnitude
	if dist <= def.radius + reachOf(enemy) then
		local f = 0.5 + 0.5 * SpecialLogic.falloff(dist, def.radius + reachOf(enemy))
		ctx.deal(car, enemy, def.damage * f, enemy.body.Position, "BOMB!")
		knock(enemy, pos, def.push, def.lift, f)
	end
end

local function stepBombs(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	now: number,
	ctx: Context
)
	for i = #s.bombs, 1, -1 do
		local b = s.bombs[i]
		local left = b.explodeAt - now
		if left <= 0 then
			explodeBomb(car, enemy, s, b.part.Position, ctx)
			b.part:Destroy()
			table.remove(s.bombs, i)
		else
			-- Blink faster as the fuse runs out.
			local blink = math.floor(now * (4 + 8 * (1 - left / s.def.duration))) % 2 == 0
			b.part.Color = if blink then Color3.fromRGB(255, 70, 50) else color3(s.def.color)
		end
	end
end

local function stepRockets(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	dt: number,
	now: number,
	ctx: Context
)
	local def = s.def
	for i = #s.rockets, 1, -1 do
		local r = s.rockets[i]
		local pos = r.part.Position + r.dir * def.speed * dt
		r.part.CFrame = CFrame.lookAt(pos, pos + r.dir)
		local out = (flat(pos) - flat(ctx.origin)).Magnitude > ctx.rimRadius
		local hit = not enemy.dead
			and (enemy.body.Position - pos).Magnitude <= def.radius + reachOf(enemy)
		if hit then
			ring(s.folder, pos, 8, Color3.fromRGB(255, 120, 50))
			ctx.deal(car, enemy, def.damage, pos, "ROCKET!")
			knock(enemy, pos - r.dir * 4, def.push, def.lift, 1)
		end
		if hit or out or now >= r.expireAt then
			r.part:Destroy()
			table.remove(s.rockets, i)
		end
	end
end

local function stepAxe(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	dt: number,
	now: number,
	ctx: Context
)
	local axe = s.axe
	if axe == nil then
		return
	end
	local def = s.def
	s.angle = (s.angle + def.speed * dt) % (math.pi * 2)
	local center = car.body.Position
	local pos = center + Vector3.new(math.cos(s.angle), 0, math.sin(s.angle)) * def.radius
	axe.CFrame = CFrame.lookAt(pos, center) * CFrame.Angles(0, 0, s.angle * 3)
	if enemy.dead or now - s.axeHitAt < def.interval then
		return
	end
	if (enemy.body.Position - pos).Magnitude <= reachOf(enemy) + 1.5 then
		s.axeHitAt = now
		ctx.deal(car, enemy, def.damage, pos, "AXE!")
		knock(enemy, center, def.push, 3, 1)
	end
end

local function stepShock(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	now: number,
	ctx: Context
)
	local def = s.def
	if now < s.readyAt or not enemyInReach(car, enemy, def.radius) then
		return
	end
	s.readyAt = now + def.interval
	ring(
		s.folder,
		car.body.Position - Vector3.new(0, car.stats.size[2] / 2 - 0.5, 0),
		def.radius,
		color3(def.color)
	)
	ctx.deal(car, enemy, def.damage, enemy.body.Position, "SHOCK!")
	knock(enemy, car.body.Position, def.push, 4, 1)
end

local function stepTimed(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	s: State,
	now: number,
	ctx: Context
)
	local def = s.def
	if def.id == "Hammer" then
		if s.smashAt > 0 and now >= s.smashAt then
			s.smashAt = 0
			local pos = car.body.Position - Vector3.new(0, car.stats.size[2] / 2 - 0.5, 0)
			ring(s.folder, pos, def.radius, Color3.fromRGB(255, 220, 90))
			if enemyInReach(car, enemy, def.radius) then
				ctx.deal(car, enemy, def.damage, enemy.body.Position, "SMASH!")
				knock(enemy, car.body.Position, def.push, def.lift, 1)
			end
		end
		return
	end
	-- Magnet and Flame tick while they are running.
	if now >= s.activeUntil then
		if s.fire and s.fire.Enabled then
			s.fire.Enabled = false
		end
		return
	end
	if now < s.nextTickAt then
		return
	end
	s.nextTickAt = now + def.interval
	if enemy.dead then
		return
	end
	if def.id == "Magnet" then
		local offset = car.body.Position - enemy.body.Position
		if flat(offset).Magnitude <= def.radius then
			-- Pull: knock "away from a point on the far side of the enemy", i.e. toward the car.
			knock(enemy, enemy.body.Position - offset, def.push, 0, 1)
			ring(s.folder, car.body.Position, 6, color3(def.color))
		end
		if
			now + def.interval >= s.activeUntil
			and flat(offset).Magnitude <= 14 + reachOf(enemy)
		then
			ctx.deal(car, enemy, def.damage, enemy.body.Position, "MAGNET!")
		end
	elseif def.id == "Flame" then
		local back = -lookOf(car)
		local off = enemy.body.Position - car.body.Position
		if
			SpecialLogic.inCone(
				back.X,
				back.Z,
				off.X,
				off.Z,
				def.radius + reachOf(enemy),
				def.coneDeg
			)
		then
			ctx.deal(car, enemy, def.damage, enemy.body.Position, "BURN!")
		end
	end
end

-- Bots press their button by themselves when it makes sense.
local function botThink(car: CarBuilder.Car, enemy: CarBuilder.Car, s: State, now: number)
	if enemy.dead or SpecialLogic.cooldownLeft(s.readyAt, now) > 0 then
		return
	end
	local def = s.def
	local off = enemy.body.Position - car.body.Position
	local dist = flat(off).Magnitude
	local look = lookOf(car)
	local facing = if dist > 0.01 then look:Dot(flat(off).Unit) else 0
	local fire = false
	if def.id == "Bomb" then
		fire = dist < 24
	elseif def.id == "Rocket" then
		fire = dist < 70 and facing > 0.93
	elseif def.id == "Hammer" then
		fire = dist < def.radius
	elseif def.id == "Magnet" then
		fire = dist > 16 and dist < def.radius
	elseif def.id == "Flame" then
		fire = dist < def.radius and facing < -0.8
	end
	if fire then
		Weapon.press(car, enemy, now)
	end
end

-- Every fight frame for one car. `isBot` cars press their own button.
function Weapon.tick(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	dt: number,
	now: number,
	isBot: boolean,
	ctx: Context
)
	local s = states[car]
	if s == nil or car.dead then
		return
	end
	local id = s.def.id
	if id == "Axe" then
		stepAxe(car, enemy, s, dt, now, ctx)
	elseif id == "Shock" then
		stepShock(car, enemy, s, now, ctx)
	end
	if s.def.kind == "active" then
		if isBot then
			botThink(car, enemy, s, now)
		end
		if id == "Bomb" then
			stepBombs(car, enemy, s, now, ctx)
		elseif id == "Rocket" then
			stepRockets(car, enemy, s, dt, now, ctx)
		else
			stepTimed(car, enemy, s, now, ctx)
		end
	end
end

-- Removes the free parts (axe, bombs, rockets) and forgets the weapon.
function Weapon.clear(car: CarBuilder.Car)
	local s = states[car]
	if s == nil then
		return
	end
	if s.axe then
		s.axe:Destroy()
	end
	for _, b in s.bombs do
		b.part:Destroy()
	end
	for _, r in s.rockets do
		r.part:Destroy()
	end
	states[car] = nil
end

return Weapon
