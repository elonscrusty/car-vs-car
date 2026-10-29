--!strict
-- Wheel trails (CarFxStyles.TRAIL): carter picked "Scrap Sparks" (10-29): while the car drives
-- fast, sparks fly off both rear tyres and bounce along behind it, with a little brown dust.
-- They follow the car's own wheel contact points (car.telemetry.wheels), so it fits any car, and
-- die away when the tyre leaves the ground or the car slows. Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarFxStyles = require(ReplicatedStorage.Shared.CarFxStyles)
local FxEmitter = require(script.Parent.FxEmitter)
local RCCar = require(script.Parent.RCCar)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type TrailFx = {
	-- car: the car showing a skin (nil: none shown); styleId: the player's pick (nil or unknown:
	-- Scrap Sparks)
	step: (car: RCCar.Car?, styleId: string?) -> (),
}

type Spot = {
	wheel: number, -- index in car.telemetry.wheels
	at: Attachment,
	sparks: ParticleEmitter,
	dust: ParticleEmitter,
}

type Rig = { body: BasePart, style: CarFxStyles.Trail, spots: { Spot } }

local TrailFx = {}

local function build(car: RCCar.Car, style: CarFxStyles.Trail): Rig
	local u = Tuning.scale
	local spots = {}
	for i, info in car.telemetry.wheels do
		if info.rear then
			local a = Instance.new("Attachment")
			a.Name = "TrailSpot"
			a.Parent = car.body
			local sparks = FxEmitter.make(style.sparks, u, Enum.NormalId.Front)
			sparks.Parent = a
			local dust = FxEmitter.make(style.dust, u, Enum.NormalId.Front)
			dust.Parent = a
			table.insert(spots, { wheel = i, at = a, sparks = sparks, dust = dust })
		end
	end
	return { body = car.body, style = style, spots = spots }
end

local function destroy(r: Rig)
	for _, s in r.spots do
		s.at:Destroy()
	end
end

function TrailFx.new(): TrailFx
	local rig: Rig? = nil

	local self = {} :: TrailFx

	function self.step(car: RCCar.Car?, styleId: string?)
		local r = rig
		if not car or car.body.Parent == nil then
			rig = nil -- (the car went away with its emitters)
			return
		end
		local style = CarFxStyles.trail(styleId)
		if not r or r.body ~= car.body or r.style ~= style then
			if r and r.body == car.body then
				destroy(r) -- same car, new style
			end
			r = build(car, style)
			rig = r
		end
		local t = car.telemetry
		local S = Tuning.scale
		local fast = math.clamp(
			(t.speed - style.minSpeed * S) / ((style.fullSpeed - style.minSpeed) * S),
			0,
			1
		)
		local boost = if t.boost > 0 then style.boostMul else 1
		-- the way the car came from: sparks fly back and up
		local vel = car.body.AssemblyLinearVelocity
		local flat = Vector3.new(vel.X, 0, vel.Z)
		local back = if flat.Magnitude > 0.1 then -flat.Unit else -car.body.CFrame.LookVector
		for _, s in r.spots do
			local info = t.wheels[s.wheel]
			local on = info ~= nil and info.touching and info.material ~= Enum.Material.Water
			if on and info then
				local up = Vector3.yAxis * 0.6
				s.at.WorldCFrame = CFrame.lookAt(info.contact, info.contact + back + up)
			end
			local k = if on then fast * boost else 0
			s.sparks.Rate = style.sparks.rate * k
			s.dust.Rate = style.dust.rate * k
		end
	end

	return self
end

return TrailFx
