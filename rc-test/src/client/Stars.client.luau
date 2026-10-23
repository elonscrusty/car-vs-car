--!strict
-- Carter's stars loop, phase 1, on screen: the star count (top left, under the timer) and a pop
-- when a run ends with a medal or a plot record. The server decides everything (Stars.server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:WaitForChild("StarsEvent") :: RemoteEvent
local player = Players.LocalPlayer

local NAMES = { "BRONZE", "SILVER", "GOLD" }
local COLORS = {
	Color3.fromRGB(214, 140, 80),
	Color3.fromRGB(215, 222, 232),
	Color3.fromRGB(255, 205, 60),
}

local gui = Instance.new("ScreenGui")
gui.Name = "Stars"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local chip = Instance.new("TextLabel")
chip.Name = "StarCount"
chip.AnchorPoint = Vector2.new(0, 0)
chip.Position = UDim2.new(0.02, 0, 0.14, 70) -- under the timer
chip.Size = UDim2.fromScale(0.13, 0.06)
chip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
chip.BackgroundTransparency = 0.3
chip.TextColor3 = Color3.fromRGB(255, 213, 79)
chip.Font = Enum.Font.GothamBlack
chip.TextScaled = true
chip.Text = "⭐ 0"
chip.Parent = gui
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0.3, 0)
chipCorner.Parent = chip
local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

-- coins, beside the stars
local coinChip = chip:Clone()
coinChip.Name = "CoinCount"
coinChip.Position = UDim2.new(0.16, 0, 0.14, 70)
coinChip.TextColor3 = Color3.fromRGB(255, 236, 150)
coinChip.Text = "0"
coinChip.Parent = gui
-- a drawn coin (the coin emoji is missing from Roblox's font): gold disc, darker rim, a lighter
-- inner ring. The number sits to its right.
local coinPad = Instance.new("UIPadding")
coinPad.PaddingLeft = UDim.new(0.42, 0)
coinPad.PaddingRight = UDim.new(0.08, 0)
coinPad.Parent = coinChip
local coin = Instance.new("Frame")
coin.Name = "Coin"
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.new(-0.42 / 0.5, 6, 0.5, 0) -- back over the left padding
coin.Size = UDim2.fromScale(0.7, 0.7)
coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
coin.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
coin.Parent = coinChip
local coinRound = Instance.new("UICorner")
coinRound.CornerRadius = UDim.new(0.5, 0)
coinRound.Parent = coin
local coinRim = Instance.new("UIStroke")
coinRim.Color = Color3.fromRGB(176, 112, 10)
coinRim.Thickness = 2
coinRim.Parent = coin
local coinInner = Instance.new("Frame")
coinInner.AnchorPoint = Vector2.new(0.5, 0.5)
coinInner.Position = UDim2.fromScale(0.5, 0.5)
coinInner.Size = UDim2.fromScale(0.55, 0.55)
coinInner.BackgroundTransparency = 1
coinInner.Parent = coin
local innerRound = Instance.new("UICorner")
innerRound.CornerRadius = UDim.new(0.5, 0)
innerRound.Parent = coinInner
local innerRing = Instance.new("UIStroke")
innerRing.Color = Color3.fromRGB(255, 232, 140)
innerRing.Thickness = 1.5
innerRing.Parent = coinInner

-- gold bolts found, only while on a rock plot
local boltChip = chip:Clone()
boltChip.Name = "BoltCount"
boltChip.Position = UDim2.new(0.30, 0, 0.14, 70)
boltChip.TextColor3 = Color3.fromRGB(255, 200, 70)
boltChip.Text = "🔩 0/5"
boltChip.Visible = false
boltChip.Parent = gui

-- found bolts are hidden on this screen (the server says which)
local foundBolts: { [number]: boolean } = {}
local function hideFound()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, d in plots:GetDescendants() do
		local id = d:GetAttribute("BoltId")
		if type(id) == "number" and foundBolts[id] then
			for _, p in { d, table.unpack(d:GetDescendants()) } do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 1
				elseif p:IsA("Light") or p:IsA("ParticleEmitter") then
					(p :: any).Enabled = false
				end
			end
		end
	end
end

-- short messages: likes, visit gifts
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.fromScale(0.5, 0.76)
toast.Size = UDim2.fromScale(0.5, 0.06)
toast.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0.4, 0)
toastCorner.Parent = toast
local toasts = 0
local function showToast(text: string)
	toasts += 1
	local mine = toasts
	toast.Text = text
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.3
	task.delay(2.5, function()
		if toasts == mine then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end
	end)
end

-- shown when this server can't save (Studio without API access, DataStore down)
local noSave = Instance.new("TextLabel")
noSave.Name = "NotSaving"
noSave.AnchorPoint = Vector2.new(0, 0)
noSave.Position = UDim2.new(0, 0, 1, 2)
noSave.Size = UDim2.fromScale(1, 0.5)
noSave.BackgroundTransparency = 1
noSave.TextColor3 = Color3.fromRGB(255, 110, 100)
noSave.TextStrokeTransparency = 0.4
noSave.Font = Enum.Font.GothamBold
noSave.TextScaled = true
noSave.Text = "NOT SAVING"
noSave.Visible = false
noSave.Parent = chip

local pop = Instance.new("TextLabel")
pop.Name = "MedalPop"
pop.AnchorPoint = Vector2.new(0.5, 0.5)
pop.Position = UDim2.fromScale(0.5, 0.62) -- under the drift score pop
pop.Size = UDim2.fromScale(0.56, 0.16)
pop.BackgroundTransparency = 1
pop.Font = Enum.Font.GothamBlack
pop.TextScaled = true
pop.RichText = true
pop.TextColor3 = Color3.new(1, 1, 1)
pop.TextStrokeColor3 = Color3.new(0, 0, 0)
pop.TextTransparency = 1
pop.TextStrokeTransparency = 1
pop.Parent = gui
local popScale = Instance.new("UIScale")
popScale.Parent = pop

local shown = 0 -- pops in a row: an old pop's fade must not hide a newer one
local function showPop(text: string, color: Color3)
	shown += 1
	local mine = shown
	pop.Text = text
	pop.TextColor3 = color
	pop.TextTransparency = 0
	pop.TextStrokeTransparency = 0.3
	popScale.Scale = 0.6
	TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.8, function()
		if shown ~= mine then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(pop, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function setStars(n: number, bump: boolean)
	chip.Text = `⭐ {n}`
	if bump then
		chipScale.Scale = 1.4
		TweenService:Create(chipScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end
end

remote.OnClientEvent:Connect(function(kind: unknown, info: unknown, saving: unknown, ...: unknown)
	if kind == "stars" and type(info) == "number" then
		setStars(info, false)
		noSave.Visible = saving == false
		return
	end
	if kind == "coins" and type(info) == "number" then
		coinChip.Text = tostring(info)
		return
	end
	if kind == "bolts" and type(info) == "number" then
		-- ("bolts", found, total, onRock)
		local total = saving
		boltChip.Text = `🔩 {info}/{if type(total) == "number" then total else 5}`
		boltChip.Visible = select(1, ...) == true
		return
	end
	if kind == "bolt" and type(info) == "number" then
		foundBolts[info] = true
		hideFound()
		return
	end
	if kind == "boltsFound" and type(info) == "table" then
		for _, id in info :: { any } do
			if type(id) == "number" then
				foundBolts[id] = true
			end
		end
		hideFound()
		return
	end
	if kind == "toast" and type(info) == "string" then
		showToast(info)
		return
	end
	if kind ~= "run" or type(info) ~= "table" then
		return
	end
	local r = info :: any
	local medal = if type(r.medal) == "number" then r.medal else 0
	local lines: { string } = {}
	if medal > 0 then
		local line = `{NAMES[medal]}  {r.text}`
		if type(r.gained) == "number" and r.gained > 0 then
			line ..= `  +{r.gained} ⭐`
		end
		table.insert(lines, line)
	else
		table.insert(lines, tostring(r.text))
	end
	if r.record then
		table.insert(lines, `<font color="#FFD54F">NEW PLOT RECORD!</font>`)
	elseif medal > 0 and r.own then
		table.insert(lines, `<font size="20">your plot: win stars on friends' plots</font>`)
	end
	showPop(table.concat(lines, "\n"), if medal > 0 then COLORS[medal] else Color3.new(1, 1, 1))
	if type(r.stars) == "number" then
		setStars(r.stars, type(r.gained) == "number" and r.gained > 0)
	end
end)
