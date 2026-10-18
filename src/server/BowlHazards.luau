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

	-- Boost pads: a glowing slab with chevrons on the slope, and a BOOST sign leaning on the
	-- wall behind it. All look-only.
	local padRadius = cfg.flatRadius + (cfg.rimRadius - cfg.flatRadius) * pcfg.radiusShare
	local spots = BowlRules.padSpots(pcfg.count, padRadius, math.rad(45))
	local pulsing: { Part } = {}

	local function glowPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = PAD_COLOR
		part.Size = size
		part.CFrame = cf
		part.Parent = parent
		table.insert(pulsing, part)
		return part
	end

	for _, s in spots do
		local a = math.atan2(s.z, s.x)
		local yaw = math.atan2(-math.cos(a), -math.sin(a))
		-- Local -Z points out of the bowl, +Z toward the middle.
		local model = Instance.new("Model")
		model.Name = "BoostPad"
		model.Parent = folder

		local slabCF = CFrame.new(center.X + s.x, surfaceY(padRadius) + 0.25, center.Z + s.z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(tilt, 0, 0)
		local slab =
			glowPart("Slab", Vector3.new(pcfg.size[1], pcfg.size[2], pcfg.size[3]), slabCF, model)
		slab.Color = Color3.fromRGB(20, 90, 140)
		local light = Instance.new("PointLight")
		light.Color = PAD_COLOR
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = slab

		-- Three cyan chevrons (two arms each) pointing sideways, along the rim.
		local armLen, armAngle = 3.6, math.rad(55)
		for i = -1, 1 do
			local tipX = i * 3.6 + 1.2
			for side = -1, 1, 2 do
				local dirX, dirZ = -math.cos(armAngle), side * math.sin(armAngle)
				local armCF = slabCF
					* CFrame.new(
						tipX + dirX * armLen / 2,
						pcfg.size[2] / 2 + 0.08,
						dirZ * armLen / 2
					)
					* CFrame.Angles(0, math.pi + side * armAngle, 0)
				glowPart("Chevron", Vector3.new(armLen, 0.15, 0.9), armCF, model)
			end
		end

		-- The sign: dark navy panel, cyan border, leaning back against the wall, facing the middle.
		local pw, ph = pcfg.panelSize[1], pcfg.panelSize[2]
		local backR = padRadius + pcfg.panelBack
		local baseCF = CFrame.new(
			center.X + math.cos(a) * backR,
			surfaceY(backR) + 0.2,
			center.Z + math.sin(a) * backR
		) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.rad(pcfg.panelLeanDeg), 0, 0)
		local panelCF = baseCF * CFrame.new(0, ph / 2, 0)
		local panel = Instance.new("Part")
		panel.Name = "Panel"
		panel.Anchored = true
		panel.CanCollide = false
		panel.CanQuery = false
		panel.CanTouch = false
		panel.CastShadow = false
		panel.Material = Enum.Material.SmoothPlastic
		panel.Color = Color3.fromRGB(14, 24, 56)
		panel.Size = Vector3.new(pw, ph, 0.4)
		panel.CFrame = panelCF
		panel.Parent = model
		local bar = 0.35
		local edges = {
			{ Vector3.new(pw, bar, 0.5), Vector3.new(0, (ph - bar) / 2, 0) },
			{ Vector3.new(pw, bar, 0.5), Vector3.new(0, -(ph - bar) / 2, 0) },
			{ Vector3.new(bar, ph, 0.5), Vector3.new((pw - bar) / 2, 0, 0) },
			{ Vector3.new(bar, ph, 0.5), Vector3.new(-(pw - bar) / 2, 0, 0) },
		}
		for _, e in edges do
			glowPart("Border", e[1], panelCF * CFrame.new(e[2]), model)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		gui.Parent = panel
		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.62)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Text = "BOOST"
		title.TextColor3 = PAD_COLOR
		title.Parent = gui
		local arrows = Instance.new("TextLabel")
		arrows.Position = UDim2.fromScale(0, 0.58)
		arrows.Size = UDim2.fromScale(1, 0.34)
		arrows.BackgroundTransparency = 1
		arrows.Font = Enum.Font.FredokaOne
		arrows.TextScaled = true
		arrows.Text = ">>>"
		arrows.TextColor3 = Color3.new(1, 1, 1)
		arrows.Parent = gui
	end

	local padReadyAt: { [CarBuilder.Car]: number } = {}
	local lastGlow = 0

	local handle: Handle = {} :: any
	handle.step = function(dt, now)
		-- Gentle glow pulse on the signs and chevrons.
		-- Updated 10 times a second, not every frame, to keep network traffic low.
		if now - lastGlow >= 0.1 then
			lastGlow = now
			local glow = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(now * 2 * math.pi / pcfg.pulseSeconds))
			for _, part in pulsing do
				part.Transparency = glow
			end
		end
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
						local v = car.body.AssemblyLinearVelocity
						local vx, vy, vz = BowlRules.padLaunch(s, pcfg.kick, pcfg.lift, v.X, v.Z)
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
		table.clear(pulsing)
		folder:Destroy()
	end
	return handle
end

return BowlHazards
