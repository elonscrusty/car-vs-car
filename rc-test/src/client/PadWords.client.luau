--!strict
-- Two or three words over each play pad at the spawn saying what it does (DRIFT NOW / RACE NOW /
-- GO BUILD) and "STAND HERE" under it, so a new player knows what the pads are for. The pads
-- only work in the break (workspace BuildOpen): from the pick until the race is over the small
-- line says AFTER THE RACE. Looks only, on this screen. The pads are the
-- "QueuePad" bases (attribute PlotType) that the spawn lobby builds.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WORDS: { [string]: string } = { drift = "DRIFT NOW", race = "RACE NOW", build = "GO BUILD" }
local smalls: { TextLabel } = {}
local function smallText(): string
	return if workspace:GetAttribute("BuildOpen") == false then "AFTER THE RACE" else "STAND HERE"
end

local holder = Instance.new("ScreenGui")
holder.Name = "PadWords"
holder.ResetOnSpawn = false
holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function add(base: Instance)
	if not base:IsA("BasePart") then
		return
	end
	local kind = base:GetAttribute("PlotType")
	local word = if type(kind) == "string" then WORDS[kind] else nil
	if word == nil then
		return
	end
	-- a BillboardGui only draws reliably from PlayerGui; Adornee puts it over the pad
	local sign = Instance.new("BillboardGui")
	sign.Name = "Pad" .. tostring(base:GetAttribute("Pad") or "")
	sign.Adornee = base
	sign.AlwaysOnTop = false
	sign.Size = UDim2.fromOffset(220, 90)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	sign.MaxDistance = 60 -- the spawn only, not from across the tracks
	sign.LightInfluence = 0
	sign.Parent = holder
	local big = Instance.new("TextLabel")
	big.BackgroundTransparency = 1
	big.Size = UDim2.fromScale(1, 0.68)
	big.Font = Enum.Font.GothamBlack
	big.TextScaled = true
	big.Text = word
	-- the pad's own colour (its neon rim; the base itself is dark)
	local rim = if base.Parent then base.Parent:FindFirstChild("Rim") else nil
	big.TextColor3 = if rim and rim:IsA("BasePart") then rim.Color else Color3.fromRGB(255, 205, 60)
	big.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	big.TextStrokeTransparency = 0
	big.Parent = sign
	local small = Instance.new("TextLabel")
	small.BackgroundTransparency = 1
	small.Position = UDim2.fromScale(0, 0.68)
	small.Size = UDim2.fromScale(1, 0.32)
	small.Font = Enum.Font.GothamBlack
	small.TextScaled = true
	small.Text = smallText()
	small.TextColor3 = Color3.new(1, 1, 1)
	small.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	small.TextStrokeTransparency = 0
	small.Parent = sign
	table.insert(smalls, small)
	base.AncestryChanged:Connect(function()
		if not base:IsDescendantOf(workspace) then
			sign:Destroy()
			local i = table.find(smalls, small)
			if i then
				table.remove(smalls, i)
			end
		end
	end)
end

-- hidden while driving (they showed over the race from far away)
local function showAll()
	workspace:GetAttributeChangedSignal("BuildOpen"):Connect(function()
		for _, small in smalls do
			small.Text = smallText()
		end
	end)
	holder.Enabled = Players.LocalPlayer:GetAttribute("Driving") ~= true
end
Players.LocalPlayer:GetAttributeChangedSignal("Driving"):Connect(showAll)
showAll()

for _, base in CollectionService:GetTagged("QueuePad") do
	add(base)
end
CollectionService:GetInstanceAddedSignal("QueuePad"):Connect(add)
