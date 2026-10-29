--!strict
-- The name tag over a kart in a Smash match (carter's pick: "New Classic",
-- nametag-preview/nametag-pick.html). On top of OtherCars' BillboardGui it draws:
--   a level star (blue, purple from 10, gold from 25) + the name (FredokaOne, ink stroke),
--   a shiny health bar with a heart, ticks, a gold chunk that trails behind a hit, a red throb
--   when low, a glow + shield for the spawn shield, a FROZEN pill, a crown for the leader.
-- Rules and numbers are in shared/NameTagLook. Looks only: the server sets Health (the
-- MatchBoard row), Shield (the player), Frozen / Smashed / Wrecked (the car).
--   MatchNameTag.attach(tag, plain, model, name) -> a handle: show(on), destroy()
--     tag: OtherCars' BillboardGui; plain: its old one-word label (hidden while this shows)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Look = require(Shared:WaitForChild("NameTagLook"))
local Match = require(Shared:WaitForChild("Match"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local NAVY = Color3.fromRGB(13, 44, 64)
local TRACK = Color3.fromRGB(34, 42, 72)
local LIME_TOP = Color3.fromRGB(168, 255, 160)
local LIME_MID = Color3.fromRGB(51, 207, 78)
local LIME_END = Color3.fromRGB(29, 156, 56)
local RED_TOP = Color3.fromRGB(255, 176, 154)
local RED_MID = Color3.fromRGB(240, 68, 44)
local RED_END = Color3.fromRGB(184, 36, 20)
local ICE_TOP = Color3.fromRGB(232, 251, 255)
local ICE_MID = Color3.fromRGB(143, 216, 255)
local ICE_END = Color3.fromRGB(74, 168, 232)
local GOLD = Color3.fromRGB(255, 210, 60)
local SHIELD_BLUE = Color3.fromRGB(127, 232, 255)

local SIZE = UDim2.fromOffset(116, 62) -- what the BillboardGui is while this shows
local SCALE = if Base.phone() then 0.86 else 1

local MatchNameTag = {}

export type Handle = {
	id: number,
	setLeader: (on: boolean) -> (),
	show: (on: boolean) -> (),
	destroy: () -> (),
}
local handles: { [Handle]: boolean } = {}
local watching = false

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function box(parent: Instance, color: Color3, size: UDim2, pos: UDim2?, round: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos or UDim2.new()
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, round)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function gradient(parent: Instance, top: Color3, mid: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.55, mid),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Parent = parent
	return g
end

-- a star from two squares (one turned 45 degrees), over a slightly bigger dark pair as its outline
type Star = { fill: { Frame }, grad: { UIGradient } }
local function starShape(parent: Instance, name: string, size: number): Star
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	local function sq(rot: number, color: Color3, scale: number): Frame
		local f = box(holder, color, UDim2.fromScale(scale, scale), UDim2.fromScale(0.5, 0.5), 2)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Rotation = rot
		return f
	end
	sq(0, NAVY, 0.84)
	sq(45, NAVY, 0.84)
	local a, b = sq(0, Color3.new(1, 1, 1), 0.66), sq(45, Color3.new(1, 1, 1), 0.66)
	local grads = { gradient(a, Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1)) }
	table.insert(grads, gradient(b, Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1)))
	return { fill = { a, b }, grad = grads }
end

function MatchNameTag.attach(
	tag: BillboardGui,
	plain: GuiObject,
	model: Model,
	name: string
): Handle
	local id = tonumber(string.match(model.Name, "^Car_(%-?%d+)$")) or 0
	local conns: { RBXScriptConnection } = {}
	local alive = true

	local root = Instance.new("Frame")
	root.Name = "MatchTag"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = tag
	local scale = Instance.new("UIScale")
	scale.Scale = SCALE
	scale.Parent = root

	-- row 1 (y 10..30): the star and the name, centered
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Position = UDim2.fromOffset(0, 10)
	row.Parent = root
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local star = starShape(row, "Star", 24)
	local starHolder = star.fill[1].Parent :: Frame
	starHolder.LayoutOrder = 1
	local levelLabel = Instance.new("TextLabel")
	levelLabel.BackgroundTransparency = 1
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.Position = UDim2.fromOffset(0, 1)
	levelLabel.Font = Enum.Font.FredokaOne
	levelLabel.TextSize = 11
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	levelLabel.Text = ""
	levelLabel.Parent = starHolder
	local lvStroke = Instance.new("UIStroke")
	lvStroke.Color = NAVY
	lvStroke.Thickness = 1.5
	lvStroke.Parent = levelLabel
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.Size = UDim2.fromOffset(0, 20)
	nameLabel.LayoutOrder = 2
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = Look.shortName(name)
	nameLabel.Parent = row
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = NAVY
	nameStroke.Thickness = 2.5
	nameStroke.Parent = nameLabel

	-- the crown (over the star)
	local crown = Instance.new("Frame")
	crown.Name = "Crown"
	crown.BackgroundTransparency = 1
	crown.Size = UDim2.fromOffset(20, 10)
	crown.Position = UDim2.fromOffset(0, 0)
	crown.Visible = false
	crown.Parent = root
	box(crown, GOLD, UDim2.new(1, 0, 0, 4), UDim2.fromOffset(0, 6), 1)
	for i = 0, 2 do
		local tip = box(crown, GOLD, UDim2.fromOffset(6, 6), UDim2.fromOffset(i * 7, 1), 1)
		tip.Rotation = 45
	end

	-- row 2 (y 34..46): the bar with its heart, and the shield
	local trackW = 54
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(trackW + 40, 12)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 34)
	bar.Parent = root
	local trackAt = UDim2.new(0.5, -trackW / 2, 0, 1)
	local track = box(bar, TRACK, UDim2.fromOffset(trackW, 10), trackAt, 5)
	track.ClipsDescendants = true
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = NAVY
	trackStroke.Thickness = 2
	trackStroke.Parent = track
	local ghost = box(track, GOLD, UDim2.fromScale(1, 1), nil, 5)
	ghost.ZIndex = 1
	local fill = box(track, Color3.new(1, 1, 1), UDim2.fromScale(1, 1), nil, 5)
	fill.ZIndex = 2
	local fillGrad = gradient(fill, LIME_TOP, LIME_MID, LIME_END)
	local shine = box(fill, Color3.new(1, 1, 1), UDim2.new(1, -6, 0, 2), UDim2.fromOffset(3, 1), 1)
	shine.BackgroundTransparency = 0.35
	for _, at in { 0.25, 0.5, 0.75 } do
		local t = box(track, NAVY, UDim2.new(0, 1, 1, 0), UDim2.fromScale(at, 0))
		t.BackgroundTransparency = 0.45
		t.ZIndex = 3
	end
	-- the heart on the bar's left end: two circles over a turned square
	local heart = Instance.new("Frame")
	heart.BackgroundTransparency = 1
	heart.Size = UDim2.fromOffset(14, 13)
	heart.Position = UDim2.new(0.5, -trackW / 2 - 9, 0, 0)
	heart.ZIndex = 4
	heart.Parent = bar
	local red = Color3.fromRGB(235, 40, 60)
	for _, spec in {
		{ Vector2.new(0.28, 0.32), 0.58, 0 },
		{ Vector2.new(0.72, 0.32), 0.58, 0 },
		{ Vector2.new(0.5, 0.55), 0.5, 45 },
	} do
		local at = UDim2.fromScale(spec[1].X, spec[1].Y)
		local p = box(heart, red, UDim2.fromScale(spec[2], spec[2]), at, 6)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Rotation = spec[3]
		p.ZIndex = 4
	end
	local shieldAt = UDim2.new(0.5, trackW / 2 + 5, 0, 0)
	local shield = box(bar, SHIELD_BLUE, UDim2.fromOffset(11, 13), shieldAt, 4)
	shield.Visible = false
	local shieldStroke = Instance.new("UIStroke")
	shieldStroke.Color = NAVY
	shieldStroke.Thickness = 1.5
	shieldStroke.Parent = shield

	-- row 3 (y 48..60): FROZEN
	local pill = Instance.new("TextLabel")
	pill.BackgroundColor3 = Color3.fromRGB(47, 134, 224)
	pill.Size = UDim2.fromOffset(52, 13)
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 48)
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = 10
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.Text = "FROZEN"
	pill.Visible = false
	pill.Parent = root
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 6)
	pc.Parent = pill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = NAVY
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pill

	-- ===== state =====
	local frac = 1
	local shielded, frozen = false, false
	local low = false
	local throb: Tween? = nil

	local function look()
		-- the bar's colors and glow from the state (frozen over low over normal)
		local top, mid, bottom = LIME_TOP, LIME_MID, LIME_END
		local edge = NAVY
		if frozen then
			top, mid, bottom = ICE_TOP, ICE_MID, ICE_END
			edge = Color3.fromRGB(191, 240, 255)
		elseif low then
			top, mid, bottom = RED_TOP, RED_MID, RED_END
		elseif shielded then
			edge = SHIELD_BLUE
		end
		fillGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(0.55, mid),
			ColorSequenceKeypoint.new(1, bottom),
		})
		trackStroke.Color = edge
		shield.Visible = shielded
		pill.Visible = frozen
		local wantThrob = low and not frozen
		if wantThrob and not throb then
			trackStroke.Thickness = 2
			local t = TweenService:Create(
				trackStroke,
				TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 3.5, Color = Color3.fromRGB(255, 70, 50) }
			)
			throb = t
			t:Play()
		elseif not wantThrob and throb then
			throb:Cancel()
			throb = nil
			trackStroke.Thickness = 2
		end
	end

	local function setHealth(h: number?)
		local f = Look.fraction(h, Match.HEALTH)
		local was = frac
		frac = f
		low = Look.isLow(f)
		local out, quad = Enum.EasingDirection.Out, Enum.EasingStyle.Quad
		fill:TweenSize(UDim2.fromScale(f, 1), out, quad, 0.18, true)
		if f < was then
			-- a hit: the gold chunk stays where it was, then slides down to the new health
			ghost.Size = UDim2.fromScale(was, 1)
			TweenService:Create(
				ghost,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25),
				{ Size = UDim2.fromScale(f, 1) }
			):Play()
			local from = nameLabel.TextColor3
			nameLabel.TextColor3 = Color3.fromRGB(255, 138, 122)
			TweenService:Create(nameLabel, TweenInfo.new(0.3), { TextColor3 = from }):Play()
		else
			ghost.Size = UDim2.fromScale(f, 1)
		end
		look()
	end

	local function setLevel(lv: number?)
		local tier = Look.tier(lv)
		local top, bottom = rgb(Look.STAR[tier][1]), rgb(Look.STAR[tier][2])
		for i, g in star.grad do
			g.Color = ColorSequence.new(top, bottom)
			star.fill[i].BackgroundColor3 = Color3.new(1, 1, 1)
		end
		levelLabel.Text = if type(lv) == "number" then tostring(math.floor(lv)) else ""
		starHolder.Visible = type(lv) == "number"
	end

	local function reposition()
		-- the crown sits over the star wherever the centered row put it
		local sx = starHolder.AbsolutePosition.X - root.AbsolutePosition.X
		crown.Position = UDim2.fromOffset(sx / SCALE + 2, 0)
	end
	table.insert(conns, starHolder:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition))
	table.insert(conns, nameLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition))

	local function setShield()
		local p = Players:GetPlayerByUserId(id)
		shielded = p ~= nil and p:GetAttribute("Shield") == true
		look()
	end
	local function setFrozen()
		frozen = model:GetAttribute("Frozen") == true
			or (model:GetAttribute("Smashed") == true and model:GetAttribute("Wrecked") ~= true)
		look()
	end

	-- ===== binding (the MatchBoard row appears when the round starts) =====
	local bound = false
	local function bind()
		if bound then
			return true
		end
		local board = ReplicatedStorage:FindFirstChild("MatchBoard")
		local row = board and board:FindFirstChild(tostring(id))
		if not row then
			return false
		end
		bound = true
		setHealth(row:GetAttribute("Health") :: any)
		local lv = row:GetAttribute("Level")
		if type(lv) ~= "number" then
			local p = Players:GetPlayerByUserId(id)
			lv = p and p:GetAttribute("Level")
		end
		setLevel(lv :: any)
		table.insert(
			conns,
			row:GetAttributeChangedSignal("Health"):Connect(function()
				setHealth(row:GetAttribute("Health") :: any)
			end)
		)
		table.insert(
			conns,
			row:GetAttributeChangedSignal("Level"):Connect(function()
				setLevel(row:GetAttribute("Level") :: any)
			end)
		)
		return true
	end
	local p = Players:GetPlayerByUserId(id)
	if p then
		table.insert(conns, p:GetAttributeChangedSignal("Shield"):Connect(setShield))
	end
	for _, a in { "Frozen", "Smashed", "Wrecked" } do
		table.insert(conns, model:GetAttributeChangedSignal(a):Connect(setFrozen))
	end
	setShield()
	setFrozen()
	setLevel(nil)

	local handle: Handle
	local function show(on: boolean)
		root.Visible = on
		plain.Visible = not on
		if on then
			tag.Size = SIZE
			if not bound then
				task.spawn(function()
					-- (the row comes a moment after the round starts: look for it a few seconds)
					for _ = 1, 40 do
						if not alive or bind() then
							break
						end
						task.wait(0.5)
					end
				end)
			end
		end
	end
	handle = {
		id = id,
		setLeader = function(on: boolean)
			crown.Visible = on
		end,
		show = show,
		destroy = function()
			alive = false
			handles[handle] = nil
			for _, c in conns do
				c:Disconnect()
			end
			if throb then
				throb:Cancel()
			end
			root:Destroy()
		end,
	}
	handles[handle] = true
	MatchNameTag.watchBoard()
	return handle
end

-- every kart's smashes, the leaders (the crown), updated on any board change
local function refreshLeaders()
	local board = ReplicatedStorage:FindFirstChild("MatchBoard")
	if not board then
		return
	end
	local smashes: { [number]: number } = {}
	for _, row in board:GetChildren() do
		local id = tonumber(row.Name)
		local n = row:GetAttribute("Smashes")
		if id and type(n) == "number" then
			smashes[id] = n
		end
	end
	local lead = Look.leaders(smashes)
	for h in handles do
		h.setLeader(lead[h.id] == true)
	end
end

function MatchNameTag.watchBoard()
	if watching then
		return
	end
	watching = true
	task.spawn(function()
		local board = ReplicatedStorage:WaitForChild("MatchBoard")
		local function hook(row: Instance)
			row:GetAttributeChangedSignal("Smashes"):Connect(refreshLeaders)
			refreshLeaders()
		end
		for _, row in board:GetChildren() do
			hook(row)
		end
		board.ChildAdded:Connect(hook)
		board.ChildRemoved:Connect(refreshLeaders)
	end)
end

return MatchNameTag
