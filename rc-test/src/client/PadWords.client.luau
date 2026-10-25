--!strict
-- Two or three words over each play pad at the spawn saying what it does (DRIFT NOW / RACE NOW /
-- GO BUILD) and "STAND HERE" under it, so a new player knows what the pads are for. The pads
-- only work in the break (workspace BuildOpen): from the pick until the race is over the small
-- line says AFTER THE RACE; when every plot of that kind is taken (the pad's BusyUntil, set by
-- QueuePads) it says ALL BUSY, WAIT. Also one or two words over the car shops and the gumball,
-- big enough to read on a phone from the spawn. Looks only, on this screen. The pads are the
-- "QueuePad" bases (attribute PlotType) that the spawn lobby builds.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garage"))

local WORDS: { [string]: string } = { drift = "DRIFT NOW", race = "RACE NOW", build = "GO BUILD" }
local SHOP_WORDS: { [string]: string } =
	{ drift = "DRIFT CARS", race = "RACE CARS", looks = "LOOKS" }
local INK = Color3.fromRGB(20, 20, 30)

local holder = Instance.new("ScreenGui")
holder.Name = "PadWords"
holder.ResetOnSpawn = false
holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

type Small = { label: TextLabel, base: BasePart }
local smalls: { Small } = {}

local function smallText(base: BasePart): string
	if workspace:GetAttribute("BuildOpen") == false then
		return "AFTER THE RACE"
	end
	local busy = base:GetAttribute("BusyUntil")
	if type(busy) == "number" and busy > workspace:GetServerTimeNow() then
		return "ALL BUSY, WAIT"
	end
	return "STAND HERE"
end

local function label(parent: Instance, text: string, color: Color3, y: number, h: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	l.Parent = parent
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
	local b =
		sign(base, "Pad" .. tostring(base:GetAttribute("Pad") or ""), Vector2.new(9, 3.6), 6, 60)
	-- the side pads' words lean in toward the middle pad, so from the spawn all three fit on a
	-- phone screen (tour 5: GO BUILD and DRIFT NOW were cut off at the edges)
	task.delay(1, function()
		for _, other in CollectionService:GetTagged("QueuePad") do
			if
				other ~= base
				and other:IsA("BasePart")
				and other:GetAttribute("PlotType") == "race"
			then
				local to = other.Position - base.Position
				to = Vector3.new(to.X, 0, to.Z)
				if to.Magnitude > 1 then
					b.StudsOffsetWorldSpace = Vector3.new(0, 6, 0) + to.Unit * 10
				end
			end
		end
	end)
	-- the pad's own colour (its neon rim; the base itself is dark)
	local rim = if base.Parent then base.Parent:FindFirstChild("Rim") else nil
	label(
		b,
		word,
		if rim and rim:IsA("BasePart") then rim.Color else Color3.fromRGB(255, 205, 60),
		0,
		0.68
	)
	table.insert(
		smalls,
		{ label = label(b, smallText(base), Color3.new(1, 1, 1), 0.68, 0.32), base = base }
	)
end

local function addShop(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local kind = model:GetAttribute("ShopKind")
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
	local orange = Garage.COLORS.orange -- the garage has no counter: its frame colour
	local color = if top and top:IsA("BasePart")
		then top.Color
		elseif kind == "looks" then Color3.fromRGB(orange[1], orange[2], orange[3])
		else Color3.new(1, 1, 1)
	label(b, word, color, 0, 1)
end

local function middlePad(): BasePart?
	for _, pad in CollectionService:GetTagged("QueuePad") do
		if pad:IsA("BasePart") and pad:GetAttribute("PlotType") == "race" then
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
	label(b, "LUCKY CAR", Color3.fromRGB(255, 120, 190), 0, 1)
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
end
Players.LocalPlayer:GetAttributeChangedSignal("Driving"):Connect(showAll)
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
