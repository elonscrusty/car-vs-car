--!strict
-- The garage yards come alive (PlotGarage has the layout, PlotGarageBuilder builds the road):
-- each plot's parked cars (its "Parked" attribute) drive round the little loop, one spot each,
-- in their own colour and style with their kind's glow (CarGlow, when it's in); spots the level
-- has room for but nobody fills ride round as a faint "?" pad. The coins
-- waiting in the plot ("PlotCoins") lie in a heap on the pile pad with the number over it, and
-- the heap grows as they come in. On your own plot, tap the pile (or walk onto it) to collect
-- and tap the sign to buy the next level (RemoteEvent Plot: "collect" / "level").
-- Looks only, on this screen: nothing here is solid. Far plots stop moving to save the phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)

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
	model.Parent = parent
	holder:Destroy()
	return model
end

local function placeCars(y: Yard, clock: number)
	local n = #y.cars
	for i, car in y.cars do
		local x, z, yaw = PlotGarage.spot(i, n, clock)
		car:PivotTo(y.pivot * CFrame.new(x, 0.1, z) * CFrame.Angles(0, math.rad(yaw), 0))
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
	y.carsKey = key
	for _, c in y.cars do
		c:Destroy()
	end
	y.cars = {}
	for _, id in list do
		table.insert(y.cars, makeCar(id, y.folder))
	end
	for _ = 1, open do
		table.insert(y.cars, makeOpen(y.folder))
	end
	placeCars(y, workspace:GetServerTimeNow())
end

local function refreshCoins(y: Yard)
	local coins = if (tonumber(y.plot:GetAttribute("OwnerId")) or 0) == 0
		then 0
		else math.floor(tonumber(y.plot:GetAttribute("PlotCoins")) or 0)
	y.count.Text = if coins > 0 then "🪙 " .. coins else ""
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
		c.Size = Vector3.new(0.3, 1.3, 1.3)
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
	gui.Size = UDim2.fromScale(7, 2)
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

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local clock = workspace:GetServerTimeNow()
	for _, y in yards do
		if #y.cars > 0 and (y.pivot.Position - eye).Magnitude < NEAR then
			placeCars(y, clock)
		end
	end
end)
