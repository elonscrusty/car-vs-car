--!strict
-- The center workshop of the Car Battle Lobby: the garage shell with the big crossed-wrenches sign,
-- the GIANT gumball machine, the odds sign beside it and the two display stages (rarest car, and
-- the weekly #1's gold car). Looks only; the cars on the stages and the prompt logic live elsewhere.
-- Orange lights are steady.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gacha = require(ReplicatedStorage.Shared.Gacha)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyText = require(ReplicatedStorage.Shared.LobbyText)
local GumballAnim = require(script.Parent.GumballAnim)
local LobbyGarageShell = require(script.Parent.LobbyGarageShell)
local MapParts = require(script.Parent.MapParts)

local LobbyWorkshop = {}

export type Workshop = {
	machine: Model,
	anim: GumballAnim.Anim,
	stageRare: CFrame, -- where the rarest car stands (faces the mouth)
	stageGold: CFrame, -- where the weekly #1's gold car stands
	goldSign: TextLabel, -- Leaderboards sets this to the weekly #1's name
	group: Folder,
}

local rgb, part, ball, can = MapParts.rgb, MapParts.part, MapParts.ball, MapParts.can
local C = LobbyLayout.colors

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(235, 238, 244),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(196, 130, 255),
	Legendary = Color3.fromRGB(255, 205, 64),
}

local CAPSULE_COLORS = {
	rgb(C.orange),
	rgb(C.blue),
	rgb(C.marking),
	rgb(C.gold),
	Color3.fromRGB(86, 190, 90),
}

local function text(
	parent: Instance,
	str: string,
	pos: UDim2,
	size: UDim2,
	textSize: number,
	color: Color3,
	align: Enum.TextXAlignment?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = str
	l.TextSize = textSize
	l.TextColor3 = color
	l.Font = Enum.Font.GothamBlack
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

-- A SurfaceGui on the +Z face of a panel (the side that looks at the mouth), 40 pixels a stud.
local function gui(panel: Part, w: number, h: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(w * 40, h * 40)
	g.LightInfluence = 0
	g.Parent = panel
	return g
end

-- The wrench sign on the front of the roof, over the mouth.
local function buildSign(shell: LobbyGarageShell.Shell)
	local grp = shell.group
	local at = shell.at
	local navy, orange = rgb(C.panel), rgb(C.orange)
	local z = shell.depth / 2 + 1.2
	local cy, w, h = 25.4, 26, 11
	local function box(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		dz: number,
		color: Color3,
		mat: Enum.Material?
	)
		return part(grp, name, size, at(x, y, z + dz), color, false, nil, mat)
	end
	box("SignPanel", Vector3.new(w, h, 1.2), 0, cy, 0, navy)
	box("SignTrimTop", Vector3.new(w + 1.6, 1, 1.6), 0, cy + h / 2, 0.1, orange)
	box("SignTrimBottom", Vector3.new(w + 1.6, 1, 1.6), 0, cy - h / 2, 0.1, orange)
	for _, s in { -1, 1 } do
		box("SignTrimSide", Vector3.new(1, h + 1, 1.6), s * (w / 2), cy, 0.1, orange)
	end
	-- two chunky wrenches crossed in an X
	local metal, white = Color3.fromRGB(200, 206, 216), rgb(C.marking)
	for k, angle in { 30, -30 } do
		local frame = at(0, cy, z + 1.1) * CFrame.Angles(0, 0, math.rad(angle))
		local color = if k == 1 then white else metal
		local function piece(name: string, size: Vector3, x: number, shape: Enum.PartType?)
			local p = part(
				grp,
				name,
				size,
				frame * CFrame.new(x, 0, 0),
				color,
				false,
				nil,
				Enum.Material.Metal
			)
			if shape then
				p.Shape = shape
				-- a cylinder's axis is x: turn it so it points out of the sign
				p.CFrame = frame * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
			end
			return p
		end
		piece("WrenchHandle", Vector3.new(12, 1.3, 0.9), 0)
		piece("WrenchHeadA", Vector3.new(0.9, 3.8, 3.8), -6.2, Enum.PartType.Cylinder)
		piece("WrenchHeadB", Vector3.new(0.9, 3.2, 3.2), 6.2, Enum.PartType.Cylinder)
		-- the jaw notches cut into each head (navy so they read as gaps)
		part(
			grp,
			"WrenchJawA",
			Vector3.new(1.8, 1.5, 1.2),
			frame * CFrame.new(-7.4, 0, 0.1),
			navy,
			false
		)
		part(
			grp,
			"WrenchJawB",
			Vector3.new(1.6, 1.3, 1.2),
			frame * CFrame.new(7.2, 0, 0.1),
			navy,
			false
		)
	end
	-- small orange bolts in the corners
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local b = ball(
				grp,
				"SignBolt",
				1.1,
				at(sx * (w / 2 - 1.3), cy + sy * (h / 2 - 1.3), z + 0.8).Position,
				orange,
				false
			)
			b.Material = Enum.Material.Metal
		end
	end
end

-- The giant gumball machine. Everything is in one Model with the base as its primary part.
local function buildMachine(shell: LobbyGarageShell.Shell): Model
	local at = shell.at
	local g = LobbyLayout.gumball
	local R = g.radius
	local model = Instance.new("Model")
	model.Name = "GumballMachine"
	model.Parent = shell.group
	local blue, orange, navy, white = rgb(C.blue), rgb(C.orange), rgb(C.panel), rgb(C.marking)
	local function box(
		name: string,
		size: Vector3,
		u: number,
		y: number,
		v: number,
		color: Color3,
		mat: Enum.Material?
	): Part
		return part(model, name, size, at(g.u + u, y, g.v + v), color, false, nil, mat)
	end
	local function pos(u: number, y: number, v: number): Vector3
		return at(g.u + u, y, g.v + v).Position
	end

	local baseH = 6.5
	local base = box("Base", Vector3.new(12, baseH, 10), 0, baseH / 2, 0, blue)
	model.PrimaryPart = base
	box("BaseFoot", Vector3.new(13, 0.8, 11), 0, 0.4, 0, navy)
	box("BaseTop", Vector3.new(12.6, 0.7, 10.6), 0, baseH + 0.1, 0, orange)
	-- the collar the glass ball sits in
	local collar = can(model, "Collar", 11, 1.2, pos(0, baseH + 0.4, 0), orange, false)
	collar.Material = Enum.Material.SmoothPlastic
	local glow = can(
		model,
		"GlowRing",
		11.5,
		0.35,
		pos(0, baseH + 0.5, 0),
		rgb(C.light),
		false,
		nil,
		Enum.Material.Neon
	)
	glow.CastShadow = false

	-- the glass ball, then the capsules inside it
	local cy = baseH + 1.6 + R - 1.4
	local glass =
		ball(model, "GlassBall", R * 2, pos(0, cy, 0), Color3.fromRGB(205, 232, 255), false)
	glass.Transparency = 0.5
	glass.Reflectance = 0.1
	local layers = { { -5.2, 4 }, { -2.6, 6 }, { 0, 7 }, { 2.6, 5 }, { 5.2, 2 } }
	local n = 0
	for li, layer in layers do
		local y, count = layer[1], layer[2]
		local ring = math.max(0, math.sqrt((R - 1.5) ^ 2 - y * y) - 0.4) * 0.85
		for k = 1, count do
			n += 1
			local a = (k / count) * math.pi * 2 + li * 0.9
			local r = if li % 2 == 0 then ring * 0.55 else ring
			local d = 2.4 + (n % 3) * 0.3
			ball(
				model,
				"Capsule",
				d,
				pos(math.cos(a) * r, cy + y, math.sin(a) * r),
				CAPSULE_COLORS[n % #CAPSULE_COLORS + 1],
				false
			)
		end
	end
	-- the cap on top (steady orange light inside it)
	local cap = can(model, "Cap", 6, 1.2, pos(0, cy + R - 0.9, 0), orange, false)
	local topKnob = ball(model, "CapKnob", 2.2, pos(0, cy + R + 0.5, 0), navy, false)
	topKnob.Material = Enum.Material.SmoothPlastic
	local lamp = Instance.new("PointLight")
	lamp.Color = rgb(C.light)
	lamp.Brightness = 1.2
	lamp.Range = 26
	lamp.Shadows = false
	lamp.Parent = cap

	-- the front panel: chute and tray on the left, the crank on the right
	local body = box("GachaBody", Vector3.new(10.4, 5.4, 0.6), 0, 3.25, 5.3, orange)
	box("PanelRim", Vector3.new(10.9, 0.6, 0.9), 0, 6.1, 5.3, navy)
	box("ChuteHousing", Vector3.new(3.8, 2.8, 0.9), -2.7, 2.1, 5.8, navy)
	box("GumballChute", Vector3.new(3, 1.9, 0.3), -2.7, 2.1, 6.3, Color3.fromRGB(14, 16, 24))
	box("Tray", Vector3.new(4.8, 0.4, 3.4), -2.7, 0.7, 7.4, rgb(C.metal), Enum.Material.Metal)
	box(
		"TrayBack",
		Vector3.new(4.8, 0.9, 0.4),
		-2.7,
		1.1,
		5.9,
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	for _, s in { -1, 1 } do
		box(
			"TraySide",
			Vector3.new(0.4, 0.9, 3.4),
			-2.7 + s * 2.4,
			1.1,
			7.4,
			rgb(C.metalDark),
			Enum.Material.Metal
		)
	end
	box("TrayLip", Vector3.new(4.8, 0.7, 0.4), -2.7, 1, 9.1, rgb(C.metalDark), Enum.Material.Metal)
	-- coin slot plate with a steady neon edge
	box("SlotPlate", Vector3.new(2.6, 3.2, 0.5), 2.9, 4.2, 5.7, navy)
	local slot =
		box("SlotGlow", Vector3.new(1.4, 0.3, 0.3), 2.9, 5.3, 6.0, rgb(C.light), Enum.Material.Neon)
	slot.CastShadow = false
	-- the crank: a disc with a bar and a knob on the end (all spin together)
	local crankCF = at(g.u + 2.9, 3.0, g.v + 6.3)
	local bar = part(
		model,
		"GumballCrank",
		Vector3.new(3.8, 0.9, 0.8),
		crankCF,
		rgb(C.metal),
		false,
		nil,
		Enum.Material.Metal
	)
	bar.Name = "GumballCrank"
	local disc = part(
		model,
		"GumballCrankDisc",
		Vector3.new(0.6, 1.8, 1.8),
		crankCF * CFrame.Angles(0, math.pi / 2, 0),
		white,
		false
	)
	disc.Shape = Enum.PartType.Cylinder
	local knob = part(
		model,
		"GumballCrankKnob",
		Vector3.new(1.5, 1.5, 1.5),
		crankCF * CFrame.new(1.9, 0, 0.4),
		orange,
		false
	)
	knob.Shape = Enum.PartType.Ball

	-- the prompt lives on the front panel
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GachaPrompt"
	prompt.ActionText = "Pull"
	prompt.ObjectText = "Gumball Machine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 22
	prompt.HoldDuration = 0
	prompt.Parent = body
	return model
end

local function percent(p: number): string
	return LobbyText.percentText(p)
end

-- The standing odds sign: price and every rarity with its chance.
local function buildOddsSign(shell: LobbyGarageShell.Shell)
	local grp = shell.group
	local at = shell.at
	local o = LobbyLayout.oddsSign
	local navy, orange = rgb(C.panel), rgb(C.orange)
	local bottom = 3
	local midY = bottom + o.h / 2
	for _, s in { -1, 1 } do
		part(
			grp,
			"OddsPost",
			Vector3.new(0.9, bottom + 1, 0.9),
			at(o.u + s * (o.w / 2 - 1.2), (bottom + 1) / 2, o.v),
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	local panel =
		part(grp, "OddsPanel", Vector3.new(o.w, o.h, 0.8), at(o.u, midY, o.v), navy, false)
	part(
		grp,
		"OddsTrimTop",
		Vector3.new(o.w + 1, 0.7, 1.1),
		at(o.u, midY + o.h / 2, o.v),
		orange,
		false
	)
	part(
		grp,
		"OddsTrimBottom",
		Vector3.new(o.w + 1, 0.7, 1.1),
		at(o.u, midY - o.h / 2, o.v),
		orange,
		false
	)
	for _, s in { -1, 1 } do
		part(
			grp,
			"OddsTrimSide",
			Vector3.new(0.7, o.h + 0.7, 1.1),
			at(o.u + s * (o.w / 2), midY, o.v),
			orange,
			false
		)
	end

	local g = gui(panel, o.w, o.h)
	local W, H = o.w * 40, o.h * 40
	local white = rgb(C.marking)
	text(g, "GUMBALL ODDS", UDim2.new(0, 0, 0, 14), UDim2.new(1, 0, 0, 62), 52, orange)
	local priceLine = `1 PULL = {LobbyText.formatNumber(LobbyConfig.Gacha.price)} COINS`
	text(g, priceLine, UDim2.new(0, 0, 0, 78), UDim2.new(1, 0, 0, 40), 30, rgb(C.gold))
	local rows = Gacha.oddsTable()
	local top = 130
	local rowH = math.min(56, (H - top - 16) / math.max(1, #rows))
	for i, row in rows do
		local y = top + (i - 1) * rowH
		local color = RARITY_COLORS[row.rarity] or white
		text(
			g,
			string.upper(row.rarity),
			UDim2.new(0, 36, 0, y),
			UDim2.new(0, W * 0.5, 0, rowH),
			38,
			color,
			Enum.TextXAlignment.Left
		)
		text(
			g,
			percent(row.percent),
			UDim2.new(0, W * 0.5, 0, y),
			UDim2.new(0, W * 0.5 - 36, 0, rowH),
			38,
			white,
			Enum.TextXAlignment.Right
		)
	end
end

-- One round stage with a glowing rim and a small sign behind it. Returns the car spot and the label.
local function buildStage(
	shell: LobbyGarageShell.Shell,
	name: string,
	s: { u: number, v: number, radius: number },
	rim: Color3,
	label: string
): (CFrame, TextLabel)
	local grp = shell.group
	local at = shell.at
	local r = s.radius - 0.8
	local topY = 1.8
	local navy = rgb(C.panel)
	local function pos(u: number, y: number, v: number): Vector3
		return at(s.u + u, y, s.v + v).Position
	end
	can(
		grp,
		name .. "Base",
		r * 2,
		1.4,
		pos(0, 0, 0),
		rgb(C.metalDark),
		false,
		nil,
		Enum.Material.Metal
	)
	local glow = can(
		grp,
		name .. "Rim",
		r * 2 + 0.5,
		0.35,
		pos(0, 0.55, 0),
		rim,
		false,
		nil,
		Enum.Material.Neon
	)
	glow.CastShadow = false
	can(grp, name .. "Top", r * 2 - 1.2, 0.4, pos(0, 1.4, 0), rgb(C.asphalt), false)
	-- the sign stands on the floor behind the stage
	local sv = -r - 1.6
	local panelY = 5.2
	for _, side in { -1, 1 } do
		part(
			grp,
			name .. "SignPost",
			Vector3.new(0.6, panelY, 0.6),
			at(s.u + side * 3.6, panelY / 2, s.v + sv),
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	local panel = part(
		grp,
		name .. "SignPanel",
		Vector3.new(9, 2.8, 0.6),
		at(s.u, panelY, s.v + sv),
		navy,
		false
	)
	part(
		grp,
		name .. "SignTrim",
		Vector3.new(9.6, 0.5, 0.9),
		at(s.u, panelY + 1.4, s.v + sv),
		rim,
		false
	)
	local g = gui(panel, 9, 2.8)
	local l = text(g, label, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), 56, rgb(C.marking))
	return at(s.u, topY, s.v), l
end

function LobbyWorkshop.build(folder: Folder, origin: Vector3): Workshop
	local shell = LobbyGarageShell.build(folder, origin, LobbyLayout.workshop, "orange", "Workshop")
	buildSign(shell)
	local machine = buildMachine(shell)
	buildOddsSign(shell)
	local stageRare, _ =
		buildStage(shell, "StageRare", LobbyLayout.stageRare, rgb(C.light), "RAREST CAR")
	local stageGold, goldLabel =
		buildStage(shell, "StageGold", LobbyLayout.stageGold, rgb(C.blue), "TOP DRIVER")
	return {
		machine = machine,
		anim = GumballAnim.new(machine),
		stageRare = stageRare,
		stageGold = stageGold,
		goldSign = goldLabel,
		group = shell.group,
	}
end

return LobbyWorkshop
