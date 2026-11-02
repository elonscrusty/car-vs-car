--!strict
-- What you see when a kart grabs a gold box (carter picked "C Spiral", 10-29): a swirl of gold
-- bits flies from the box into the kart's roof, a ring rolls out where it lands, and over the kart
-- three little dots show its special (a third of it fills, so one more dot lights with a pop) with
-- a "+1/3" that floats up. Looks only: the server already added the charge (server/SpecialCharge)
-- and told us the level through the box's TakenLevel attribute (client/BoxFx calls `play`).
-- Sizes follow the box: the preview's box side was 4 studs, the RC arena box is about 1.
-- Page with the 3 tries: car-vs-car/charge-box-preview/charge-box-tries.html.
--   ChargeFx.play(boxAt, carId, level, boxSide)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Charge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Charge"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local ChargeFx = {}

local DESIGN = 4 -- the preview's box side, studs
local BITS = 28
local FIRST = 0.08 -- seconds until the first bit leaves the box
local GAP = 0.014 -- between bits
local FLY = 0.8 -- seconds a bit takes to reach the kart
local ROOF = 3.3 -- preview studs above the kart's middle where the bits land
local PIPS_UP = 4.6 -- and where the dots float
local ARRIVE = 0.85 -- the first bits land: the dot pops and the ring rolls out

local GOLD = Color3.fromRGB(255, 194, 46)
local PALE = Color3.fromRGB(255, 241, 168)
local RING = Color3.fromRGB(255, 226, 122)
local LIT = Color3.fromRGB(255, 210, 74)
local DIM = Color3.fromRGB(58, 63, 85)
local WORD = Color3.fromRGB(255, 251, 230)
local WORD_EDGE = Color3.fromRGB(122, 42, 0)

type Flight = {
	t0: number,
	from: Vector3,
	body: BasePart?,
	unit: number,
	bits: { BasePart },
}

local flights: { Flight } = {}
local beat: RBXScriptConnection? = nil
local folderRef: Folder? = nil

local function folder(): Folder
	local f = folderRef
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ChargeFx"
	made.Parent = workspace
	folderRef = made
	return made
end

local function bit(i: number, unit: number): Part
	local p = Instance.new("Part")
	p.Size = Vector3.one * 0.46 * 1.25 * unit
	p.Color = if i % 3 == 0 then PALE else GOLD
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = folder()
	return p
end

local function ring(at: Vector3, unit: number, reach: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.1 * unit, 0.8 * unit, 0.8 * unit)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = RING
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = folder()
	local d = reach * unit * 2
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1 * unit, d, d),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.55)
end

local function step()
	local now = os.clock()
	for n = #flights, 1, -1 do
		local f = flights[n]
		local age = now - f.t0
		if age > FIRST + BITS * GAP + FLY + 0.1 then
			for _, b in f.bits do
				b:Destroy()
			end
			table.remove(flights, n)
			continue
		end
		local body = f.body
		local to = f.from + Vector3.new(0, ROOF * f.unit, 0)
		if body and body.Parent then
			to = body.Position + Vector3.new(0, ROOF * f.unit, 0)
		end
		local line = to - f.from
		local dir = if line.Magnitude > 1e-3 then line.Unit else Vector3.new(0, 0, -1)
		local side = dir:Cross(Vector3.yAxis)
		side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
		local lift = side:Cross(dir)
		for i, b in f.bits do
			local u = (age - FIRST - (i - 1) * GAP) / FLY
			if u < 0 or u >= 1 then
				b.Transparency = 1
				continue
			end
			local e = u * u * (3 - 2 * u)
			local r = (0.2 + math.sin(u * math.pi) * 2.6) * f.unit
			local a = i * 0.55 + u * 9
			b.CFrame = CFrame.new(
				f.from
					+ line * e
					+ Vector3.new(0, math.sin(u * math.pi) * 1.8 * f.unit, 0)
					+ lift * (math.cos(a) * r)
					+ side * (math.sin(a) * r)
			) * CFrame.Angles(i, age * 4, 0)
			b.Size = Vector3.one * 0.46 * (1.25 - u * 0.8) * f.unit
			b.Transparency = if u > 0.8 then (u - 0.8) * 5 else 0
		end
	end
	if #flights == 0 and beat then
		beat:Disconnect()
		beat = nil
	end
end

-- "+1/3" and the three dots over the kart, on the kart so they ride with it
local function dots(body: BasePart, unit: number, level: number)
	local lit = Charge.pips(level)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChargeDots"
	gui.Adornee = body
	gui.Size = UDim2.new(5.2 * unit, 0, 2.4 * unit, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, PIPS_UP * unit, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.ResetOnSpawn = false

	local word = Instance.new("TextLabel")
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(1, 0.55)
	word.Position = UDim2.fromScale(0, 0.45)
	word.Font = Enum.Font.RobotoCondensed
	word.Text = "+1/3"
	word.TextScaled = true
	word.TextColor3 = WORD
	word.TextTransparency = 1
	word.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = WORD_EDGE
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = word
	word.Parent = gui

	local pop: Frame? = nil
	for i = 1, Charge.PIPS do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromScale(0.26, 0.3)
		dot.Position = UDim2.fromScale(0.2 + (i - 1) * 0.3, 0.2)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = if i < lit then LIT else DIM -- the new one lights on arrival
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = dot
		dot.Parent = gui
		if i == lit then
			pop = dot
		end
	end
	gui.Parent = body

	local calm = Base.reduced()
	task.delay(if calm then 0 else ARRIVE, function()
		if pop and pop.Parent then
			pop.BackgroundColor3 = LIT
			if not calm then
				pop.Size = UDim2.fromScale(0.26 * 1.7, 0.3 * 1.7)
				TweenService:Create(
					pop,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(0.26, 0.3) }
				):Play()
			end
		end
		if word.Parent then
			word.TextTransparency = 0
			stroke.Transparency = 0
			if not calm then
				word.Position = UDim2.fromScale(0, 0.6)
				TweenService:Create(
					word,
					TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = UDim2.fromScale(0, 0.3), TextTransparency = 1 }
				):Play()
				TweenService:Create(
					stroke,
					TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Transparency = 1 }
				):Play()
			end
		end
	end)
	Debris:AddItem(gui, if calm then 1.6 else 2.2)
end

-- A box at `boxAt` was grabbed by kart `carId`, whose special is now `level` (0..1). `boxSide` is
-- the box's side in studs (sizes follow it). A kart we can't see (no Car_<id> model) just gets
-- the flash at the box from client/BoxFx.
function ChargeFx.play(boxAt: Vector3, carId: string, level: number, boxSide: number)
	local unit = math.max(boxSide, 0.1) / DESIGN
	local car = workspace:FindFirstChild("Car_" .. carId)
	local found: BasePart? = nil
	if car and car:IsA("Model") then
		found = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
	end
	if found == nil then
		return
	end
	local body: BasePart = found
	local ground = boxAt - Vector3.new(0, 3 * unit, 0)
	ring(ground, unit, 4.5)
	if Base.reduced() then
		dots(body, unit, level)
		return
	end
	local flight: Flight = { t0 = os.clock(), from = boxAt, body = body, unit = unit, bits = {} }
	for i = 1, BITS do
		table.insert(flight.bits, bit(i, unit))
	end
	table.insert(flights, flight)
	if not beat then
		beat = RunService.Heartbeat:Connect(step)
	end
	dots(body, unit, level)
	task.delay(ARRIVE, function()
		if body.Parent then
			ring(body.Position - Vector3.new(0, 0.4 * unit, 0), unit, 6)
		end
	end)
end

return ChargeFx
