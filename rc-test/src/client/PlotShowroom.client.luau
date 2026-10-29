--!strict
-- Car VS Car SMASH garages come alive (PlotShowroom has the layout, PlotGarageBuilder builds the
-- floor, the stands and the crate): the kart you play with turns slowly on the turntable, the
-- others wait on their stands. On your own plot, walk up to a kart: PICK THIS KART (Garage
-- remote "racer"); walk up to the crate: OPEN CRATE (the crate window, CvcCrateShop, shows the
-- odds first). Your karts come from CvcState; anyone else's from their plot's Garage and
-- RacerCar attributes. Looks only, on this screen: nothing here is solid. Far plots stop turning
-- to save the phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
if not (Features.CVC and Features.SMASH) then
	return
end

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotShowroom = require(ReplicatedStorage.Shared.PlotShowroom)
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CarSkin = require(script.Parent:WaitForChild("CarSkin"))

CvcState.start()

local me = Players.LocalPlayer
local glowModule = ReplicatedStorage.Shared:FindFirstChild("CarGlow")
local CarGlow: any = if glowModule and glowModule:IsA("ModuleScript")
	then require(glowModule) :: any
	else nil

type Shown = {
	plot: Instance,
	pivot: CFrame,
	folder: Folder,
	key: string,
	spinner: Model?,
	angle: number,
	glow: { BasePart }, -- the turntable's glow ring (it pulses)
	bulbs: { PointLight }, -- the lamp bulbs' soft lights (they chase round the ring)
}

local shown: { [Instance]: Shown } = {}

local function mine(plot: Instance): boolean
	return tonumber(plot:GetAttribute("OwnerId")) == me.UserId
end

-- the hook into the crate window (whichever side starts first makes it)
local function crateEvent(): BindableEvent
	local e = ReplicatedStorage:FindFirstChild("CvcCrateShop")
	if e and e:IsA("BindableEvent") then
		return e
	end
	local made = Instance.new("BindableEvent")
	made.Name = "CvcCrateShop"
	made.Parent = ReplicatedStorage
	return made
end

-- one kart, nose to -z around its bottom middle: its real kart (CarSkins) as long as the toy, else
-- the toy
local function makeCar(id: string, parent: Instance, scale: number): Model?
	local info = CarCatalog.get(id) :: any
	if not info then
		return nil
	end
	local pieces = {}
	Garage.toyCar(
		Garage.adder(pieces),
		"Car",
		{ x = 0, y = 0, z = 0 },
		0,
		info.color,
		scale,
		info.style
	)
	local holder = Instance.new("Model")
	local groups = Garage.makeParts(pieces, holder, CFrame.identity)
	local model = groups.Car
	model.Name = id
	model.WorldPivot = CFrame.identity
	local _, toySize = model:GetBoundingBox()
	local ok, real = pcall(CarSkin.standIn, id, toySize.Z)
	if ok and real then
		model = real -- (the toy goes with its holder below)
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	if CarGlow and type(CarGlow.apply) == "function" then
		pcall(CarGlow.apply, model, info.rarity)
	end
	model.Parent = parent
	holder:Destroy()
	return model
end

-- an invisible spot to hang a walk-up prompt on
local function prompt(
	s: Shown,
	at: Garage.V3,
	action: string,
	object: string,
	range: number,
	go: () -> ()
)
	local spot = Instance.new("Part")
	spot.Name = "PromptSpot"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = s.pivot * CFrame.new(at.x, at.y, at.z)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Pick"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = range
	p.RequiresLineOfSight = false
	p.Parent = spot
	p.Triggered:Connect(go)
	spot.Parent = s.folder
end

local function carName(id: string): string
	local info = CarCatalog.get(id) :: any
	return string.upper(if info then info.name else id)
end

-- the karts to show: (yours, from CvcState) or (anyone's, from the plot's attributes)
local function cars(plot: Instance): ({ PlotShowroom.Entry }, string?)
	local list: { PlotShowroom.Entry } = {}
	if (tonumber(plot:GetAttribute("OwnerId")) or 0) == 0 then
		return list, nil
	end
	if mine(plot) and CvcState.loaded then
		for _, c in CvcState.garage do
			table.insert(list, { id = c.id, uid = c.uid })
		end
		return list, CvcState.racer
	end
	for _, id in string.split(tostring(plot:GetAttribute("Garage") or ""), ",") do
		if id ~= "" then
			table.insert(list, { id = id })
		end
	end
	local racer = plot:GetAttribute("RacerCar")
	return list, if type(racer) == "string" then racer else nil
end

local function refresh(s: Shown)
	local room = s.plot:FindFirstChild("Showroom")
	local list, racer = cars(s.plot)
	local top, rest = PlotShowroom.order(list, racer)
	local stands = if room then tonumber(room:GetAttribute("Stands")) or 0 else 0
	local own = mine(s.plot)
	local bits = { tostring(own), tostring(stands), if top then top.uid or top.id else "" }
	for _, e in rest do
		table.insert(bits, e.uid or e.id)
	end
	local key = table.concat(bits, ",")
	if key == s.key then
		return
	end
	s.key = key
	s.folder:ClearAllChildren()
	s.spinner = nil
	if not room then
		return
	end
	local T = PlotShowroom.TURNTABLE
	if top then
		s.spinner = makeCar(top.id, s.folder, PlotShowroom.TURNTABLE.car)
		if s.spinner then
			s.spinner:PivotTo(
				s.pivot * CFrame.new(T.x, T.top, T.z) * CFrame.Angles(0, math.rad(s.angle), 0)
			)
		end
	end
	local S = PlotShowroom.STAND
	for i = 1, math.min(#rest, stands) do
		local e = rest[i]
		local p = PlotShowroom.SPOTS[i]
		local car = makeCar(e.id, s.folder, S.car)
		if car then
			car:PivotTo(
				s.pivot * CFrame.new(p.x, S.top, p.z) * CFrame.Angles(0, math.rad(p.yaw), 0)
			)
		end
		local uid = e.uid
		if own and uid then
			prompt(
				s,
				PlotShowroom.standPrompt(i),
				"PICK THIS KART",
				carName(e.id),
				PlotShowroom.PICK_RANGE,
				function()
					CvcState.ask("racer", uid)
				end
			)
		end
	end
	if own and top then
		-- the turntable opens the kart window (WINDOWS makes ReplicatedStorage.OpenCustomize)
		prompt(
			s,
			PlotShowroom.turntablePrompt(),
			"CUSTOMIZE",
			carName(top.id),
			PlotShowroom.TABLE_RANGE,
			function()
				local open = ReplicatedStorage:FindFirstChild("OpenCustomize")
				if open and open:IsA("BindableEvent") then
					open:Fire()
				end
			end
		)
	end
	if own then
		prompt(
			s,
			PlotShowroom.cratePrompt(),
			"OPEN CRATE",
			"CRATES",
			PlotShowroom.CRATE_RANGE,
			function()
				crateEvent():Fire()
			end
		)
	end
end

local function watch(plot: Instance)
	local room: Instance? = nil
	local s: Shown = {
		plot = plot,
		pivot = CFrame.identity,
		folder = Instance.new("Folder"),
		key = "",
		spinner = nil,
		angle = 0,
		glow = {},
		bulbs = {},
	}
	s.folder.Name = "ShowroomKarts_" .. plot.Name
	s.folder.Parent = workspace
	shown[plot] = s
	local function find()
		room = plot:FindFirstChild("Showroom")
		s.glow, s.bulbs = {}, {}
		if room and room:IsA("Model") then
			s.pivot = room.WorldPivot
			for _, d in room:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "TableGlow" then
					table.insert(s.glow, d)
				elseif d:IsA("PointLight") and d.Parent and d.Parent.Name == "LampBulb" then
					table.insert(s.bulbs, d)
				end
			end
			-- (in order round the ring, so the chase runs round it)
			local function turn(l: PointLight): number
				local b = l.Parent :: BasePart
				local at = s.pivot:PointToObjectSpace(b.Position)
				return math.atan2(at.X, at.Z - PlotShowroom.TURNTABLE.z)
			end
			table.sort(s.bulbs, function(a: PointLight, b: PointLight): boolean
				return turn(a) < turn(b)
			end)
		end
		s.key = ""
		refresh(s)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Showroom" then
			task.defer(find)
		end
	end)
	plot.ChildRemoved:Connect(function(child)
		if child.Name == "Showroom" then
			task.defer(find)
		end
	end)
	for _, name in { "OwnerId", "Garage", "RacerCar" } do
		plot:GetAttributeChangedSignal(name):Connect(function()
			refresh(s)
		end)
	end
	find()
end

local plots = workspace:WaitForChild("Plots")
for _, plot in plots:GetChildren() do
	watch(plot)
end
plots.ChildAdded:Connect(watch)

CvcState.changed:Connect(function()
	for plot, s in shown do
		if mine(plot) then
			refresh(s)
		end
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local T = PlotShowroom.TURNTABLE
	for _, s in shown do
		local car = s.spinner
		if car and car.Parent then
			s.angle = (s.angle + T.spin * dt) % 360
			local at = s.pivot * CFrame.new(T.x, T.top, T.z)
			if (at.Position - eye).Magnitude < PlotShowroom.NEAR then
				car:PivotTo(at * CFrame.Angles(0, math.rad(s.angle), 0))
			end
		end
		-- the glow ring breathes and the lamp bulbs chase round it (near plots only)
		if #s.glow + #s.bulbs > 0 then
			local mid = s.pivot * CFrame.new(T.x, T.top, T.z)
			if (mid.Position - eye).Magnitude < PlotShowroom.NEAR then
				local t = os.clock()
				for _, g in s.glow do
					g.Transparency = 0.2 + 0.2 * math.sin(t * 2.5)
				end
				for i, b in s.bulbs do
					b.Brightness = 0.6 + 0.5 * math.sin(t * 4 - i * math.pi / 4)
				end
			end
		end
	end
end)
