--!strict
-- Screens, camera and driving controls for the 1v1 battle. The server runs everything; this shows what it
-- sends (BattleUpdate) and sends back taps (BattleAction): queue, select, lock, rematch, leave, attack.
-- You drive your own car (stick or WASD, via SteerInput) and press ATTACK (button, Space, E or F).
-- Layout uses scale sizes with size limits, so it works on phones and desktops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SteerInput = require(script.Parent.SteerInput)
local BattleFx = require(script.Parent.BattleFx)
local SoundFx = require(script.Parent.SoundFx)
local UserInputService = game:GetService("UserInputService")

local BattleUi = {}

local FONT = Enum.Font.GothamBold
local COL_ME = Color3.fromRGB(70, 150, 255)
local COL_OPP = Color3.fromRGB(255, 140, 60)
local COL_PANEL = Color3.fromRGB(20, 24, 40)
local COL_GOOD = Color3.fromRGB(80, 210, 120)
local COL_BAD = Color3.fromRGB(240, 90, 90)
local COL_TEXT = Color3.fromRGB(245, 247, 255)
local CHAMPIONS_GUIS = { "CVC_Champions", "CVC_ChampionsDim", "CVC_ChampionsHud" }

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
end

local function frame(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	color: Color3?,
	alpha: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or COL_PANEL
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3?,
	maxText: number?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = text
	l.TextColor3 = color or COL_TEXT
	l.TextScaled = true
	l.TextWrapped = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText or 28
	c.MinTextSize = 8
	c.Parent = l
	l.Parent = parent
	return l
end

local function button(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	onTap: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Font = FONT
	b.Text = text
	b.TextColor3 = COL_TEXT
	b.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 26
	c.MinTextSize = 8
	c.Parent = b
	corner(b, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.Parent = b
	b.Activated:Connect(onTap)
	b.Parent = parent
	return b
end

local function clock(sec: number): string
	local s = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", s // 60, s % 60)
end

function BattleUi.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = Remotes.get()
	local function act(name: string, arg: any)
		remotes.BattleAction:FireServer(name, arg)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BattleUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- ---------- queue ----------
	local queueF =
		frame(gui, "Queue", UDim2.fromScale(0.5, 0.26), UDim2.fromScale(0.5, 0.5), COL_PANEL, 0.1)
	queueF.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(queueF, 16)
	local qLimit = Instance.new("UISizeConstraint")
	qLimit.MaxSize = Vector2.new(460, 220)
	qLimit.MinSize = Vector2.new(260, 150)
	qLimit.Parent = queueF
	local qText = label(
		queueF,
		"Searching for opponent",
		UDim2.fromScale(0.9, 0.3),
		UDim2.fromScale(0.05, 0.08),
		COL_TEXT,
		30
	)
	button(
		queueF,
		"CANCEL",
		UDim2.fromScale(0.44, 0.26),
		UDim2.fromScale(0.05, 0.66),
		COL_BAD,
		function()
			act("cancel")
		end
	)
	local botBtn = button(
		queueF,
		"TEST BOT",
		UDim2.fromScale(0.44, 0.2),
		UDim2.fromScale(0.51, 0.46),
		Color3.fromRGB(110, 110, 130),
		function()
			act("queueBot")
		end
	)
	queueF.Visible = false

	-- DEV BOT: a small lobby button that starts a fight against a bot right away. The server
	-- only turns the "DevBot" attribute on for Studio, the game owner and listed dev ids.
	local devBtn = button(
		gui,
		"DEV: PLAY BOT",
		UDim2.fromScale(0.16, 0.06),
		UDim2.fromScale(0.01, 0.9),
		Color3.fromRGB(110, 110, 130),
		function()
			act("queueBot")
		end
	)
	devBtn.Visible = false

	-- ---------- select ----------
	local selectF = frame(
		gui,
		"Select",
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		Color3.fromRGB(12, 14, 26),
		0.08
	)
	selectF.Visible = false
	local selHead =
		label(selectF, "", UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.05, 0.02), COL_TEXT, 30)
	local selTimer =
		label(selectF, "", UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.78, 0.02), COL_GOOD, 34)
	label(
		selectF,
		BattleConfig.Text.chooseLine,
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.05, 0.1),
		COL_TEXT,
		22
	)
	label(
		selectF,
		BattleConfig.Text.rulesLine,
		UDim2.fromScale(0.9, 0.045),
		UDim2.fromScale(0.05, 0.15),
		Color3.fromRGB(190, 200, 225),
		18
	)
	local cardsF = frame(
		selectF,
		"Cards",
		UDim2.fromScale(0.96, 0.43),
		UDim2.fromScale(0.02, 0.2),
		COL_PANEL,
		1
	)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.015, 0)
	list.Parent = cardsF
	local lockBtn: TextButton
	label(
		selectF,
		BattleConfig.Text.upgradesLine,
		UDim2.fromScale(0.6, 0.04),
		UDim2.fromScale(0.02, 0.93),
		Color3.fromRGB(160, 170, 195),
		16
	)
	local coinsLbl = label(
		selectF,
		"",
		UDim2.fromScale(0.3, 0.04),
		UDim2.fromScale(0.02, 0.885),
		Color3.fromRGB(255, 215, 90),
		20
	)

	type Card = {
		root: Frame,
		stroke: UIStroke,
		state: TextLabel,
		id: string,
	}
	local cards: { [string]: Card } = {}
	local selectedId: string? = nil
	local locked = false
	local choiceState: { [string]: any } = {}
	local selectEnd = 0

	local function previewInto(vp: ViewportFrame, f: BattleConfig.Fighter, holder: Frame)
		local models = ReplicatedStorage:FindFirstChild("BattleModels")
		local src = if models then models:FindFirstChild(f.model) else nil
		if src == nil or not src:IsA("Model") then
			vp:Destroy()
			label(
				holder,
				"Model missing",
				UDim2.fromScale(0.9, 0.2),
				UDim2.fromScale(0.05, 0.4),
				COL_BAD,
				20
			)
			return
		end
		local clone = src:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local world = Instance.new("WorldModel")
		world.Parent = vp
		clone.Parent = world
		vp.Ambient = Color3.fromRGB(190, 190, 200)
		vp.LightColor = Color3.fromRGB(255, 255, 255)
		vp.LightDirection = Vector3.new(-1, -2, -1)
		local cf, size = clone:GetBoundingBox()
		local cam = Instance.new("Camera")
		local dist = size.Magnitude * 1.1
		cam.CFrame =
			CFrame.lookAt(cf.Position + Vector3.new(-0.75, 0.5, -1) * dist * 0.8, cf.Position)
		cam.FieldOfView = 40
		vp.CurrentCamera = cam
		cam.Parent = vp
	end

	local function buildCards()
		for _, id in BattleConfig.Order do
			local f = BattleConfig.Fighters[id]
			local root =
				frame(cardsF, id, UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), COL_PANEL, 0.05)
			corner(root, 14)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(70, 76, 100)
			stroke.Parent = root
			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.fromScale(0.94, 0.4)
			vp.Position = UDim2.fromScale(0.03, 0.02)
			vp.BackgroundColor3 = Color3.fromRGB(34, 40, 62)
			vp.BorderSizePixel = 0
			vp.Parent = root
			corner(vp, 10)
			previewInto(vp, f, root)
			label(
				root,
				f.name,
				UDim2.fromScale(0.94, 0.09),
				UDim2.fromScale(0.03, 0.43),
				COL_TEXT,
				26
			)
			local st = label(
				root,
				"",
				UDim2.fromScale(0.94, 0.07),
				UDim2.fromScale(0.03, 0.52),
				COL_GOOD,
				18
			)
			label(
				root,
				f.weaponName .. ": " .. f.blurb,
				UDim2.fromScale(0.94, 0.14),
				UDim2.fromScale(0.03, 0.6),
				COL_TEXT,
				16
			)
			label(
				root,
				"Weakness: " .. f.weakness,
				UDim2.fromScale(0.94, 0.13),
				UDim2.fromScale(0.03, 0.74),
				Color3.fromRGB(255, 170, 130),
				15
			)
			label(
				root,
				`HP {f.hp}`,
				UDim2.fromScale(0.3, 0.06),
				UDim2.fromScale(0.03, 0.89),
				Color3.fromRGB(190, 200, 225),
				15
			)
			local tap = Instance.new("TextButton")
			tap.BackgroundTransparency = 1
			tap.Text = ""
			tap.Size = UDim2.fromScale(1, 0.86)
			tap.Parent = root
			tap.Activated:Connect(function()
				local c = choiceState[id]
				if c and c.selectable and not locked then
					selectedId = id
					act("select", id)
				end
			end)
			cards[id] = { root = root, stroke = stroke, state = st, id = id }
		end
	end

	local function refreshCards()
		for id, card in cards do
			local c = choiceState[id]
			local f = BattleConfig.Fighters[id]
			local text, color = "", COL_GOOD
			if c == nil or not f.enabled then
				text, color = "COMING SOON", Color3.fromRGB(150, 150, 160)
			elseif c.state == "owned" then
				text = "OWNED"
			elseif c.state == "loaner" then
				text, color = "LOANER", Color3.fromRGB(255, 215, 90)
			elseif c.state == "test" then
				text, color = "TEST", Color3.fromRGB(190, 140, 255)
			else
				text, color = "LOCKED  Gumball machine", COL_BAD
			end
			card.state.Text = text
			card.state.TextColor3 = color
			card.root.BackgroundTransparency = if c and c.selectable then 0.05 else 0.35
			card.stroke.Color = if selectedId == id then COL_GOOD else Color3.fromRGB(70, 76, 100)
			card.stroke.Thickness = if selectedId == id then 5 else 3
		end
	end

	lockBtn = button(
		selectF,
		"LOCK IN",
		UDim2.fromScale(0.28, 0.08),
		UDim2.fromScale(0.7, 0.88),
		COL_GOOD,
		function()
			if not locked then
				act("lock")
			end
		end
	)

	-- ---------- prep: just the big 3-2-1 number, nothing else on screen ----------
	local prepF = frame(
		gui,
		"Prep",
		UDim2.fromScale(0.3, 0.22),
		UDim2.fromScale(0.35, 0.14),
		Color3.fromRGB(10, 12, 22),
		1
	)
	prepF.Visible = false
	local prepCount = label(prepF, "3", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), COL_TEXT, 110)
	prepCount.TextStrokeTransparency = 0
	prepCount.TextStrokeColor3 = Color3.fromRGB(10, 12, 22)

	-- ---------- fight HUD ----------
	local hudF = frame(gui, "Hud", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0), COL_PANEL, 1)
	hudF.Visible = false
	type Side = { name: TextLabel, hp: Frame, hpText: TextLabel, ready: Frame }
	local function sidePanel(xScale: number, color: Color3, mirror: boolean): Side
		local p = frame(
			hudF,
			"Side",
			UDim2.fromScale(0.36, 0.78),
			UDim2.fromScale(xScale, 0.08),
			COL_PANEL,
			0.2
		)
		corner(p, 10)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = 3
		s.Parent = p
		local nm =
			label(p, "", UDim2.fromScale(0.94, 0.32), UDim2.fromScale(0.03, 0.04), COL_TEXT, 18)
		nm.TextXAlignment = if mirror then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		local back = frame(
			p,
			"HpBack",
			UDim2.fromScale(0.94, 0.3),
			UDim2.fromScale(0.03, 0.38),
			Color3.fromRGB(50, 54, 74),
			0
		)
		corner(back, 6)
		local fill = frame(back, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0)
		corner(fill, 6)
		fill.AnchorPoint = if mirror then Vector2.new(1, 0) else Vector2.new(0, 0)
		if mirror then
			fill.Position = UDim2.fromScale(1, 0)
		end
		local txt = label(back, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), COL_TEXT, 16)
		local rb = frame(
			p,
			"ReadyBack",
			UDim2.fromScale(0.5, 0.13),
			UDim2.fromScale(if mirror then 0.47 else 0.03, 0.74),
			Color3.fromRGB(50, 54, 74),
			0
		)
		corner(rb, 5)
		local rf = frame(
			rb,
			"Fill",
			UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0),
			Color3.fromRGB(255, 220, 90),
			0
		)
		corner(rf, 5)
		local rl = label(
			p,
			"WEAPON",
			UDim2.fromScale(0.3, 0.16),
			UDim2.fromScale(if mirror then 0.03 else 0.55, 0.72),
			Color3.fromRGB(190, 200, 225),
			12
		)
		rl.TextXAlignment = if mirror then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		return { name = nm, hp = fill, hpText = txt, ready = rf }
	end
	local hudMe = sidePanel(0.01, COL_ME, false)
	local hudOpp = sidePanel(0.63, COL_OPP, true)
	local hudMid =
		frame(hudF, "Mid", UDim2.fromScale(0.22, 0.78), UDim2.fromScale(0.39, 0.08), COL_PANEL, 0.2)
	corner(hudMid, 10)
	local midRound =
		label(hudMid, "", UDim2.fromScale(0.94, 0.3), UDim2.fromScale(0.03, 0.04), COL_TEXT, 16)
	local midScore =
		label(hudMid, "", UDim2.fromScale(0.94, 0.36), UDim2.fromScale(0.03, 0.34), COL_TEXT, 26)
	local midTime =
		label(hudMid, "", UDim2.fromScale(0.94, 0.28), UDim2.fromScale(0.03, 0.7), COL_GOOD, 18)
	local eventL =
		label(gui, "", UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.25, 0.22), COL_TEXT, 24)
	eventL.TextStrokeTransparency = 0.3
	eventL.Visible = false
	local lastEventText, lastEventAt, eventToken = "", 0, 0

	-- leave (with confirmation)
	local leaveBtn = button(
		gui,
		"LEAVE",
		UDim2.fromScale(0.12, 0.06),
		UDim2.fromScale(0.01, 0.175),
		Color3.fromRGB(120, 60, 60),
		function() end
	)
	leaveBtn.Visible = false
	local confirmF =
		frame(gui, "Confirm", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.5, 0.5), COL_PANEL, 0.05)
	confirmF.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmF.ZIndex = 10
	corner(confirmF, 16)
	label(
		confirmF,
		"Leave the match? Your opponent wins.",
		UDim2.fromScale(0.9, 0.38),
		UDim2.fromScale(0.05, 0.08),
		COL_TEXT,
		26
	)
	button(
		confirmF,
		"STAY",
		UDim2.fromScale(0.4, 0.3),
		UDim2.fromScale(0.05, 0.6),
		COL_GOOD,
		function()
			confirmF.Visible = false
		end
	)
	button(
		confirmF,
		"LEAVE",
		UDim2.fromScale(0.4, 0.3),
		UDim2.fromScale(0.55, 0.6),
		COL_BAD,
		function()
			confirmF.Visible = false
			act("leave")
		end
	)
	confirmF.Visible = false
	leaveBtn.Activated:Connect(function()
		confirmF.Visible = true
	end)

	-- ---------- round result ----------
	local roundF =
		frame(gui, "Round", UDim2.fromScale(0.6, 0.3), UDim2.fromScale(0.5, 0.4), COL_PANEL, 0.1)
	roundF.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(roundF, 16)
	local roundLimit = Instance.new("UISizeConstraint")
	roundLimit.MaxSize = Vector2.new(560, 230)
	roundLimit.Parent = roundF
	local roundTitle =
		label(roundF, "", UDim2.fromScale(0.94, 0.28), UDim2.fromScale(0.03, 0.04), COL_TEXT, 34)
	local roundScore =
		label(roundF, "", UDim2.fromScale(0.94, 0.16), UDim2.fromScale(0.03, 0.33), COL_TEXT, 22)
	local roundRecap = label(
		roundF,
		"",
		UDim2.fromScale(0.94, 0.3),
		UDim2.fromScale(0.03, 0.5),
		Color3.fromRGB(255, 225, 150),
		20
	)
	local roundNext = label(
		roundF,
		"",
		UDim2.fromScale(0.94, 0.15),
		UDim2.fromScale(0.03, 0.83),
		Color3.fromRGB(190, 200, 225),
		16
	)
	roundF.Visible = false

	-- ---------- match result ----------
	local resF =
		frame(gui, "Result", UDim2.fromScale(0.6, 0.62), UDim2.fromScale(0.5, 0.5), COL_PANEL, 0.04)
	resF.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(resF, 18)
	local resLimit = Instance.new("UISizeConstraint")
	resLimit.MaxSize = Vector2.new(640, 460)
	resLimit.MinSize = Vector2.new(280, 300)
	resLimit.Parent = resF
	local resTitle =
		label(resF, "", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.03), COL_TEXT, 80)
	local resScore =
		label(resF, "", UDim2.fromScale(0.9, 0.11), UDim2.fromScale(0.05, 0.25), COL_TEXT, 26)
	local resWhy = label(
		resF,
		"",
		UDim2.fromScale(0.9, 0.09),
		UDim2.fromScale(0.05, 0.37),
		Color3.fromRGB(255, 200, 140),
		18
	)
	local resCoins = label(
		resF,
		"",
		UDim2.fromScale(0.9, 0.12),
		UDim2.fromScale(0.05, 0.47),
		Color3.fromRGB(255, 215, 90),
		24
	)
	local resNote = label(
		resF,
		"",
		UDim2.fromScale(0.9, 0.08),
		UDim2.fromScale(0.05, 0.6),
		Color3.fromRGB(190, 200, 225),
		16
	)
	local rematchBtn = button(
		resF,
		"REMATCH",
		UDim2.fromScale(0.42, 0.18),
		UDim2.fromScale(0.05, 0.76),
		COL_GOOD,
		function()
			act("rematch")
		end
	)
	button(
		resF,
		"RETURN TO GARAGE",
		UDim2.fromScale(0.46, 0.18),
		UDim2.fromScale(0.49, 0.76),
		Color3.fromRGB(90, 100, 140),
		function()
			act("leave")
		end
	)
	resF.Visible = false

	local errorL =
		label(gui, "", UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.45), COL_BAD, 22)
	errorL.Visible = false

	-- ---------- camera ----------
	local camera = workspace.CurrentCamera
	local arenaCenter: Vector3? = nil
	local arenaHalf = Vector2.zero
	local camOn = false
	local camSmooth: CFrame? = nil
	local mySpawn: string? = nil -- which end my car starts at this round ("a" west / "b" east)
	local flyStart = -100 -- when the spawn fly-over began
	local flying = false -- the fly-over is steering the camera right now
	local shakeAmp = 0 -- camera shake, studs; decays by itself
	local fovKick = 0 -- extra field of view from a big hit; eases back by itself
	-- the final wreck: the camera swings round the wreck for a moment, between two black bars
	local koT, koTotal = 0, 1
	local koPos: Vector3? = nil
	local bars: { Frame } = {}
	for i = 1, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "KoBar"
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 0)
		bar.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		bar.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		bar.ZIndex = 20
		bar.Visible = false
		bar.Parent = gui
		bars[i] = bar
	end
	local function setBars(on: boolean)
		for _, bar in bars do
			if on then
				bar.Visible = true
			end
			local t = TweenService:Create(
				bar,
				TweenInfo.new(0.35),
				{ Size = UDim2.fromScale(1, if on then 0.11 else 0) }
			)
			t:Play()
			if not on then
				task.delay(0.4, function()
					if bar.Size.Y.Scale < 0.01 then
						bar.Visible = false
					end
				end)
			end
		end
	end

	-- the two cars of my arena (found by their side attribute near the arena middle)
	local carBodies: { BasePart } = {}
	local carScanT = 0
	local mySide: string? = nil -- which car is mine ("a" / "b"), from the prep message
	local myFighter: string? = nil
	local myBody: BasePart? = nil
	local function scanCars()
		local c = arenaCenter
		carBodies = {}
		myBody = nil
		if c == nil then
			return
		end
		for _, folder in workspace:GetChildren() do
			if folder:IsA("Folder") and string.sub(folder.Name, 1, 12) == "BattleArena_" then
				for _, m in folder:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("BattleSide") ~= nil then
						local body = m:FindFirstChild("Body")
						if
							body
							and body:IsA("BasePart")
							and (body.Position - c).Magnitude < arenaHalf.Magnitude * 1.5
						then
							table.insert(carBodies, body)
							if mySide ~= nil and m:GetAttribute("BattleSide") == mySide then
								myBody = body
							end
						end
					end
				end
			end
		end
	end

	local carLen = 16
	local function cruiseSpeed(): number
		return BattleConfig.fighter("RamTruck").cruiseL * carLen
	end
	local fx = BattleFx.new({
		shake = function(amp: number)
			shakeAmp = math.max(shakeAmp, amp)
		end,
		cruise = cruiseSpeed(),
	})
	local function chaseTarget(): CFrame?
		local c = arenaCenter
		if c == nil then
			return nil
		end
		local mine = myBody
		if mine ~= nil and mine.Parent ~= nil then
			-- chase view: behind my own car, looking where it points
			local H = BattleConfig.Human
			local lv = mine.CFrame.LookVector
			local look = Vector3.new(lv.X, 0, lv.Z)
			if look.Magnitude > 1e-3 then
				look = look.Unit
				local focus = mine.Position + Vector3.new(0, 0.3 * carLen, 0)
				local want = focus
					- look * (H.camDistL * carLen)
					+ Vector3.new(0, H.camHeightL * carLen, 0)
				-- and always stay INSIDE the arena walls: a camera above a low wall would look
				-- over it and the wall would hide the car (a car that starts next to a wall)
				local inset = 9
				want = Vector3.new(
					math.clamp(want.X, c.X - arenaHalf.X + inset, c.X + arenaHalf.X - inset),
					want.Y,
					math.clamp(want.Z, c.Z - arenaHalf.Y + inset, c.Z + arenaHalf.Y - inset)
				)
				-- then pull it in where something (a wall, furniture) is in the way, after the clamp so the clamp cannot push it back inside
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				local skip: { Instance } = {}
				for _, b in carBodies do
					if b.Parent then
						table.insert(skip, b.Parent)
					end
				end
				params.FilterDescendantsInstances = skip
				local hit = workspace:Raycast(focus, want - focus, params)
				if hit then
					want = hit.Position + hit.Normal * 1.5
				end
				return CFrame.lookAt(want, mine.Position + look * (H.camLookL * carLen))
			end
		end
		local cc = BattleConfig.Camera
		local pitch = math.rad(cc.pitchDeg)
		local vp = camera.ViewportSize
		local aspect = math.max(vp.X / math.max(vp.Y, 1), 0.3)
		local vHalf = math.rad(cc.fovDeg) / 2
		local hHalf = math.atan(math.tan(vHalf) * aspect)
		local focus = Vector3.new(c.X, c.Y, c.Z)
		local halfW, halfD
		if #carBodies >= 2 then
			local p1, p2 = carBodies[1].Position, carBodies[2].Position
			local mid = (p1 + p2) / 2
			local gapX, gapZ = math.abs(p1.X - p2.X), math.abs(p1.Z - p2.Z)
			focus = Vector3.new(
				math.clamp(mid.X, c.X - arenaHalf.X, c.X + arenaHalf.X),
				c.Y,
				math.clamp(mid.Z, c.Z - arenaHalf.Y, c.Z + arenaHalf.Y)
			)
			halfW = math.max(cc.minHalfL * carLen, gapX / 2 + cc.marginL * carLen)
			halfD = math.max(cc.minHalfL * carLen * 0.7, gapZ / 2 + cc.marginL * carLen)
		else
			halfW = arenaHalf.X * cc.padding
			halfD = arenaHalf.Y * cc.padding
		end
		local needW = halfW / math.tan(hHalf)
		local needH = (halfD * math.sin(pitch) + 6 * math.cos(pitch)) / math.tan(vHalf)
		local dist = math.max(needW, needH, 40)
		local pos = focus + Vector3.new(0, math.sin(pitch), math.cos(pitch)) * dist
		return CFrame.lookAt(pos, focus)
	end

	-- The first FLY_SECONDS of every round: my garage, then theirs, then swooping in behind my car.
	local FLY_SECONDS = 2
	local GARAGE_X = 102 -- garage centers, from the arena middle (mouths face the arena)
	local function garageShot(c: Vector3, spawn: string, grow: number): CFrame
		local dir = if spawn == "a" then 1 else -1
		local gx = c.X - dir * GARAGE_X
		local at = Vector3.new(gx, c.Y + 6, c.Z)
		local pos = Vector3.new(gx + dir * (46 - 8 * grow), c.Y + 14 - 2 * grow, c.Z + 16)
		return CFrame.lookAt(pos, at)
	end
	local function cameraTarget(): CFrame?
		local chase = chaseTarget()
		local c = arenaCenter
		local sp = mySpawn
		local t = os.clock() - flyStart
		flying = false
		if c == nil or sp == nil or t >= FLY_SECONDS then
			return chase
		end
		flying = true
		local other = if sp == "a" then "b" else "a"
		local half = FLY_SECONDS * 0.35
		if t < half then
			return garageShot(c, sp, t / half)
		elseif t < 2 * half then
			return garageShot(c, other, (t - half) / half)
		end
		local last = garageShot(c, other, 1)
		if chase == nil then
			return last
		end
		local k = math.clamp((t - 2 * half) / (FLY_SECONDS - 2 * half), 0, 1)
		return last:Lerp(chase, k * k * (3 - 2 * k))
	end

	local function cameraOn()
		if camOn then
			return
		end
		camOn = true
		carScanT = 0
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = BattleConfig.Camera.fovDeg
		camSmooth = nil
	end

	local function cameraOff()
		if not camOn then
			return
		end
		camOn = false
		camSmooth = nil
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local hum = if player.Character
			then player.Character:FindFirstChildOfClass("Humanoid")
			else nil
		if hum then
			camera.CameraSubject = hum
		end
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if not camOn then
			return
		end
		carScanT -= dt
		if carScanT <= 0 then
			carScanT = 0.5
			scanCars()
		end
		-- effects that follow the cars (smoke, skid marks, flame, speed lines, engine sound)
		local models: { Model } = {}
		for _, b in carBodies do
			if b.Parent and b.Parent:IsA("Model") then
				table.insert(models, b.Parent)
			end
		end
		local mineModel = if myBody
				and myBody.Parent
				and myBody.Parent:IsA("Model")
			then myBody.Parent
			else nil
		fx.step(dt, models, mineModel)
		local target = cameraTarget()
		local wreck = koPos
		if koT > 0 and wreck ~= nil then
			-- final wreck: swing round it, closing in, the view narrowing
			koT -= dt
			local t = math.clamp(1 - koT / koTotal, 0, 1)
			local ang = 0.6 + t * 1.5
			local radius = 62 - 30 * t
			local at = wreck + Vector3.new(0, 3, 0)
			target = CFrame.lookAt(
				at + Vector3.new(math.sin(ang) * radius, 16 - 6 * t, math.cos(ang) * radius),
				at
			)
			camSmooth = target
		end
		if target == nil then
			return
		end
		camera = workspace.CurrentCamera
		if flying then
			camSmooth = target -- the fly-over is already smooth
		end
		local cur = camSmooth
		if cur == nil then
			cur = target
		else
			-- eased, so the camera glides after the pair instead of snapping
			local rate = if myBody ~= nil
				then BattleConfig.Human.camSmooth
				else BattleConfig.Camera.smooth
			cur = cur:Lerp(target, math.clamp(rate * dt, 0, 1))
		end
		camSmooth = cur
		local shaken = cur :: CFrame
		if shakeAmp > 0.02 then
			local r = shakeAmp
			shaken = shaken
				* CFrame.new((math.random() - 0.5) * r, (math.random() - 0.5) * r, 0)
				* CFrame.Angles(
					(math.random() - 0.5) * r * 0.012,
					(math.random() - 0.5) * r * 0.012,
					(math.random() - 0.5) * r * 0.02
				)
			shakeAmp *= math.max(0, 1 - 6 * dt)
		else
			shakeAmp = 0
		end
		camera.CFrame = shaken
		fovKick *= math.max(0, 1 - 4 * dt)
		local baseFov = if myBody ~= nil
			then BattleConfig.Human.camFov
			else BattleConfig.Camera.fovDeg
		local koFov = if koT > 0 then -20 * math.clamp(1 - koT / koTotal, 0, 1) else 0
		camera.FieldOfView = baseFov + fovKick + koFov
	end)

	-- ---------- driving: wheel stick (bottom-left), GAS (bottom-right) and ATTACK above it ----------
	local attackNames: { [string]: string } =
		{ RamTruck = "CHARGE", CannonVan = "FIRE", SawBuggy = "HOLD: SAW" }
	local steerInput = SteerInput.new(function(steer: number, gas: number)
		remotes.Steer:FireServer(steer, gas, false)
	end, {
		wheel = true,
		sendFull = function(steer: number, gas: number, attack: boolean)
			remotes.Steer:FireServer(steer, gas, attack)
		end,
	})
	local driving = false
	local attackReady = 1 -- 1 = the weapon is ready (the button is full and glows)

	-- a button that is "down" while a finger / the mouse holds it
	local function holdButton(btn: GuiButton, onDown: () -> (), onUp: () -> ())
		local held: InputObject? = nil
		btn.InputBegan:Connect(function(input: InputObject)
			if
				held == nil
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				held = input
				onDown()
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if held ~= nil and input == held then
				held = nil
				onUp()
			end
		end)
	end

	local gasWrap =
		frame(gui, "GasWrap", UDim2.fromScale(0.19, 0.3), UDim2.fromScale(0.79, 0.66), COL_PANEL, 1)
	gasWrap.Visible = false
	local gasBtn = button(
		gasWrap,
		"GAS",
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		COL_GOOD,
		function() end
	)
	holdButton(gasBtn, function()
		if driving then
			steerInput.setGas(true)
		end
	end, function()
		steerInput.setGas(false)
	end)

	local attackWrap = frame(
		gui,
		"AttackWrap",
		UDim2.fromScale(0.15, 0.24),
		UDim2.fromScale(0.81, 0.39),
		COL_PANEL,
		1
	)
	attackWrap.Visible = false
	local attackBtn = button(
		attackWrap,
		"ATTACK",
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		COL_OPP,
		function() end
	)
	-- the clock-fill: a dark cover that shrinks away as the weapon recharges (full = ready)
	local attackWipe = frame(
		attackWrap,
		"Wipe",
		UDim2.fromScale(1, 0),
		UDim2.fromScale(0, 0),
		Color3.fromRGB(10, 12, 24),
		0.35
	)
	attackWipe.ZIndex = 3
	attackWipe.Active = false
	corner(attackWipe, 12)
	local attackGlow = Instance.new("UIStroke")
	attackGlow.Color = Color3.fromRGB(255, 240, 150)
	attackGlow.Thickness = 6
	attackGlow.Transparency = 1
	attackGlow.Parent = attackBtn
	holdButton(attackBtn, function()
		if driving then
			steerInput.setAttack(true)
		end
	end, function()
		steerInput.setAttack(false)
	end)

	local helpL = label(
		gui,
		"Steer with the wheel on the left. GAS is the green button, ATTACK is above it. PC: W A S D and Space.",
		UDim2.fromScale(0.5, 0.05),
		UDim2.fromScale(0.25, 0.8),
		COL_TEXT,
		20
	)
	helpL.TextStrokeTransparency = 0.3
	helpL.Visible = false
	local helpToken = 0
	local function isAttackKey(k: Enum.KeyCode): boolean
		return k == Enum.KeyCode.Space or k == Enum.KeyCode.E or k == Enum.KeyCode.F
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if not gp and driving and isAttackKey(input.KeyCode) then
			steerInput.setAttack(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if isAttackKey(input.KeyCode) then
			steerInput.setAttack(false)
		end
	end)
	-- the READY glow pulses; the cover grows while the weapon recharges
	RunService.RenderStepped:Connect(function()
		if not driving then
			return
		end
		attackWipe.Size = UDim2.fromScale(1, 1 - math.clamp(attackReady, 0, 1))
		attackGlow.Transparency = if attackReady >= 1
			then 0.1 + 0.35 * math.abs(math.sin(os.clock() * 5))
			else 1
	end)
	local function startDriving()
		if driving then
			return
		end
		driving = true
		steerInput.start()
		attackBtn.Text = attackNames[myFighter or ""] or "ATTACK"
		attackReady = 1
		attackWrap.Visible = true
		gasWrap.Visible = true
		helpToken += 1
		local mine = helpToken
		helpL.Visible = true
		task.delay(6, function()
			if helpToken == mine then
				helpL.Visible = false
			end
		end)
	end
	local function stopDriving()
		if not driving then
			return
		end
		driving = false
		steerInput.stop()
		attackWrap.Visible = false
		gasWrap.Visible = false
		helpL.Visible = false
	end

	-- ---------- show / hide helpers ----------
	local function setChampions(on: boolean)
		for _, name in CHAMPIONS_GUIS do
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") then
				g.Enabled = on
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.4)
			local allowed = player:GetAttribute(BattleConfig.Test.devBotAttribute) == true
			local busy = queueF.Visible
				or selectF.Visible
				or prepF.Visible
				or hudF.Visible
				or roundF.Visible
				or resF.Visible
			devBtn.Visible = allowed and not busy
		end
	end)

	local function hideAll()
		stopDriving()
		koT, koPos = 0, nil
		setBars(false)
		for _, f in
			{ queueF, selectF, prepF, hudF, roundF, resF, leaveBtn, confirmF, eventL, errorL }
		do
			f.Visible = false
		end
	end

	local function endAll()
		hideAll()
		koT, koPos = 0, nil
		setBars(false)
		fx.stop()
		cameraOff()
		setChampions(true)
		arenaCenter = nil
		selectedId, locked = nil, false
	end

	local function scoreText(s: any): string
		return `{s.me} - {s.opp}`
	end

	local function sparks(pos: Vector3, big: boolean)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Position = pos
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.Speed = NumberRange.new(14, 28)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(if big then 1.4 else 0.8, 0)
		e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 120, 40))
		e.Parent = p
		p.Parent = workspace
		e:Emit(if big then 16 else 9)
		Debris:AddItem(p, 1)
	end

	-- ---------- hit juice: debris, damage numbers, shake, flash, wreck explosion ----------
	local flashF = frame(gui, "HitFlash", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), COL_BAD, 1)
	flashF.ZIndex = 20
	flashF.Visible = true
	local function flash(color: Color3, strength: number)
		flashF.BackgroundColor3 = color
		flashF.BackgroundTransparency = 1 - strength
		TweenService:Create(
			flashF,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	local DEBRIS_COLORS = {
		Color3.fromRGB(255, 200, 70),
		Color3.fromRGB(255, 120, 40),
		Color3.fromRGB(150, 155, 165),
		Color3.fromRGB(60, 60, 70),
	}
	local function debris(pos: Vector3, count: number, speed: number, floaty: boolean?)
		for _ = 1, count do
			local p = Instance.new("Part")
			local size = 0.3 + math.random() * 0.6
			p.Size = Vector3.new(size, size * 0.6, size)
			p.Color = DEBRIS_COLORS[math.random(1, #DEBRIS_COLORS)]
			p.Material = Enum.Material.SmoothPlastic
			p.CanQuery = false
			p.CanTouch = false
			p.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
				* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			local dir =
				Vector3.new(math.random() - 0.5, 0.4 + math.random() * 0.9, math.random() - 0.5)
			p.AssemblyLinearVelocity = dir.Unit * speed * (0.5 + math.random())
			p.AssemblyAngularVelocity =
				Vector3.new(math.random() * 14 - 7, math.random() * 14 - 7, math.random() * 14 - 7)
			p.Parent = workspace
			if floaty == true then
				-- slow-motion feel: most of gravity is cancelled, so the pieces hang in the air
				local att = Instance.new("Attachment")
				att.Parent = p
				local vf = Instance.new("VectorForce")
				vf.Attachment0 = att
				vf.RelativeTo = Enum.ActuatorRelativeTo.World
				vf.ApplyAtCenterOfMass = true
				vf.Force = Vector3.new(0, p.AssemblyMass * workspace.Gravity * 0.85, 0)
				vf.Parent = p
			end
			Debris:AddItem(p, if floaty == true then 2.6 else 1.6)
		end
	end

	local function damageNumber(pos: Vector3, dmg: number, big: boolean, mine: boolean)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = pos + Vector3.new(0, 4, 0)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(if big then 150 else 110, if big then 70 else 52)
		bb.AlwaysOnTop = true
		bb.Adornee = anchor
		bb.Parent = anchor
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = FONT
		t.Text = "-" .. tostring(dmg)
		t.TextScaled = true
		t.TextColor3 = if mine then COL_BAD else Color3.fromRGB(255, 225, 90)
		t.TextStrokeTransparency = 0.2
		t.Parent = bb
		anchor.Parent = workspace
		TweenService:Create(
			anchor,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = anchor.Position + Vector3.new(0, 7, 0) }
		):Play()
		TweenService:Create(
			t,
			TweenInfo.new(0.8, Enum.EasingStyle.Linear),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
		Debris:AddItem(anchor, 0.9)
	end

	-- the final blow: a fireball, a shock ring and a lot of debris
	local function wreckExplosion(pos: Vector3)
		for i = 1, 3 do
			task.delay((i - 1) * 0.08, function()
				sparks(pos + Vector3.new(0, 2, 0), true)
			end)
		end
		debris(pos, 34, 70)
		debris(pos, 22, 28, true)
		SoundFx.play("wreck")
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Material = Enum.Material.Neon
		ball.Color = Color3.fromRGB(255, 170, 50)
		ball.Transparency = 0.2
		ball.Size = Vector3.one * 4
		ball.Position = pos + Vector3.new(0, 3, 0)
		ball.Parent = workspace
		TweenService:Create(
			ball,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * 40, Transparency = 1 }
		):Play()
		Debris:AddItem(ball, 1)
		shakeAmp = math.max(shakeAmp, 7)
		fovKick = 12
		koPos, koTotal, koT = pos, BattleConfig.Timing.koSeconds, BattleConfig.Timing.koSeconds
		setBars(true)
		gui:SetAttribute("WreckCamAt", os.clock()) -- lets a test see afterwards that the wreck camera ran
		flash(Color3.fromRGB(255, 240, 200), 0.75)
	end

	local function showEvent(text: string)
		local now = os.clock()
		if text == lastEventText and now - lastEventAt < 1 then
			return -- no spam
		end
		lastEventText, lastEventAt = text, now
		eventToken += 1
		local mine = eventToken
		eventL.Text = text
		eventL.Visible = true
		task.delay(1.6, function()
			if eventToken == mine then
				eventL.Visible = false
			end
		end)
	end

	-- ---------- server messages ----------
	local prepEnd = 0
	local roundEnd = 0
	local lastScore: any = { me = 0, opp = 0 }
	local lastRound = 1
	local myName, oppName = player.DisplayName, "Opponent"

	local handlers: { [string]: (m: any) -> () } = {}

	handlers.queue = function(m)
		if m.searching then
			setChampions(false) -- hide the lobby menus behind the Searching panel
			queueF.Visible = true
			botBtn.Visible = m.studioBot == true
			qText.Text = "Finding player..."
		else
			queueF.Visible = false
			setChampions(true)
			if m.timedOut then
				errorL.Text = "No opponent found. Try again."
				errorL.Visible = true
				task.delay(3, function()
					errorL.Visible = false
				end)
			end
		end
	end

	handlers.found = function(m)
		queueF.Visible = false
		oppName = m.opp.name
		setChampions(false)
		cameraOn() -- the camera waits on the arena once the server sends its place
	end

	handlers.choices = function(m)
		choiceState = {}
		for _, c in m.choices do
			choiceState[c.id] = c
		end
		selectedId = m.selected
		coinsLbl.Text = `Coins: {m.coins}`
		refreshCards()
	end

	handlers.select = function(m)
		hideAll()
		setChampions(false)
		locked = false
		lastScore, lastRound = m.score, m.round
		oppName = m.opp.name
		if next(cards) == nil then
			buildCards()
		end
		choiceState = {}
		for _, c in m.choices do
			choiceState[c.id] = c
		end
		selectedId = m.selected or m.last
		coinsLbl.Text = `Coins: {m.coins}`
		selHead.Text = `ROUND {m.round} OF {m.rounds}    You {scoreText(m.score)} {m.opp.name}`
		selectEnd = os.clock() + m.seconds
		lockBtn.Text = "LOCK IN"
		lockBtn.BackgroundColor3 = COL_GOOD
		refreshCards()
		selectF.Visible = true
		leaveBtn.Visible = true
		-- the camera is not needed on this screen; keep the lobby view behind it
		cameraOff()
	end

	handlers.selected = function(m)
		selectedId = m.id
		if m.locked then
			locked = true
			lockBtn.Text = "LOCKED"
			lockBtn.BackgroundColor3 = Color3.fromRGB(90, 100, 130)
		end
		refreshCards()
	end

	handlers.prep = function(m)
		hideAll()
		myName = m.me.name
		oppName = m.opp.name
		mySide, myFighter, myBody = m.side, m.me.id, nil
		arenaCenter = Vector3.new(m.arena.x, m.arena.y, m.arena.z)
		arenaHalf = Vector2.new(m.arena.halfX, m.arena.halfZ)
		cameraOn()
		mySpawn = m.spawn
		flyStart = os.clock()
		camSmooth = nil
		prepEnd = os.clock() + m.seconds
		prepF.Visible = true
		leaveBtn.Visible = true
	end

	handlers.fight = function(_m)
		hideAll()
		hudF.Visible = true
		leaveBtn.Visible = true
		startDriving()
		showEvent("GO!")
		midRound.Text = `ROUND {lastRound} OF {BattleConfig.Series.rounds}`
		midScore.Text = scoreText(lastScore)
		hudMe.name.Text = myName
		hudOpp.name.Text = oppName
	end

	local function setHud(side: Side, v: any, fighterId: string?)
		local frac = math.clamp(v.hp / math.max(v.max, 1), 0, 1)
		side.hp.Size = UDim2.fromScale(frac, 1)
		side.hpText.Text = `HP {v.hp}/{v.max}`
		side.ready.Size = UDim2.fromScale(math.clamp(v.ready, 0, 1), 1)
		local _ = fighterId
	end

	handlers.hud = function(m)
		setHud(hudMe, m.me, nil)
		setHud(hudOpp, m.opp, nil)
		midTime.Text = clock(m.left)
		attackReady = m.me.ready
		attackBtn.BackgroundColor3 = if m.me.ready >= 1
			then COL_OPP
			else Color3.fromRGB(110, 90, 80)
	end

	local eventSounds: { [string]: string } =
		{ ["Charge!"] = "ramCharge", ["Fire!"] = "cannonFire" }
	handlers.event = function(m)
		local snd = eventSounds[m.text]
		if snd ~= nil then
			SoundFx.play(snd)
		end
		showEvent((if m.mine then "You: " else "Foe: ") .. m.text)
	end

	handlers.phase = function(m)
		showEvent(m.text)
	end

	handlers.hit = function(m)
		if m.ko == true then
			wreckExplosion(m.pos)
			return
		end
		local big = m.big == true
		local mine = m.victim ~= nil and m.victim == mySide
		sparks(m.pos, big)
		debris(m.pos, if big then 12 else 5, if big then 40 else 24)
		if type(m.dmg) == "number" and m.dmg > 0 then
			damageNumber(m.pos, m.dmg, big, mine)
		end
		-- a hit on YOU shakes the view harder and flashes red
		local amp = if big then 3.2 else 1.3
		shakeAmp = math.max(shakeAmp, if mine then amp * 1.5 else amp)
		fovKick = math.max(fovKick, if big then 6 else 2.5)
		SoundFx.hit(if big then 1 else 0.3)
		if mine then
			flash(COL_BAD, if big then 0.45 else 0.25)
		end
	end

	handlers.roundResult = function(m)
		stopDriving()
		koT, koPos = 0, nil
		setBars(false)
		hudF.Visible = false
		eventL.Visible = false
		lastScore = m.score
		roundTitle.Text = if m.result == "win"
			then "YOU WON THE ROUND"
			elseif m.result == "loss" then "YOU LOST THE ROUND"
			else "ROUND DRAWN"
		roundTitle.TextColor3 = if m.result == "win"
			then COL_GOOD
			elseif m.result == "loss" then COL_BAD
			else COL_TEXT
		roundScore.Text = `Score  You {scoreText(m.score)} Foe`
		roundRecap.Text = if m.recap then table.concat(m.recap, "\n") else ""
		roundEnd = os.clock() + m.seconds
		roundNext.Text = ""
		roundF.Visible = true
		resF.Visible = false
		-- remember how to word the countdown
		roundF:SetAttribute("Over", m.matchOver)
	end

	handlers.matchResult = function(m)
		hideAll()
		resTitle.Text = if m.result == "win"
			then "YOU WIN!"
			elseif m.result == "loss" then "YOU LOSE"
			else "DRAW"
		resTitle.TextColor3 = if m.result == "win"
			then COL_GOOD
			elseif m.result == "loss" then COL_BAD
			else COL_TEXT
		resScore.Text = `Round wins  You {scoreText(m.score)} {m.opp.name}`
		resWhy.Text = if m.forfeit
			then (if m.result == "win" then "Opponent left the match." else "You left the match.")
			else ""
		if m.vsBot then
			resCoins.Text = "Test match: no rewards"
		else
			resCoins.Text = `Coins earned: +{m.coins}   (total {m.total})`
		end
		resNote.Text = if m.opp.left then "Opponent has left." else ""
		rematchBtn.Visible = false -- carter: the banner, then back to the lobby (no rematch)
		resNote.Text = "Back to the lobby in a moment..."
		resF.Visible = true
		cameraOn()
	end

	handlers.rematch = function(m)
		if m.oppLeft then
			rematchBtn.Visible = false
			resNote.Text = "Opponent has left."
		elseif m.mine and not m.theirs then
			rematchBtn.Text = "WAITING..."
			resNote.Text = "Waiting for your opponent."
		elseif m.theirs and not m.mine then
			resNote.Text = "Your opponent wants a rematch!"
		end
	end

	handlers.error = function(m)
		errorL.Text = tostring(m.text)
		errorL.Visible = true
		task.delay(4, function()
			errorL.Visible = false
		end)
	end

	handlers["end"] = function()
		endAll()
	end

	remotes.BattleUpdate.OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" or type(m.kind) ~= "string" then
			return
		end
		local h = handlers[m.kind]
		if h then
			h(m)
		end
	end)

	-- clocks that count down on the client
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if selectF.Visible then
			selTimer.Text = clock(selectEnd - now)
		end
		if prepF.Visible then
			prepCount.Text = tostring(math.max(0, math.ceil(prepEnd - now)))
		end
		if roundF.Visible then
			local over = roundF:GetAttribute("Over") == true
			roundNext.Text = `{if over then "Match result" else "Next round"} in {math.max(
				0,
				math.ceil(roundEnd - now)
			)}`
		end
	end)
end

return BattleUi
