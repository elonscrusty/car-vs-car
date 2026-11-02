--!strict
-- Two or three words over each play pad at the spawn saying what it does (DRIFT NOW / RACE NOW /
-- GO BUILD) and "STAND HERE" under it, so a new player knows what the pads are for. The pads
-- only work in the break (workspace BuildOpen): from the pick until the race is over their signs
-- are off; when every plot of that kind is taken (the pad's BusyUntil, set by
-- QueuePads) it says ALL BUSY, WAIT. Also one or two words over the car shops and the gumball,
-- big enough to read on a phone from the spawn. Looks only, on this screen. The pads are the
-- "QueuePad" bases (attribute PlotType) that the spawn lobby builds.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local Garage = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garage"))
local StageGate = require(script.Parent:WaitForChild("StageGate"))
local KartStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartStyle"))

local WORDS: { [string]: string } =
	{ drift = "DRIFT NOW", race = "JOIN RACE", smash = "SMASH!", build = "GO BUILD" }
local SHOP_WORDS: { [string]: string } =
	{ drift = "DRIFT CARS", race = "RACE CARS", looks = "LOOKS", crates = "CRATES" }

local holder = Instance.new("ScreenGui")
holder.Name = "PadWords"
holder.ResetOnSpawn = false
holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

type Small = { label: TextLabel, base: BasePart }
-- each sign's JoinStage name: a brand new player sees only the way to their own pad, the rest
-- comes back as their Stage goes up (carter 10-25: joining was overwhelming)
local gates: { [BillboardGui]: string } = {}
local PAD_GATE: { [string]: string } = { drift = "pads", race = "joinrace", smash = "smash" }
local SHOP_GATE: { [string]: string } =
	{ drift = "shop", race = "shop", looks = "looks", crates = "shop" }
local smalls: { Small } = {}
-- the pad signs: off during the race call and race (BuildOpen false: the pads do nothing then,
-- and the words sat on the race card and countdown), and smaller from close up
local padSigns: { [BillboardGui]: string } = {} -- each pad sign's kind
-- studs, from far; low and small enough that from the plaza ring it doesn't stand in front of
-- the crate shop (Studio batch-2035 #4: at 9x3.6, 6 up, it covered the prices)
local PAD_SIZE = Vector2.new(7.5, 3)
local PAD_UP = 4.2
local PAD_NEAR = 26 -- closer than this (camera to sign) they shrink with the distance...
local PAD_MIN = 0.35 -- ...down to this much (from the spawn the middle pad is ~12 away)

-- the pad that puts you in the next race / Smash match (works any time, not a plot pad)
local function joinPad(kind: any): boolean
	return kind == "race" or kind == "smash"
end

local function smallText(base: BasePart): string
	-- JOIN RACE: works any time, and says so once you're in (RaceJoined, set by the race runner
	-- and cleared after each race)
	-- SMASH!: in the queue for the next round (MatchRunner.join sets MatchQueued)
	if base:GetAttribute("PlotType") == "smash" then
		-- once you're in, the time to the match (workspace NextMatchAt, server time)
		if Players.LocalPlayer:GetAttribute("MatchQueued") == true then
			local at = workspace:GetAttribute("NextMatchAt")
			if type(at) == "number" then
				local left = math.max(0, math.ceil(at - workspace:GetServerTimeNow()))
				return string.format("YOU'RE IN! %d:%02d", left // 60, left % 60)
			end
			return "YOU'RE IN!"
		end
		return "STAND HERE"
	end
	if base:GetAttribute("PlotType") == "race" then
		return if Players.LocalPlayer:GetAttribute("RaceJoined") == true
			then "YOU'RE IN!"
			else "STAND HERE"
	end
	local busy = base:GetAttribute("BusyUntil")
	if type(busy) == "number" and busy > workspace:GetServerTimeNow() then
		return "ALL BUSY, WAIT"
	end
	return "STAND HERE"
end

-- Style A, Kart Party (KartStyle): Luckiest Guy, white words with a dark ink outline. With a
-- `fill` the words sit on a pill of that colour with an ink rim and an ink shadow under it,
-- like the game's buttons; without one they stand on their own (the small STAND HERE line).
local function label(parent: Instance, text: string, fill: Color3?, y: number, h: number): TextLabel
	local box: GuiObject = parent :: any
	if fill then
		local shadow = Instance.new("Frame")
		shadow.BackgroundColor3 = KartStyle.INK
		shadow.BorderSizePixel = 0
		shadow.Position = UDim2.fromScale(0.02, y + h * 0.1)
		shadow.Size = UDim2.fromScale(0.96, h * 0.9)
		shadow.Parent = parent
		local pill = Instance.new("Frame")
		pill.BackgroundColor3 = fill
		pill.BorderSizePixel = 0
		pill.Position = UDim2.fromScale(0.02, y)
		pill.Size = UDim2.fromScale(0.96, h * 0.9)
		pill.Parent = parent
		for _, f in { shadow, pill } do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
		local rim = Instance.new("UIStroke")
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Color = KartStyle.INK
		rim.Thickness = KartStyle.PANEL_RIM
		rim.Parent = pill
		box = pill
	end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	if fill then
		l.Position = UDim2.fromScale(0.06, 0.12)
		l.Size = UDim2.fromScale(0.88, 0.8)
	else
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
	end
	l.Font = KartStyle.FONT
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = KartStyle.WHITE
	local ink = Instance.new("UIStroke")
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ink.Color = KartStyle.INK
	ink.Thickness = KartStyle.BUTTON_RIM
	ink.Parent = l
	l.Parent = box
	return l
end

-- a BillboardGui only draws reliably from PlayerGui; Adornee puts it over the part. Sized in
-- studs (tour 5: pixel-sized ones ran off a phone's edges and piled on each other from the
-- spawn), so a far sign is small and a near one big, like a real sign.
local function sign(
	over: BasePart,
	name: string,
	size: Vector2,
	up: number,
	far: number
): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = name
	b.Adornee = over
	b.AlwaysOnTop = false
	b.Size = UDim2.new(size.X, 0, size.Y, 0)
	b.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	b.MaxDistance = far -- the spawn only, not from across the tracks
	b.LightInfluence = 0
	b.Parent = holder
	over.AncestryChanged:Connect(function()
		if not over:IsDescendantOf(workspace) then
			b:Destroy()
			for i, s in smalls do
				if s.base == over then
					table.remove(smalls, i)
					break
				end
			end
		end
	end)
	return b
end

local function addPad(base: Instance)
	if not base:IsA("BasePart") then
		return
	end
	local kind = base:GetAttribute("PlotType")
	local word = if type(kind) == "string" then WORDS[kind] else nil
	if word == nil then
		return
	end
	local b = sign(base, "Pad" .. tostring(base:GetAttribute("Pad") or ""), PAD_SIZE, PAD_UP, 60)
	gates[b] = PAD_GATE[kind] or "pads"
	padSigns[b] = kind
	-- the side pads' words lean in toward the middle pad, so from the spawn all three fit on a
	-- phone screen (tour 5: GO BUILD and DRIFT NOW were cut off at the edges)
	task.delay(1, function()
		for _, other in CollectionService:GetTagged("QueuePad") do
			if
				other ~= base
				and other:IsA("BasePart")
				and joinPad(other:GetAttribute("PlotType"))
			then
				local to = other.Position - base.Position
				to = Vector3.new(to.X, 0, to.Z)
				if to.Magnitude > 1 then
					b.StudsOffsetWorldSpace = Vector3.new(0, PAD_UP, 0) + to.Unit * 10
				end
			end
		end
	end)
	-- the pad's own colour (its neon rim; the base itself is dark)
	local rim = if base.Parent then base.Parent:FindFirstChild("Rim") else nil
	label(b, word, if rim and rim:IsA("BasePart") then rim.Color else KartStyle.YELLOW, 0, 0.68)
	table.insert(smalls, { label = label(b, smallText(base), nil, 0.68, 0.32), base = base })
end

local function addShop(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local kind = model:GetAttribute("ShopKind")
	-- (Features.NEW_UI: the CRATES tile opens the crates; the stall's big floating word sat by
	-- JOBS on a phone and read like a second button, Studio live1)
	if kind == "crates" and Features.CVC and Features.NEW_UI then
		return
	end
	local word = if type(kind) == "string" then SHOP_WORDS[kind] else nil
	local floor = model.PrimaryPart
	if word == nil or floor == nil then
		return
	end
	-- the shop's trim colour (its counter top), white when there is none; just over the roof
	local counter = model:FindFirstChild("Counter")
	local top = counter and counter:FindFirstChild("Top")
	-- over the roof (9 up), higher than the pad words, so from the spawn they sit above them;
	-- 18 wide reads on a phone from the spawn and still clears the next shop (tour 6)
	local b = sign(floor, "Shop" .. kind, Vector2.new(18, 3.9), 13.5, 120)
	gates[b] = SHOP_GATE[kind] or "shop"
	local orange = Garage.COLORS.orange -- the garage has no counter: its frame colour
	local color = if top and top:IsA("BasePart")
		then top.Color
		elseif kind == "looks" then Color3.fromRGB(orange[1], orange[2], orange[3])
		else KartStyle.BLUE
	label(b, word, color, 0, 1)
end

local function middlePad(): BasePart?
	for _, pad in CollectionService:GetTagged("QueuePad") do
		if pad:IsA("BasePart") and joinPad(pad:GetAttribute("PlotType")) then
			return pad
		end
	end
	return nil
end

local function addGumball(base: Instance)
	if not base:IsA("BasePart") then
		return
	end
	local b = sign(base, "Gumball", Vector2.new(10, 2.4), 8.5, 100)
	gates[b] = "gumball"
	label(b, "LUCKY CAR", KartStyle.PINK, 0, 1)
	-- the LOOKS garage stands right behind it from the spawn (tour 7: the two signs ran into
	-- each other): slide these words 7 studs sideways, as seen from the middle pad, to the side
	-- away from the garage, and drop them a little
	task.delay(1.5, function()
		local mid = middlePad()
		for _, d in workspace:GetDescendants() do
			if
				d:IsA("Model")
				and d:GetAttribute("ShopKind") == "looks"
				and d.PrimaryPart
				and mid
			then
				local view = base.Position - mid.Position
				local side = Vector3.new(-view.Z, 0, view.X)
				if side.Magnitude > 1 then
					side = side.Unit
					if side:Dot(base.Position - d.PrimaryPart.Position) < 0 then
						side = -side
					end
					b.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0) + side * 7
				end
				break
			end
		end
	end)
end

-- Only at the spawn, on foot: hidden while driving, and whenever the camera is away from the
-- spawn (tour 5: driving plot 1 they floated over the barrier ahead).
local SPAWN_NEAR = 90 -- studs from the middle (race) pad
local function showAll()
	local me = Players.LocalPlayer
	local on = me:GetAttribute("Driving") ~= true
	local char = me.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart ~= nil then
		on = false
	end
	local mid = middlePad()
	local cam = workspace.CurrentCamera
	if on and mid and cam and (cam.CFrame.Position - mid.Position).Magnitude > SPAWN_NEAR then
		on = false
	end
	holder.Enabled = on
	local callOn = false
	local eye = if cam then cam.CFrame.Position else nil
	for b, gate in gates do
		if b.Parent == nil then
			gates[b] = nil
			padSigns[b] = nil
		elseif padSigns[b] then
			-- JOIN RACE works any time (it waits for the next race)
			b.Enabled = StageGate.shows(gate) and (not callOn or joinPad(padSigns[b]))
			local over = b.Adornee
			if b.Enabled and eye and over and over:IsA("BasePart") then
				local d = (over.Position + b.StudsOffsetWorldSpace - eye).Magnitude
				local k = math.clamp(d / PAD_NEAR, PAD_MIN, 1)
				b.Size = UDim2.new(PAD_SIZE.X * k, 0, PAD_SIZE.Y * k, 0)
			end
		else
			b.Enabled = StageGate.shows(gate)
		end
	end
end
Players.LocalPlayer:GetAttributeChangedSignal("Driving"):Connect(showAll)
Players.LocalPlayer:GetAttributeChangedSignal("Stage"):Connect(showAll)
workspace:GetAttributeChangedSignal("BuildOpen"):Connect(showAll)
showAll()

for _, base in CollectionService:GetTagged("QueuePad") do
	addPad(base)
end
CollectionService:GetInstanceAddedSignal("QueuePad"):Connect(addPad)
for _, base in CollectionService:GetTagged("Gumball") do
	addGumball(base)
end
CollectionService:GetInstanceAddedSignal("Gumball"):Connect(addGumball)
local function checkShop(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("ShopKind") ~= nil then
		-- its parts arrive just after the model
		task.delay(1, addShop, inst)
	end
end
for _, d in workspace:GetDescendants() do
	checkShop(d)
end
workspace.DescendantAdded:Connect(checkShop)

-- the small lines: four times a second is plenty (BusyUntil is a time, not a change)
task.spawn(function()
	while true do
		task.wait(0.25)
		showAll()
		if holder.Enabled then
			for _, s in smalls do
				local t = smallText(s.base)
				if s.label.Text ~= t then
					s.label.Text = t
				end
			end
		end
	end
end)
