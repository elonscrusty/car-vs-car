--!strict
-- Screens and camera for the 1v1 auto-battle. The server runs everything; this only shows what it
-- sends (BattleUpdate) and sends back taps (BattleAction): queue, select, lock, buy, rematch, leave.
-- Layout uses scale sizes with size limits, so it works on phones and desktops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

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
	local function act(name: string, arg: string?)
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
		"TEST BOT (Studio only)",
		UDim2.fromScale(0.44, 0.26),
		UDim2.fromScale(0.51, 0.66),
		Color3.fromRGB(110, 110, 130),
		function()
			act("queueBot")
		end
	)
	queueF.Visible = false

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
		UDim2.fromScale(0.96, 0.58),
		UDim2.fromScale(0.02, 0.21),
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
		buy: TextButton,
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
		clone.Parent = vp
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
			local buy = button(
				root,
				"BUY",
				UDim2.fromScale(0.5, 0.1),
				UDim2.fromScale(0.47, 0.88),
				COL_GOOD,
				function()
					act("buy", id)
				end
			)
			buy.Visible = false
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
			cards[id] = { root = root, stroke = stroke, state = st, buy = buy, id = id }
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
				text, color = `LOCKED  {f.price} coins`, COL_BAD
			end
			card.state.Text = text
			card.state.TextColor3 = color
			card.buy.Visible = c ~= nil and c.state == "locked" and f.enabled
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

	-- ---------- prep ----------
	local prepF = frame(
		gui,
		"Prep",
		UDim2.fromScale(1, 0.34),
		UDim2.fromScale(0, 0.66),
		Color3.fromRGB(10, 12, 22),
		0.25
	)
	prepF.Visible = false
	local prepMe =
		label(prepF, "", UDim2.fromScale(0.36, 0.8), UDim2.fromScale(0.03, 0.1), COL_ME, 22)
	prepMe.TextXAlignment = Enum.TextXAlignment.Left
	local prepOpp =
		label(prepF, "", UDim2.fromScale(0.36, 0.8), UDim2.fromScale(0.61, 0.1), COL_OPP, 22)
	prepOpp.TextXAlignment = Enum.TextXAlignment.Right
	local prepCount =
		label(prepF, "3", UDim2.fromScale(0.16, 0.8), UDim2.fromScale(0.42, 0.1), COL_TEXT, 60)

	-- ---------- fight HUD ----------
	local hudF = frame(gui, "Hud", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0), COL_PANEL, 1)
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
		UDim2.fromScale(0.14, 0.07),
		UDim2.fromScale(0.01, 0.91),
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
		frame(gui, "Round", UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.5, 0.36), COL_PANEL, 0.1)
	roundF.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(roundF, 16)
	local roundLimit = Instance.new("UISizeConstraint")
	roundLimit.MaxSize = Vector2.new(520, 160)
	roundLimit.Parent = roundF
	local roundTitle =
		label(roundF, "", UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.06), COL_TEXT, 36)
	local roundScore =
		label(roundF, "", UDim2.fromScale(0.94, 0.28), UDim2.fromScale(0.03, 0.48), COL_TEXT, 22)
	local roundNext = label(
		roundF,
		"",
		UDim2.fromScale(0.94, 0.2),
		UDim2.fromScale(0.03, 0.77),
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
		label(resF, "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.04), COL_TEXT, 48)
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
	local wallH = 14
	local camOn = false
	local camSmooth: CFrame? = nil

	local function cameraTarget(): CFrame?
		local c = arenaCenter
		if c == nil then
			return nil
		end
		local cc = BattleConfig.Camera
		local pitch = math.rad(cc.pitchDeg)
		local vp = camera.ViewportSize
		local aspect = math.max(vp.X / math.max(vp.Y, 1), 0.3)
		local vHalf = math.rad(cc.fovDeg) / 2
		local hHalf = math.atan(math.tan(vHalf) * aspect)
		local needW = arenaHalf.X * cc.padding / math.tan(hHalf)
		local needH = (arenaHalf.Y * math.sin(pitch) + wallH * math.cos(pitch))
			* cc.padding
			/ math.tan(vHalf)
		local dist = math.max(needW, needH) * 1.15
		local pos = c + Vector3.new(0, math.sin(pitch), math.cos(pitch)) * dist
		return CFrame.lookAt(pos, c)
	end

	local function cameraOn()
		if camOn then
			return
		end
		camOn = true
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
		local target = cameraTarget()
		if target == nil then
			return
		end
		camera = workspace.CurrentCamera
		local cur = camSmooth
		if cur == nil then
			cur = target
		else
			-- only eases when the screen shape changes; the pose itself never moves
			cur = cur:Lerp(target, math.clamp(BattleConfig.Camera.smooth * dt, 0, 1))
		end
		camSmooth = cur
		camera.CFrame = cur :: CFrame
	end)

	-- ---------- show / hide helpers ----------
	local function setChampions(on: boolean)
		for _, name in CHAMPIONS_GUIS do
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") then
				g.Enabled = on
			end
		end
	end

	local function hideAll()
		for _, f in
			{ queueF, selectF, prepF, hudF, roundF, resF, leaveBtn, confirmF, eventL, errorL }
		do
			f.Visible = false
		end
	end

	local function endAll()
		hideAll()
		cameraOff()
		setChampions(true)
		arenaCenter = nil
		selectedId, locked = nil, false
	end

	local function sideText(info: any): string
		local f = BattleConfig.fighter(info.id)
		if f == nil then
			return ""
		end
		local tag = if info.label and info.label ~= "" then ` [{info.label}]` else ""
		return `{info.name}\n{f.name}{tag}\n{f.weaponName}: {f.blurb}`
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
			queueF.Visible = true
			botBtn.Visible = m.studioBot == true
			qText.Text = "Searching for opponent"
		else
			queueF.Visible = false
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
		arenaCenter = Vector3.new(m.arena.x, m.arena.y, m.arena.z)
		arenaHalf = Vector2.new(m.arena.halfX, m.arena.halfZ)
		wallH = m.arena.wall
		cameraOn()
		prepMe.Text = "YOU  " .. sideText(m.me)
		prepOpp.Text = "FOE  " .. sideText(m.opp)
		prepEnd = os.clock() + m.seconds
		prepF.Visible = true
		leaveBtn.Visible = true
	end

	handlers.fight = function(m)
		hideAll()
		hudF.Visible = true
		leaveBtn.Visible = true
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
	end

	handlers.event = function(m)
		showEvent((if m.mine then "You: " else "Foe: ") .. m.text)
	end

	handlers.hit = function(m)
		sparks(m.pos, m.big == true)
	end

	handlers.roundResult = function(m)
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
		rematchBtn.Visible = not m.opp.left
		rematchBtn.Text = "REMATCH"
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
