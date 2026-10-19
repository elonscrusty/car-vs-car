--!strict
-- Shapes, not just colours (audit #81): a small bomb above the IT car (tag) and a small chevron
-- above your teammates (soccer), as world-space BillboardGuis made on this client. Reads what
-- the server already puts in the world: the "TagIt" Highlight on the IT car, and the team
-- colour of each car's "Marker" part (blue / red, ModesConfig.Soccer.colors) in an arena with a
-- "Ball". Rule: FeelRules.iconFor (pure, tested). No UI layout is touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeelRules = require(ReplicatedStorage.Shared.FeelRules)
local ModesConfig = require(ReplicatedStorage.Shared.ModesConfig)

local TeamIcons = {}

local SCAN_EVERY = 0.5
local running = false
local generation = 0
local icons: { [Model]: { gui: BillboardGui, kind: string } } = {}

local function teamOf(model: Model): number
	local marker = model:FindFirstChild("Marker")
	if marker and marker:IsA("BasePart") then
		local c = marker.Color
		return FeelRules.teamOfColor(c.R * 255, c.G * 255, c.B * 255, ModesConfig.Soccer.colors)
	end
	return 0
end

local function makeIcon(model: Model, kind: string, team: number): BillboardGui?
	local adornee = model.PrimaryPart
	if adornee == nil then
		return nil
	end
	local g = Instance.new("BillboardGui")
	g.Name = "TeamIcon"
	g.Adornee = adornee
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(if kind == "bomb" then 40 else 28, if kind == "bomb" then 40 else 28)
	g.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	g.MaxDistance = 400
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	if kind == "bomb" then
		l.Text = "\u{1F4A3}"
	else
		l.Text = "\u{25BC}"
		local rgb = ModesConfig.Soccer.colors[team]
		l.TextColor3 = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else Color3.new(1, 1, 1)
		l.TextStrokeColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0
	end
	l.Parent = g
	g.Parent = adornee
	return g
end

local function scan()
	local me = Players.LocalPlayer.UserId
	local wanted: { [Model]: { kind: string, team: number } } = {}
	for _, arena in workspace:GetChildren() do
		if arena.Name == "Arena" then
			local soccer = arena:FindFirstChild("Ball") ~= nil
			local mine: Model? = nil
			for _, m in arena:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("DriverUserId") == me then
					mine = m
				end
			end
			local myTeam = if mine and soccer then teamOf(mine) else 0
			for _, m in arena:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart ~= nil then
					local isIt = m:FindFirstChild("TagIt") ~= nil
					local team = if soccer then teamOf(m) else 0
					local isMate = soccer and m ~= mine and myTeam ~= 0 and team == myTeam
					local kind = FeelRules.iconFor(isIt, isMate)
					if kind ~= nil then
						wanted[m] = { kind = kind, team = team }
					end
				end
			end
		end
	end
	for m, icon in icons do
		local w = wanted[m]
		if w == nil or w.kind ~= icon.kind or m.Parent == nil then
			icon.gui:Destroy()
			icons[m] = nil
		end
	end
	for m, w in wanted do
		if icons[m] == nil then
			local g = makeIcon(m, w.kind, w.team)
			if g then
				icons[m] = { gui = g, kind = w.kind }
			end
		end
	end
end

function TeamIcons.start()
	if running then
		return
	end
	running = true
	generation += 1
	local mine = generation
	task.spawn(function()
		while running and generation == mine do
			pcall(scan)
			task.wait(SCAN_EVERY)
		end
	end)
end

function TeamIcons.stop()
	running = false
	generation += 1
	for m, icon in icons do
		icon.gui:Destroy()
		icons[m] = nil
	end
end

return TeamIcons
