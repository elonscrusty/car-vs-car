--!strict
-- A look-only skin for the RC car: a real car model drawn over the grey blocks (the truck on the
-- rock track, the coupe on the drift track). The grey body still does all the driving; the skin just follows it every frame, and
-- its wheels ride the same springs. B turns the skin off and on to compare.
--
-- Each skin is a Model in ReplicatedStorage.CarSkins (RockCrawler, DriftCoupe, ...), with MeshParts
-- named Body, WheelFL, WheelFR, WheelRL and WheelRR. Studio's 3D import puts the nose at +Z, and
-- the car drives toward -Z, so the copy is turned around before use.
--
-- HOW TO ADD A CAR MODEL: name the Model the car's id from CarCatalog (e.g. race_bolt), give it
-- MeshParts Body, WheelFL, WheelFR, WheelRL, WheelRR, and drop it in ReplicatedStorage.CarSkins.
-- It then replaces that car's toy look in races, for your own car and everyone else's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RCCar = require(script.Parent.RCCar)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Garage = require(ReplicatedStorage.Shared.Garage)
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
	extras: { [BasePart]: CFrame }, -- a toy car's cab, roof, wing and lights, seen from its body
}

-- "toy:<car id>": the same toy car the plot shows for that car (Garage.toyCar: its colour and
-- style, round wheels), for a car with no Meshy model of its own (playtest u01: the grey box).
CarSkin.TOY = "toy:"
local toys: { [string]: Model } = {}
local function toy(id: string): Model?
	local info = CarCatalog.get(id)
	if not info then
		return nil
	end
	local pieces = {}
	-- nose to +Z, like a Meshy import (show turns it round)
	Garage.toyCar(
		Garage.adder(pieces),
		"Car",
		{ x = 0, y = 0, z = 0 },
		180,
		info.color,
		1,
		info.style
	)
	local holder = Instance.new("Model")
	local car = Garage.makeParts(pieces, holder, CFrame.identity).Car
	car.Parent = nil
	holder:Destroy()
	for _, p in car:GetChildren() do
		if p.Name == "Hub" then
			p:Destroy() -- (it would not spin or steer with its wheel)
		elseif p.Name == "Wheel" and p:IsA("BasePart") then
			-- front = +Z here; the car's right (+X once turned round) = -X here
			local front, right = p.Position.Z > 0, p.Position.X < 0
			p.Name = "Wheel" .. (if front then "F" else "R") .. (if right then "R" else "L")
		end
	end
	car:SetAttribute("Extras", true)
	return car
end

local function template(name: string): Model?
	if string.sub(name, 1, #CarSkin.TOY) == CarSkin.TOY then
		local made = toys[name] or toy(string.sub(name, #CarSkin.TOY + 1))
		if made then
			toys[name] = made
		end
		return made
	end
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
	if copy:GetAttribute("Extras") == true then
		-- a toy car: as long as the grey body it covers (built at s = 1, Garage.toyFit)
		copy:ScaleTo(copy:GetScale() * Garage.toyFit(Tuning.bodyZ))
	else
		copy:ScaleTo(copy:GetScale() * Tuning.wheelRadius / meshRadius)
	end

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
	-- a toy car's other parts ride on its body (a Meshy model's are dropped, as before)
	local extras: { [BasePart]: CFrame } = {}
	if copy:GetAttribute("Extras") == true then
		local keep: { [Instance]: boolean } = { [body] = true }
		for _, w in wheels do
			keep[w] = true
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") and not keep[d] then
				extras[d] = body.CFrame:ToObjectSpace(d.CFrame)
				d.Parent = folder
			end
		end
	end
	copy:Destroy()
	folder.Parent = workspace

	local hidden: { [BasePart]: number } = {}
	for _, d in car.model:GetDescendants() do
		-- (a kart topper the server welds on, Model "Hat", stays shown on the skin's roof)
		if d:IsA("BasePart") and not d:FindFirstAncestor("Hat") then
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
		extras = extras,
	}
end

-- Paints the skin's body (not its wheels) the colour of the shop car. carter's Meshy cars always
-- keep their own painted texture, so only a skin with no texture of its own is tinted.
local function paint(s: Shown, color: Color3)
	s.tint = color
	local own = color == NO_PICK or s.texture ~= "" or #s.looks > 0
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
			for p, rel in cur.extras do
				p.CFrame = cur.body.CFrame * rel
			end
			if cur.tint ~= car.body.Color then
				paint(cur, car.body.Color)
			end
		end
	end

	return self
end

return CarSkin
