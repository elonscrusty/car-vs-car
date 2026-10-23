--!strict
-- A look-only skin for the RC car: a real car model drawn over the grey blocks (the truck on the
-- rock track, the coupe on the drift track). The grey body still does all the driving; the skin just follows it every frame, and
-- its wheels ride the same springs. B turns the skin off and on to compare.
--
-- Each skin is a Model in ReplicatedStorage.CarSkins (RockCrawler, DriftCoupe, ...), with MeshParts
-- named Body, WheelFL, WheelFR, WheelRL and WheelRR. Studio's 3D import puts the nose at +Z, and
-- the car drives toward -Z, so the copy is turned around before use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RCCar = require(script.Parent.RCCar)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local WHEEL_NAMES = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" } -- same order as RCCar
-- the server paints the grey body this red when no shop car is picked: then keep the truck's own paint
local NO_PICK = Color3.fromRGB(220, 50, 47)

local CarSkin = {}

type Shown = {
	car: RCCar.Car,
	name: string,
	scale: number,
	folder: Folder,
	body: BasePart,
	offset: CFrame, -- the skin body, seen from the grey body
	hidden: { [BasePart]: number }, -- grey parts and how see-through they were
	tint: Color3?, -- the colour last copied from the grey body
	texture: string, -- the body's own paint, put back when there's no pick
	looks: { Instance }, -- its SurfaceAppearance, if any, taken off while tinted
}

local function template(name: string): Model?
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local m = skins and skins:FindFirstChild(name)
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

local function show(car: RCCar.Car, name: string, src: Model): Shown?
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
	-- turn it so its nose points where the car drives
	copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, math.pi, 0))
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
	local turns: { CFrame } = {}
	for i, w in wheels do
		spots[i] = w.Position - mid
		turns[i] = w.CFrame.Rotation
	end
	-- parked on flat ground the springs settle at this length; line the model's axles up there
	local rest = math.clamp(
		Tuning.maxSusp - workspace.Gravity * Tuning.scale / (Tuning.springOmega ^ 2),
		0,
		Tuning.maxSusp
	)
	local offset = CFrame.new(Vector3.new(0, Tuning.attachY - rest, 0) + body.Position - mid)
		* body.CFrame.Rotation

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
	car.setLook({ wheels = wheels, spots = spots, turns = turns })
	local looks: { Instance } = {}
	for _, d in body:GetChildren() do
		if d:IsA("SurfaceAppearance") then
			table.insert(looks, d)
		end
	end
	return {
		car = car,
		name = name,
		scale = Tuning.scale,
		folder = folder,
		body = body,
		offset = offset,
		hidden = hidden,
		tint = nil,
		texture = if body:IsA("MeshPart") then body.TextureID else "",
		looks = looks,
	}
end

-- Paints the truck's body (not its wheels) the colour of the shop car. A painted texture hides
-- Color, so it comes off while tinted and goes back when there's no pick.
local function paint(s: Shown, color: Color3)
	s.tint = color
	local own = color == NO_PICK
	local body = s.body
	if body:IsA("MeshPart") then
		body.TextureID = if own then s.texture else ""
	end
	for _, l in s.looks do
		l.Parent = if own then body else nil
	end
	body.Color = color
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

-- Starts the skin. Call update(car, name) every frame right after car.render, with the skin's
-- name in CarSkins, or nil for none.
function CarSkin.new()
	local enabled = true
	local shown: Shown? = nil
	local broken: { [Model]: boolean } = {} -- models missing a part: don't keep trying them every frame

	UserInputService.InputBegan:Connect(function(input: InputObject, typing: boolean)
		if not typing and input.KeyCode == Enum.KeyCode.B then
			enabled = not enabled
		end
	end)

	local self = {}

	function self.update(car: RCCar.Car, name: string?)
		local want = name ~= nil and enabled and car.body.Parent ~= nil
		local cur = shown
		if
			cur and (not want or cur.car ~= car or cur.name ~= name or cur.scale ~= Tuning.scale)
		then
			hide(cur)
			shown = nil
			cur = nil
		end
		if want and name and not cur then
			local src = template(name)
			if src and not broken[src] then
				shown = show(car, name, src)
				cur = shown
				if not shown then
					broken[src] = true
					warn(`CarSkin: {name} needs Body, WheelFL, WheelFR, WheelRL and WheelRR`)
				end
			end
		end
		if cur then
			cur.body.CFrame = car.body.CFrame * cur.offset
			if cur.tint ~= car.body.Color then
				paint(cur, car.body.Color)
			end
		end
	end

	return self
end

return CarSkin
