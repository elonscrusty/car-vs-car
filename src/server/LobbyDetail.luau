--!strict
-- Small garage details for the lobby (look only: nothing here collides, so nobody gets stuck):
-- car lift with a car, tool carts, tire rack, gas cans, lounge corner with a TV, posters, ceiling
-- pipes and vents, string lights, floor markings, drain grates, light pools and window panes in
-- the roller doors. Lobby.build calls `LobbyDetail.build` once, after the garage shell.
-- Everything is named (Lift*, Cart*, Poster*, ...) so real models can replace it later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

export type Helpers = {
	part: (
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	) -> Part,
	label: (
		p: BasePart,
		face: Enum.NormalId,
		text: string,
		color: Color3,
		strokeColor: Color3?
	) -> TextLabel,
	glow: (p: BasePart, color: Color3, range: number, brightness: number) -> (),
}

local LobbyDetail = {}

local RED = Color3.fromRGB(215, 40, 40)
local YELLOW = Color3.fromRGB(255, 205, 40)
local CYAN = Color3.fromRGB(60, 220, 255)
local DARK = Color3.fromRGB(28, 30, 38)
local STEEL = Color3.fromRGB(85, 88, 98)
local LIGHT_METAL = Color3.fromRGB(150, 153, 163)
local WHITE = Color3.fromRGB(240, 240, 240)
local WARM = Color3.fromRGB(255, 244, 200)
local BULBS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 205, 40),
	Color3.fromRGB(60, 220, 255),
	Color3.fromRGB(90, 255, 120),
	Color3.fromRGB(255, 110, 200),
}

function LobbyDetail.build(folder: Folder, origin: Vector3, h: Helpers)
	local room = LobbyLayout.room
	local R, WH = room.radius, room.wallHeight
	local top = WH + 15 -- underside of the roof

	local function world(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end

	-- A look-only part.
	local function d(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = h.part(folder, name, size, cf, color, material, shape)
		p.CanCollide = false
		p.CanQuery = false
		return p
	end

	-- A spot on the wall ring: its -Z side faces the middle of the room, `inset` studs inside the
	-- inner wall face (0 = on it).
	local function wallCf(deg: number, inset: number, y: number): CFrame
		local a = math.rad(deg)
		local r = R - room.wall / 2 - inset
		return CFrame.lookAt(
			origin + Vector3.new(math.sin(a) * r, y, math.cos(a) * r),
			origin + Vector3.new(0, y, 0)
		)
	end

	-- A long thin part along X or Z (pipes, cables, floor strips).
	local function rod(
		name: string,
		a: Vector3,
		b: Vector3,
		thick: number,
		color: Color3,
		material: Enum.Material?
	)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		return d(
			name,
			Vector3.new(thick, thick, len),
			CFrame.lookAt(origin + mid, origin + b),
			color,
			material
		)
	end

	-- Car lift (left of the pads) with a blue car raised on it.
	local lx, lz = -38, 4
	for _, sx in { -1, 1 } do
		h.part(
			folder,
			"LiftPost",
			Vector3.new(1.2, 14, 1.6),
			world(lx + sx * 4.6, 7, lz),
			STEEL,
			Enum.Material.Metal
		)
		d("LiftPlate", Vector3.new(2.6, 0.3, 3.6), world(lx + sx * 4.6, 0.15, lz), YELLOW)
		d("LiftArm", Vector3.new(0.8, 0.8, 12), world(lx + sx * 3.2, 6, lz), YELLOW)
	end
	d("LiftBeam", Vector3.new(10, 0.9, 1), world(lx, 14, lz), STEEL, Enum.Material.Metal)
	local carBlue = Color3.fromRGB(40, 110, 230)
	d("LiftCarBody", Vector3.new(5.4, 1.6, 10.5), world(lx, 7.6, lz), carBlue)
	d(
		"LiftCarCabin",
		Vector3.new(4.4, 1.4, 5),
		world(lx, 9, lz + 0.6),
		Color3.fromRGB(150, 210, 250)
	)
	d("LiftCarBumper", Vector3.new(5.6, 0.7, 0.6), world(lx, 7, lz - 5.3), DARK)
	for _, sx in { -1, 1 } do
		d(
			"LiftCarHeadlight",
			Vector3.new(0.9, 0.6, 0.3),
			world(lx + sx * 1.9, 7.8, lz - 5.3),
			WARM,
			Enum.Material.Neon
		)
		d(
			"LiftCarTaillight",
			Vector3.new(0.9, 0.6, 0.3),
			world(lx + sx * 1.9, 7.8, lz + 5.3),
			RED,
			Enum.Material.Neon
		)
		for _, sz in { -1, 1 } do
			d(
				"LiftCarWheel",
				Vector3.new(0.9, 2.2, 2.2),
				world(lx + sx * 3, 6.8, lz + sz * 3.4),
				DARK,
				nil,
				Enum.PartType.Cylinder
			)
		end
	end
	-- Yellow outline on the floor around the lift.
	for _, sx in { -1, 1 } do
		d("LiftMark", Vector3.new(0.4, 0.05, 15), world(lx + sx * 8, 0.07, lz), YELLOW)
	end
	for _, sz in { -1, 1 } do
		d("LiftMark", Vector3.new(16.4, 0.05, 0.4), world(lx, 0.07, lz + sz * 7.5), YELLOW)
	end

	-- Rolling tool carts (red, with drawers and four small wheels).
	for _, c in { Vector3.new(-33, 0, -14), Vector3.new(41, 0, -9), Vector3.new(-45, 0, 17) } do
		local ccf = world(c.X, 0, c.Z)
		d("CartBody", Vector3.new(3.2, 3, 2.2), ccf * CFrame.new(0, 2, 0), RED)
		d("CartTop", Vector3.new(3.5, 0.3, 2.5), ccf * CFrame.new(0, 3.65, 0), DARK)
		for k = 0, 2 do
			d(
				"CartDrawer",
				Vector3.new(2.8, 0.12, 0.12),
				ccf * CFrame.new(0, 1.2 + k * 0.9, -1.15),
				DARK
			)
			d(
				"CartHandle",
				Vector3.new(1, 0.2, 0.2),
				ccf * CFrame.new(0, 1.5 + k * 0.9, -1.2),
				LIGHT_METAL
			)
		end
		for _, wx in { -1.3, 1.3 } do
			for _, wz in { -0.8, 0.8 } do
				d(
					"CartWheel",
					Vector3.new(0.3, 0.6, 0.6),
					ccf * CFrame.new(wx, 0.3, wz),
					DARK,
					nil,
					Enum.PartType.Cylinder
				)
			end
		end
		d(
			"CartWrench",
			Vector3.new(0.3, 0.2, 1.8),
			ccf * CFrame.new(0.6, 3.9, 0.2) * CFrame.Angles(0, 0.4, 0),
			YELLOW
		)
	end

	-- Tire rack on the front-right wall, with gas cans next to it.
	local rack = wallCf(32, 1.4, 0)
	for _, rx in { -6, 0, 6 } do
		d(
			"RackPost",
			Vector3.new(0.5, 8, 0.5),
			rack * CFrame.new(rx, 4, 0),
			STEEL,
			Enum.Material.Metal
		)
	end
	for level = 1, 2 do
		d(
			"RackShelf",
			Vector3.new(13, 0.5, 2.6),
			rack * CFrame.new(0, level * 3, 0),
			STEEL,
			Enum.Material.Metal
		)
		for k = 1, 4 do
			d(
				"RackTire",
				Vector3.new(1.2, 2.8, 2.8),
				rack
					* CFrame.new(-4.8 + (k - 1) * 3.2, level * 3 + 1.65, 0)
					* CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(22, 22, 26),
				nil,
				Enum.PartType.Cylinder
			)
		end
	end
	for k = 0, 3 do
		local gc = rack * CFrame.new(8.5 + (k % 2) * 1.6, 0, -1.2 - math.floor(k / 2) * 1.4)
		d("GasCan", Vector3.new(1.4, 1.9, 0.9), gc * CFrame.new(0, 0.95, 0), RED)
		d("GasCanSpout", Vector3.new(0.4, 0.5, 0.4), gc * CFrame.new(0.4, 2.1, 0), YELLOW)
	end

	-- Lounge corner (front-left): TV on the wall, sofa, coffee table and a rug.
	local lounge = wallCf(-30, 0.8, 0)
	d(
		"LoungeRug",
		Vector3.new(14, 0.06, 9),
		lounge * CFrame.new(0, 0.08, -6),
		Color3.fromRGB(40, 60, 110)
	)
	d("TvStand", Vector3.new(10, 2, 2.4), lounge * CFrame.new(0, 1, -1.4), DARK)
	d("TvFrame", Vector3.new(8.4, 4.6, 0.4), lounge * CFrame.new(0, 5.2, -0.3), DARK)
	local screen = d(
		"TvPicture",
		Vector3.new(7.8, 4, 0.1),
		lounge * CFrame.new(0, 5.2, -0.6),
		Color3.fromRGB(30, 90, 170),
		Enum.Material.Neon
	)
	h.label(screen, Enum.NormalId.Front, "RACE REPLAYS", WHITE, nil)
	h.glow(screen, CYAN, 16, 0.5)
	local sofa = lounge * CFrame.new(0, 0, -8.5)
	d("SofaSeat", Vector3.new(8, 1.2, 3), sofa * CFrame.new(0, 1.2, 0), RED)
	d("SofaBack", Vector3.new(8, 3, 0.8), sofa * CFrame.new(0, 2.4, -1.4), RED)
	for _, sx in { -1, 1 } do
		d(
			"SofaArm",
			Vector3.new(0.8, 2.2, 3),
			sofa * CFrame.new(sx * 4.1, 1.6, 0),
			Color3.fromRGB(170, 30, 30)
		)
	end
	for _, sx in { -2, 2 } do
		d("SofaCushion", Vector3.new(2.6, 0.7, 2.4), sofa * CFrame.new(sx, 2, 0.1), YELLOW)
	end
	d(
		"CoffeeTable",
		Vector3.new(4, 1.1, 2.4),
		lounge * CFrame.new(0, 0.55, -4.6),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood
	)
	d("TvFridge", Vector3.new(2.6, 4.4, 2.4), lounge * CFrame.new(-7, 2.2, -1.4), CYAN)
	d("TvFridgeDoor", Vector3.new(0.2, 3, 0.2), lounge * CFrame.new(-6, 2.6, -2.7), DARK)
	d("FloorLampPole", Vector3.new(0.3, 7, 0.3), lounge * CFrame.new(7.5, 3.5, -3), STEEL)
	local lampBulb = d(
		"FloorLampBulb",
		Vector3.new(1.8, 1.8, 1.8),
		lounge * CFrame.new(7.5, 7.4, -3),
		WARM,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	h.glow(lampBulb, WARM, 22, 0.6)

	-- Pile of spare parts in the right-hand corner behind the claw: crates, an engine, rims.
	local px, pz = 49, -22
	for k = 0, 2 do
		d(
			"PartsCrate",
			Vector3.new(3, 3, 3),
			world(px + (k % 2) * 3.2, 1.5 + math.floor(k / 2) * 3, pz),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood
		)
	end
	d(
		"EngineBlock",
		Vector3.new(3.6, 2.4, 2.4),
		world(px - 4.5, 1.2, pz + 1),
		Color3.fromRGB(120, 124, 135),
		Enum.Material.Metal
	)
	for k = 0, 3 do
		d(
			"EnginePiston",
			Vector3.new(0.7, 1.2, 0.7),
			world(px - 5.8 + k * 0.9, 2.9, pz + 1),
			LIGHT_METAL,
			Enum.Material.Metal
		)
	end
	for k = 0, 2 do
		d(
			"SpareRim",
			Vector3.new(0.5, 2.6, 2.6),
			world(px - 4.5, 0.35 + k * 0.5, pz - 2.6) * CFrame.Angles(0, 0, math.pi / 2),
			if k == 1 then YELLOW else LIGHT_METAL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	d(
		"Muffler",
		Vector3.new(4, 1.2, 1.2),
		world(px + 2, 0.6, pz - 3),
		Color3.fromRGB(130, 130, 140),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for k = 0, 1 do
		d("GasCan", Vector3.new(1.4, 1.9, 0.9), world(px + 4.5 + k * 1.6, 0.95, pz + 2.6), RED)
		d(
			"GasCanSpout",
			Vector3.new(0.4, 0.5, 0.4),
			world(px + 4.9 + k * 1.6, 2.1, pz + 2.6),
			YELLOW
		)
	end

	-- Posters on the upper wall (not over the gate or the back gantry).
	local posters = {
		{ "SPEED", Color3.fromRGB(215, 40, 40) },
		{ "TURBO", Color3.fromRGB(255, 190, 30) },
		{ "NITRO", Color3.fromRGB(40, 150, 230) },
		{ "DRIFT KING", Color3.fromRGB(150, 70, 220) },
		{ "GARAGE 66", Color3.fromRGB(240, 120, 30) },
		{ "RACE DAY", Color3.fromRGB(40, 170, 90) },
	}
	for i, deg in { -160, -135, -110, -85, -60, -35, 35, 60, 85, 110, 135, 160 } do
		local pcfg = posters[(i - 1) % #posters + 1]
		local pcf = wallCf(deg, 0.2, WH + 7.6)
		d("PosterFrame", Vector3.new(6.6, 8.6, 0.3), pcf, DARK)
		local poster =
			d("Poster", Vector3.new(6, 8, 0.3), pcf * CFrame.new(0, 0, -0.1), pcfg[2] :: Color3)
		h.label(poster, Enum.NormalId.Front, pcfg[1] :: string, WHITE, DARK)
	end
	-- Neon signs high above the store and the truck stage.
	for _, sg in { { -127, "OPEN 24H", CYAN }, { 125, "RACE ZONE", YELLOW } } do
		local scf = wallCf(sg[1] :: number, 0.2, WH + 6)
		local board = d("NeonSign", Vector3.new(10, 2.6, 0.4), scf, DARK)
		h.label(board, Enum.NormalId.Front, sg[2] :: string, sg[3] :: Color3, nil)
		h.glow(board, sg[3] :: Color3, 18, 0.5)
	end

	-- Hose reels high on the side walls, with a hose hanging down.
	for _, deg in { -90, 90 } do
		local rcf = wallCf(deg, 1.2, WH + 4.5)
		d(
			"HoseBracket",
			Vector3.new(0.6, 4.4, 0.6),
			rcf * CFrame.new(0, 0, 0.6),
			STEEL,
			Enum.Material.Metal
		)
		d(
			"HoseReel",
			Vector3.new(1.6, 3.8, 3.8),
			rcf * CFrame.Angles(0, math.pi / 2, 0),
			YELLOW,
			nil,
			Enum.PartType.Cylinder
		)
		d(
			"HoseCoil",
			Vector3.new(1.8, 2.4, 2.4),
			rcf * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(40, 140, 70),
			nil,
			Enum.PartType.Cylinder
		)
		d(
			"HoseDrop",
			Vector3.new(0.5, 4.5, 0.5),
			rcf * CFrame.new(0, -4, -1.8),
			Color3.fromRGB(40, 140, 70)
		)
		d("HoseNozzle", Vector3.new(0.8, 0.8, 1.4), rcf * CFrame.new(0, -6.5, -1.8), RED)
	end

	-- Window panes in the closed roller doors.
	for _, deg in { -55, 55 } do
		local dcf = wallCf(deg, 0.8, 5.8)
		for _, wx in { -4.5, -1.5, 1.5, 4.5 } do
			local pane = d(
				"DoorWindow",
				Vector3.new(2.6, 1.5, 0.15),
				dcf * CFrame.new(wx, 3.5, -0.62),
				Color3.fromRGB(150, 215, 255),
				Enum.Material.Glass
			)
			pane.Transparency = 0.3
		end
	end

	-- Fire extinguishers beside the entrance.
	for _, sx in { -1, 1 } do
		d(
			"Extinguisher",
			Vector3.new(1, 2.6, 1),
			world(sx * 11.5, 1.3, 54),
			RED,
			nil,
			Enum.PartType.Cylinder
		).CFrame = world(
			sx * 11.5,
			1.3,
			54
		) * CFrame.Angles(0, 0, math.pi / 2)
		d("ExtinguisherTop", Vector3.new(0.5, 0.6, 0.5), world(sx * 11.5, 2.8, 54), DARK)
	end

	-- Ceiling: pipes, a duct with vents, cable runs.
	local pipeY = top - 2.4
	for _, pz2 in { -22, 34 } do
		local half = math.sqrt(R * R - pz2 * pz2) - 2
		rod(
			"CeilingPipe",
			Vector3.new(-half, pipeY, pz2),
			Vector3.new(half, pipeY, pz2),
			1.4,
			LIGHT_METAL,
			Enum.Material.Metal
		)
		rod(
			"CeilingGasPipe",
			Vector3.new(-half, pipeY + 0.2, pz2 + 1.5),
			Vector3.new(half, pipeY + 0.2, pz2 + 1.5),
			0.7,
			YELLOW,
			Enum.Material.Metal
		)
		for k = -3, 3 do
			d("PipeClamp", Vector3.new(0.5, 2, 2), world(k * 14, pipeY + 0.4, pz2), STEEL)
		end
	end
	d(
		"CeilingDuct",
		Vector3.new(2.6, 2.4, 78),
		world(-36, top - 2.2, 0),
		Color3.fromRGB(170, 175, 185),
		Enum.Material.Metal
	)
	d(
		"CeilingDuct",
		Vector3.new(2.6, 2.4, 78),
		world(36, top - 2.2, 0),
		Color3.fromRGB(170, 175, 185),
		Enum.Material.Metal
	)
	for _, dx in { -36, 36 } do
		for k = -2, 2 do
			d("VentGrille", Vector3.new(2.7, 0.2, 3.4), world(dx, top - 3.45, k * 14), DARK)
			for s = -1, 1 do
				d(
					"VentSlat",
					Vector3.new(2.5, 0.1, 0.2),
					world(dx, top - 3.6, k * 14 + s * 1),
					LIGHT_METAL
				)
			end
		end
	end
	for _, cx in { -14, 14 } do
		rod("CableRun", Vector3.new(cx, top - 1.9, -44), Vector3.new(cx, top - 1.9, 44), 0.3, DARK)
		rod(
			"CableRun",
			Vector3.new(cx + 0.6, top - 1.9, -44),
			Vector3.new(cx + 0.6, top - 1.9, 44),
			0.3,
			RED
		)
	end

	-- String lights: two lines of coloured bulbs across the room, sagging in the middle.
	for _, sz in { 12, -32 } do
		local half = math.sqrt(R * R - sz * sz) - 4
		local count = 22
		for k = 0, count - 1 do
			local t = k / (count - 1)
			local x = -half + t * half * 2
			local sag = 4 * 3 * t * (1 - t)
			local bulb = d(
				"StringLight",
				Vector3.new(0.8, 0.8, 0.8),
				world(x, top - 4.5 - sag, sz),
				BULBS[k % #BULBS + 1],
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			if k % 7 == 0 then
				h.glow(bulb, bulb.Color, 10, 0.4)
			end
		end
	end

	-- Floor: dashed centre line, hazard stripes before the claw, drain grates, light pools.
	for z = 14, 34, 5 do
		d("FloorDash", Vector3.new(0.5, 0.05, 2.6), world(0, 0.06, z), YELLOW)
	end
	for z = 48, 54, 4 do
		d("FloorDash", Vector3.new(0.5, 0.05, 2.6), world(0, 0.06, z), YELLOW)
	end
	for k = 0, 5 do
		d(
			"ClawHazard",
			Vector3.new(1.6, 0.05, 2),
			world(42.6, 0.07, 6 + k * 2),
			if k % 2 == 0 then YELLOW else DARK
		)
	end
	for _, g in { Vector3.new(0, 0, 22), Vector3.new(0, 0, -8), Vector3.new(-30, 0, -4) } do
		d("DrainGrate", Vector3.new(4, 0.08, 4), world(g.X, 0.06, g.Z), Color3.fromRGB(20, 21, 26))
		for s = -2, 2 do
			d(
				"DrainSlat",
				Vector3.new(0.3, 0.1, 3.6),
				world(g.X + s * 0.7, 0.1, g.Z),
				LIGHT_METAL,
				Enum.Material.Metal
			)
		end
	end
	for _, px2 in { -30, -10, 10, 30 } do
		for _, pz3 in { -30, -10, 10, 30 } do
			local pool = d(
				"LightPool",
				Vector3.new(0.05, 9, 9),
				world(px2, 0.075, pz3) * CFrame.Angles(0, 0, math.pi / 2),
				WARM,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			pool.Transparency = 0.94
		end
	end
end

return LobbyDetail
