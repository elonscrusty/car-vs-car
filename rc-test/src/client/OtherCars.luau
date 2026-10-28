--!strict
-- Other players' RC cars, as this screen sees them. The server builds every car's body and each
-- player's own device drives theirs, so here the bodies already move; what is missing are the
-- wheels (each device draws only its own) and a name. This draws both, look-only: the wheels hang
-- from the body on a ray down to the ground, roll with the speed and turn with the bends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Features = require(ReplicatedStorage.Shared.Features)
local Garage = require(ReplicatedStorage.Shared.Garage)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local OtherCars = {}

-- the car's numbers at big size (Tuning holds them already shrunk to this screen's size)
local function base(key: string): number
	return (Tuning :: any)[key] / Tuning.scale
end

local FAR = 400 -- studs: past this, other cars' wheels are not drawn (phones)
-- studs: in the big race, names show this far. (It was the whole map for the stand cam; behind
-- the car the far names piled into one clump, Studio score/25.)
local RACE_TAG_FAR = 90
local STEER_MAX = 0.75 -- radians, the base car's widest wheel angle
local MAX_SUSP = 4 -- big-size spring travel; the ray stops it sooner on the ground
local TAG_W, TAG_H = 120, 26 -- a name tag's size on screen (px)

type Wheel = { part: Part, spot: Vector3, front: boolean, shown: number, spin: number }
-- Car VS Car: the toy car's shell (body, cab, roof, wing, lights) over the grey blocks, the same
-- toy car the plots show (playtest u01: every rival was a grey block). Its round wheels are
-- this file's own, which already roll and steer.
type Toy = { parts: { BasePart }, offsets: { CFrame } }
type Other = {
	body: BasePart,
	folder: Folder,
	wheels: { Wheel },
	scale: number,
	tag: BillboardGui,
	hidden: boolean?,
	toy: Toy?,
}

-- the toy car this model wears: a bot's ToyCar, a player's racer (nil = keep the grey blocks)
local function toyId(model: Model): string?
	if not Features.CVC then
		return nil
	end
	local id = model:GetAttribute("ToyCar")
	if type(id) ~= "string" then
		local uid = tonumber(string.match(model.Name, "^Car_(%d+)$"))
		local p = uid and Players:GetPlayerByUserId(uid)
		id = p and p:GetAttribute("RacerCar")
	end
	return if type(id) == "string" and CarCatalog.get(id) then id else nil
end

-- as long as the grey body it covers (Garage.toyFit: the chase camera was tuned for that size)
local TOY_SIZE = Garage.toyFit(base("bodyZ"))
local function toyShell(folder: Folder, id: string, s: number): Toy
	local info = CarCatalog.get(id) :: CarCatalog.Car
	local pieces = {}
	Garage.toyCar(
		Garage.adder(pieces),
		"Toy",
		{ x = 0, y = 0, z = 0 },
		0,
		info.color,
		TOY_SIZE * s,
		info.style
	)
	local holder = Instance.new("Model")
	local made = Garage.makeParts(pieces, holder, CFrame.identity).Toy
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, p in made:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Wheel" and p.Name ~= "Hub" then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			table.insert(offsets, p.CFrame) -- (from the ground under the middle of the car)
			table.insert(parts, p)
			p.Parent = folder
		end
	end
	holder:Destroy()
	return { parts = parts, offsets = offsets }
end

-- carter's own model for this car (ReplicatedStorage.CarSkins, named the car id): its body parts,
-- turned to drive toward -Z and sized to the grey body's length; this file's wheels stay
local function modelShell(folder: Folder, m: Model, s: number): Toy?
	local pivot, size = m:GetBoundingBox()
	if size.Z <= 0 then
		return nil
	end
	local k = base("bodyZ") * s / size.Z
	local floor = CFrame.new(0, -size.Y / 2, 0)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 5) ~= "Wheel" then
			local p = d:Clone()
			p:ClearAllChildren()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size *= k
			-- (Studio's 3D import puts the nose at +Z, like CarSkin: turned around)
			local rel = floor:Inverse() * pivot:Inverse() * d.CFrame
			table.insert(
				offsets,
				CFrame.Angles(0, math.pi, 0) * (rel - rel.Position + rel.Position * k)
			)
			table.insert(parts, p)
			p.Parent = folder
		end
	end
	return if #parts > 0 then { parts = parts, offsets = offsets } else nil
end

local function wheelPart(folder: Folder, s: number): Part
	local d = base("wheelRadius") * 2 * s
	local p = Instance.new("Part")
	p.Name = "Wheel"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(base("wheelWidth") * s, d, d)
	p.Color = Color3.fromRGB(30, 30, 33)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	-- a light stripe so the roll shows
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(p.Size.X + 0.02, d * 0.2, d * 0.7)
	stripe.Color = Color3.fromRGB(215, 215, 220)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.CastShadow = false
	stripe.Parent = p
	return p
end

local function nameTag(body: BasePart, text: string, s: number): BillboardGui
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(TAG_W, TAG_H)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * s, 0)
	tag.AlwaysOnTop = false -- (on carter's PC AlwaysOnTop tags never drew: Studio score/16-18)
	-- (far off, two tags drew over each other and read garbled, "TRORBO TIM": near cars only)
	tag.MaxDistance = 70
	tag.Adornee = body
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Text = text
	l.Parent = tag
	return tag
end

local function playerName(model: Model): string
	local bot = model:GetAttribute("BotName") -- a race bot (server's RaceBotCars)
	if type(bot) == "string" then
		-- just the name: "TURBO TIM (bot)" ran off the screen edge (phone 10-28)
		return (string.gsub(bot, "%s*%(bot%)$", ""))
	end
	local id = tonumber(string.match(model.Name, "^Car_(%-?%d+)$"))
	local p = id and Players:GetPlayerByUserId(id)
	return if p then p.DisplayName else "RC"
end

function OtherCars.new(myCarName: () -> string): { update: (dt: number) -> () }
	local folder = Instance.new("Folder")
	folder.Name = "OtherCars"
	folder.Parent = workspace
	local others: { [Model]: Other } = {}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function add(model: Model): Other?
		local body = model.PrimaryPart
		if not body then
			return nil
		end
		local s = body.Size.Z / base("bodyZ")
		local f = Instance.new("Folder")
		f.Name = model.Name
		f.Parent = folder
		local wheels: { Wheel } = {}
		for _, fz in { -1, 1 } do
			for _, sx in { -1, 1 } do
				table.insert(wheels, {
					part = wheelPart(f, s),
					spot = Vector3.new(sx * base("wheelX"), base("attachY"), fz * base("wheelZ"))
						* s,
					front = fz < 0,
					shown = MAX_SUSP * s * 0.5,
					spin = 0,
				})
			end
		end
		-- the tag lives on the car's body, like the training tag (CarTag): from PlayerGui it never
		-- showed in the Studio check
		local tag = nameTag(body, playerName(model), s)
		tag.Parent = body
		local id = toyId(model)
		local skins = ReplicatedStorage:FindFirstChild("CarSkins")
		local own = id and skins and skins:FindFirstChild(id)
		local toy = if own and own:IsA("Model") then modelShell(f, own, s) else nil
		toy = toy or if id then toyShell(f, id, s) else nil
		if toy then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				end
			end
		end
		local o = { body = body, folder = f, wheels = wheels, scale = s, tag = tag, toy = toy }
		others[model] = o
		return o
	end

	local function remove(model: Model)
		local o = others[model]
		if o then
			o.folder:Destroy()
			o.tag:Destroy()
			others[model] = nil
		end
	end

	-- every Car_<id> model in the workspace, kept as they come and go (not a GetChildren and two
	-- new tables every frame: phone fps in a full race); the ray filter changes only with it
	local cars: { [Model]: boolean } = {}
	local carsChanged = true
	local function watch(m: Instance)
		if m:IsA("Model") and string.sub(m.Name, 1, 4) == "Car_" then
			cars[m] = true
			carsChanged = true
		end
	end
	for _, m in workspace:GetChildren() do
		watch(m)
	end
	workspace.ChildAdded:Connect(watch)
	workspace.ChildRemoved:Connect(function(m)
		if cars[m :: Model] then
			cars[m :: Model] = nil
			carsChanged = true
		end
	end)

	-- this frame's shown tags, nearest first (reused: no new tables each frame)
	local tags: { BillboardGui } = {}
	local tagFar: { number } = {}
	local kept: { Vector3 } = {}
	-- Tags that would sit on top of each other on screen: only the nearest shows (Studio pr839: a
	-- bunch of cars read as one garbled line)
	local function unstack(cam: Camera)
		table.clear(kept)
		for _, tag in tags do
			local body = tag.Adornee :: BasePart
			local p, onScreen = cam:WorldToViewportPoint(body.Position + tag.StudsOffsetWorldSpace)
			if onScreen then
				for _, q in kept do
					if math.abs(p.X - q.X) < TAG_W and math.abs(p.Y - q.Y) < TAG_H then
						tag.Enabled = false
						break
					end
				end
				if tag.Enabled then
					table.insert(kept, p)
				end
			end
		end
	end

	local function update(dt: number)
		local mine = myCarName()
		local myGroup = Players.LocalPlayer:GetAttribute("RaceGroup")
		local cam = workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else Vector3.zero
		if carsChanged then
			carsChanged = false
			local skip: { Instance } = { folder }
			for m in cars do
				table.insert(skip, m)
			end
			rayParams.FilterDescendantsInstances = skip
		end
		for m in others do
			if not cars[m] or m.Name == mine or m.PrimaryPart ~= others[m].body then
				remove(m)
			end
		end
		for m in cars do
			if m.Name == mine then
				continue
			end
			local o = others[m] or add(m)
			if not o then
				continue
			end
			local body = o.body
			local cf = body.CFrame
			-- Car VS Car: another league's race on the same track at the same time: not shown
			local group = m:GetAttribute("RaceGroup")
			local hide = myGroup ~= nil and group ~= nil and group ~= myGroup
			if hide ~= (o.hidden == true) then
				o.hidden = hide
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = if hide or o.toy then 1 else 0
					end
				end
			end
			local far = (cf.Position - eye).Magnitude
			local near = not hide and far < FAR
			o.folder.Parent = if near then folder else nil
			-- carter's pick 18: in the big race every car in your race wears its name, however far
			-- (the stand cam watches from the side of the track)
			local inRace = myGroup ~= nil and group == myGroup
			o.tag.MaxDistance = if inRace then RACE_TAG_FAR else 150
			o.tag.Enabled = near or (inRace and not hide)
			if o.tag.Enabled and far < o.tag.MaxDistance then
				-- (kept nearest first)
				local k = #tags + 1
				while k > 1 and tagFar[k - 1] > far do
					tags[k], tagFar[k] = tags[k - 1], tagFar[k - 1]
					k -= 1
				end
				tags[k], tagFar[k] = o.tag, far
			end
			if not near then
				continue
			end
			local s = o.scale
			local up = cf.UpVector
			local rot = cf.Rotation
			local vel = body.AssemblyLinearVelocity
			local vLong = vel:Dot(cf.LookVector)
			local yawRate = body.AssemblyAngularVelocity:Dot(up)
			local radius = base("wheelRadius") * s
			local steer = CarMath.guessSteer(yawRate, vLong, base("wheelZ") * 2 * s, STEER_MAX)
			local reach = MAX_SUSP * s
			for _, w in o.wheels do
				local from = cf * w.spot
				local hit = workspace:Raycast(from, -up * (reach + radius), rayParams)
				local susp = if hit then math.clamp(hit.Distance - radius, 0, reach) else reach
				w.shown += (susp - w.shown) * math.min(1, 20 * dt)
				w.spin -= vLong / radius * dt
				local yaw = if w.front then -steer else 0
				local wcf = CFrame.new(from - up * w.shown)
					* rot
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(w.spin, 0, 0)
				w.part.CFrame = wcf
				local stripe = w.part:FindFirstChild("Stripe") :: Part?
				if stripe then
					stripe.CFrame = wcf
				end
			end
			local toy = o.toy
			if toy then
				-- the shell sits on the wheels: its ground is where they touch, on average
				local hang = 0
				for _, w in o.wheels do
					hang += w.shown / #o.wheels
				end
				local ground = cf * CFrame.new(0, base("attachY") * s - hang - radius, 0)
				local at: { CFrame } = table.create(#toy.parts)
				for k, off in toy.offsets do
					at[k] = ground * off
				end
				workspace:BulkMoveTo(toy.parts, at, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
		if cam then
			unstack(cam)
		end
		table.clear(tags)
	end

	return { update = update }
end

return OtherCars
