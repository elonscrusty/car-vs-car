--!strict
-- A look-only skin for the RC car: a real truck model drawn over the grey blocks on the rock
-- track. The grey body still does all the driving; the skin just follows it every frame, and
-- its wheels ride the same springs. B turns the skin off and on to compare.
--
-- The model is a Model named RockCrawler in ReplicatedStorage.CarSkins, with MeshParts named
-- Body, WheelFL, WheelFR, WheelRL and WheelRR (front is -Z, as imported).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RCCar = require(script.Parent.RCCar)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local WHEEL_NAMES = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" } -- same order as RCCar

local CarSkin = {}

type Shown = {
	car: RCCar.Car,
	scale: number,
	folder: Folder,
	body: BasePart,
	offset: CFrame, -- the skin body, seen from the grey body
	hidden: { [BasePart]: number }, -- grey parts and how see-through they were
}

local function template(): Model?
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local m = skins and skins:FindFirstChild("RockCrawler")
	return if m and m:IsA("Model") then m else nil
end

local function lookOnly(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
end

local function show(car: RCCar.Car, src: Model): Shown?
	local copy = src:Clone()
	local body = copy:FindFirstChild("Body", true)
	if not (body and body:IsA("BasePart")) then
		copy:Destroy()
		return nil
	end
	local wheels: { BasePart } = {}
	for i, name in WHEEL_NAMES do
		local w = copy:FindFirstChild(name, true)
		if not (w and w:IsA("BasePart")) then
			copy:Destroy()
			return nil
		end
		wheels[i] = w
	end
	-- size it so its tyres are as big as the driving wheels
	local meshRadius = 0
	for _, w in wheels do
		meshRadius += w.Size.Y / 8
	end
	copy:ScaleTo(copy:GetScale() * Tuning.wheelRadius / meshRadius)

	-- where its wheels sit, seen from the middle between them
	local mid = Vector3.zero
	for _, w in wheels do
		mid += w.Position / 4
	end
	local spots: { Vector3 } = {}
	for i, w in wheels do
		spots[i] = w.Position - mid
	end
	-- parked on flat ground the springs settle at this length; line the model's axles up there
	local rest = math.clamp(
		Tuning.maxSusp - workspace.Gravity * Tuning.scale / (Tuning.springOmega ^ 2),
		0,
		Tuning.maxSusp
	)
	local offset = CFrame.new(Vector3.new(0, Tuning.attachY - rest, 0) + body.Position - mid)

	local folder = Instance.new("Folder")
	folder.Name = "RCSkin"
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			lookOnly(d)
		end
	end
	body.Parent = folder
	for _, w in wheels do
		w.Parent = folder
	end
	copy:Destroy()
	folder.Parent = workspace

	local hidden: { [BasePart]: number } = {}
	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	car.setLook({ wheels = wheels, spots = spots })
	return {
		car = car,
		scale = Tuning.scale,
		folder = folder,
		body = body,
		offset = offset,
		hidden = hidden,
	}
end

local function hide(s: Shown)
	s.car.setLook(nil)
	for p, t in s.hidden do
		if p.Parent then
			p.Transparency = t
		end
	end
	s.folder:Destroy()
end

-- Starts the skin. Call update(car, wanted) every frame right after car.render.
function CarSkin.new()
	local enabled = true
	local shown: Shown? = nil
	local broken: Model? = nil -- a model missing a part: don't keep trying it every frame

	UserInputService.InputBegan:Connect(function(input: InputObject, typing: boolean)
		if not typing and input.KeyCode == Enum.KeyCode.B then
			enabled = not enabled
		end
	end)

	local self = {}

	function self.update(car: RCCar.Car, wanted: boolean)
		local want = wanted and enabled and car.body.Parent ~= nil
		local cur = shown
		if cur and (not want or cur.car ~= car or cur.scale ~= Tuning.scale) then
			hide(cur)
			shown = nil
			cur = nil
		end
		if want and not cur then
			local src = template()
			if src and src ~= broken then
				shown = show(car, src)
				cur = shown
				if not shown then
					broken = src
					warn("CarSkin: RockCrawler needs Body, WheelFL, WheelFR, WheelRL and WheelRR")
				end
			end
		end
		if cur then
			cur.body.CFrame = car.body.CFrame * cur.offset
		end
	end

	return self
end

return CarSkin
