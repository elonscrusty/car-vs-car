--!strict
-- The Garage Hub look for the Smash lobby (carter picked layout F, 10-30): the plaza as one big
-- garage hall for everyone. A back wall with four roll-up doors, a front wall with an arena door
-- over each side match pad (the middle pad's is the open arch), hanging lamp arms, a tyre rack, tyre
-- stacks, oil drums, crates, an engine on a gantry, and pink arrows on the floor that lead from the
-- spawn to the three match pads. Looks only: no words, nothing on the walk lines. Plain numbers
-- (Lune tests load it).
--
-- Lobby-local space like SpawnLobby: (0, 0, 0) is the middle of the square on the floor, -Z the back.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")

type V3 = Garage.V3
type Add = Garage.Add

local LobbyGarage = {}

LobbyGarage.WALL_H = 16
LobbyGarage.GAP = 13 -- the open arch in the front wall: |x| < GAP
LobbyGarage.PAD_X = 19 -- the side match pads: an arena door stands over each
LobbyGarage.DOORS = { -45, -15, 15, 45 } -- x of each roll-up door
LobbyGarage.GANTRY = { x = 14, z = -30 }
LobbyGarage.RACK = { x = -56.5, z = -29 }
LobbyGarage.DRUMS = { x = 44, z = -28 }
LobbyGarage.CRATES = { x = 26, z = -24 }
LobbyGarage.STACKS =
	{ { x = -45, z = -32 }, { x = -41.5, z = -32.6 }, { x = 41, z = -33 }, { x = 52, z = -22 } }
LobbyGarage.LAMP_ARMS = { -48, -24, 0, 24, 48 }
LobbyGarage.ARROW_Z = { 6, 9.6, 13.2 } -- the three chevrons in front of each pad

local P = {
	wall = { 58, 63, 84 },
	wallLow = { 46, 50, 68 },
	door = { 122, 127, 144 },
	slat = { 90, 95, 112 },
	yellow = { 255, 205, 40 },
	black = { 26, 26, 32 },
	steel = { 154, 163, 178 },
	dark = { 42, 45, 56 },
	wood = { 176, 138, 80 },
	rust = { 181, 72, 42 },
	blue = { 47, 95, 158 },
	red = { 208, 42, 42 },
	crate = { 138, 106, 58 },
	tyre = { 26, 26, 34 },
	tyre2 = { 34, 34, 44 },
	pink = { 255, 95, 180 },
	orange = { 232, 112, 40 },
	lamp = { 255, 243, 196 },
}

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- a tyre standing with its face toward +X (axis along X) or lying flat
local function tyreFace(
	add: Add,
	g: string,
	x: number,
	y: number,
	z: number,
	d: number,
	col: { number }
)
	add(g, "Tyre", v(1.6, d, d), v(x, y, z), col, { shape = "Cylinder", collide = false })
	add(
		g,
		"Hub",
		v(1.7, d * 0.45, d * 0.45),
		v(x + 0.05, y, z),
		P.steel,
		{ shape = "Cylinder", collide = false }
	)
end

local function tyreFlat(
	add: Add,
	g: string,
	x: number,
	y: number,
	z: number,
	d: number,
	col: { number }
)
	add(g, "Tyre", v(1.2, d, d), v(x, y, z), col, { shape = "Cylinder", rot = v(0, 0, 90) })
end

-- a roll-up door in a wall at z = wallZ whose open face looks along `dir` (+1 toward +Z, -1 toward -Z)
local function rollDoor(
	add: Add,
	x: number,
	wallZ: number,
	dir: number,
	panel: { number },
	trim: { number },
	w: number
)
	local zf = wallZ - dir * 0.2 -- (the wall's face is at wallZ; pieces stand in front of it)
	add("GarageDoor", "Panel", v(w, 11, 0.4), v(x, 5.5, zf), panel, { collide = false })
	for k = 1, 7 do
		add(
			"GarageDoor",
			"Slat",
			v(w, 0.22, 0.5),
			v(x, k * 1.4, zf - dir * 0.15),
			P.slat,
			{ collide = false }
		)
	end
	add("GarageDoor", "Header", v(w + 1.6, 1, 0.6), v(x, 11.5, zf - dir * 0.1), trim, {
		collide = false,
		material = if trim == P.pink then "Neon" else "SmoothPlastic",
	})
	for _, sx in { -1, 1 } do
		add(
			"GarageDoor",
			"Post",
			v(1, 11.5, 0.7),
			v(x + sx * (w / 2 + 0.6), 5.75, zf - dir * 0.1),
			trim,
			{ collide = false }
		)
	end
end

-- back wall, side walls, roll-up doors, hazard base, round neon sign, lamp arms
local function hall(add: Add, W: number, D: number)
	local back = -D / 2
	local wz = back - 0.8
	local H = LobbyGarage.WALL_H
	add("GarageHall", "BackWall", v(W, H, 1.6), v(0, H / 2, wz), P.wall)
	add("GarageHall", "BackCap", v(W, 0.8, 2.4), v(0, H + 0.4, wz), P.dark)
	for _, sx in { -1, 1 } do
		-- (on top of the kerb: the box ends at 60)
		add(
			"GarageHall",
			"SideWall",
			v(1, H, 14),
			v(sx * (W / 2 - 0.5), H / 2, back + 7),
			P.wallLow
		)
		add(
			"GarageHall",
			"SideCap",
			v(1.6, 0.8, 14),
			v(sx * (W / 2 - 0.5), H + 0.4, back + 7),
			P.dark
		)
	end
	-- roll-up doors on the back wall (their front faces the plaza)
	for _, x in LobbyGarage.DOORS do
		rollDoor(add, x, back, 1, P.door, P.yellow, 14)
	end
	-- the front wall with an arena door over each side pad (the middle pad's is the open arch)
	local front = D / 2
	for _, sx in { -1, 1 } do
		local half = W / 2 - LobbyGarage.GAP
		local cx = sx * (LobbyGarage.GAP + half / 2)
		add("GarageHall", "FrontWall", v(half, H, 1.6), v(cx, H / 2, front + 0.8), P.wall)
		add("GarageHall", "FrontCap", v(half, 0.8, 2.4), v(cx, H + 0.4, front + 0.8), P.dark)
		rollDoor(add, sx * LobbyGarage.PAD_X, front, -1, P.orange, P.pink, 12)
	end
	-- the hazard strip along the foot of the wall: black base, yellow blocks
	add(
		"GarageHall",
		"HazardBase",
		v(W - 2, 0.5, 1.2),
		v(0, 0.28, back + 0.4),
		P.black,
		{ collide = false }
	)
	for i = 0, 19 do
		add(
			"GarageHall",
			"Hazard",
			v(2.6, 0.55, 1.25),
			v(-W / 2 + 4 + i * ((W - 8) / 19), 0.3, back + 0.4),
			P.yellow,
			{ collide = false }
		)
	end
	-- lamp arms: from the wall, a shade and a glowing bulb
	for _, x in LobbyGarage.LAMP_ARMS do
		add("GarageLamp", "Arm", v(0.6, 0.6, 7.6), v(x, 14.2, back + 3.6), P.dark)
		add("GarageLamp", "Shade", v(1.6, 3.4, 3.4), v(x, 13.4, back + 7.4), P.dark, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
		add("GarageLamp", "Bulb", v(2.2, 2.2, 2.2), v(x, 12.4, back + 7.4), P.lamp, {
			shape = "Ball",
			material = "Neon",
			collide = false,
		})
	end
end

-- a tyre rack on the left wall, tyre stacks, oil drums and crates
local function junk(add: Add)
	local r = LobbyGarage.RACK
	local g = "GarageRack"
	for _, dz in { -4.6, 4.6 } do
		add(g, "Post", v(1, 8, 0.8), v(r.x, 4, r.z + dz), P.yellow)
	end
	for k = 0, 2 do
		local y = 1.2 + k * 2.4
		add(g, "Shelf", v(2.4, 0.4, 10), v(r.x, y, r.z), P.steel)
		for i = 0, 3 do
			tyreFace(
				add,
				g,
				r.x + 0.2,
				y + 1.55,
				r.z - 3.6 + i * 2.4,
				2.8,
				if (i + k) % 2 == 0 then P.tyre else P.tyre2
			)
		end
	end
	for i, s in LobbyGarage.STACKS do
		for k = 0, 3 do
			tyreFlat(
				add,
				"GarageTyres",
				s.x + ((i + k) % 2) * 0.12,
				0.6 + k * 1.2,
				s.z,
				3.8,
				if k % 2 == 0 then P.tyre else P.tyre2
			)
		end
	end
	local d = LobbyGarage.DRUMS
	local cols = { P.rust, P.blue, P.rust, P.red }
	for i = 0, 3 do
		local x, z = d.x + (i % 2) * 2.6, d.z + (i // 2) * 2.6
		add(
			"GarageDrums",
			"Drum",
			v(3.2, 2.6, 2.6),
			v(x, 1.6, z),
			cols[i + 1],
			{ shape = "Cylinder", rot = v(0, 0, 90) }
		)
		add(
			"GarageDrums",
			"Band",
			v(0.5, 2.75, 2.75),
			v(x, 1.0, z),
			P.dark,
			{ shape = "Cylinder", rot = v(0, 0, 90), collide = false }
		)
	end
	local c = LobbyGarage.CRATES
	for i = 0, 2 do
		add("GarageCrates", "Crate", v(4, 4, 4), v(c.x + i * 4.3, 2, c.z), P.crate)
		add(
			"GarageCrates",
			"Strap",
			v(4.1, 0.5, 4.1),
			v(c.x + i * 4.3, 2, c.z),
			P.dark,
			{ collide = false }
		)
	end
	add("GarageCrates", "Crate", v(4, 4, 4), v(c.x + 2.1, 6, c.z), P.crate)
end

-- an engine hanging on a chain from a gantry
local function gantry(add: Add)
	local q = LobbyGarage.GANTRY
	local g = "GarageGantry"
	for _, sx in { -6, 6 } do
		add(g, "Leg", v(1, 15, 1), v(q.x + sx, 7.5, q.z), P.yellow)
		add(g, "Foot", v(2.6, 0.5, 2.6), v(q.x + sx, 0.25, q.z), P.dark)
	end
	add(g, "Beam", v(14, 1, 1.4), v(q.x, 15, q.z), P.yellow)
	add(g, "Chain", v(0.3, 5.4, 0.3), v(q.x, 12, q.z), P.black, { collide = false })
	add(
		g,
		"Engine",
		v(4.8, 3, 3.2),
		v(q.x, 8.2, q.z),
		{ 85, 96, 110 },
		{ material = "Metal", collide = false }
	)
	for i = 0, 3 do
		add(
			g,
			"Piston",
			v(1.5, 0.9, 0.9),
			v(q.x - 1.8 + i * 1.2, 10.2, q.z),
			P.steel,
			{ shape = "Cylinder", rot = v(0, 0, 90), collide = false }
		)
	end
end

-- pink chevrons on the floor from the spawn toward each match pad
local function arrows(add: Add, padXs: { number })
	for i, px in padXs do
		for k, z in LobbyGarage.ARROW_Z do
			for _, s in { -1, 1 } do
				add(
					"GarageArrows",
					"Chevron" .. i,
					v(0.9, 0.06, 3.6),
					v(px + s * 1.15, 0.12, z),
					P.pink,
					{
						rot = v(0, -s * 38, 0),
						material = "Neon",
						collide = false,
					}
				)
			end
		end
	end
end

function LobbyGarage.parts(add: Add, W: number, D: number, padXs: { number })
	hall(add, W, D)
	junk(add)
	gantry(add)
	arrows(add, padXs)
end

return LobbyGarage
