--!strict
-- Cosmetic parts break off a damaged car. Only the massless decoration parts CarBuilder welds on
-- leave; the heavy Body is never touched, so mass and physics stay the same.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CarBuilder = require(script.Parent.CarBuilder)

local Parts = {}

local function attached(car: CarBuilder.Car): { BasePart }
	local out = {}
	for _, p in car.model:GetChildren() do
		if p:IsA("BasePart") and p ~= car.body and p:FindFirstChildOfClass("WeldConstraint") then
			table.insert(out, p)
		end
	end
	return out
end

-- Detaches `fraction` (0..1, rounded up) of the parts still attached.
function Parts.breakOff(car: CarBuilder.Car, fraction: number)
	local list = attached(car)
	local n = math.min(#list, math.ceil(#list * fraction))
	local cfg = CombatConfig.Parts
	local vel = car.body.AssemblyLinearVelocity
	for i = 1, n do
		local p = list[i]
		for _, c in p:GetChildren() do
			if c:IsA("WeldConstraint") then
				c:Destroy()
			end
		end
		p:SetAttribute("CarIdx", nil) -- so the debris never counts as a car hit
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
		local out = p.Position - car.body.Position
		out = if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis
		p.AssemblyLinearVelocity = vel + out * cfg.outSpeed + Vector3.yAxis * cfg.upSpeed
		p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, 1) * 10
		Debris:AddItem(p, cfg.lifetime)
	end
end

-- Call after damage: breaks parts for each HP threshold crossed (all remaining parts on death).
function Parts.onDamage(car: CarBuilder.Car, crossed: { number }, dead: boolean)
	if dead then
		Parts.breakOff(car, 1)
		return
	end
	for _, i in crossed do
		Parts.breakOff(car, CombatConfig.Parts.fractions[i] or 0.5)
	end
end

return Parts
