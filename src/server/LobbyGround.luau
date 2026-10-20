--!strict
-- The ground of the Car Battle Lobby: asphalt plaza, light gray paths, the big PLAY ring, parking
-- lines, tire wall with steady orange lights, flags, the entrance arch with the CAR VS CAR sign,
-- benches, cones, tool carts, the invisible blockers and the silent music spot.
-- Every position and color comes from LobbyLayout. Local coordinates: x right, z toward the spawn,
-- plaza top y = 0; `origin` is added to everything. Look only, except the plaza slab (players
-- stand on it) and the invisible blockers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyGround = {}

local rgb, shade, part, can, group =
	MapParts.rgb, MapParts.shade, MapParts.part, MapParts.can, MapParts.group
local C = LobbyLayout.colors

local WHITE = rgb(C.marking)
local BLOCKER_TALL = 40
local PROP_BLOCKER_TALL = 14

local function look(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return part(parent, name, size, cf, color, false, nil, material)
end

-- ---------------------------------------------------------------------------------------------
-- 1. the plaza

local function plaza(folder: Folder, origin: Vector3)
	local grp = group(folder, "Plaza")
	local p = LobbyLayout.plaza
	local asphalt = rgb(C.asphalt)
	local dark = rgb(C.asphaltDark)
	local zLen = p.frontZ - p.backZ
	local zMid = (p.frontZ + p.backZ) / 2
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	-- the one big slab players stand on (top at y = 0)
	part(
		grp,
		"PlazaSlab",
		Vector3.new(p.halfX * 2, 1, zLen - p.corner * 2),
		at(0, -0.5, zMid),
		asphalt,
		true,
		nil,
		Enum.Material.Asphalt
	)
	-- front and back strips between the rounded corners (solid too, so nobody falls at the edge)
	for _, sz in { -1, 1 } do
		local z = if sz == 1 then p.frontZ - p.corner / 2 else p.backZ + p.corner / 2
		part(
			grp,
			"PlazaStrip",
			Vector3.new((p.halfX - p.corner) * 2, 1, p.corner),
			at(0, -0.5, z),
			asphalt,
			true,
			nil,
			Enum.Material.Asphalt
		)
		for _, sx in { -1, 1 } do
			local cz = if sz == 1 then p.frontZ - p.corner else p.backZ + p.corner
			can(
				grp,
				"PlazaCorner",
				p.corner * 2,
				1,
				origin + Vector3.new(sx * (p.halfX - p.corner), -1, cz),
				asphalt,
				true,
				nil,
				Enum.Material.Asphalt
			)
		end
	end

	-- darker patches (x, z, w, d, yaw)
	local patches = {
		{ -62, 18, 22, 14, 10 },
		{ 58, -6, 18, 20, -15 },
		{ -24, 66, 16, 10, 5 },
		{ 30, 30, 12, 18, 25 },
		{ -88, 56, 14, 12, 0 },
		{ 86, 46, 12, 16, -8 },
		{ -30, -46, 20, 10, -12 },
		{ 24, -2, 10, 8, 30 },
		{ 92, -52, 14, 14, 18 },
		{ -94, -66, 12, 12, 0 },
	}
	for _, q in patches do
		look(
			grp,
			"Patch",
			Vector3.new(q[3], 0.06, q[4]),
			at(q[1], 0.03, q[2]) * CFrame.Angles(0, math.rad(q[5]), 0),
			dark,
			Enum.Material.Asphalt
		)
	end
	-- skid marks: pairs of thin dark strips (x, z, length, yaw)
	local skids = {
		{ -16, 48, 16, 12 },
		{ 18, 56, 14, -10 },
		{ 34, 20, 18, 70 },
		{ -40, 30, 20, 110 },
		{ -56, -24, 16, 35 },
		{ 60, -30, 18, -40 },
	}
	for _, s in skids do
		for k = -1, 1, 2 do
			local yaw = math.rad(s[4])
			-- the second strip sits 1.4 studs to the side, across the strip
			local off = Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) * 0.7 * -k
			look(
				grp,
				"Skid",
				Vector3.new(s[3], 0.05, 0.5),
				CFrame.new(origin + Vector3.new(s[1], 0.04, s[2]) + off)
					* CFrame.Angles(0, yaw + math.pi / 2, 0),
				rgb(C.tire),
				Enum.Material.Asphalt
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- 2. paths

local function paths(folder: Folder, origin: Vector3)
	local grp = group(folder, "Paths")
	local color = rgb(C.path)
	for _, r in LobbyLayout.paths do
		local base = CFrame.new(origin + Vector3.new(r.x, 0, r.z))
			* CFrame.Angles(0, math.rad(r.yawDeg), 0)
		look(
			grp,
			"Path",
			Vector3.new(r.w, 0.2, r.d),
			base * CFrame.new(0, 0.1, 0),
			color,
			Enum.Material.Concrete
		)
		for _, s in { -1, 1 } do
			look(
				grp,
				"EdgeLine",
				Vector3.new(0.35, 0.04, r.d - 1),
				base * CFrame.new(s * (r.w / 2 - 0.7), 0.22, 0),
				WHITE
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- 3. the big PLAY ring

local function ring(folder: Folder, origin: Vector3)
	local grp = group(folder, "PlayRing")
	local r = LobbyLayout.ring
	local c = origin + Vector3.new(r.x, 0, r.z)
	local darkDisc = shade(C.asphalt, 0.62)
	local navy = rgb(C.panel)

	can(grp, "RingDisc", r.radius * 2, 0.2, c, darkDisc, false, nil, Enum.Material.Asphalt)
	-- white ring line just inside the colored rim; the dark inner disc leaves a 0.4 stud line
	can(grp, "RingLine", 44.8, 0.24, c, WHITE)
	can(grp, "RingInner", 44.0, 0.26, c, darkDisc, false, nil, Enum.Material.Asphalt)

	-- alternating orange / blue rim blocks
	local n = 24
	local rimR = 23.2
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * rimR, 0.23, math.sin(a) * rimR)
		look(
			grp,
			"RimSegment",
			Vector3.new(5.7, 0.06, 1.5),
			CFrame.new(pos) * CFrame.Angles(0, math.atan2(-math.cos(a), -math.sin(a)), 0),
			if i % 2 == 0 then rgb(C.orange) else rgb(C.blue)
		)
	end

	-- small chevrons pointing in, between the pads
	local tipR = 16.5
	for _, deg in { 0, 90, 180, 270 } do
		local a = math.rad(deg)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-math.sin(a), 0, math.cos(a))
		local tip = c + out * tipR
		for _, s in { -1, 1 } do
			local dir = out * math.cos(math.rad(40)) + side * (s * math.sin(math.rad(40)))
			look(
				grp,
				"Chevron",
				Vector3.new(3.6, 0.06, 0.9),
				CFrame.new(tip + dir * 1.8 + Vector3.new(0, 0.27, 0))
					* CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0),
				rgb(C.orange)
			)
		end
	end

	-- the hub with PLAY on top
	can(grp, "HubRim", r.hubRadius * 2 + 0.8, 0.12, c + Vector3.new(0, 0.26, 0), rgb(C.orange))
	can(grp, "Hub", r.hubRadius * 2, 0.16, c + Vector3.new(0, 0.26, 0), navy)
	local side = r.hubRadius * 1.38
	local face = look(
		grp,
		"HubFace",
		Vector3.new(side, 0.04, side),
		CFrame.new(c + Vector3.new(0, 0.44, 0)),
		navy
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlayGui"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = face
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "PLAY"
	label.TextColor3 = rgb(C.orange)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = rgb(C.blue)
	label.Parent = gui
end

-- ---------------------------------------------------------------------------------------------
-- 4. parking lines

local function parking(folder: Folder, origin: Vector3)
	local grp = group(folder, "Parking")
	local w, d = LobbyLayout.parkingSize.w, LobbyLayout.parkingSize.d
	for _, s in LobbyLayout.parking() do
		local c = origin + Vector3.new(s.x, 0.05, s.z)
		-- the car's long side runs along x: two side lines, one line at the back (away from the path)
		for _, sz in { -1, 1 } do
			look(
				grp,
				"SlotLine",
				Vector3.new(w, 0.1, 0.3),
				CFrame.new(c + Vector3.new(0, 0, sz * d / 2)),
				WHITE
			)
		end
		look(
			grp,
			"SlotBack",
			Vector3.new(0.3, 0.1, d),
			CFrame.new(c + Vector3.new(s.side * (w / 2 - 0.15), 0, 0)),
			WHITE
		)
	end
end

-- ---------------------------------------------------------------------------------------------
-- 5. tire wall

local TIRE_D, TIRE_H = 4.6, 1.6

local function tireWall(folder: Folder, origin: Vector3)
	local grp = group(folder, "TireWall")
	local tire = rgb(C.tire)
	local glow = rgb(C.light)
	for _, s in LobbyLayout.tireWall() do
		local base = origin + Vector3.new(s.x, 0, s.z)
		for k = 0, 1 do
			local off = Vector3.new((k % 2 - 0.5) * 0.6, k * (TIRE_H + 0.2), (1 - k % 2 * 2) * 0.2)
			can(grp, "Tire", TIRE_D, TIRE_H, base + off, tire, false, nil, Enum.Material.Rubber)
		end
		if s.light then
			local top = (TIRE_H + 0.2) * 2 - 0.2
			can(
				grp,
				"LightPost",
				0.8,
				1.2,
				base + Vector3.new(0, top, 0),
				rgb(C.metalDark),
				false,
				nil,
				Enum.Material.Metal
			)
			look(
				grp,
				"WallLight",
				Vector3.new(1.6, 1.4, 1.6),
				CFrame.new(base + Vector3.new(0, top + 1.2 + 0.7, 0))
					* CFrame.Angles(0, math.rad(s.yawDeg), 0),
				glow,
				Enum.Material.Neon
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- 6. flags

local function flags(folder: Folder, origin: Vector3)
	local grp = group(folder, "Flags")
	local poleH, bw, bh = 14, 6, 4
	for _, f in LobbyLayout.flags do
		local base = CFrame.new(origin + Vector3.new(f.x, 0, f.z))
		-- banners at the side entrances face along x, the front ones along z
		if math.abs(f.x) > 50 then
			base = base * CFrame.Angles(0, math.pi / 2, 0)
		end
		local color = if f.color == "orange" then rgb(C.orange) else rgb(C.blue)
		can(grp, "Pole", 0.7, poleH, base.Position, rgb(C.metal), false, nil, Enum.Material.Metal)
		look(
			grp,
			"PoleCap",
			Vector3.new(1.1, 1.1, 1.1),
			base * CFrame.new(0, poleH + 0.4, 0),
			rgb(C.gold),
			Enum.Material.Metal
		)
		local bannerCf = base * CFrame.new(bw / 2 + 0.35, poleH - bh / 2 - 0.6, 0)
		look(grp, "Banner", Vector3.new(bw, bh, 0.25), bannerCf, color)
		local len = math.sqrt((bw - 1) ^ 2 + (bh - 1) ^ 2)
		local ang = math.atan2(bh - 1, bw - 1)
		for _, s in { -1, 1 } do
			look(
				grp,
				"BannerX",
				Vector3.new(len, 0.45, 0.4),
				bannerCf * CFrame.Angles(0, 0, s * ang),
				WHITE
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- 7. the entrance arch

local function arch(folder: Folder, origin: Vector3)
	local grp = group(folder, "Arch")
	local a = LobbyLayout.arch
	local px = a.halfOpening + 2
	local beamH = 3
	local pillarH = a.height - a.signH -- the sign panel sits on top of the beam
	local function at(x: number, y: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, a.z))
	end
	for i, s in { -1, 1 } do
		local main = if i == 1 then rgb(C.blue) else rgb(C.orange)
		look(
			grp,
			"Pillar",
			Vector3.new(4, pillarH - beamH, 4),
			at(s * px, (pillarH - beamH) / 2),
			main,
			Enum.Material.SmoothPlastic
		)
		look(
			grp,
			"PillarBase",
			Vector3.new(5, 1.2, 5),
			at(s * px, 0.6),
			rgb(C.metalDark),
			Enum.Material.Metal
		)
		look(grp, "PillarBand", Vector3.new(4.3, 1.4, 4.3), at(s * px, pillarH * 0.5), WHITE)
	end
	-- top beam between the pillars, the sign panel above it
	local beamW = px * 2 + 4
	look(
		grp,
		"Beam",
		Vector3.new(beamW, beamH, 4.4),
		at(0, pillarH - beamH / 2),
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	look(
		grp,
		"BeamLight",
		Vector3.new(beamW - 2, 0.5, 0.3),
		at(0, pillarH - beamH / 2) * CFrame.new(0, -0.4, -2.3),
		rgb(C.light),
		Enum.Material.Neon
	)

	local panelY = pillarH + a.signH / 2
	local panel = look(
		grp,
		"SignPanel",
		Vector3.new(a.signW, a.signH, 1.6),
		at(0, panelY),
		rgb(C.panel),
		Enum.Material.Metal
	)
	-- chunky orange frame in front of the panel
	local fz = -0.9
	look(
		grp,
		"FrameTop",
		Vector3.new(a.signW + 1, 0.8, 1.2),
		at(0, panelY + a.signH / 2 + 0.2) * CFrame.new(0, 0, fz + 0.3),
		rgb(C.orange)
	)
	look(
		grp,
		"FrameBottom",
		Vector3.new(a.signW + 1, 0.8, 1.2),
		at(0, panelY - a.signH / 2 - 0.2) * CFrame.new(0, 0, fz + 0.3),
		rgb(C.orange)
	)
	for _, s in { -1, 1 } do
		look(
			grp,
			"FrameSide",
			Vector3.new(0.8, a.signH, 1.2),
			at(s * (a.signW / 2 + 0.2), panelY) * CFrame.new(0, 0, fz + 0.3),
			rgb(C.orange)
		)
	end

	-- both faces: the spawn is on the +z side (outside), the plaza on the -z side
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.8)
		label.Position = UDim2.fromScale(0.03, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "CAR VS CAR"
		label.TextColor3 = rgb(C.orange)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = rgb(C.blue)
		label.Parent = gui
	end
end

-- ---------------------------------------------------------------------------------------------
-- 8. props

local function bench(grp: Folder, origin: Vector3, b: { x: number, z: number, yawDeg: number })
	local m = group(grp, "Bench")
	local base = CFrame.new(origin + Vector3.new(b.x, 0, b.z))
		* CFrame.Angles(0, math.rad(b.yawDeg), 0)
	-- yaw 0: the long side runs along z, the back is on the -x side
	look(
		m,
		"Seat",
		Vector3.new(2.6, 0.5, 8),
		base * CFrame.new(0, 1.7, 0),
		rgb(C.wood),
		Enum.Material.Wood
	)
	look(
		m,
		"Back",
		Vector3.new(0.5, 1.8, 8),
		base * CFrame.new(-1.2, 2.9, 0),
		rgb(C.wood),
		Enum.Material.Wood
	)
	for _, s in { -1, 1 } do
		look(
			m,
			"Leg",
			Vector3.new(2.2, 1.5, 0.7),
			base * CFrame.new(0, 0.75, s * 3.3),
			rgb(C.metalDark),
			Enum.Material.Metal
		)
	end
end

local function cone(grp: Folder, origin: Vector3, x: number, z: number)
	local m = group(grp, "Cone")
	local p = origin + Vector3.new(x, 0, z)
	look(
		m,
		"Base",
		Vector3.new(1.8, 0.2, 1.8),
		CFrame.new(p + Vector3.new(0, 0.1, 0)),
		rgb(C.asphaltDark)
	)
	can(m, "Lower", 1.3, 0.7, p + Vector3.new(0, 0.2, 0), rgb(C.orange))
	can(m, "Stripe", 1.0, 0.4, p + Vector3.new(0, 0.9, 0), WHITE)
	can(m, "Top", 0.65, 0.6, p + Vector3.new(0, 1.3, 0), rgb(C.orange))
end

local function cart(
	grp: Folder,
	origin: Vector3,
	c: { x: number, z: number, yawDeg: number },
	i: number
)
	local m = group(grp, "ToolCart")
	local base = CFrame.new(origin + Vector3.new(c.x, 0, c.z))
		* CFrame.Angles(0, math.rad(c.yawDeg), 0)
	local body = if i % 2 == 1 then rgb(C.blue) else rgb(C.orange)
	local drawer = shade(if i % 2 == 1 then C.blue else C.orange, 1.22)
	-- footprint 6 x 4: long side along x, the drawers face +z
	look(m, "Body", Vector3.new(5.6, 2.6, 3.4), base * CFrame.new(0, 1.9, 0), body)
	look(
		m,
		"Top",
		Vector3.new(6, 0.4, 3.8),
		base * CFrame.new(0, 3.4, 0),
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	for k = -1, 1 do
		look(m, "Drawer", Vector3.new(1.6, 0.7, 0.2), base * CFrame.new(k * 1.8, 1.9, 1.75), drawer)
		look(m, "Handle", Vector3.new(0.9, 0.15, 0.2), base * CFrame.new(k * 1.8, 1.9, 1.9), WHITE)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = look(
				m,
				"Wheel",
				Vector3.new(0.6, 1.2, 1.2),
				base * CFrame.new(sx * 2.4, 0.6, sz * 1.5) * CFrame.Angles(0, math.pi / 2, 0),
				rgb(C.tire),
				Enum.Material.Rubber
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
end

local function props(folder: Folder, origin: Vector3)
	local grp = group(folder, "Props")
	local benches = group(grp, "Benches")
	for _, b in LobbyLayout.benches do
		bench(benches, origin, b)
	end
	local cones = group(grp, "Cones")
	for _, c in LobbyLayout.cones do
		cone(cones, origin, c.x, c.z)
	end
	local carts = group(grp, "Carts")
	for i, c in LobbyLayout.carts do
		cart(carts, origin, c, i)
	end
end

-- ---------------------------------------------------------------------------------------------
-- 9. blockers

local function blocker(grp: Folder, name: string, size: Vector3, cf: CFrame)
	local p = part(grp, name, size, cf, Color3.new(1, 1, 1), true, nil, nil)
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function blockers(folder: Folder, origin: Vector3)
	local grp = group(folder, "Blockers")
	for _, r in LobbyLayout.blockers() do
		blocker(
			grp,
			"Blocker",
			Vector3.new(r.w, BLOCKER_TALL, r.d),
			CFrame.new(origin + Vector3.new(r.x, BLOCKER_TALL / 2, r.z))
				* CFrame.Angles(0, math.rad(r.yawDeg), 0)
		)
	end
	-- look-only props get a short invisible box so nobody climbs them
	local function prop(name: string, x: number, z: number, w: number, d: number, yaw: number)
		blocker(
			grp,
			name,
			Vector3.new(w, PROP_BLOCKER_TALL, d),
			CFrame.new(origin + Vector3.new(x, PROP_BLOCKER_TALL / 2, z))
				* CFrame.Angles(0, math.rad(yaw), 0)
		)
	end
	for _, b in LobbyLayout.benches do
		prop("BenchBlocker", b.x, b.z, 3.2, 8.4, b.yawDeg)
	end
	for _, c in LobbyLayout.carts do
		prop("CartBlocker", c.x, c.z, 6.2, 4.2, c.yawDeg)
	end
	local a = LobbyLayout.arch
	for _, s in { -1, 1 } do
		prop("PillarBlocker", s * (a.halfOpening + 2), a.z, 5, 5, 0)
	end
end

-- ---------------------------------------------------------------------------------------------
-- 10. music spot

local function music(folder: Folder, origin: Vector3)
	local m = LobbyLayout.music
	local spot = Instance.new("Part")
	spot.Name = "MusicSpot"
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = CFrame.new(origin + Vector3.new(m.x, m.y, m.z))
	spot.Anchored = true
	spot.Transparency = 1
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.CastShadow = false
	spot.Parent = folder
	local sound = Instance.new("Sound")
	sound.Name = "LobbyMusic"
	sound.SoundId = "" -- silent until carter gives an id
	sound.Looped = true
	sound.Volume = 0.5
	sound.RollOffMaxDistance = 260
	sound.Parent = spot
end

function LobbyGround.build(folder: Folder, origin: Vector3)
	plaza(folder, origin)
	paths(folder, origin)
	ring(folder, origin)
	parking(folder, origin)
	tireWall(folder, origin)
	flags(folder, origin)
	arch(folder, origin)
	props(folder, origin)
	blockers(folder, origin)
	music(folder, origin)
end

return LobbyGround
