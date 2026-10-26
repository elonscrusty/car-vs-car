--!strict
-- The garage yards come alive (PlotGarage has the layout, PlotGarageBuilder builds the road):
-- each plot's parked cars (its "Parked" attribute) drive round the little loop, one spot each,
-- in their own colour and style with their kind's glow (CarGlow, when it's in); spots the level
-- has room for but nobody fills ride round as a faint "?" pad. Each car's name and kind
-- (COMMON, RARE, ...) ride above it. The coins
-- waiting in the plot ("PlotCoins") lie in a heap on the pile pad with the number over it, and
-- the heap grows as they come in. On your own plot, tap the pile (or walk onto it) to collect
-- and tap the sign to buy the next level (RemoteEvent Plot: "collect" / "level").
-- Looks only, on this screen: nothing here is solid. Far plots stop moving to save the phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Features = require(ReplicatedStorage.Shared.Features)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)
local Tycoon = require(ReplicatedStorage.Shared.Tycoon)

local me = Players.LocalPlayer
local glowModule = ReplicatedStorage.Shared:FindFirstChild("CarGlow")
local CarGlow: any = if glowModule and glowModule:IsA("ModuleScript")
	then require(glowModule) :: any
	else nil

local NEAR = 220 -- studs: plots farther from the camera than this stop moving
local COIN = Color3.fromRGB(255, 200, 50)
local COIN_EDGE = Color3.fromRGB(214, 150, 30)

type Yard = {
	plot: Instance,
	garage: Model,
	pivot: CFrame,
	folder: Folder,
	cars: { Model },
	entering: { [Model]: number },
	spread: number, -- the gap between cars, in spots: eases to #cars so they slide apart, not jump -- cars rolling out of the door (os.clock they started)
	ids: { string }, -- the parked cars' ids (the first #ids of `cars`; the rest are open spots)
	carsKey: string,
	coins: Folder,
	shown: number, -- coins drawn in the heap now
	count: TextLabel,
	zone: BasePart,
}

local yards: { [Instance]: Yard } = {}

local function remote(): RemoteEvent?
	local e = ReplicatedStorage:FindFirstChild("Plot")
	return if e and e:IsA("RemoteEvent") then e else nil
end

local function mine(plot: Instance): boolean
	return tonumber(plot:GetAttribute("OwnerId")) == me.UserId
end

local function level(plot: Instance): number
	if (tonumber(plot:GetAttribute("OwnerId")) or 0) == 0 then
		return 0
	end
	return math.clamp(
		math.floor(tonumber(plot:GetAttribute("PlotLevel")) or 0),
		0,
		PlotGarage.MAX_LEVEL
	)
end

-- the car ids that drive here: the owner's parked list, as many as the level has spots for
local function parked(plot: Instance): { string }
	local out: { string } = {}
	if (tonumber(plot:GetAttribute("OwnerId")) or 0) == 0 then
		return out
	end
	local max = PlotGarage.slots(level(plot))
	for _, id in string.split(tostring(plot:GetAttribute("Parked") or ""), ",") do
		if id ~= "" and CarCatalog.get(id) and #out < max then
			table.insert(out, id)
		end
	end
	return out
end

-- one toy car, nose to -z around its own middle (PivotTo puts it on the loop)
local function makeCar(id: string, parent: Instance): Model
	local car = CarCatalog.get(id) :: any
	local pieces = {}
	Garage.toyCar(
		Garage.adder(pieces),
		"Car",
		{ x = 0, y = 0, z = 0 },
		0,
		car.color,
		PlotGarage.CAR,
		car.style
	)
	local holder = Instance.new("Model")
	local groups = Garage.makeParts(pieces, holder, CFrame.identity)
	local model = groups.Car
	model.Name = id
	model.WorldPivot = CFrame.identity
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
		end
	end
	if CarGlow and type(CarGlow.apply) == "function" then
		pcall(CarGlow.apply, model, car.rarity)
	end
	-- its name and kind ride above it (only from close up, so the yard doesn't fill with words)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		local kind = CarCatalog.rarity(id)
		local tag = Instance.new("BillboardGui")
		tag.Name = "CarTag"
		tag.Size = UDim2.fromOffset(150, 44)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		tag.Parent = body
		local function line(text: string, y: number, h: number, color: Color3)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0, y)
			l.Size = UDim2.fromScale(1, h)
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = color
			l.TextStrokeTransparency = 0.2
			l.Text = text
			l.Parent = tag
		end
		line(string.upper(car.name), 0, 0.56, Color3.new(1, 1, 1))
		local c = kind.color
		line(kind.label, 0.58, 0.42, Color3.fromRGB(c[1], c[2], c[3]))
	end
	model.Parent = parent
	holder:Destroy()
	return model
end

local ROLL_SECS = 2.5 -- a newly parked car rolls out of the garage door to its spot this long

local function placeCars(y: Yard, clock: number)
	local n = y.spread
	local now = os.clock()
	for i, car in y.cars do
		local x, z, yaw = PlotGarage.spot(i, n, clock)
		local spot = y.pivot * CFrame.new(x, 0.1, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local since = y.entering[car]
		if since then
			local a = (now - since) / ROLL_SECS
			if a >= 1 then
				y.entering[car] = nil
			else
				-- out of the door nose first (+z), then on to its spot
				local D = PlotGarage.DOOR
				local door = y.pivot * CFrame.new(D.x, 0.1, D.z) * CFrame.Angles(0, math.pi, 0)
				local e = 1 - (1 - a) * (1 - a)
				spot = door:Lerp(spot, e)
			end
		end
		car:PivotTo(spot)
	end
end

-- an open spot on the loop (the level has room, no car parked there yet): a faint pad with a "?"
-- riding round with the cars, so you can see there's room for one more
local function makeOpen(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "OpenSpot"
	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = Vector3.new(2.6, 0.06, 4)
	pad.Color = Color3.new(1, 1, 1)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Transparency = 0.55
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = false
	pad.CastShadow = false
	pad.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = pad
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.TextScaled = true
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.TextStrokeTransparency = 0.3
	mark.Text = "?"
	mark.Parent = gui
	model.PrimaryPart = pad
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end

local function refreshCars(y: Yard)
	local list = parked(y.plot)
	local owned = (tonumber(y.plot:GetAttribute("OwnerId")) or 0) ~= 0
	local open = if owned then math.max(0, PlotGarage.slots(level(y.plot)) - #list) else 0
	local key = table.concat(list, ",") .. "+" .. open
	if key == y.carsKey then
		return
	end
	-- cars just parked (not on the first look at this yard) roll out of the garage door
	local roll = y.carsKey ~= "?"
	local had: { [string]: boolean } = {}
	for _, id in y.ids do
		had[id] = true
	end
	y.carsKey = key
	for _, c in y.cars do
		c:Destroy()
	end
	y.cars = {}
	y.entering = {}
	y.ids = list
	for _, id in list do
		local car = makeCar(id, y.folder)
		table.insert(y.cars, car)
		if roll and not had[id] then
			y.entering[car] = os.clock()
		end
	end
	for _ = 1, open do
		table.insert(y.cars, makeOpen(y.folder))
	end
	if y.spread == 0 then
		y.spread = #y.cars
	end
	placeCars(y, workspace:GetServerTimeNow())
end

local function refreshCoins(y: Yard)
	local coins = if (tonumber(y.plot:GetAttribute("OwnerId")) or 0) == 0
		then 0
		else math.floor(tonumber(y.plot:GetAttribute("PlotCoins")) or 0)
	y.count.Text = if coins > 0 then tostring(coins) else ""
	y.count.Parent.Enabled = coins > 0
	local want = PlotGarage.pileCoins(coins)
	if want == y.shown then
		return
	end
	y.coins:ClearAllChildren()
	for k = 1, want do
		local x, h, z, tilt = PlotGarage.coinSpot(k)
		local c = Instance.new("Part")
		c.Name = "Coin"
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.35, 2, 2)
		c.Color = if k % 3 == 0 then COIN_EDGE else COIN
		c.Material = Enum.Material.SmoothPlastic
		c.Reflectance = 0.15
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		-- a cylinder lies along x: turn it up so it lies flat, then tip it a little
		c.CFrame = y.pivot
			* CFrame.new(x, h + 0.3, z)
			* CFrame.Angles(0, math.rad(k * 47), 0)
			* CFrame.Angles(math.rad(tilt), 0, math.rad(90))
		c.Parent = y.coins
	end
	y.shown = want
end

local lastAsk = 0
local function ask(kind: string)
	local now = os.clock()
	if now - lastAsk < 0.6 then
		return
	end
	lastAsk = now
	local e = remote()
	if e then
		e:FireServer(kind)
	end
end

local function setUp(plot: Instance, garage: Model)
	local old = yards[plot]
	if old then
		old.folder:Destroy()
	end
	local pivot = garage.WorldPivot
	local folder = Instance.new("Folder")
	folder.Name = "GarageLive"
	folder.Parent = plot
	local coins = Instance.new("Folder")
	coins.Name = "Coins"
	coins.Parent = folder

	-- the tap / step zone over the pile (invisible), with the coin count above it
	local P = PlotGarage.PILE
	local zone = Instance.new("Part")
	zone.Name = "PileZone"
	zone.Size = Vector3.new(P.r * 2 + 1, 4, P.r * 2 + 1)
	zone.CFrame = pivot * CFrame.new(P.x, 2, P.z)
	zone.Transparency = 1
	zone.Anchored = true
	zone.CanCollide = false
	zone.CastShadow = false
	zone.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Name = "Count"
	gui.Size = UDim2.fromScale(4.5, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = zone
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Size = UDim2.fromScale(1, 1)
	count.Font = Enum.Font.GothamBlack
	count.TextScaled = true
	count.TextColor3 = COIN
	count.TextStrokeTransparency = 0
	count.Parent = gui

	local y: Yard = {
		plot = plot,
		garage = garage,
		pivot = pivot,
		folder = folder,
		cars = {},
		ids = {},
		entering = {},
		spread = 0,
		carsKey = "?",
		coins = coins,
		shown = -1,
		count = count,
		zone = zone,
	}
	yards[plot] = y

	-- your own plot: tap or walk onto the pile to collect, tap the sign to level up
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 60
	click.Parent = zone
	click.MouseClick:Connect(function()
		if mine(plot) then
			ask("collect")
		end
	end)
	zone.Touched:Connect(function(hit)
		local char = me.Character
		if
			char
			and hit:IsDescendantOf(char)
			and mine(plot)
			and (tonumber(plot:GetAttribute("PlotCoins")) or 0) >= 1
		then
			ask("collect")
		end
	end)
	local sign = garage:FindFirstChild("Sign")
	local board = sign and sign:FindFirstChild("SignBoard")
	if board and board:IsA("BasePart") then
		local signClick = Instance.new("ClickDetector")
		signClick.MaxActivationDistance = 60
		signClick.Parent = board
		signClick.MouseClick:Connect(function()
			if mine(plot) then
				ask("level")
			end
		end)
	end

	refreshCars(y)
	refreshCoins(y)
end

local function float(at: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = at
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = COIN
	l.TextStrokeTransparency = 0
	l.Text = text
	l.Parent = gui
	local slow = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, slow, { StudsOffsetWorldSpace = Vector3.new(0, offset + 3.5, 0) })
		:Play()
	TweenService:Create(l, slow, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.5, gui.Destroy, gui)
end

-- a level bought: a burst of confetti over the middle of the loop and "LEVEL n!" floating up
local function celebrate(y: Yard, lv: number)
	local L = PlotGarage.LOOP
	local spot = Instance.new("Part")
	spot.Name = "LevelParty"
	spot.Size = Vector3.new(1, 1, 1)
	spot.Transparency = 1
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.CFrame = y.pivot * CFrame.new(L.x, 6, L.z)
	spot.Parent = y.folder
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 110)),
	})
	fx.Size = NumberSequence.new(0.6)
	fx.Lifetime = NumberRange.new(1.5, 2.5)
	fx.Speed = NumberRange.new(18, 30)
	fx.SpreadAngle = Vector2.new(60, 60)
	fx.Acceleration = Vector3.new(0, -25, 0)
	fx.Rotation = NumberRange.new(0, 360)
	fx.RotSpeed = NumberRange.new(-200, 200)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Rate = 0
	fx.Parent = spot
	fx:Emit(120)
	float(spot, "LEVEL " .. lv .. "!", 2)
	task.delay(3, spot.Destroy, spot)
end

local function watch(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	local function found(child: Instance)
		if child.Name == "Garage" and child:IsA("Model") then
			setUp(plot, child)
		end
	end
	plot.ChildAdded:Connect(found)
	local g = plot:FindFirstChild("Garage")
	if g then
		found(g)
	end
	plot.ChildRemoved:Connect(function(child)
		local y = yards[plot]
		if y and child == y.garage then
			y.folder:Destroy()
			yards[plot] = nil
		end
	end)
	-- your plot went up a level: confetti over the yard and a big "LEVEL n!"
	local lastLevel = level(plot)
	plot:GetAttributeChangedSignal("PlotLevel"):Connect(function()
		local now = level(plot)
		if now > lastLevel and mine(plot) then
			task.delay(0.3, function()
				local y = yards[plot]
				if y then
					celebrate(y, now)
				end
			end)
		end
		lastLevel = now
	end)
	for _, name in { "Parked", "PlotLevel", "OwnerId" } do
		plot:GetAttributeChangedSignal(name):Connect(function()
			local y = yards[plot]
			if y then
				refreshCars(y)
				refreshCoins(y)
			end
		end)
	end
	plot:GetAttributeChangedSignal("PlotCoins"):Connect(function()
		local y = yards[plot]
		if y then
			refreshCoins(y)
		end
	end)
end

local plots = workspace:WaitForChild("Plots")
plots.ChildAdded:Connect(watch)
for _, p in plots:GetChildren() do
	watch(p)
end

local moveAcc = 0
RunService.RenderStepped:Connect(function(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local clock = workspace:GetServerTimeNow()
	local due: boolean
	moveAcc, due = PlotGarage.stepDue(moveAcc, dt, Features.PLOT_CAR_HZ)
	for _, y in yards do
		local n = #y.cars
		y.spread += (n - y.spread) * math.min(1, dt * 1.5)
		if math.abs(n - y.spread) < 0.001 then
			y.spread = n
		end
		if due and n > 0 and (y.pivot.Position - eye).Magnitude < NEAR then
			placeCars(y, clock)
		end
	end
end)

-- ===== feel: "+N" off the cars, and the pile flying to you when you collect =====

-- each car's last "+N" beat (weak: cars come and go)
local beats: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
task.spawn(function()
	while true do
		task.wait(1)
		local cam = workspace.CurrentCamera
		local now = workspace:GetServerTimeNow()
		for _, y in yards do
			local near = cam and (y.pivot.Position - cam.CFrame.Position).Magnitude < NEAR
			for i, id in y.ids do
				local car = y.cars[i]
				local beat = math.floor((now + i * 7) / PlotGarage.POP_SECS)
				if near and car and beats[car] and beats[car] ~= beat then
					local body = car:FindFirstChild("Body")
					if body and body:IsA("BasePart") then
						float(body, "+" .. PlotGarage.popCoins(Tycoon.perMin(id)), 5.5)
					end
				end
				if car then
					beats[car] = beat
				end
			end
		end
	end
end)

-- collected: the heap's coins jump up and fly to you
local function burst(y: Yard)
	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local P = PlotGarage.PILE
	local from = y.pivot * CFrame.new(P.x, 1, P.z)
	for k = 1, 14 do
		local c = Instance.new("Part")
		c.Name = "FlyingCoin"
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.35, 2, 2)
		c.Color = COIN
		c.Material = Enum.Material.Neon
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		local a = k * 2.4
		c.CFrame = from
			* CFrame.new(math.cos(a) * 2, 0, math.sin(a) * 2)
			* CFrame.Angles(0, 0, math.rad(90))
		c.Parent = y.folder
		local up = c.CFrame * CFrame.new(5 + (k % 4), math.cos(a) * 3, math.sin(a) * 3)
		local rise = TweenService:Create(
			c,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = up }
		)
		rise:Play()
		task.delay(0.35 + k * 0.03, function()
			local fly = TweenService:Create(
				c,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = root.CFrame, Size = Vector3.new(0.1, 0.6, 0.6) }
			)
			fly:Play()
			fly.Completed:Once(function()
				c:Destroy()
			end)
		end)
	end
end

task.spawn(function()
	local e = ReplicatedStorage:WaitForChild("Plot", 30)
	if not (e and e:IsA("RemoteEvent")) then
		return
	end
	e.OnClientEvent:Connect(function(what: unknown, n: unknown)
		if what ~= "collected" or type(n) ~= "number" or n <= 0 then
			return
		end
		for plot, y in yards do
			if mine(plot) then
				burst(y)
			end
		end
	end)
end)
