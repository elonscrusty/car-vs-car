--!strict
-- The bowl's fun-stuff, run during a fight: boost pads on the wall (launch a car over the middle),
-- the shrinking safe ring (HP drains outside it) and the magnet power-up. Rules and numbers:
-- shared/BowlRules + BowlConfig. Everything is decided here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaMath = require(ReplicatedStorage.Shared.ArenaMath)
local BowlConfig = require(ReplicatedStorage.Shared.BowlConfig)
local BowlRules = require(ReplicatedStorage.Shared.BowlRules)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Arena = require(script.Parent.Arena)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)

export type Handle = {
	-- Call every frame of the fight. `damage(car, amount)` is how HP is taken (the match owns HP).
	step: (
		dt: number,
		now: number,
		fightElapsed: number,
		damage: (CarBuilder.Car, number) -> ()
	) -> (),
	destroy: () -> (),
}

local BowlHazards = {}

local RING_COLOR = Color3.fromRGB(255, 70, 60)
local PAD_COLOR = Color3.fromRGB(255, 220, 60)

function BowlHazards.new(arena: Arena.Arena, cars: { CarBuilder.Car }): Handle
	local cfg = GameConfig.Arena
	local pcfg = BowlConfig.Pads
	local scfg = BowlConfig.Shrink
	local center = arena.center
	local tilt = math.rad(cfg.tiltDeg)
	local folder = Instance.new("Folder")
	folder.Name = "BowlHazards"
	folder.Parent = arena.model

	local function surfaceY(r: number): number
		return center.Y + ArenaMath.surfaceHeight(r, cfg.flatRadius, cfg.rimRadius, cfg.tiltDeg)
	end

	-- Boost pads: glowing slabs lying on the slope.
	local padRadius = cfg.flatRadius + (cfg.rimRadius - cfg.flatRadius) * pcfg.radiusShare
	local spots = BowlRules.padSpots(pcfg.count, padRadius, math.rad(45))
	for _, s in spots do
		local a = math.atan2(s.z, s.x)
		local yaw = math.atan2(-math.cos(a), -math.sin(a))
		local pad = Instance.new("Part")
		pad.Name = "BoostPad"
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.Size = Vector3.new(pcfg.size[1], pcfg.size[2], pcfg.size[3])
		pad.Material = Enum.Material.Neon
		pad.Color = PAD_COLOR
		pad.CFrame = CFrame.new(center.X + s.x, surfaceY(padRadius) + 0.25, center.Z + s.z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(tilt, 0, 0)
		pad.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = PAD_COLOR
		light.Range = 16
		light.Brightness = 2
		light.Parent = pad
	end

	-- The safe ring, drawn as glowing blocks. Hidden until it is about to close.
	local ring: { Part } = {}
	for i = 1, scfg.ringParts do
		local p = Instance.new("Part")
		p.Name = "SafeRing"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(3, 0.5, 5)
		p.Material = Enum.Material.Neon
		p.Color = RING_COLOR
		p.Transparency = 1
		p.Parent = folder
		ring[i] = p
	end
	local lastRingAt = -1

	local padReadyAt: { [CarBuilder.Car]: number } = {}

	local function updateRing(radius: number, visible: boolean)
		local y = surfaceY(radius) + 0.3
		for i, p in ring do
			local a = i / #ring * math.pi * 2
			p.CFrame = CFrame.new(
				center.X + math.cos(a) * radius,
				y,
				center.Z + math.sin(a) * radius
			) * CFrame.Angles(0, -a + math.pi / 2, 0)
			p.Transparency = if visible then 0.15 else 1
		end
	end

	local handle: Handle = {} :: any
	handle.step = function(dt, now, fightElapsed, damage)
		-- Boost pads.
		for _, car in cars do
			if car.dead then
				continue
			end
			local pos = car.body.Position
			local rel = { x = pos.X - center.X, z = pos.Z - center.Z }
			if (padReadyAt[car] or 0) <= now then
				for _, s in spots do
					if BowlRules.onPad(rel, s, pcfg.triggerRadius) then
						local vx, vy, vz = BowlRules.padLaunch(s, pcfg.kick, pcfg.lift)
						Impulse.linear(car.body, Vector3.new(vx, vy, vz) * car.body.AssemblyMass)
						padReadyAt[car] = now + pcfg.cooldown
						break
					end
				end
			end
		end
		-- Shrinking safe ring.
		local safe = BowlRules.safeRadius(fightElapsed, cfg.rimRadius, scfg)
		if now - lastRingAt >= 0.1 then
			lastRingAt = now
			updateRing(safe, fightElapsed >= scfg.startSeconds - 6)
		end
		if fightElapsed >= scfg.startSeconds then
			for _, car in cars do
				if not car.dead then
					local pos = car.body.Position
					local dist = math.sqrt((pos.X - center.X) ^ 2 + (pos.Z - center.Z) ^ 2)
					local lost = BowlRules.ringDamage(dist, safe, scfg.damagePerSecond, dt)
					if lost > 0 then
						damage(car, lost)
					end
				end
			end
		end
		-- Magnet: a car with the buff drags the other car toward itself.
		for _, car in cars do
			if not car.dead and Buffs.has(car, "magnet") then
				for _, other in cars do
					if other ~= car and not other.dead then
						local offset = car.body.Position - other.body.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						local pull = BowlRules.magnetPull(
							flat.Magnitude,
							BowlConfig.Magnet.range,
							BowlConfig.Magnet.pull,
							dt
						)
						if pull > 0 then
							Impulse.linear(other.body, flat.Unit * pull * other.body.AssemblyMass)
						end
					end
				end
			end
		end
	end
	handle.destroy = function()
		folder:Destroy()
	end
	return handle
end

return BowlHazards
