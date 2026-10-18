--!strict
-- Extra detail for the lobby: floor stains and hazard strips, wall posters and vents, hanging
-- banners, fire extinguishers, tool carts, tire racks, garage shelves and a few animated bits
-- (spinning fans, blinking signs). Look only (no collision), plain parts so it stays light on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyDetail = {}

local RED = Color3.fromRGB(228, 40, 44)
local YELLOW = Color3.fromRGB(255, 205, 30)
local CYAN = Color3.fromRGB(40, 230, 235)
local NAVY = Color3.fromRGB(18, 28, 70)
local DARK = Color3.fromRGB(24, 26, 34)
local STEEL = Color3.fromRGB(170, 176, 190)
local WHITE = Color3.fromRGB(240, 242, 248)

function LobbyDetail.build(parent: Folder, origin: Vector3)
	local L = LobbyLayout
	local room = L.room
	local HW, HL, WH = room.halfW, room.halfL, room.wallHeight
	local top = WH + room.upper

	local folder = Instance.new("Folder")
	folder.Name = "Detail"
	folder.Parent = parent

	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = folder
		return p
	end
	local function world(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	-- A part facing the direction (dx, dz) (a wall item looking into the room).
	local function facing(x: number, y: number, z: number, dx: number, dz: number): CFrame
		local pos = origin + Vector3.new(x, y, z)
		return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
	end
	local function text(
		p: BasePart,
		face: Enum.NormalId,
		str: string,
		color: Color3,
		ppu: number?
	): TextLabel
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppu or 24
		gui.LightInfluence = 0
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = str
		t.TextColor3 = color
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = gui
		return t
	end
	local function glow(p: BasePart, color: Color3, range: number, brightness: number)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = p
	end

	------------------------------------------------------------------ floor
	-- Oil stains and tire marks (flat, dark, a little see-through).
	local function stain(x: number, z: number, d: number)
		local s = part(
			"OilStain",
			Vector3.new(0.04, d, d * 0.8),
			world(x, 0.07, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(10, 12, 18),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		s.Transparency = 0.45
	end
	for _, s in
		{
			{ -44, 6, 6 },
			{ -40, 8, 3.5 },
			{ 44, -26, 5 },
			{ 40, -23, 3 },
			{ -14, 36, 4.5 },
			{ 16, -8, 3 },
			{ -50, -38, 5 },
			{ 52, 12, 4 },
			{ -8, -18, 3.5 },
		}
	do
		stain(s[1], s[2], s[3])
	end
	-- Skid marks: pairs of thin dark strips, a few segments making a gentle curve.
	local function skid(x: number, z: number, yawDeg: number, len: number)
		for _, off in { -1.1, 1.1 } do
			local m = part(
				"TireMark",
				Vector3.new(0.7, 0.04, len),
				world(x, 0.075, z) * CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.new(off, 0, 0),
				Color3.fromRGB(14, 16, 22),
				Enum.Material.SmoothPlastic
			)
			m.Transparency = 0.35
		end
	end
	skid(-16, 16, 14, 12)
	skid(-13.6, 6, 28, 10)
	skid(-9.4, -1.5, 44, 8)
	skid(18, 38, -10, 12)
	skid(20.5, 28.5, -26, 8)
	skid(36, -16, 70, 14)
	skid(-38, -22, -60, 12)

	-- Hazard strips along the foot of both side walls (black strip, yellow blocks).
	for _, sx in { -1, 1 } do
		local x = sx * (HW - 1.8)
		part(
			"HazardBase",
			Vector3.new(2.4, 0.06, HL * 2 - 4),
			world(x, 0.08, 0),
			DARK,
			Enum.Material.SmoothPlastic
		)
		for k = 0, 16 do
			part(
				"HazardBlock",
				Vector3.new(2.4, 0.07, 2.4),
				world(x, 0.1, -HL + 4 + k * 8),
				YELLOW,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Hazard strip across the front, by the door.
	for k = -8, 8 do
		part(
			"HazardBlock",
			Vector3.new(2.4, 0.07, 2.4),
			world(k * 6, 0.1, HL - 3.4),
			if k % 2 == 0 then YELLOW else DARK,
			Enum.Material.SmoothPlastic
		)
	end

	------------------------------------------------------------------ walls
	-- Posters and sponsor stickers. face: the way the poster looks (into the room).
	local function poster(
		x: number,
		y: number,
		z: number,
		dx: number,
		dz: number,
		w: number,
		h: number,
		bg: Color3,
		title: string,
		sub: string?,
		fg: Color3
	)
		part("PosterFrame", Vector3.new(w + 0.8, h + 0.8, 0.3), facing(x, y, z, dx, dz), DARK)
		local back = part(
			"Poster",
			Vector3.new(w, h, 0.4),
			facing(x + dx * 0.05, y, z + dz * 0.05, dx, dz),
			bg
		)
		local t = text(back, Enum.NormalId.Front, title, fg, 14)
		if sub then
			t.Size = UDim2.fromScale(1, 0.6)
			t.Position = UDim2.fromScale(0, 0.08)
			local s = text(back, Enum.NormalId.Front, sub, fg, 14)
			s.Size = UDim2.fromScale(0.9, 0.22)
			s.Position = UDim2.fromScale(0.05, 0.7)
		end
	end
	local POSTERS = {
		{ "NITRO", "BOOST UP", Color3.fromRGB(230, 50, 50), WHITE },
		{ "TURBO", "OIL & TIRES", YELLOW, DARK },
		{ "SPEED", "LEAGUE 2025", Color3.fromRGB(30, 150, 220), WHITE },
		{ "DRIFT", "KING", Color3.fromRGB(30, 30, 40), YELLOW },
		{ "RACE HQ", "WIN BIG", Color3.fromRGB(40, 170, 90), WHITE },
		{ "FAST", "LANE", Color3.fromRGB(150, 60, 200), WHITE },
	}
	local pi = 0
	local function nextPoster(): { any }
		pi = pi % #POSTERS + 1
		return POSTERS[pi]
	end
	-- Side walls, the short stretch beside the store and the paint booth (x = +-63.8).
	for _, sx in { -1, 1 } do
		for _, z in { 48, 58, 66 } do
			local p = nextPoster()
			poster(sx * (HW - 0.2), 12, z, -sx, 0, 6, 8, p[3], p[1], p[2], p[4])
		end
	end
	-- Above the garage portals, high on the side walls: big stickers.
	for _, sx in { -1, 1 } do
		for k = 0, 3 do
			local p = nextPoster()
			poster(sx * (HW - 0.2), 31.5, -50 + k * 28, -sx, 0, 14, 6, p[3], p[1], p[2], p[4])
		end
	end
	-- Back wall: posters between the roller doors and a big checkered band under the claw sign.
	for _, x in { -57, -24, 25 } do
		local p = nextPoster()
		poster(x, 12, -HL + 1.1, 0, 1, 7, 9, p[3], p[1], p[2], p[4])
	end
	-- Front wall (behind the player when they spawn).
	for _, x in { -52, -34, 34, 52 } do
		local p = nextPoster()
		poster(x, 12, HL - 1.1, 0, -1, 9, 11, p[3], p[1], p[2], p[4])
	end

	-- Neon accent strips running round the hall under the roof.
	local function neon(x: number, y: number, z: number, sx: number, sz: number, color: Color3)
		local n =
			part("NeonStrip", Vector3.new(sx, 0.5, sz), world(x, y, z), color, Enum.Material.Neon)
		return n
	end
	for _, sx in { -1, 1 } do
		local n = neon(sx * (HW - 0.4), top - 6, 0, 0.5, HL * 2 - 4, CYAN)
		glow(n, CYAN, 22, 0.8)
	end
	local nb = neon(0, top - 6, -HL + 0.4, HW * 2 - 4, 0.5, YELLOW)
	glow(nb, YELLOW, 22, 0.6)
	neon(0, top - 6, HL - 0.4, HW * 2 - 4, 0.5, RED)

	-- Vents with spinning fans on the back and front walls (the fans are animated below).
	type Fan = { parts: { BasePart }, rel: { CFrame }, base: CFrame }
	local fans: { Fan } = {}
	local function vent(x: number, y: number, z: number, dx: number, dz: number)
		local cf = facing(x, y, z, dx, dz)
		part(
			"VentFrame",
			Vector3.new(7.6, 7.6, 0.5),
			cf,
			Color3.fromRGB(96, 102, 118),
			Enum.Material.Metal
		)
		part("VentHole", Vector3.new(6.4, 6.4, 0.5), cf * CFrame.new(0, 0, -0.1), DARK)
		local fan: Fan = { parts = {}, rel = {}, base = cf * CFrame.new(0, 0, -0.4) }
		local hubRel = CFrame.Angles(0, math.pi / 2, 0)
		local hub = part(
			"Fan",
			Vector3.new(0.4, 1.2, 1.2),
			fan.base * hubRel,
			STEEL,
			nil,
			Enum.PartType.Cylinder
		)
		table.insert(fan.parts, hub)
		table.insert(fan.rel, hubRel)
		for k = 0, 2 do
			local rel = CFrame.Angles(0, 0, math.rad(k * 60))
			table.insert(
				fan.parts,
				part("FanBlade", Vector3.new(0.7, 2.8, 0.2), fan.base * rel, STEEL)
			)
			table.insert(fan.rel, rel)
		end
		table.insert(fans, fan)
		-- Grille bars over the fan.
		for k = -2, 2 do
			part("VentBar", Vector3.new(6.4, 0.3, 0.3), cf * CFrame.new(0, k * 1.2, -0.6), STEEL)
		end
	end
	for _, x in { -52, -34, 34 } do
		vent(x, 30, -HL + 0.6, 0, 1)
	end
	vent(-24, 30, HL - 0.6, 0, -1)
	vent(24, 30, HL - 0.6, 0, -1)

	-- Pipes and cable runs along the side walls, with brackets.
	for _, sx in { -1, 1 } do
		local x = sx * (HW - 0.9)
		local pipe = part(
			"WallPipe",
			Vector3.new(HL * 2 - 6, 0.9, 0.9),
			world(x, 20, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(178, 182, 196),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		local _ = pipe
		part(
			"WallCable",
			Vector3.new(0.5, 0.5, HL * 2 - 6),
			world(x, 21.3, 0),
			Color3.fromRGB(230, 60, 50)
		)
		for k = 0, 8 do
			part("PipeBracket", Vector3.new(0.6, 2.4, 0.6), world(x, 20.6, -HL + 5 + k * 16), DARK)
		end
	end

	-- Fire extinguishers (red can, black nozzle, a white sign above).
	local function extinguisher(x: number, z: number, dx: number)
		local can = part(
			"Extinguisher",
			Vector3.new(2.6, 1.1, 1.1),
			world(x, 3, z) * CFrame.Angles(0, 0, math.pi / 2),
			RED,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		can.Size = Vector3.new(2.6, 1.1, 1.1)
		part("ExtinguisherTop", Vector3.new(0.5, 0.9, 0.5), world(x, 4.5, z), DARK)
		part(
			"ExtinguisherBand",
			Vector3.new(0.3, 1.2, 1.2),
			world(x, 3, z) * CFrame.Angles(0, 0, math.pi / 2),
			YELLOW,
			nil,
			Enum.PartType.Cylinder
		)
		local sign =
			part("ExtSign", Vector3.new(2.2, 2.2, 0.2), facing(x - dx * 0.4, 7, z, -dx, 0), RED)
		text(sign, Enum.NormalId.Front, "FIRE", WHITE, 20)
	end
	extinguisher(-HW + 1.4, 44, -1)
	extinguisher(HW - 1.4, 44, 1)
	extinguisher(-HW + 1.4, -66, -1)
	extinguisher(HW - 1.4, -66, 1)

	------------------------------------------------------------------ floor props
	-- A tool cart: red box with drawers, a steel top and wheels.
	local function cart(x: number, z: number, yaw: number)
		local cf = world(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
		part("CartBody", Vector3.new(4, 3.2, 2.4), cf * CFrame.new(0, 2.2, 0), RED)
		part(
			"CartTop",
			Vector3.new(4.3, 0.3, 2.7),
			cf * CFrame.new(0, 3.95, 0),
			STEEL,
			Enum.Material.Metal
		)
		for k = 0, 2 do
			part(
				"CartDrawer",
				Vector3.new(3.4, 0.7, 0.2),
				cf * CFrame.new(0, 1.4 + k * 0.95, -1.2),
				DARK
			)
			part(
				"CartHandle",
				Vector3.new(1.4, 0.2, 0.3),
				cf * CFrame.new(0, 1.4 + k * 0.95, -1.3),
				STEEL
			)
		end
		for _, wx in { -1.6, 1.6 } do
			for _, wz in { -0.9, 0.9 } do
				part(
					"CartWheel",
					Vector3.new(0.4, 0.8, 0.8),
					cf * CFrame.new(wx, 0.45, wz),
					DARK,
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
			end
		end
		-- A wrench and a can on top.
		part(
			"CartWrench",
			Vector3.new(0.3, 0.2, 2),
			cf * CFrame.new(-0.8, 4.2, 0) * CFrame.Angles(0, 0.4, 0),
			YELLOW
		)
		part(
			"CartCan",
			Vector3.new(0.9, 0.9, 0.9),
			cf * CFrame.new(1, 4.5, 0.2),
			CYAN,
			nil,
			Enum.PartType.Cylinder
		)
	end
	cart(-60, 34, 90)
	cart(60, 34, -90)
	cart(-60, -66, 90)

	-- A tire rack: steel frame with three tires on each of two shelves.
	local function tireRack(x: number, z: number, yaw: number)
		local cf = world(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
		for _, px in { -3.4, 3.4 } do
			part(
				"RackPost",
				Vector3.new(0.5, 6.4, 0.5),
				cf * CFrame.new(px, 3.2, 0),
				YELLOW,
				Enum.Material.Metal
			)
		end
		for level = 0, 1 do
			part(
				"RackShelf",
				Vector3.new(7.4, 0.4, 2.4),
				cf * CFrame.new(0, 0.6 + level * 2.8, 0),
				STEEL,
				Enum.Material.Metal
			)
			for k = -1, 1 do
				local t = part(
					"RackTire",
					Vector3.new(1.4, 2.2, 2.2),
					cf
						* CFrame.new(k * 2.2, 1.9 + level * 2.8, 0)
						* CFrame.Angles(0, math.pi / 2, 0),
					DARK,
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
				part(
					"RackRim",
					Vector3.new(1.5, 1.2, 1.2),
					t.CFrame,
					if (k + level) % 2 == 0 then RED else YELLOW,
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
			end
		end
	end
	tireRack(-61, 50, 90)
	tireRack(61, 50, -90)

	-- A trolley jack by the paint side and a stack of crates.
	local function jack(x: number, z: number, yaw: number)
		local cf = world(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
		part("JackBase", Vector3.new(1.4, 0.6, 3.2), cf * CFrame.new(0, 0.5, 0), RED)
		part(
			"JackArm",
			Vector3.new(0.5, 0.5, 2.6),
			cf * CFrame.new(0, 1.2, -0.4) * CFrame.Angles(0.3, 0, 0),
			STEEL,
			Enum.Material.Metal
		)
		part("JackPad", Vector3.new(1.2, 0.3, 1.2), cf * CFrame.new(0, 1.8, -1.2), YELLOW)
		part(
			"JackHandle",
			Vector3.new(0.3, 0.3, 3),
			cf * CFrame.new(0, 1.8, 2.6) * CFrame.Angles(-0.4, 0, 0),
			DARK
		)
	end
	jack(-52, 62, 20)
	jack(52, 62, -30)
	jack(28, -64, 10)

	-- Crates by the back corners.
	for _, c in { { -60, -62 }, { -57, -60 }, { 60, -64 } } do
		part(
			"Crate",
			Vector3.new(3.2, 3.2, 3.2),
			world(c[1], 1.6, c[2]) * CFrame.Angles(0, math.rad(c[1] * 3), 0),
			Color3.fromRGB(176, 128, 70),
			Enum.Material.Wood
		)
		part(
			"CrateBand",
			Vector3.new(3.3, 0.5, 3.3),
			world(c[1], 2.6, c[2]) * CFrame.Angles(0, math.rad(c[1] * 3), 0),
			YELLOW
		)
	end

	------------------------------------------------------------------ garages
	local bay = L.bay
	for _, b in L.bays do
		local inward = b.face
		local backX = b.x - inward * (bay.w / 2 - 0.4)
		-- Parts shelf against the back wall: three levels with boxes, cans and a tire.
		local shelfX = backX + inward * 1.8
		local shelfZ = b.z - 9
		for _, side in { -1, 1 } do
			part(
				"ShelfPost",
				Vector3.new(0.5, 8, 0.5),
				world(shelfX, 4, shelfZ + side * 3.4),
				STEEL,
				Enum.Material.Metal
			)
		end
		for level = 1, 3 do
			local y = level * 2.4 - 1.2
			part(
				"ShelfPlank",
				Vector3.new(2.6, 0.4, 7.4),
				world(shelfX, y, shelfZ),
				YELLOW,
				Enum.Material.Metal
			)
			for k = -1, 1 do
				local c = k + level
				if c % 3 == 0 then
					part(
						"ShelfBox",
						Vector3.new(1.8, 1.3, 1.8),
						world(shelfX, y + 0.85, shelfZ + k * 2.2),
						Color3.fromRGB(176, 128, 70),
						Enum.Material.Wood
					)
				elseif c % 3 == 1 then
					part(
						"ShelfCan",
						Vector3.new(1.4, 1.2, 1.2),
						world(shelfX, y + 0.8, shelfZ + k * 2.2),
						if level == 2 then RED else CYAN,
						nil,
						Enum.PartType.Cylinder
					)
					part(
						"ShelfCan",
						Vector3.new(1.1, 1.0, 1.0),
						world(shelfX, y + 0.8, shelfZ + k * 2.2 + 0.9),
						WHITE,
						nil,
						Enum.PartType.Cylinder
					)
				else
					part(
						"ShelfTire",
						Vector3.new(1.0, 1.8, 1.8),
						world(shelfX, y + 1.1, shelfZ + k * 2.2) * CFrame.Angles(0, 0, math.pi / 2),
						DARK,
						nil,
						Enum.PartType.Cylinder
					)
				end
			end
		end
		-- Oil drum and cone by the lift, and an extinguisher on the divider.
		part(
			"BayDrum",
			Vector3.new(3, 2.4, 2.4),
			world(b.x - inward * 6, 1.5, b.z + 11) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(30, 100, 190),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		).Size =
			Vector3.new(3, 2.4, 2.4)
		part(
			"BayDrumBand",
			Vector3.new(0.4, 2.5, 2.5),
			world(b.x - inward * 6, 1.5, b.z + 11) * CFrame.Angles(0, 0, math.pi / 2),
			YELLOW,
			nil,
			Enum.PartType.Cylinder
		)
		-- A hanging work lamp with a glow.
		local lamp = part(
			"BayLamp",
			Vector3.new(2, 0.8, 2),
			world(b.x + inward * 4, WH - 3, b.z),
			Color3.fromRGB(255, 240, 200),
			Enum.Material.Neon
		)
		glow(lamp, Color3.fromRGB(255, 240, 200), 28, 1.2)
		-- Hazard stripes on the garage floor edge at the portal.
		for k = -6, 6 do
			part(
				"PortalStripe",
				Vector3.new(2, 0.07, 2),
				world(b.x + inward * (bay.w / 2 - 1.2), 0.1, b.z + k * 2),
				if k % 2 == 0 then YELLOW else DARK
			)
		end
	end

	------------------------------------------------------------------ hanging banners
	local BANNERS = {
		{ "TURBO", Color3.fromRGB(230, 50, 50), WHITE },
		{ "NITRO", YELLOW, DARK },
		{ "RACE", Color3.fromRGB(30, 150, 220), WHITE },
	}
	local bi = 0
	for _, x in { -48, 48 } do
		for _, z in { -26, 4, 34 } do
			bi = bi % #BANNERS + 1
			local def = BANNERS[bi]
			local by = top - 10
			-- Two cables, the banner and a checkered foot.
			for _, cx in { -2.4, 2.4 } do
				part("BannerCable", Vector3.new(0.2, 6, 0.2), world(x + cx, top - 3, z), DARK)
			end
			local banner = part("Banner", Vector3.new(7, 9, 0.4), world(x, by, z), def[2])
			text(banner, Enum.NormalId.Front, def[1], def[3], 10)
			text(banner, Enum.NormalId.Back, def[1], def[3], 10)
			for k = -3, 3 do
				part(
					"BannerCheck",
					Vector3.new(1, 1, 0.5),
					world(x + k, by - 4, z),
					if k % 2 == 0 then DARK else WHITE
				)
			end
		end
	end

	------------------------------------------------------------------ blinking signs
	local blinkers: { { part: BasePart, on: Color3, off: Color3 } } = {}
	local function blinkSign(
		x: number,
		y: number,
		z: number,
		dx: number,
		dz: number,
		str: string,
		color: Color3
	)
		part("BlinkSign", Vector3.new(11, 3.4, 0.5), facing(x, y, z, dx, dz), DARK)
		local face = part(
			"BlinkFace",
			Vector3.new(10, 2.6, 0.4),
			facing(x + dx * 0.1, y, z + dz * 0.1, dx, dz),
			NAVY
		)
		text(face, Enum.NormalId.Front, str, color, 20)
		glow(face, color, 16, 0.6)
		local rim = part(
			"BlinkRim",
			Vector3.new(11.4, 0.4, 0.6),
			facing(x, y + 1.9, z, dx, dz),
			color,
			Enum.Material.Neon
		)
		table.insert(blinkers, { part = rim, on = color, off = DARK })
	end
	blinkSign(-HW + 0.8, 24, 56, 1, 0, "OPEN 24H", RED)
	blinkSign(HW - 0.8, 24, 56, -1, 0, "PIT STOP", YELLOW)
	blinkSign(-24, 22, HL - 1, 0, -1, "EXIT", CYAN)

	-- Animate: fans spin, sign rims blink. One light loop for the whole hall.
	local t = 0
	local step = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if folder.Parent == nil then
			conn:Disconnect()
			return
		end
		t += dt
		step += dt
		if step >= 1 / 20 then
			step = 0
			local spin = CFrame.Angles(0, 0, t * 6)
			for _, fan in fans do
				for i, p in fan.parts do
					p.CFrame = fan.base * spin * fan.rel[i]
				end
			end
		end
		local on = (math.floor(t * 1.6) % 2) == 0
		for _, bl in blinkers do
			bl.part.Color = if on then bl.on else bl.off
			bl.part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end)
end

return LobbyDetail
