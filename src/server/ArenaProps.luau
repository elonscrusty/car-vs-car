--!strict
-- Looks for the fight floor: dirt-show markings, and paint on the ramps, crates, pillars and hammers.
-- Nothing here changes how the arena plays: every extra piece is non-solid (CanCollide false).

local ArenaProps = {}

local YELLOW = Color3.fromRGB(255, 205, 40)
local BLACK = Color3.fromRGB(34, 34, 42)
local WHITE = Color3.fromRGB(245, 245, 245)
local RED = Color3.fromRGB(235, 60, 55)
local NEON_BLUE = Color3.fromRGB(120, 215, 255)

local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function disc(
	parent: Instance,
	name: string,
	radius: number,
	center: Vector3,
	color: Color3,
	neon: boolean?
): Part
	local p = deco(
		parent,
		name,
		Vector3.new(0.08, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		neon
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Painted marks on the dirt: a centre emblem, two tyre-track rings and scuff marks.
function ArenaProps.floorArt(model: Model, origin: Vector3, flatRadius: number, dirt: Color3)
	local folder = Instance.new("Folder")
	folder.Name = "FloorArt"
	folder.Parent = model
	local y = origin.Y
	local rng = Random.new(31)
	local dark = dirt:Lerp(BLACK, 0.28)
	local light = dirt:Lerp(WHITE, 0.22)
	-- Tyre-track rings: a darker disc with a dirt disc on top leaves a ring.
	for i, r in { flatRadius * 0.8, flatRadius * 0.5 } do
		disc(
			folder,
			"TrackRing",
			r + 1.6,
			Vector3.new(origin.X, y + 0.04 + i * 0.02, origin.Z),
			dark
		)
		disc(
			folder,
			"TrackInner",
			r - 1.6,
			Vector3.new(origin.X, y + 0.05 + i * 0.02, origin.Z),
			dirt
		)
	end
	-- Centre emblem: ring, cream disc, red hub.
	local c = Vector3.new(origin.X, y, origin.Z)
	disc(folder, "EmblemRim", 11, c + Vector3.new(0, 0.12, 0), YELLOW)
	disc(folder, "EmblemBody", 9.6, c + Vector3.new(0, 0.14, 0), dark)
	disc(folder, "EmblemMid", 6, c + Vector3.new(0, 0.16, 0), light)
	disc(folder, "EmblemHub", 3, c + Vector3.new(0, 0.18, 0), RED)
	for k = 0, 3 do
		local yaw = k * math.pi / 2
		deco(
			folder,
			"EmblemArrow",
			Vector3.new(1.8, 0.08, 6),
			CFrame.new(c + Vector3.new(0, 0.2, 0))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.new(0, 0, -13.5),
			YELLOW
		)
	end
	-- Scuff marks: short dark streaks lying every which way.
	for _ = 1, 46 do
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * (flatRadius - 4)
		deco(
			folder,
			"Scuff",
			Vector3.new(0.5 + rng:NextNumber() * 0.7, 0.06, 5 + rng:NextNumber() * 9),
			CFrame.new(c + Vector3.new(math.cos(a) * r, 0.07, math.sin(a) * r))
				* CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
			dark
		)
	end
end

-- Neon strip along the top of a wall piece (looks only).
function ArenaProps.wallStrip(model: Model, wall: BasePart, color: Color3)
	local up = wall.CFrame * CFrame.new(0, wall.Size.Y / 2 + 0.05, 0)
	deco(
		model,
		"WallStrip",
		Vector3.new(wall.Size.X * 0.98, 0.3, wall.Size.Z * 0.6),
		up,
		color,
		true
	)
end

-- A ramp: dark deck, yellow side rails, chevron bars and a lit lip.
function ArenaProps.dressRamp(model: Model, ramp: BasePart)
	ramp.Color = Color3.fromRGB(70, 76, 98)
	local sx, sz = ramp.Size.X, ramp.Size.Z
	local cf = ramp.CFrame * CFrame.new(0, ramp.Size.Y / 2 + 0.03, 0)
	for _, side in { -1, 1 } do
		deco(
			model,
			"RampRail",
			Vector3.new(0.9, 0.5, sz),
			cf * CFrame.new(side * (sx / 2 - 0.45), 0.25, 0),
			YELLOW
		)
	end
	local bars = math.floor(sz / 3.5)
	for i = 1, bars do
		local z = (i / (bars + 1) - 0.5) * sz
		deco(
			model,
			"RampChevron",
			Vector3.new(sx - 2.6, 0.12, 1.1),
			cf * CFrame.new(0, 0.04, z),
			if i % 2 == 0 then YELLOW else WHITE
		)
	end
	-- High end (toward -Z) is the lip: a glowing line.
	deco(
		model,
		"RampLip",
		Vector3.new(sx, 0.35, 0.6),
		cf * CFrame.new(0, 0.15, -sz / 2 + 0.3),
		NEON_BLUE,
		true
	)
end

-- A crate-style block: orange with dark frame bands and a hazard stripe round the bottom.
function ArenaProps.dressBlock(model: Model, block: BasePart)
	block.Color = Color3.fromRGB(240, 135, 45)
	local s = block.Size
	local top = block.CFrame * CFrame.new(0, s.Y / 2 + 0.05, 0)
	deco(
		model,
		"CrateLid",
		Vector3.new(s.X * 0.8, 0.2, s.Z * 0.8),
		top,
		Color3.fromRGB(255, 175, 80)
	)
	local n = math.max(2, math.floor(s.X / 2))
	for i = 1, n do
		local x = (i / (n + 1) - 0.5) * s.X
		for _, face in { 1, -1 } do
			deco(
				model,
				"CrateStripe",
				Vector3.new(s.X / (n + 1) * 0.9, 1.2, 0.12),
				block.CFrame * CFrame.new(x, -s.Y / 2 + 0.8, face * (s.Z / 2 + 0.07)),
				if i % 2 == 0 then YELLOW else BLACK
			)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(
				model,
				"CratePost",
				Vector3.new(0.7, s.Y + 0.1, 0.7),
				block.CFrame * CFrame.new(sx * (s.X / 2 - 0.2), 0, sz * (s.Z / 2 - 0.2)),
				BLACK
			)
		end
	end
end

-- A pillar: pale concrete with caution bands and a glowing cap.
function ArenaProps.dressPillar(model: Model, pillar: BasePart)
	pillar.Color = Color3.fromRGB(175, 180, 200)
	local h, d = pillar.Size.X, pillar.Size.Y -- cylinder: length along X = height once turned
	local base = pillar.Position
	for i = 0, 2 do
		local band = deco(
			model,
			"PillarBand",
			Vector3.new(0.9, d + 0.3, d + 0.3),
			CFrame.new(base + Vector3.new(0, -h / 2 + 1 + i * 2.2, 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			if i % 2 == 0 then YELLOW else BLACK
		)
		band.Shape = Enum.PartType.Cylinder
	end
	local cap = deco(
		model,
		"PillarCap",
		Vector3.new(0.5, d * 0.8, d * 0.8),
		CFrame.new(base + Vector3.new(0, h / 2 + 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		NEON_BLUE,
		true
	)
	cap.Shape = Enum.PartType.Cylinder
end

-- A hammer: warning stripes on the arm, glowing tips, a tall hub, and a painted sweep ring on the floor.
function ArenaProps.dressHammer(model: Model, bar: BasePart, center: Vector3, floorY: number)
	local len = bar.Size.X
	-- Parts welded to the bar so they turn with it.
	local function onBar(name: string, size: Vector3, offset: CFrame, color: Color3, neon: boolean?)
		local p = deco(model, name, size, bar.CFrame * offset, color, neon)
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = bar
		w.Part1 = p
		w.Parent = p
	end
	local stripes = 6
	for i = 1, stripes do
		local x = (i / (stripes + 1) - 0.5) * len * 0.8
		onBar(
			"HammerStripe",
			Vector3.new(len * 0.8 / (stripes + 1), 0.15, bar.Size.Z * 0.98),
			CFrame.new(x, bar.Size.Y / 2 + 0.05, 0),
			if i % 2 == 0 then YELLOW else WHITE
		)
	end
	for _, side in { -1, 1 } do
		onBar(
			"HammerTip",
			Vector3.new(1.2, bar.Size.Y + 0.2, bar.Size.Z + 0.2),
			CFrame.new(side * (len / 2 - 0.6), 0, 0),
			YELLOW,
			true
		)
	end
	-- Hub: dark post and a bright cap above the arm.
	local post = deco(
		model,
		"HammerHub",
		Vector3.new(7, 5.2, 5.2),
		CFrame.new(center.X, floorY + 3.5, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(60, 66, 86)
	)
	post.Shape = Enum.PartType.Cylinder
	local cap = deco(
		model,
		"HammerHubCap",
		Vector3.new(0.6, 4, 4),
		CFrame.new(center.X, floorY + 7.2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		RED
	)
	cap.Shape = Enum.PartType.Cylinder
	-- Sweep ring: yellow/black dashes show where the arm reaches.
	local r = len / 2
	local dashes = 24
	for i = 0, dashes - 1 do
		local a = i / dashes * math.pi * 2
		deco(
			model,
			"HammerSweep",
			Vector3.new(1.2, 0.06, 2 * math.pi * r / dashes * 0.8),
			CFrame.new(center.X + math.cos(a) * r, floorY + 0.09, center.Z + math.sin(a) * r)
				* CFrame.Angles(0, -a, 0),
			if i % 2 == 0 then YELLOW else BLACK
		)
	end
end

return ArenaProps
