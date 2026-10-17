--!strict
-- Spawns floating power-ups on the arena floor during a fight and gives them to the car that
-- drives into them. Rules and numbers: PickupLogic, PickupsConfig. Effects: Buffs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BowlConfig = require(ReplicatedStorage.Shared.BowlConfig)
local PickupLogic = require(ReplicatedStorage.Shared.PickupLogic)
local PickupsConfig = require(ReplicatedStorage.Shared.PickupsConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)

export type Handle = { destroy: () -> () }

type Pickup = { kind: string, part: Part, x: number, z: number, tweens: { Tween } }

local Pickups = {}

local function colorOf(kind: string): Color3
	local c = (PickupsConfig.colors :: any)[kind] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function makePart(kind: string, pos: Vector3, parent: Instance): (Part, { Tween })
	local part = Instance.new("Part")
	part.Name = "Pickup_" .. kind
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(2.6, 2.6, 2.6)
	part.Material = Enum.Material.Neon
	part.Color = colorOf(kind)
	part.Position = pos
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 14
	light.Brightness = 3
	light.Parent = part
	part.Parent = parent

	local bob = TweenService:Create(
		part,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = pos + Vector3.new(0, 1.2, 0) }
	)
	local spin = TweenService:Create(
		part,
		TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Orientation = Vector3.new(0, 360, 0) }
	)
	bob:Play()
	spin:Play()
	return part, { bob, spin }
end

-- notify(car, update) sends a UiUpdate to that car's player (nil for bots / no listener).
function Pickups.start(
	arena: Arena.Arena,
	cars: { CarBuilder.Car },
	rng: Random,
	notify: ((car: CarBuilder.Car, update: Types.UiUpdate) -> ())?
): Handle
	local cfg = PickupsConfig
	local center = arena.center
	local floorY = center.Y + cfg.hoverHeight
	local pickups: { Pickup } = {}
	local elapsed = 0
	local lastSpawnAt: number? = nil
	local destroyed = false

	local function listenerFor(car: CarBuilder.Car): (string, number) -> ()
		return function(kind: string, seconds: number)
			if notify then
				notify(car, { kind = "buff", buff = kind, seconds = seconds })
			end
		end
	end
	for _, car in cars do
		Buffs.setListener(car, listenerFor(car))
	end

	local function spawn()
		local avoid: { PickupLogic.Point } = {}
		for _, car in cars do
			local p = car.body.Position
			table.insert(avoid, { x = p.X - center.X, z = p.Z - center.Z })
		end
		local taken: { PickupLogic.Point } = {}
		for _, pk in pickups do
			table.insert(taken, { x = pk.x, z = pk.z })
		end
		local rolls: { { number } } = {}
		for _ = 1, 8 do
			table.insert(rolls, { rng:NextNumber(), rng:NextNumber() })
		end
		local spot = PickupLogic.pickSpot(
			rolls,
			cfg.ringMin,
			cfg.ringMax,
			avoid,
			cfg.minCarDistance,
			taken,
			cfg.minPickupDistance
		)
		lastSpawnAt = elapsed -- even when no spot was free: try again after the usual wait
		if spot == nil then
			return
		end
		local kind = cfg.kinds[rng:NextInteger(1, #cfg.kinds)]
		local part, tweens =
			makePart(kind, Vector3.new(center.X + spot.x, floorY, center.Z + spot.z), arena.model)
		table.insert(pickups, { kind = kind, part = part, x = spot.x, z = spot.z, tweens = tweens })
	end

	local function remove(index: number)
		local pk = pickups[index]
		for _, t in pk.tweens do
			t:Cancel()
		end
		pk.part:Destroy()
		table.remove(pickups, index)
	end

	local conn = RunService.Heartbeat:Connect(function(dt)
		if destroyed then
			return
		end
		elapsed += dt
		if
			PickupLogic.shouldSpawn(
				elapsed,
				lastSpawnAt,
				#pickups,
				cfg.firstSpawnSeconds,
				cfg.spawnEverySeconds,
				cfg.maxOnFloor
			)
		then
			spawn()
		end
		for i = #pickups, 1, -1 do
			local pk = pickups[i]
			for _, car in cars do
				if not car.dead then
					local p = car.body.Position
					if
						PickupLogic.touches(
							p.X - center.X,
							p.Z - center.Z,
							pk.x,
							pk.z,
							cfg.pickupRadius
						)
					then
						Buffs.apply(car, pk.kind)
						if pk.kind == "rocket" then
							-- Dash straight at the other car.
							for _, other in cars do
								if other ~= car and not other.dead then
									local d = other.body.Position - car.body.Position
									local flat = Vector3.new(d.X, 0, d.Z)
									if flat.Magnitude > 0.5 then
										Impulse.linear(
											car.body,
											flat.Unit
												* BowlConfig.Rocket.speed
												* car.body.AssemblyMass
										)
									end
								end
							end
						end
						remove(i)
						break
					end
				end
			end
		end
	end)

	return {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			conn:Disconnect()
			while #pickups > 0 do
				remove(#pickups)
			end
			for _, car in cars do
				Buffs.setListener(car, nil)
			end
		end,
	}
end

return Pickups
