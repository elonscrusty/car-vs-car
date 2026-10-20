--!strict
-- The CUSTOMIZE garage of the Car Battle Lobby (orange shell): the spinning turntable, the counter
-- with the "CustomizePrompt" (the client opens paint / garage from it by that name), a paint can
-- shelf, a tool chest and a spray-paint swatch wall. Look only (no collision, no query, no touch).
--
-- The turntable is a cylinder whose axis is its own X axis, so another module spins it with
-- `turntable.CFrame = turntable.CFrame * CFrame.Angles(step, 0, 0)` (that turns about the world up
-- axis). `turntableCF` is the world CFrame of the top centre (upright: put the car there).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyGarageShell = require(script.Parent.LobbyGarageShell)
local MapParts = require(script.Parent.MapParts)

local LobbyCustomize = {}

export type Result = { turntable: Part, turntableCF: CFrame, group: Folder }

local rgb, part, can = MapParts.rgb, MapParts.part, MapParts.can
local C = LobbyLayout.colors

local FLOOR = 0.4 -- the shell's floor slab is this thick

-- A chunky sign on the roof front: a slanted panel leaning toward the plaza with big text on it,
-- a trim frame, two struts and a steady glow strip. Used by the customize garage and the shop.
function LobbyCustomize.roofSign(
	shell: LobbyGarageShell.Shell,
	text: string,
	panelColor: Color3,
	trimColor: Color3
)
	local grp = shell.group
	local w, h = shell.width, shell.height
	local sw, sh = math.min(w - 8, 30), 8.4
	local y = h + 2 + sh / 2 + 0.6
	local v = shell.depth / 2 - 1.8
	local tilt = CFrame.Angles(0.25, 0, 0)
	local base = shell.at(0, y, v) * tilt
	local panel = part(
		grp,
		"SignPanel",
		Vector3.new(sw, sh, 1),
		base,
		panelColor,
		false,
		nil,
		Enum.Material.SmoothPlastic
	)
	-- trim frame round the panel (just proud of the front)
	for _, s in { -1, 1 } do
		part(
			grp,
			"SignTrimSide",
			Vector3.new(1.2, sh + 1.2, 1.4),
			base * CFrame.new(s * (sw / 2 + 0.2), 0, 0.1),
			trimColor,
			false
		)
		part(
			grp,
			"SignTrimEdge",
			Vector3.new(sw + 2.4, 1.2, 1.4),
			base * CFrame.new(0, s * (sh / 2 + 0.2), 0.1),
			trimColor,
			false
		)
	end
	-- two struts down to the roof
	for _, s in { -1, 1 } do
		part(
			grp,
			"SignStrut",
			Vector3.new(1.4, sh * 0.5, 1.4),
			shell.at(s * (sw / 2 - 3), h + 2 + sh * 0.25, v - 1.6),
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	-- steady glow strip under the panel
	part(
		grp,
		"SignGlow",
		Vector3.new(sw - 2, 0.5, 0.5),
		base * CFrame.new(0, -sh / 2 - 1, 0.7),
		rgb(C.light),
		false,
		nil,
		Enum.Material.Neon
	)
	-- the text: chunky white letters with a dark outline on the panel's +v (front) face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(C.marking)
	label.TextStrokeColor3 = rgb(C.tire)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return panel
end

function LobbyCustomize.build(folder: Folder, origin: Vector3): Result
	local b = LobbyLayout.customize
	local shell = LobbyGarageShell.build(folder, origin, b, "orange", "Customize")
	local grp, at = shell.group, shell.at
	local w, d = shell.width, shell.depth
	local innerU, backV = w / 2 - 1.6, -d / 2 + 1.6
	local metalDark = rgb(C.metalDark)

	LobbyCustomize.roofSign(shell, "CUSTOMIZE", rgb(C.orange), rgb(C.blue))

	-- the turntable: dark base, blue glow ledge, the spinning disc
	local T = LobbyLayout.turntable
	local R = T.radius
	local basePos = at(T.u, FLOOR, T.v).Position
	local baseDisc = can(
		grp,
		"TurntableBase",
		R * 2 + 3,
		0.5,
		basePos,
		metalDark,
		false,
		nil,
		Enum.Material.Metal
	)
	local rimPos = at(T.u, FLOOR + 0.5, T.v).Position
	local rim = can(
		grp,
		"TurntableRim",
		R * 2 + 1.6,
		0.3,
		rimPos,
		rgb(C.blue),
		false,
		nil,
		Enum.Material.Neon
	)
	rim.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = rgb(C.blue)
	light.Brightness = 1
	light.Range = 18
	light.Shadows = false
	light.Parent = rim
	local discBottom = FLOOR + 0.5
	local discH = 0.6
	local turntable = can(
		grp,
		"Turntable",
		R * 2,
		discH,
		at(T.u, discBottom, T.v).Position,
		rgb(C.asphaltDark),
		false,
		nil,
		Enum.Material.SmoothPlastic
	)
	-- the cylinder's cap that faces up is its Right face (axis = own X): a plus of light bars that
	-- turns with the disc so the spin shows
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SpinMarks"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0.3
	gui.Parent = turntable
	for i = 1, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = if i == 1 then UDim2.fromScale(1, 0.06) else UDim2.fromScale(0.06, 1)
		bar.BackgroundColor3 = rgb(C.marking)
		bar.BackgroundTransparency = 0.35
		bar.BorderSizePixel = 0
		bar.Parent = gui
	end
	local turntableCF = at(T.u, discBottom + discH, T.v)
	-- an orange bumper ring round the base, four chunky bollards
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		can(
			grp,
			"Bollard",
			1.4,
			1.6,
			at(T.u + math.cos(a) * (R + 2.2), FLOOR, T.v + math.sin(a) * (R + 2.2)).Position,
			rgb(C.orange),
			false
		)
	end
	baseDisc.CastShadow = false

	-- the counter (front right): body, top slab, a paint can and a roller on it
	local cu, cv = 13, 9
	local counter = part(
		grp,
		"CustomizeCounter",
		Vector3.new(9, 3.4, 3),
		at(cu, FLOOR + 1.7, cv),
		rgb(C.blue),
		false
	)
	part(
		grp,
		"CounterTop",
		Vector3.new(9.8, 0.6, 3.8),
		at(cu, FLOOR + 3.7, cv),
		rgb(C.marking),
		false
	)
	part(
		grp,
		"CounterStripe",
		Vector3.new(9.2, 0.5, 0.2),
		at(cu, FLOOR + 1.9, cv + 1.55),
		rgb(C.orange),
		false
	)
	can(grp, "CounterCan", 1.6, 2, at(cu - 2.5, FLOOR + 4, cv).Position, rgb(C.orange), false)
	can(grp, "CounterCan", 1.6, 2, at(cu - 0.8, FLOOR + 4, cv + 0.4).Position, rgb(C.gold), false)
	part(
		grp,
		"CounterBrush",
		Vector3.new(2.6, 0.5, 0.9),
		at(cu + 2.4, FLOOR + 4.25, cv),
		rgb(C.blue),
		false
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CustomizePrompt"
	prompt.ActionText = "Customize"
	prompt.ObjectText = "Paint & Garage"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 22
	prompt.HoldDuration = 0
	prompt.Enabled = true
	prompt.Parent = counter

	-- paint can shelf along the left wall: two uprights, three planks, rows of cans
	local sx = -innerU + 1.4
	local shelfColors = { C.orange, C.blue, C.marking, C.gold, C.leaf, C.flowers[2] }
	for _, v in { -8.5, 6.5 } do
		part(
			grp,
			"ShelfUpright",
			Vector3.new(2.6, 11, 0.8),
			at(sx, FLOOR + 5.5, v),
			metalDark,
			false
		)
	end
	for tier = 1, 3 do
		local py = FLOOR + tier * 3.2
		part(
			grp,
			"ShelfPlank",
			Vector3.new(2.6, 0.5, 16),
			at(sx, py, -1),
			rgb(C.wood),
			false,
			nil,
			Enum.Material.Wood
		)
		for i = 1, 6 do
			local col = shelfColors[(i + tier) % #shelfColors + 1]
			local h2 = if (i + tier) % 2 == 0 then 2 else 1.6
			can(
				grp,
				"PaintCan",
				1.5,
				h2,
				at(sx, py + 0.25, -7.2 + (i - 1) * 2.6).Position,
				rgb(col),
				false
			)
		end
	end

	-- tool chest against the right wall, with drawers, handles and a stack of tires beside it
	local tu, tv = innerU - 2.2, -7
	part(grp, "ToolChest", Vector3.new(3.6, 5, 7), at(tu, FLOOR + 2.5, tv), rgb(C.orange), false)
	part(
		grp,
		"ToolChestLid",
		Vector3.new(4, 0.7, 7.4),
		at(tu, FLOOR + 5.35, tv),
		metalDark,
		false,
		nil,
		Enum.Material.Metal
	)
	for i = 1, 3 do
		part(
			grp,
			"ChestDrawer",
			Vector3.new(0.3, 1.1, 6.2),
			at(tu - 1.85, FLOOR + 0.9 + (i - 1) * 1.5, tv),
			rgb(C.marking),
			false
		)
		part(
			grp,
			"ChestHandle",
			Vector3.new(0.4, 0.3, 2.2),
			at(tu - 2.05, FLOOR + 0.9 + (i - 1) * 1.5, tv),
			metalDark,
			false
		)
	end
	for i = 1, 3 do
		can(
			grp,
			"Tire",
			3.4,
			1.2,
			at(innerU - 2.4, FLOOR + (i - 1) * 1.2, tv + 6.5).Position,
			rgb(C.tire),
			false
		)
	end

	-- spray-paint swatch wall on the back wall: navy board, trim, 2 x 8 colour squares, label
	local wallV = backV + 0.5
	local boardW = 26
	part(
		grp,
		"SwatchBoard",
		Vector3.new(boardW, 6.6, 0.5),
		at(0, FLOOR + 6.4, wallV),
		rgb(C.panel),
		false
	)
	for _, s in { -1, 1 } do
		part(
			grp,
			"SwatchTrim",
			Vector3.new(boardW + 1, 0.6, 0.8),
			at(0, FLOOR + 6.4 + s * 3.5, wallV + 0.1),
			rgb(C.orange),
			false
		)
		part(
			grp,
			"SwatchTrim",
			Vector3.new(0.6, 7.6, 0.8),
			at(s * (boardW / 2 + 0.2), FLOOR + 6.4, wallV + 0.1),
			rgb(C.orange),
			false
		)
	end
	local swatches = {
		C.orange,
		C.blue,
		C.marking,
		C.gold,
		C.leaf,
		C.flowers[2],
		C.flowers[4],
		C.tire,
	}
	for row = 1, 2 do
		for i, col in swatches do
			local c = col
			if row == 2 then
				c = { math.floor(col[1] * 0.7), math.floor(col[2] * 0.7), math.floor(col[3] * 0.7) }
			end
			part(
				grp,
				"Swatch",
				Vector3.new(2.4, 2.2, 0.4),
				at((i - 4.5) * 3, FLOOR + 6.4 + (if row == 1 then 1.35 else -1.35), wallV + 0.4),
				rgb(c),
				false
			)
		end
	end
	local labelPart = part(
		grp,
		"SwatchLabel",
		Vector3.new(10, 1.6, 0.4),
		at(0, FLOOR + 10.6, wallV + 0.2),
		rgb(C.blue),
		false
	)
	local lg = Instance.new("SurfaceGui")
	lg.Name = "LabelGui"
	lg.Face = Enum.NormalId.Back
	lg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	lg.PixelsPerStud = 30
	lg.Parent = labelPart
	local lt = Instance.new("TextLabel")
	lt.Name = "Text"
	lt.Size = UDim2.fromScale(1, 1)
	lt.BackgroundTransparency = 1
	lt.Text = "PICK YOUR PAINT"
	lt.Font = Enum.Font.FredokaOne
	lt.TextScaled = true
	lt.TextColor3 = rgb(C.marking)
	lt.Parent = lg

	return { turntable = turntable, turntableCF = turntableCF, group = grp }
end

return LobbyCustomize
