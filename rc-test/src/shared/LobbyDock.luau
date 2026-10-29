--!strict
-- The spawn lobby's "Junkyard Dock" look (carter picked D, 10-29: lobby-preview/lobby-pick.html):
-- the square is walled in by two rows of shipping containers on the back and both sides, with
-- yellow/black hazard kerbs along their feet, hanging banners, a yellow crane behind the back
-- wall and tyre piles in the corners. The front stays open (the street). Plain numbers only (Lune
-- tests load it); SpawnLobby.parts() calls it when SpawnLobby.DOCK is on.
--
-- Lobby-local space as in SpawnLobby: the floor is W x D around (0, 0, 0), +Z is the front.

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

local LobbyDock = {}

LobbyDock.COLORS = {
	box = {
		{ 192, 71, 47 }, -- rust red
		{ 47, 143, 157 }, -- teal
		{ 227, 168, 43 }, -- mustard
		{ 58, 111, 176 }, -- blue
		{ 127, 154, 58 }, -- olive
		{ 166, 61, 109 }, -- plum
	},
	hazard = { 255, 177, 0 },
	black = { 34, 36, 46 },
	crane = { 255, 214, 40 },
	steel = { 42, 45, 58 },
	tyre = { 24, 26, 34 },
}
LobbyDock.BOX_H = 4.6 -- a container's height, length 12, depth 4.8
LobbyDock.BOX_D = 4.8
LobbyDock.ROWS = 2
LobbyDock.CRANE_Z = -46 -- the crane's legs stand behind the back wall
LobbyDock.CRANE_TOP = 36 -- everything is under this height

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- a darker shade of a colour (the container's ribs)
local function shade(c: { number }): { number }
	return { math.floor(c[1] * 0.72), math.floor(c[2] * 0.72), math.floor(c[3] * 0.72) }
end

function LobbyDock.parts(add: Garage.Add, W: number, D: number)
	local C = LobbyDock.COLORS
	local back = -D / 2
	local BH, BD = LobbyDock.BOX_H, LobbyDock.BOX_D
	local LEN = 12

	-- one container: a body and three darker ribs. alongX: its length runs along X (back wall),
	-- else along Z (the side walls).
	local n = 0
	local function container(
		group: string,
		cx: number,
		cy: number,
		cz: number,
		alongX: boolean,
		col: { number }
	)
		n += 1
		local dark = shade(col)
		local size = if alongX then v(LEN, BH, BD) else v(BD, BH, LEN)
		add(group, "Box", size, v(cx, cy, cz), col)
		for _, o in { -LEN / 2 + 0.7, 0, LEN / 2 - 0.7 } do
			local rs = if alongX then v(0.6, BH + 0.2, BD + 0.2) else v(BD + 0.2, BH + 0.2, 0.6)
			local rp = if alongX then v(cx + o, cy, cz) else v(cx, cy, cz + o)
			add(group, "Rib", rs, rp, dark, { collide = false })
		end
	end

	-- ===== Walls: two rows of containers on the back and the two sides, just outside the floor =====
	local across = math.ceil((W + 2 * BD) / LEN) -- the back wall runs out to cover the side walls' ends
	for row = 0, LobbyDock.ROWS - 1 do
		local y = BH / 2 + row * BH
		for i = 0, across - 1 do
			local x = -(across * LEN) / 2 + LEN / 2 + i * LEN
			container("DockBack", x, y, back - BD / 2, true, C.box[(i + row * 2) % 6 + 1])
		end
		for i = 0, math.floor(D / LEN) - 1 do
			local z = back + LEN / 2 + i * LEN
			container("DockLeft", -W / 2 - BD / 2, y, z, false, C.box[(i * 2 + row + 1) % 6 + 1])
			container("DockRight", W / 2 + BD / 2, y, z, false, C.box[(i * 2 + row + 4) % 6 + 1])
		end
	end

	-- ===== Hazard kerb along the inside foot of the walls (yellow / black, 4 studs each) =====
	local SEG = 4
	for i = 0, math.floor(W / SEG) - 1 do
		local col = if i % 2 == 0 then C.hazard else C.black
		add(
			"DockKerb",
			"Back",
			v(SEG, 0.6, 1.2),
			v(-W / 2 + SEG / 2 + i * SEG, 0.3, back + 0.6),
			col
		)
	end
	for i = 0, math.floor(D / SEG) - 1 do
		local col = if i % 2 == 0 then C.hazard else C.black
		local z = back + SEG / 2 + i * SEG
		add("DockKerb", "Left", v(1.2, 0.6, SEG), v(-W / 2 + 0.6, 0.3, z), col)
		add("DockKerb", "Right", v(1.2, 0.6, SEG), v(W / 2 - 0.6, 0.3, z), col)
	end

	-- ===== Banners hanging on the back wall (the inside face), team colours =====
	local BANNERS = { C.box[1], C.box[3], C.box[2], C.box[4] }
	for i = 0, 8 do
		local x = -W / 2 + 10 + i * ((W - 20) / 8)
		add("DockBanner", "Panel", v(6, 3.2, 0.4), v(x, 6.6, back + 0.25), BANNERS[i % 4 + 1], {
			collide = false,
		})
		add("DockBanner", "Stripe", v(6.4, 0.5, 0.5), v(x, 4.6, back + 0.3), C.hazard, {
			collide = false,
		})
	end

	-- ===== Crane behind the back wall: two legs, a beam, a hanging container =====
	local cz = LobbyDock.CRANE_Z
	local TOP = 33
	for _, x in { -52, -24 } do
		add("DockCrane", "Leg", v(2.4, TOP, 2.4), v(x, TOP / 2, cz), C.crane)
		add("DockCrane", "Foot", v(3.6, 1.2, 3.6), v(x, 0.6, cz), C.steel)
	end
	add("DockCrane", "Beam", v(34, 2.6, 3), v(-38, TOP + 1.3, cz), C.crane)
	add("DockCrane", "Trolley", v(5, 3.2, 3.6), v(-30, TOP - 1.6, cz), C.steel, { collide = false })
	add("DockCrane", "Cable", v(0.4, 14, 0.4), v(-30, TOP - 10, cz), C.steel, { collide = false })
	add("DockCrane", "Hook", v(2.2, 1.6, 2.2), v(-30, TOP - 17.8, cz), C.steel, { collide = false })
	add("DockCrane", "Hanging", v(9, BH, BD), v(-30, TOP - 21, cz), C.box[2], { collide = false })

	-- ===== Tyre piles in the corners (flat tyres, stacked, each a little turned) =====
	local piles = { { -52, -31 }, { 52, -31 }, { -50, 31 }, { 50, 31 } }
	for _, p in piles do
		for k = 0, 4 do
			add(
				"DockTyres",
				"Tyre",
				v(1.5, 3.6, 3.6),
				v(p[1] + (k % 2) * 0.5, 0.75 + k * 1.5, p[2]),
				C.tyre,
				{ shape = "Cylinder", rot = v(0, k * 25, 90) }
			)
		end
	end
end

return LobbyDock
