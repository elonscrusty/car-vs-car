--!strict
-- Big landmark models for the chase map "Wreck City", built from plain parts (no meshes, no asset
-- ids): a wrecking-ball crane that swings its ball across the road, a striped tunnel portal, a
-- roadside billboard, chevron dressing for ramps, concrete road barriers and deck guard rails.
--
-- Every builder takes `cf`, the model's base on the ground (y = ground top); local -Z is the
-- model's front. Every part is anchored. Only the parts named "Core" (and the crane's mast column)
-- collide; everything else is looks only, so the phones only pay for a few colliders.

local MapParts = require(script.Parent.MapParts)

local ChaseLandmarks = {}

export type Crane = {
	model: Model,
	swing: Model,
	mast: Part,
	ball: Part,
}

local rgb, part, ball = MapParts.rgb, MapParts.part, MapParts.ball

-- Same palette as the duel arena (DuelArenaLayout.colors), plus a hazard yellow and a concrete.
local ORANGE = rgb({ 245, 130, 32 })
local BLUE = rgb({ 37, 141, 221 })
local RED = rgb({ 214, 58, 52 })
local YELLOW = rgb({ 255, 214, 64 })
local WHITE = rgb({ 237, 240, 234 })
local BLACK = rgb({ 36, 39, 43 })
local NAVY = rgb({ 26, 40, 78 })
local METAL = rgb({ 128, 134, 146 })
local METAL_DARK = rgb({ 70, 76, 88 })
local CONCRETE = rgb({ 196, 198, 194 })
local LAMP = rgb({ 255, 236, 170 })

local NEON = Enum.Material.Neon

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A look-only cylinder `len` long and `d` across, its axis along the X axis of `cf`.
local function cyl(
	parent: Instance,
	name: string,
	len: number,
	d: number,
	cf: CFrame,
	color: Color3
): Part
	local p = part(parent, name, Vector3.new(len, d, d), cf, color, false)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A look-only round rod from world point `a` to world point `b`.
local function rod(
	parent: Instance,
	name: string,
	d: number,
	a: Vector3,
	b: Vector3,
	color: Color3
): Part
	-- lookAt points -Z at b; a quarter turn about Y puts the cylinder's X axis there
	return cyl(
		parent,
		name,
		(b - a).Magnitude,
		d,
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color
	)
end

-- Chunky cartoon text on one face of `p`: FredokaOne, scaled to fit, with a thick round outline.
local function sign(
	p: Part,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	stroke: Color3,
	thickness: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.84)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	local outline = Instance.new("UIStroke") -- a TextLabel's own stroke is one pixel; this one is chunky
	outline.Color = stroke
	outline.Thickness = thickness
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label
end

-- Wrecking-ball crane (26 parts). The base box ("Core", 12 x 12) and the mast column are solid; the
-- red head on top of the mast is the part "Mast": its X/Z is the swing axis. Everything that turns
-- lives in the Model "Swing": the yellow arm along local +X (the ball hangs 34 studs out from the
-- axis), the counterweight on the other side, the tie rods, the chain and the ball. The ball is 12
-- across, its centre 6.8 up, so its bottom clears the ground by 0.8 and its top (12.8) is over a
-- car's roof. The arm's PivotOffset puts Swing's pivot on the axis (y = 27.25), so another script
-- can turn it with `rest = swing:GetPivot()` once, then
-- `swing:PivotTo(CFrame.new(rest.Position) * CFrame.Angles(0, a, 0) * rest.Rotation)`.
function ChaseLandmarks.crane(parent: Instance, cf: CFrame, reachStuds: number?): Crane
	local m = model(parent, "WreckingCrane")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the swing is animated on clients: all or nothing
	local reach = reachStuds or 34
	local core = part(m, "Core", Vector3.new(12, 4, 12), cf * CFrame.new(0, 2, 0), YELLOW, true)
	part(m, "BaseBand", Vector3.new(12.3, 1.2, 12.3), cf * CFrame.new(0, 2.2, 0), BLACK, false)
	-- the column runs 4 .. 22, banded yellow and black; the red head sits 22 .. 26
	part(m, "Column", Vector3.new(4, 18, 4), cf * CFrame.new(0, 13, 0), YELLOW, true)
	for _, y in { 8, 13, 18 } do
		part(m, "Band", Vector3.new(4.3, 1.4, 4.3), cf * CFrame.new(0, y, 0), BLACK, false)
	end
	local mast = part(m, "Mast", Vector3.new(5, 4, 5), cf * CFrame.new(0, 24, 0), RED, false)

	local swing = model(m, "Swing")
	local armY = 27.25 -- arm runs 26 .. 28.5 high, from x = -6 to x = 35
	local armLen = reach + 7 -- from x = -6 to x = reach + 1
	local armMid = (reach - 5) / 2
	local arm = part(
		swing,
		"Arm",
		Vector3.new(armLen, 2.5, 3),
		cf * CFrame.new(armMid, armY, 0),
		YELLOW,
		false
	)
	arm.PivotOffset = CFrame.new(-armMid, 0, 0) -- pivot on the mast axis
	swing.PrimaryPart = arm
	local sx = 5
	while sx < reach - 3 do
		part(
			swing,
			"Stripe",
			Vector3.new(1.4, 2.7, 3.2),
			cf * CFrame.new(sx, armY, 0),
			BLACK,
			false
		)
		sx += 6
	end
	part(
		swing,
		"Counterweight",
		Vector3.new(6, 4, 4.4),
		cf * CFrame.new(-7, armY, 0),
		METAL_DARK,
		false
	)
	-- a short peak over the axis with tie rods down to the arm tip and the counterweight
	part(swing, "Peak", Vector3.new(1.8, 4.5, 1.8), cf * CFrame.new(0, 30.75, 0), YELLOW, false)
	local peak = cf:PointToWorldSpace(Vector3.new(0, 32.5, 0))
	rod(
		swing,
		"Tie",
		0.7,
		peak,
		cf:PointToWorldSpace(Vector3.new(reach - 0.5, 28.4, 0)),
		METAL_DARK
	)
	rod(swing, "Tie", 0.7, peak, cf:PointToWorldSpace(Vector3.new(-7, 29, 0)), METAL_DARK)
	-- the pulley wheel at the tip (axis across the arm)
	cyl(
		swing,
		"Pulley",
		3.6,
		3.4,
		cf * CFrame.new(reach, armY - 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
		RED
	)

	-- chain from the arm's underside (26) down to the shackle (14.2), with three fat links on it
	cyl(
		swing,
		"Chain",
		11.8,
		1.1,
		cf * CFrame.new(reach, 20.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		METAL_DARK
	)
	for i, y in { 16.5, 20, 23.5 } do
		part(
			swing,
			"Link",
			Vector3.new(0.6, 2.2, 1.8),
			cf * CFrame.new(reach, y, 0) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0),
			METAL,
			false
		)
	end
	part(
		swing,
		"Shackle",
		Vector3.new(2.4, 1.6, 2.4),
		cf * CFrame.new(reach, 13.4, 0),
		YELLOW,
		false
	)

	local ballY = 6.8
	local wreck =
		ball(swing, "Ball", 12, cf:PointToWorldSpace(Vector3.new(reach, ballY, 0)), BLACK, false)
	-- two painted bands round the ball, crossing at the top and bottom
	cyl(swing, "BallBand", 1.6, 12.3, cf * CFrame.new(reach, ballY, 0), RED)
	cyl(
		swing,
		"BallBand",
		1.6,
		12.3,
		cf * CFrame.new(reach, ballY, 0) * CFrame.Angles(0, math.pi / 2, 0),
		YELLOW
	)

	m.PrimaryPart = core
	m:SetAttribute("SwingLength", reach)
	m:SetAttribute("BallRadius", 6)
	return { model = m, swing = swing, mast = mast, ball = wreck }
end

-- Tunnel portal (18 parts): two white pillars ("Core", solid) with red hazard plates on their
-- fronts, a red lintel with white trims over the opening, a glowing yellow "TUNNEL" strip and four
-- round lamps on the lintel's front. The opening (`width` across, `height` up, centred on cf) is
-- left empty. The pillars are 5 wide and 6 deep; the whole frame is width + 10 across and
-- height + 6.8 tall.
function ChaseLandmarks.tunnelPortal(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number
): Model
	local m = model(parent, "TunnelPortal")
	local pw, depth, lh = 5, 6, 6 -- pillar width, frame depth, lintel height
	local hw = width / 2
	local px = hw + pw / 2
	local total = width + pw * 2
	local front = -depth / 2
	for _, sx in { -1, 1 } do
		local core = part(
			m,
			"Core",
			Vector3.new(pw, height, depth),
			cf * CFrame.new(sx * px, height / 2, 0),
			WHITE,
			true
		)
		m.PrimaryPart = core
		for i = 1, 3 do
			part(
				m,
				"Stripe",
				Vector3.new(pw, 1.8, 0.3),
				cf * CFrame.new(sx * px, height * i / 4, front - 0.15),
				RED,
				false
			)
		end
		-- the foot sticks out to the outside only, never into the opening
		part(
			m,
			"Foot",
			Vector3.new(pw + 1.2, 1.2, depth + 1.2),
			cf * CFrame.new(sx * (px + 0.6), 0.6, 0),
			METAL_DARK,
			false
		)
	end
	part(
		m,
		"Lintel",
		Vector3.new(total, lh, depth),
		cf * CFrame.new(0, height + lh / 2, 0),
		RED,
		false
	)
	part(
		m,
		"Trim",
		Vector3.new(total + 0.4, 0.8, depth + 0.4),
		cf * CFrame.new(0, height + 0.4, 0),
		WHITE,
		false
	)
	part(
		m,
		"Trim",
		Vector3.new(total + 0.4, 0.8, depth + 0.4),
		cf * CFrame.new(0, height + lh + 0.4, 0),
		WHITE,
		false
	)

	local signW = math.min(width * 0.5, 24)
	local strip = part(
		m,
		"Sign",
		Vector3.new(signW, 3.4, 0.4),
		cf * CFrame.new(0, height + lh / 2, front - 0.2),
		YELLOW,
		false,
		nil,
		NEON
	)
	sign(strip, Enum.NormalId.Front, "TUNNEL", NAVY, WHITE, 3)
	-- two lamps each side of the sign: one next to it, one near the lintel's end
	local inner = signW / 2 + 1.6
	local outer = math.max(hw + pw - 1.4, inner)
	for _, sx in { -1, 1 } do
		for _, x in { inner, outer } do
			ball(
				m,
				"Lamp",
				1.8,
				cf:PointToWorldSpace(Vector3.new(sx * x, height + lh / 2, front - 0.1)),
				LAMP,
				false,
				nil,
				NEON
			)
		end
	end
	return m
end

-- Roadside billboard (12 parts): an orange board `width` x `height` with its bottom 8 studs up, a
-- glowing rim with round bulbs on the corners, a dark walkway under it and two posts behind it
-- (+Z side). One post is the solid "Core" (1.6 thick); everything else is looks only. `text` is
-- written on both faces.
function ChaseLandmarks.billboard(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	text: string
): Model
	local m = model(parent, "Billboard")
	local lift, thick = 8, 1.2
	local boardCf = cf * CFrame.new(0, lift + height / 2, 0)
	local board = part(m, "Board", Vector3.new(width, height, thick), boardCf, ORANGE, false)
	sign(board, Enum.NormalId.Front, text, WHITE, NAVY, 5)
	sign(board, Enum.NormalId.Back, text, WHITE, NAVY, 5)
	local hx, hy = width / 2 + 0.5, height / 2 + 0.5
	for _, e in
		{
			{ 0, hy, width + 2, 1 },
			{ 0, -hy, width + 2, 1 },
			{ -hx, 0, 1, height },
			{ hx, 0, 1, height },
		}
	do
		part(
			m,
			"Rim",
			Vector3.new(e[3], e[4], thick + 0.4),
			boardCf * CFrame.new(e[1], e[2], 0),
			YELLOW,
			false,
			nil,
			NEON
		)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		ball(
			m,
			"Bulb",
			2,
			boardCf:PointToWorldSpace(Vector3.new(c[1] * hx, c[2] * hy, 0)),
			LAMP,
			false,
			nil,
			NEON
		)
	end
	part(
		m,
		"Walkway",
		Vector3.new(width * 0.8, 0.4, 2.4),
		cf * CFrame.new(0, lift - 0.8, 0.6),
		METAL_DARK,
		false
	)
	-- posts from the ground up to the middle of the board, just behind it
	local postH = lift + height / 2
	local postX = math.min(width / 4, width / 2 - 2)
	local postZ = thick / 2 + 0.8
	local core = part(
		m,
		"Core",
		Vector3.new(1.6, postH, 1.6),
		cf * CFrame.new(-postX, postH / 2, postZ),
		METAL,
		true
	)
	part(
		m,
		"Post",
		Vector3.new(1.6, postH, 1.6),
		cf * CFrame.new(postX, postH / 2, postZ),
		METAL,
		false
	)
	m.PrimaryPart = core
	return m
end

-- Ramp dressing (14 parts, all looks only): three white chevrons pointing up the slope and a
-- yellow strip with black dashes along each edge. `cf` is the centre of the sloped surface; only
-- its position and its heading are used (local -Z up the slope), the pitch comes from `rise` over
-- `length` (the length along the surface), so an upright or an already tilted cf both work.
-- Everything lies 0.15 above the surface.
function ChaseLandmarks.rampDressing(
	parent: Instance,
	cf: CFrame,
	width: number,
	length: number,
	rise: number
): Model
	local m = model(parent, "RampDressing")
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	-- a positive turn about X lifts local -Z: it goes to (0, sin a, -cos a), up the slope
	local pitch = math.asin(math.clamp(rise / length, 0, 1))
	local slope = CFrame.lookAt(cf.Position, cf.Position + flat.Unit) * CFrame.Angles(pitch, 0, 0)
	local t = 0.2
	local function at(x: number, z: number, thickness: number): CFrame
		return slope * CFrame.new(x, 0.15 + thickness / 2, z)
	end

	-- chevrons: two bars meeting at the tip (0, zc - d/2), their tails at (+-s, zc + d/2)
	local s = width * 0.22
	local d = math.min(s * 0.75, length / 5)
	local bw = math.max(1.6, width * 0.06)
	local armLen = math.sqrt(s * s + d * d) + bw * 0.6
	local turn = math.atan2(d, s)
	for _, zc in { length / 4, 0, -length / 4 } do
		for _, sx in { -1, 1 } do
			part(
				m,
				"Chevron",
				Vector3.new(armLen, t, bw),
				at(sx * s / 2, zc, t) * CFrame.Angles(0, -sx * turn, 0),
				WHITE,
				false
			)
		end
	end

	-- edges: a yellow strip, with three black dashes standing 0.1 proud of it
	local ex = width / 2 - 1.2
	local run = length - 0.6
	local gap = run / 7
	for _, sx in { -1, 1 } do
		part(m, "Edge", Vector3.new(1.6, t, run), at(sx * ex, 0, t), YELLOW, false)
		for _, j in { 1, 3, 5 } do
			part(
				m,
				"EdgeDash",
				Vector3.new(1.7, t + 0.1, gap),
				at(sx * ex, -run / 2 + gap * (j + 0.5), t + 0.1),
				BLACK,
				false
			)
		end
	end
	return m
end

-- Concrete road barrier (4 parts), `length` along local X, 4.2 tall: a wide concrete foot, the
-- concrete body ("Core", the only collider, 2.6 thick), a painted band and a white top. `team`
-- "blue" paints the band blue; anything else paints it orange.
function ChaseLandmarks.jerseyBarrier(
	parent: Instance,
	cf: CFrame,
	length: number,
	team: string?
): Model
	local m = model(parent, "JerseyBarrier")
	local core = part(
		m,
		"Core",
		Vector3.new(length, 4.2, 2.6),
		cf * CFrame.new(0, 2.1, 0),
		CONCRETE,
		true,
		nil,
		Enum.Material.Concrete
	)
	part(
		m,
		"Foot",
		Vector3.new(length, 1.2, 4),
		cf * CFrame.new(0, 0.6, 0),
		CONCRETE,
		false,
		nil,
		Enum.Material.Concrete
	)
	local band = if team == "blue" then BLUE else ORANGE
	part(m, "Band", Vector3.new(length - 0.1, 1.2, 2.7), cf * CFrame.new(0, 2.9, 0), band, false)
	part(m, "Top", Vector3.new(length - 0.1, 0.52, 2.7), cf * CFrame.new(0, 3.96, 0), WHITE, false)
	m.PrimaryPart = core
	return m
end

-- Deck guard rail (5 parts), `length` along local X, 4.5 tall: a blue body ("Core", the only
-- collider, 1 thick) with an orange panel over its middle third (blue, orange, blue along the
-- rail), a glowing strip near the top, a metal cap and a dark foot plate.
function ChaseLandmarks.deckRail(parent: Instance, cf: CFrame, length: number): Model
	local m = model(parent, "DeckRail")
	local core =
		part(m, "Core", Vector3.new(length, 4.5, 1), cf * CFrame.new(0, 2.25, 0), BLUE, true)
	part(m, "Panel", Vector3.new(length / 3, 2.4, 1.2), cf * CFrame.new(0, 2, 0), ORANGE, false)
	part(
		m,
		"Glow",
		Vector3.new(length, 0.5, 1.3),
		cf * CFrame.new(0, 3.6, 0),
		LAMP,
		false,
		nil,
		NEON
	)
	part(m, "Cap", Vector3.new(length, 0.44, 1.4), cf * CFrame.new(0, 4.29, 0), METAL, false)
	part(m, "Foot", Vector3.new(length, 0.5, 1.8), cf * CFrame.new(0, 0.25, 0), METAL_DARK, false)
	m.PrimaryPart = core
	return m
end

return ChaseLandmarks
