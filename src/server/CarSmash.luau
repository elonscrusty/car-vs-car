--!strict
-- Flying bits for the car fight: scrap that sprays off a big hit, a real part torn off the car,
-- and the explosion when a car is knocked out. Everything is a server part (replicates to all)
-- and is removed by Debris after a few seconds.

local Debris = game:GetService("Debris")

local CarBuilder = require(script.Parent.CarBuilder)

local CarSmash = {}

local LIFETIME = 4
local SCRAP_COLORS = {
	Color3.fromRGB(70, 72, 82),
	Color3.fromRGB(250, 170, 50),
	Color3.fromRGB(160, 165, 175),
}

local function visibleParts(car: CarBuilder.Car): { BasePart }
	local out = {}
	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") and d ~= car.body and d.Transparency < 0.95 then
			table.insert(out, d)
		end
	end
	return out
end

local function bodyColor(car: CarBuilder.Car): Color3
	for _, p in visibleParts(car) do
		if p.Name == "Visual" then
			return p.Color
		end
	end
	return car.body.Color
end

-- Sets a loose bit flying: away from `from`, with some lift and spin.
local function fling(p: BasePart, from: Vector3, rng: Random, out: number, up: number)
	local dir = p.Position - from
	dir = if dir.Magnitude > 0.1
		then dir.Unit
		else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	p.AssemblyLinearVelocity = dir * out * rng:NextNumber(0.6, 1.2)
		+ Vector3.new(0, up * rng:NextNumber(0.6, 1.2), 0)
	p.AssemblyAngularVelocity =
		Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
end

local function loose(p: BasePart, parent: Instance)
	p.Anchored = false
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = false
	p.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.5, 0.4, 1, 1)
	p:SetAttribute("CarIdx", nil) -- never counts as a car in a hit
	p.Parent = parent
	Debris:AddItem(p, LIFETIME)
end

-- `count` small bits of metal spray off the car.
function CarSmash.scrap(
	car: CarBuilder.Car,
	count: number,
	parent: Instance,
	rng: Random,
	power: number
)
	local at = car.body.Position
	local colors = { bodyColor(car), SCRAP_COLORS[1], SCRAP_COLORS[2], SCRAP_COLORS[3] }
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Name = "Scrap"
		p.Size =
			Vector3.new(rng:NextNumber(0.6, 2), rng:NextNumber(0.4, 1.2), rng:NextNumber(0.6, 2))
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.Metal
		p.CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1)))
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		loose(p, parent)
		fling(p, at - Vector3.new(0, 1, 0), rng, 28 * power, 22 * power)
	end
end

-- A real part (wheel, spoiler, bumper ...) tears off: a copy flies away and the original vanishes.
-- The big body shell stays. Returns true when a part came off.
function CarSmash.peel(car: CarBuilder.Car, parent: Instance, rng: Random): boolean
	local parts = visibleParts(car)
	local biggest: BasePart? = nil
	for _, p in parts do
		if biggest == nil or p.Size.Magnitude > biggest.Size.Magnitude then
			biggest = p
		end
	end
	local pool = {}
	for _, p in parts do
		if p ~= biggest then
			table.insert(pool, p)
		end
	end
	if #pool == 0 then
		return false
	end
	local pick = pool[rng:NextInteger(1, #pool)]
	local copy = pick:Clone()
	for _, c in copy:GetChildren() do
		if c:IsA("WeldConstraint") or c:IsA("Motor6D") or c:IsA("Script") then
			c:Destroy()
		end
	end
	copy.CFrame = pick.CFrame
	loose(copy, parent)
	fling(copy, car.body.Position, rng, 30, 20)
	pick.Transparency = 1
	return true
end

-- The car blows up: fire, every visible part flies off, plenty of scrap. The caller removes the car.
function CarSmash.blowUp(car: CarBuilder.Car, parent: Instance, rng: Random)
	local at = car.body.Position
	local e = Instance.new("Explosion")
	e.Position = at
	e.BlastRadius = 10
	e.BlastPressure = 0 -- looks only: the server moves nothing
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = parent
	for _, p in visibleParts(car) do
		local copy = p:Clone()
		for _, c in copy:GetChildren() do
			if c:IsA("WeldConstraint") or c:IsA("Motor6D") or c:IsA("Script") then
				c:Destroy()
			end
		end
		copy.CFrame = p.CFrame
		loose(copy, parent)
		fling(copy, at, rng, 42, 34)
	end
	CarSmash.scrap(car, 12, parent, rng, 1.5)
end

return CarSmash
