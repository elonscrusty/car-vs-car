--!strict
-- The shield bubble look (carter picked "B Hex Grid", 10-30): a see-through bubble of glowing
-- hex tiles around a kart that grabbed a shield. When it blocks a hit, a bright shine flashes
-- where the hit landed, the tiles light up, the bubble swells and breaks, and the tiles fly out
-- and fall. Looks only: the server decides that a hit was blocked (and when the shield ends) and
-- calls these; nothing here changes damage. Boxes charge the kart's one ability (carter 10-29),
-- so this is not a box: whoever wires the shield item calls show / block / hide.
-- Sizes follow the kart: the preview kart was 7 studs long and the bubble 5.6 studs wide.
-- Page with the 3 tries: car-vs-car/shield-preview/shield-tries.html (B).
--   ShieldFx.show(carId)               bubble grows in and follows the kart
--   ShieldFx.block(carId, from)        a hit was blocked (from = where it came from, or nil)
--   ShieldFx.hide(carId)               shield ran out without a hit: bubble shrinks away

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local ShieldFx = {}

local DESIGN = 7 -- the preview kart's length, studs
local R = 5.6 -- bubble radius in preview studs
local LIFT = 3.4 -- bubble middle above the kart's middle, preview studs
local TILES = 26
local GROW = 0.3 -- seconds to grow in
local POP_AT = 0.1 -- seconds from the hit until the bubble starts to break
local POP = 0.5 -- seconds the break takes
local FLY = 0.7 -- seconds a tile flies

local HEX = Color3.fromRGB(125, 140, 255)
local FLASH = Color3.fromRGB(235, 238, 255)
local TILE = Color3.fromRGB(125, 140, 255)
local TILE_HOT = Color3.fromRGB(215, 222, 255)

type Bubble = {
	body: BasePart,
	unit: number,
	shell: Part,
	grown: number, -- os.clock() when it started to grow
}

type Tile = { part: Part, dir: Vector3, spin: number, gap: number, reach: number }

type Break = {
	t0: number,
	center: Vector3,
	unit: number,
	shell: Part,
	tiles: { Tile },
}

local bubbles: { [string]: Bubble } = {}
local breaks: { Break } = {}
local beat: RBXScriptConnection? = nil
local folderRef: Folder? = nil

local function folder(): Folder
	local f = folderRef
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ShieldFx"
	made.Parent = workspace
	folderRef = made
	return made
end

local function rnd(n: number): number
	local x = math.sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

local function softPart(size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = folder()
	return p
end

-- The kart's middle part and how big it is next to the preview kart (1 = 7 studs long).
local function find(carId: string): (BasePart?, number)
	local car = workspace:FindFirstChild("Car_" .. carId)
	if car == nil or not car:IsA("Model") then
		return nil, 1
	end
	local body: BasePart? = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
	local size = car:GetExtentsSize()
	return body, math.max(size.X, size.Z) / DESIGN
end

local function centerOf(b: Bubble): Vector3
	return b.body.Position + Vector3.new(0, LIFT * b.unit, 0)
end

-- The ball of hex tiles is Roblox's own ForceField material: it draws the hex grid itself, so
-- there is no picture to upload.
local function makeShell(unit: number): Part
	local p = softPart(Vector3.one * R * 2 * unit, HEX, Enum.Material.ForceField)
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.35
	return p
end

local function ring(at: Vector3, unit: number, reach: number)
	local p = softPart(Vector3.new(0.1, 0.8, 0.8) * unit, HEX, Enum.Material.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	local d = reach * unit * 2
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1 * unit, d, d),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.55)
end

-- The shine: a four-pointed star (two crossed thin bars and two shorter ones) over a soft glow,
-- on an invisible part at the hit point. It swells, spins a little and fades (0.35 s).
local function shine(at: Vector3, unit: number)
	local p = softPart(Vector3.one * 0.2, FLASH, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.CFrame = CFrame.new(at)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(1.5 * unit, 0, 1.5 * unit, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Parent = p

	local group = Instance.new("Frame")
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.55, 0.55)
	glow.BackgroundColor3 = HEX
	glow.BackgroundTransparency = 0.45
	glow.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = glow
	glow.Parent = group

	local bars: { Frame } = {}
	for _, spec in { { 1, 0.07, 0 }, { 0.07, 1, 0 }, { 0.7, 0.05, 45 }, { 0.7, 0.05, -45 } } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(spec[1], spec[2])
		bar.Rotation = spec[3]
		bar.BackgroundColor3 = FLASH
		bar.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = bar
		bar.Parent = group
		table.insert(bars, bar)
	end

	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if Base.reduced() then
		Debris:AddItem(p, 0.3)
		gui.Size = UDim2.new(4 * unit, 0, 4 * unit, 0)
		TweenService:Create(glow, info, { BackgroundTransparency = 1 }):Play()
		for _, bar in bars do
			TweenService:Create(bar, info, { BackgroundTransparency = 1 }):Play()
		end
		return
	end
	TweenService:Create(gui, info, { Size = UDim2.new(6.5 * unit, 0, 6.5 * unit, 0) }):Play()
	TweenService:Create(group, info, { Rotation = 50 }):Play()
	TweenService:Create(glow, info, { BackgroundTransparency = 1 }):Play()
	for _, bar in bars do
		TweenService:Create(bar, info, { BackgroundTransparency = 1 }):Play()
	end
	Debris:AddItem(p, 0.45)
end

local function step()
	local now = os.clock()
	for _, b in bubbles do
		if not b.body.Parent then
			continue
		end
		local grow = math.clamp((now - b.grown) / GROW, 0, 1)
		local s = ease(grow) * (1 + math.sin(grow * math.pi) * 0.12)
		b.shell.Size = Vector3.one * R * 2 * b.unit * math.max(s, 0.001)
		b.shell.CFrame = CFrame.new(centerOf(b))
		b.shell.Transparency = 0.35 + 0.06 * math.sin(now * 3) -- a slow breath
	end
	for n = #breaks, 1, -1 do
		local k = breaks[n]
		local age = now - k.t0
		if age > POP_AT + FLY + 0.1 then
			k.shell:Destroy()
			for _, t in k.tiles do
				t.part:Destroy()
			end
			table.remove(breaks, n)
			continue
		end
		-- the bubble: a quick wobble, then swells and goes
		local p = math.clamp((age - POP_AT) / POP, 0, 1)
		local wobble = if age < POP_AT then math.sin(age / POP_AT * math.pi) * 0.05 else 0
		local size = R * 2 * k.unit * (1 + wobble + p * 0.28)
		k.shell.Size = Vector3.one * size
		k.shell.CFrame = CFrame.new(k.center)
		k.shell.Transparency = if age < POP_AT then 0.2 else 1 - (1 - 0.35) * (1 - p) ^ 2.2
		k.shell.Color = if age < POP_AT + 0.15 then TILE_HOT else HEX
		-- the tiles
		for _, t in k.tiles do
			local u = (age - POP_AT - t.gap) / FLY
			if u <= 0 or u >= 1 then
				t.part.Transparency = 1
				continue
			end
			local out = R * k.unit * (1 + ease(u) * t.reach)
			local pos = k.center + t.dir * out - Vector3.new(0, u * u * 2.2 * k.unit, 0)
			local side = t.dir:Cross(Vector3.yAxis)
			side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
			t.part.CFrame = CFrame.fromMatrix(pos, t.dir, side) * CFrame.Angles(u * t.spin, 0, 0)
			t.part.Size = Vector3.new(0.1, 1.2, 1.2) * k.unit * (1 - u * 0.4)
			t.part.Transparency = 1 - (1 - u) ^ 2 * 0.85
		end
	end
	if next(bubbles) == nil and #breaks == 0 and beat then
		beat:Disconnect()
		beat = nil
	end
end

local function wake()
	if not beat then
		beat = RunService.Heartbeat:Connect(step)
	end
end

-- A kart got a shield: the bubble grows around it and follows it. A kart we can't see (no
-- Car_<id> model) gets nothing.
function ShieldFx.show(carId: string)
	ShieldFx.hide(carId, true)
	local body, unit = find(carId)
	if body == nil then
		return
	end
	local shell = makeShell(unit)
	bubbles[carId] = { body = body, unit = unit, shell = shell, grown = os.clock() }
	if Base.reduced() then
		bubbles[carId].grown = os.clock() - GROW
	end
	wake()
end

-- The shield ran out (no hit): the bubble shrinks away. `quiet` skips the shrink.
function ShieldFx.hide(carId: string, quiet: boolean?)
	local b = bubbles[carId]
	if b == nil then
		return
	end
	bubbles[carId] = nil
	if quiet == true or Base.reduced() then
		b.shell:Destroy()
		return
	end
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(b.shell, info, { Size = Vector3.one * 0.1, Transparency = 1 }):Play()
	Debris:AddItem(b.shell, 0.3)
end

-- The shield took a hit and blocked it. `from` is where the hit came from (a position); nil
-- means "from the camera's side" so the shine is seen.
function ShieldFx.block(carId: string, from: Vector3?)
	local b = bubbles[carId]
	if b == nil then
		return
	end
	bubbles[carId] = nil
	local center = centerOf(b)
	local toward = Vector3.new(-0.8, 0.35, -0.5).Unit
	local cam = workspace.CurrentCamera
	if from then
		local d = from - center
		if d.Magnitude > 1e-3 then
			toward = d.Unit
		end
	elseif cam then
		local d = cam.CFrame.Position - center
		if d.Magnitude > 1e-3 then
			toward = (d.Unit + Vector3.new(0, 0.35, 0)).Unit
		end
	end
	shine(center + toward * R * b.unit, b.unit)
	ring(center - Vector3.new(0, LIFT * b.unit - 0.1, 0), b.unit, R * 2.8)
	if Base.reduced() then
		b.shell:Destroy()
		return
	end
	local tiles: { Tile } = {}
	for i = 1, TILES do
		local y = 1 - 2 * (i - 0.5) / TILES -- evenly over the ball
		local r = math.sqrt(1 - y * y)
		local a = i * 2.39996
		local part = softPart(Vector3.new(0.1, 1.2, 1.2) * b.unit, TILE, Enum.Material.Neon)
		part.Shape = Enum.PartType.Cylinder
		part.Transparency = 1
		table.insert(tiles, {
			part = part,
			dir = Vector3.new(math.cos(a) * r, y, math.sin(a) * r),
			spin = (rnd(i) - 0.5) * 3,
			gap = rnd(i + 3) * 0.04,
			reach = 0.5 + rnd(i) * 0.8,
		})
	end
	table.insert(
		breaks,
		{ t0 = os.clock(), center = center, unit = b.unit, shell = b.shell, tiles = tiles }
	)
	wake()
end

return ShieldFx
