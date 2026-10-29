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
--
-- KART MODELS: the karts (carter's Kart_Carter1, Kart_Dozer, ...; ToyCars.KARTS says which car
-- shape wears which) are built in game by KartMesh; an imported copy in CarSkins wins. Their
-- MeshParts (Body, Accent, Trim, Driver, Head, Cap, Headlights, ..., the 4 wheels) are painted per
-- car by name (ToyCars.kartPaint). No weapon on the kart: an icon above it shows that (carter).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local RCCar = require(script.Parent.RCCar)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local CarFxStyles = require(ReplicatedStorage.Shared.CarFxStyles)
local ExhaustFx = require(script.Parent.ExhaustFx)
local FireDrake = require(script.Parent.FireDrake)
local Garage = require(ReplicatedStorage.Shared.Garage)
local KartMesh = require(script.Parent.KartMesh)
local ToyCars = require(ReplicatedStorage.Shared.ToyCars)
local TrailFx = require(script.Parent.TrailFx)
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
	rims: { [BasePart]: { wheel: BasePart, rel: CFrame } }, -- an imported kart's RimFL..: they turn with their wheel
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

-- "kart:<car id>": the car's Blender kart model (ToyCars.KARTS) painted in the car's colours
CarSkin.KART = "kart:"

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The kart model a car wears, if it is in CarSkins.
-- A bright stripe down an imported kart's middle (auditor round 12: two-tone trim, a stripe in the
-- palette). The meshes live only in the saved place, so it's laid on at run time: cast down on a
-- hidden copy of the body at a few spots along it and put a thin Stripe part between each pair of
-- flat hits (ToyCars.kartPaint paints it the car's accent). Only on the front half, the hood: the
-- rays hit the body's rough collision shape, which over an open cockpit is a lid, not the seat.
-- Once per model, on this device's copy; the hot-rod and monster have their own stripes (Accent).
local STRIPE_SPOTS = 9
local STRIPE_MIN = 4 -- segments in a row (of 8)
local function addStripe(m: Model)
	if m:GetAttribute("Striped") ~= nil then
		return
	end
	m:SetAttribute("Striped", false)
	if m:FindFirstChild("Accent", true) then
		return
	end
	local body = m:FindFirstChild("Body", true)
	if not (body and body:IsA("BasePart")) or body:GetAttribute("Baked") == true then
		return
	end
	if body:IsA("MeshPart") and body.CollisionFidelity == Enum.CollisionFidelity.Box then
		return -- (a box: every ray would hit its flat top)
	end
	local cf, size = body.CFrame, body.Size
	if math.abs(cf.UpVector.Y) < 0.99 then
		return -- (a tilted body: its own axes aren't the kart's)
	end
	-- which way the body's own Z runs to the nose (an import's is at the model's +Z, noseAtPlusZ)
	local look = m:GetPivot().LookVector -- (the model's -Z)
	local nose = if CarSkin.noseAtPlusZ(m) then -look else look
	local along = if cf:VectorToObjectSpace(nose).Z >= 0 then 1 else -1
	local probe = body:Clone()
	probe:ClearAllChildren()
	probe.Anchored, probe.CanCollide, probe.CanTouch, probe.CanQuery = true, false, false, true
	probe.Transparency = 1
	probe.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local hits: { RaycastResult? } = {}
	pcall(function()
		for i = 0, STRIPE_SPOTS - 1 do
			local z = along * (0.05 + 0.4 * i / (STRIPE_SPOTS - 1)) * size.Z
			local hit =
				workspace:Raycast(cf * Vector3.new(0, size.Y, z), cf.UpVector * -size.Y * 2, params)
			hits[i + 1] = if hit and hit.Normal:Dot(cf.UpVector) > 0.75 then hit else nil
		end
	end)
	probe:Destroy()
	-- the longest run of flat hits in a row: a stripe shorter than half the hood reads as a patch
	-- (Studio #997: the formula's and the dozer's 2-part bits at the nose), so none then
	local best, bestFrom, run = 0, 1, 0
	for i = 1, STRIPE_SPOTS - 1 do
		local a, b = hits[i], hits[i + 1]
		if a and b and math.abs(cf.UpVector:Dot(b.Position - a.Position)) < size.Y * 0.25 then
			run += 1
			if run > best then
				best, bestFrom = run, i - run + 1
			end
		else
			run = 0
		end
	end
	if best < STRIPE_MIN then
		return
	end
	local width, lift = size.X * 0.2, 0.045 * size.Y
	local made = 0
	for i = bestFrom, bestFrom + best - 1 do
		local a, b = hits[i] :: RaycastResult, hits[i + 1] :: RaycastResult
		local up = (a.Normal + b.Normal).Unit
		local from, to = a.Position + up * lift, b.Position + up * lift
		local p = Instance.new("Part")
		p.Name = "Stripe"
		p.Size = Vector3.new(width, 0.05 * size.Y, (to - from).Magnitude + 0.02)
		p.CFrame = CFrame.lookAt((from + to) / 2, to, up)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = body.Parent
		made += 1
	end
	m:SetAttribute("Striped", made > 0)
end

-- The kart model a car wears: an imported one in CarSkins, else the one built in game (KartMesh;
-- nil while it builds or on a device that can't).
function CarSkin.kartFor(id: string): Model?
	local info = CarCatalog.get(id)
	if not info then
		return nil
	end
	local name = ToyCars.kartModel(info.style)
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local m = skins and skins:FindFirstChild(name)
	if m and m:IsA("Model") then
		pcall(addStripe, m) -- (no stripe is fine: never a kart that fails to show)
		return m
	end
	return KartMesh.get(name, ToyCars.kartRim(info.color, info.style))
end

-- Paints a kart model's part for a car, by its name (ToyCars.kartPaint).
function CarSkin.paintKart(p: BasePart, id: string)
	local info = CarCatalog.get(id)
	if not info then
		return
	end
	local col, glow = ToyCars.kartPaint(p.Name, info.color, info.style)
	if p:GetAttribute("RimTint") == true then
		-- a baked kart's wheel (assets/karts/studio_bake.luau): dark tyre, white rim; the part's
		-- colour tints the rim to the car's rim colour
		p.Color = rgb(ToyCars.kartRim(info.color, info.style))
		return
	end
	if col and p:GetAttribute("Baked") ~= true then
		p.Color = rgb(col)
		p.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if p.Name == "Body" then
			p.Reflectance = 0.08 -- (a little shine on the paint: auditor round 12)
		end
		if p:IsA("MeshPart") then
			p.TextureID = ""
		end
	end
end

-- The look a car wears: carter's own model (CarSkins, named the car id), else its kart model,
-- else the toy car.
function CarSkin.lookFor(id: string): string
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local own = skins and skins:FindFirstChild(id)
	if own and own:IsA("Model") then
		return id
	end
	return if CarSkin.kartFor(id) then CarSkin.KART .. id else CarSkin.TOY .. id
end

-- A kart model's nose is where its headlights are: true when that is at +Z (Studio's import).
function CarSkin.noseAtPlusZ(m: Model): boolean
	local lights = m:FindFirstChild("Headlights", true)
	if not (lights and lights:IsA("BasePart")) then
		return true
	end
	return m:GetPivot():PointToObjectSpace(lights.Position).Z > 0
end

local function kart(id: string): Model?
	local src = CarSkin.kartFor(id)
	if not src then
		return nil
	end
	local car = src:Clone()
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			CarSkin.paintKart(d, id)
		elseif d:IsA("SurfaceAppearance") then
			d:Destroy() -- (an import's own look would hide the paint)
		end
	end
	-- (show turns the nose from +Z to -Z: a model already facing -Z is turned round first)
	if not CarSkin.noseAtPlusZ(car) then
		car:PivotTo(car:GetPivot() * CFrame.Angles(0, math.pi, 0))
	end
	car:SetAttribute("Extras", true)
	car:SetAttribute("Kart", true)
	return car
end

-- A model from CarSkins, ready to wear: the Fire Drake's heads are added to the cars that have them.
function CarSkin.prepare(m: Model)
	if FireDrake.wants(m.Name) then
		pcall(FireDrake.addTo, m) -- (no heads is fine: never a car that fails to show)
	end
end

local function template(name: string): Model?
	if string.sub(name, 1, #CarSkin.KART) == CarSkin.KART then
		local made = toys[name] or kart(string.sub(name, #CarSkin.KART + 1))
		if made then
			toys[name] = made
		end
		return made
	end
	if string.sub(name, 1, #CarSkin.TOY) == CarSkin.TOY then
		local made = toys[name] or toy(string.sub(name, #CarSkin.TOY + 1))
		if made then
			toys[name] = made
		end
		return made
	end
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local m = skins and skins:FindFirstChild(name)
	if m and m:IsA("Model") then
		CarSkin.prepare(m)
		return m
	end
	return nil
end

local function lookOnly(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
end

-- A fresh copy of the look a car wears (its own model, else its kart, else the toy car), every
-- part anchored and look-only (a kart's nose at +Z): for a picture (the round's winner). nil: no such car.
function CarSkin.copyOf(id: string): Model?
	local src = template(CarSkin.lookFor(id))
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			lookOnly(d)
		end
	end
	return m
end

-- A car's real look for a still spot (the garage showroom, a picture) in place of its toy: its kart
-- or carter's own model, `long` studs nose to tail, nose to -Z and pivot at its bottom middle like
-- the toy. nil when the car only has the toy look (the caller keeps its toy).
function CarSkin.standIn(id: string, long: number): Model?
	if string.sub(CarSkin.lookFor(id), 1, #CarSkin.TOY) == CarSkin.TOY then
		return nil
	end
	local m = CarSkin.copyOf(id)
	if not m then
		return nil
	end
	local _, size = m:GetBoundingBox()
	if size.Z <= 0 then
		m:Destroy()
		return nil
	end
	m:ScaleTo(m:GetScale() * long / size.Z)
	local cf
	cf, size = m:GetBoundingBox()
	-- (every look's nose is at +Z, see show: the pivot turned round puts it at -Z)
	m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
		* CFrame.Angles(0, math.pi, 0)
	m.Name = id
	return m
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
	if copy:GetAttribute("Extras") == true and copy:GetAttribute("Kart") ~= true then
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
	local rims: { [BasePart]: { wheel: BasePart, rel: CFrame } } = {}
	if copy:GetAttribute("Extras") == true then
		local keep: { [Instance]: boolean } = { [body] = true }
		for i, w in wheels do
			keep[w] = true
			-- (a kart imported in Studio has its rims apart from its tyres: RimFL rides on WheelFL)
			local rim = copy:FindFirstChild("Rim" .. string.sub(WHEEL_NAMES[i], 6), true)
			if rim and rim:IsA("BasePart") then
				keep[rim] = true
				rims[rim] = { wheel = w, rel = w.CFrame:ToObjectSpace(rim.CFrame) }
				rim.Parent = folder
			end
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
	-- (a model's MaxTurn attribute: its front wheels are drawn turned no further, to stay in the fenders)
	local maxTurn = src:GetAttribute("MaxTurn")
	car.setLook({
		wheels = wheels,
		spots = spots,
		turns = turns,
		maxTurn = if type(maxTurn) == "number" then maxTurn else nil,
	})
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
		rims = rims,
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

-- The look the player picked for their flames / wheel trails (a Player attribute the loadout sets;
-- nil gives the starter).
local function styleOf(attr: string): string?
	local v = Players.LocalPlayer:GetAttribute(attr)
	return if typeof(v) == "string" then v else nil
end

-- Starts the skin. Call update(car, name) every frame right after car.render, with the skin's
-- name in CarSkins, or nil for none.
function CarSkin.new()
	local enabled = true
	local shown: Shown? = nil
	local broken: { [Model]: boolean } = {} -- models missing a part: don't keep trying them every frame
	local exhaust = ExhaustFx.new() -- the tailpipe flames while it boosts (the player's pick)
	local trails = TrailFx.new() -- the sparks off the rear tyres

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
			for p, r in cur.rims do
				p.CFrame = r.wheel.CFrame * r.rel
			end
			if cur.tint ~= car.body.Color then
				paint(cur, car.body.Color)
			end
		end
		exhaust.step(
			if cur then cur.body else nil,
			cur ~= nil and car.telemetry.boost > 0,
			styleOf(CarFxStyles.ATTR_EXHAUST)
		)
		trails.step(if cur then car else nil, styleOf(CarFxStyles.ATTR_TRAIL))
	end

	return self
end

return CarSkin
