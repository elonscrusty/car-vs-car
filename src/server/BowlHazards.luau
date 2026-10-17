--!strict
-- The bowl's fun-stuff, run during a fight: boost pads on the wall (launch a car over the middle)
-- and the magnet power-up. Rules and numbers:
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
	-- Call every frame of the fight.
	step: (dt: number, now: number) -> (),
	destroy: () -> (),
}

local BowlHazards = {}

local PAD_COLOR = Color3.fromRGB(60, 200, 255) -- cyan: never confused with the yellow SPEED pickup

function BowlHazards.new(arena: Arena.Arena, cars: { CarBuilder.Car }): Handle
	local cfg = GameConfig.Arena
	local pcfg = BowlConfig.Pads
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
		-- Floating sign so nobody mistakes it for a power-up.
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(120, 44)
		sign.StudsOffset = Vector3.new(0, 5, 0)
		sign.AlwaysOnTop = true
		sign.Parent = pad
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "BOOST >>>"
		text.TextColor3 = PAD_COLOR
		text.TextStrokeTransparency = 0
		text.Parent = sign
	end

	local padReadyAt: { [CarBuilder.Car]: number } = {}

	local handle: Handle = {} :: any
	handle.step = function(dt, now)
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
