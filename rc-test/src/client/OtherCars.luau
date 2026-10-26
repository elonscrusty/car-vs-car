--!strict
-- Other players' RC cars, as this screen sees them. The server builds every car's body and each
-- player's own device drives theirs, so here the bodies already move; what is missing are the
-- wheels (each device draws only its own) and a name. This draws both, look-only: the wheels hang
-- from the body on a ray down to the ground, roll with the speed and turn with the bends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local OtherCars = {}

-- the car's numbers at big size (Tuning holds them already shrunk to this screen's size)
local function base(key: string): number
	return (Tuning :: any)[key] / Tuning.scale
end

local FAR = 400 -- studs: past this, other cars' wheels are not drawn (phones)
local STEER_MAX = 0.75 -- radians, the base car's widest wheel angle
local MAX_SUSP = 4 -- big-size spring travel; the ray stops it sooner on the ground

type Wheel = { part: Part, spot: Vector3, front: boolean, shown: number, spin: number }
type Other = {
	body: BasePart,
	folder: Folder,
	wheels: { Wheel },
	scale: number,
	tag: BillboardGui,
	hidden: boolean?,
}

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
	tag.Size = UDim2.fromOffset(120, 26)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * s, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 150
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
		return bot
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
		-- a BillboardGui only draws reliably from PlayerGui; Adornee puts it over the car
		local tag = nameTag(body, playerName(model), s)
		tag.ResetOnSpawn = false
		tag.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or f
		local o = { body = body, folder = f, wheels = wheels, scale = s, tag = tag }
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

	local function update(dt: number)
		local mine = myCarName()
		local myGroup = Players.LocalPlayer:GetAttribute("RaceGroup")
		local cam = workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else Vector3.zero
		-- find cars: every Car_<id> model in the workspace that is not this player's
		local seen: { [Model]: boolean } = {}
		local skip: { Instance } = { folder }
		for _, m in workspace:GetChildren() do
			if m:IsA("Model") and string.sub(m.Name, 1, 4) == "Car_" then
				table.insert(skip, m)
				if m.Name ~= mine then
					seen[m] = true
				end
			end
		end
		for m in others do
			if not seen[m] or m.PrimaryPart ~= others[m].body then
				remove(m)
			end
		end
		rayParams.FilterDescendantsInstances = skip
		for m in seen do
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
						d.LocalTransparencyModifier = if hide then 1 else 0
					end
				end
			end
			local near = not hide and (cf.Position - eye).Magnitude < FAR
			o.folder.Parent = if near then folder else nil
			o.tag.Enabled = near
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
		end
	end

	return { update = update }
end

return OtherCars
