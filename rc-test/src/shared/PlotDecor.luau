--!strict
-- Makes the 8 lobby plots pretty (carter 2026-10-23: "gates, places to stand, little booths"):
-- per kind of plot (race, drift, rocks) an entrance arch over the front gap with a name board for
-- the driver's name, a coloured cap on the outer walls, bunting from the arch to two corner
-- lanterns, two tall flags at the back corners, a booth in the right front corner and a pit
-- canopy in the left one. Plus spectator steps in the grass gaps between plots. Low-poly flat
-- colours, no text or logos. Only the plot's frame and front area: never the track inside.
--
-- Plot-local space at real RC size: (0, 0, 0) is the middle of the plot on the floor top, +Z the
-- front (the road), x from -40 to 40, z from -55 (back) to 55 (front). PlotDecor.parts() is
-- plain numbers (Lune tests load it); PlotDecorBuilder makes the parts.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		local node: any = (script :: any).Parent
		for _, part in string.split(name, "/") do
			node = node[part]
		end
		return require(node)
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local Kit = sibling("Plots/Kit")
local LobbyLayout = sibling("LobbyLayout")

type V3 = Garage.V3
type Piece = Garage.Piece
type Mesh = Garage.Mesh

local PlotDecor = {}

local S = LobbyLayout.MINI
PlotDecor.HALF_W = Kit.WIDTH / 2 * S -- 40
PlotDecor.HALF_D = Kit.DEPTH / 2 * S -- 55
PlotDecor.FRONT_Z = Kit.FRONT_Z * S -- 37: the low wall between the track and the front area
PlotDecor.GATE = 80 / 2 * S -- 10: half the entrance gap in the front wall (TrackBuilder)
PlotDecor.WALL_H = 6 * S -- 1.5: the outer walls
PlotDecor.WALL_T = 2 * S -- 0.5
-- Everything fits in here (flags and corner posts sit on the walls).
PlotDecor.BOX = { minX = -40.5, maxX = 40.5, minZ = -55.5, maxZ = 56, maxY = 16 }
-- The walk from the gate to the stand steps (TrackBuilder: steps run from x 3.5 to 27.5 at
-- z 45..47.5): nothing solid in here.
PlotDecor.LANE = { minX = -9.5, maxX = 29, minZ = 44, maxZ = 54 }
PlotDecor.BOOTH = { x = 35, z = 40.5 } -- right front corner, behind the steps
PlotDecor.CANOPY = { x = -35, z = 42 } -- left front corner, beside the parking
PlotDecor.FEATURE = { x = -21, z = 40.6 } -- podium / rock pile / tyre wall, by the low wall

export type Theme = {
	wall: { number }, -- outer walls
	cap: { number }, -- strip on top of the walls
	capMaterial: string,
	pillar: { number },
	trim: { number }, -- second colour: stripes, flags, roofs
	board: { number }, -- the name board (light, so a dark name reads)
	flags: { { number } }, -- bunting colours, in turn
}

PlotDecor.THEMES = {
	race = {
		wall = { 242, 242, 244 },
		cap = { 214, 48, 44 },
		capMaterial = "SmoothPlastic",
		pillar = { 214, 48, 44 },
		trim = { 30, 30, 34 },
		board = { 250, 250, 250 },
		flags = { { 214, 48, 44 }, { 250, 250, 250 }, { 30, 30, 34 } },
	},
	drift = {
		wall = { 46, 48, 58 },
		cap = { 176, 70, 255 },
		capMaterial = "Neon",
		pillar = { 40, 42, 52 },
		trim = { 40, 230, 230 },
		board = { 236, 232, 248 },
		flags = { { 176, 70, 255 }, { 40, 230, 230 }, { 255, 70, 170 } },
	},
	rock = {
		wall = { 150, 106, 66 },
		cap = { 98, 68, 42 },
		capMaterial = "WoodPlanks",
		pillar = { 120, 84, 52 },
		trim = { 236, 132, 40 },
		board = { 240, 222, 180 },
		flags = { { 236, 132, 40 }, { 96, 168, 70 }, { 250, 210, 70 } },
	},
} :: { [string]: Theme }

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

function PlotDecor.theme(kind: string): Theme
	return PlotDecor.THEMES[kind] or PlotDecor.THEMES.race
end

-- The decor pieces of one plot of `kind` ("race", "drift" or "rock"), plot-local.
function PlotDecor.parts(kind: string): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local t = PlotDecor.theme(kind)
	local W, D, H, T = PlotDecor.HALF_W, PlotDecor.HALF_D, PlotDecor.WALL_H, PlotDecor.WALL_T
	local G = PlotDecor.GATE
	local noHit = { collide = false }
	local function o(extra: Garage.Opts): Garage.Opts
		extra.collide = if extra.collide == nil then false else extra.collide
		return extra
	end

	-- wall caps (not solid: the walls stay what the car bumps into). Side caps run the full
	-- length; the back and front ones stop at them so no two tops overlap.
	local CAP_W, CAP_H = T + 0.3, 0.3
	local capY = H + CAP_H / 2
	local capOpts = o({ material = t.capMaterial })
	for _, sx in { -1, 1 } do
		add("Caps", "Cap", v(CAP_W, CAP_H, 2 * D + CAP_W), v(sx * W, capY, 0), t.cap, capOpts)
	end
	local inner = W - CAP_W / 2
	add("Caps", "Cap", v(2 * inner, CAP_H, CAP_W), v(0, capY, -D), t.cap, capOpts)
	local frontLen = inner - G
	for _, sx in { -1, 1 } do
		add(
			"Caps",
			"Cap",
			v(frontLen, CAP_H, CAP_W),
			v(sx * (G + frontLen / 2), capY, D),
			t.cap,
			capOpts
		)
	end

	-- the entrance arch over the gap: two pillars, a beam, the name board on the road side
	local PILLAR, ARCH_H = 1.6, 9
	local px = G + PILLAR / 2
	local beamY = ARCH_H + 1.3
	local beamW = 2 * px + PILLAR
	local topY = ARCH_H + 2.6 -- pillar tops (lanterns, bunting)
	if kind == "rock" then
		-- a ranch gate: tall log posts, a log across the top resting in them, log braces in
		-- the corners, a plank sign hanging on two ropes, boulders at the feet. Roblox
		-- cylinders lie along x.
		topY = ARCH_H + 3.8
		local logY = topY - 1
		local wood = { 112, 76, 46 }
		local dark = { 84, 56, 34 }
		for _, sx in { -1, 1 } do
			add(
				"Arch",
				"Pillar",
				v(topY, PILLAR + 0.3, PILLAR + 0.3),
				v(sx * px, topY / 2, D),
				wood,
				{ shape = "Cylinder", rot = v(0, 0, 90), material = "Wood" }
			)
			-- brace from the post up to the top log
			local x0, y0, x1, y1 = sx * px, logY - 4, sx * (px - 3.4), logY
			local dx, dy = x1 - x0, y1 - y0
			add(
				"Arch",
				"Brace",
				v(math.sqrt(dx * dx + dy * dy), 0.7, 0.7),
				v((x0 + x1) / 2, (y0 + y1) / 2, D),
				dark,
				o({
					shape = "Cylinder",
					rot = v(0, 0, math.deg(math.atan2(dy, dx))),
					material = "Wood",
				})
			)
			add(
				"Arch",
				"Boulder",
				v(2.6, 1.7, 1.6),
				v(sx * (px + 1.7), 0.95, D + 0.2),
				{ 128, 124, 118 },
				{ rot = v(0, 0, sx * 10), material = "Slate" }
			)
			add(
				"Arch",
				"Pebble",
				v(1.3, 0.9, 1.1),
				v(sx * (px - 1.6), 0.4, D + 0.3),
				{ 146, 140, 132 },
				o({ rot = v(0, 0, -sx * 14), material = "Slate" })
			)
			-- the sign's ropes
			add(
				"Arch",
				"Rope",
				v(0.14, logY - 0.9 - (beamY + 1), 0.14),
				v(sx * 5.5, (logY - 0.9 + beamY + 1) / 2, D + 0.3),
				{ 60, 50, 40 },
				noHit
			)
		end
		add(
			"Arch",
			"Beam",
			v(beamW + 3, 1.8, 1.8),
			v(0, logY, D),
			wood,
			{ shape = "Cylinder", material = "Wood", collide = false }
		)
		add(
			"Arch",
			"SignFrame",
			v(15, 2.6, 0.3),
			v(0, beamY, D + 0.15),
			dark,
			o({ material = "WoodPlanks" })
		)
	else
		for _, sx in { -1, 1 } do
			add(
				"Arch",
				"Pillar",
				v(PILLAR, ARCH_H + 2.6, PILLAR),
				v(sx * px, (ARCH_H + 2.6) / 2, D),
				t.pillar
			)
		end
		add("Arch", "Beam", v(beamW, 2.6, 1.2), v(0, beamY, D), t.pillar, noHit)
		if kind == "drift" then
			-- neon strips up the pillars' road side and under the beam
			for _, sx in { -1, 1 } do
				add(
					"Arch",
					"Glow",
					v(0.3, ARCH_H, 0.12),
					v(sx * px, ARCH_H / 2, D + PILLAR / 2 + 0.06),
					t.cap,
					o({ material = "Neon" })
				)
			end
			add(
				"Arch",
				"Glow",
				v(beamW - 2 * PILLAR, 0.25, 1),
				v(0, beamY - 1.3 - 0.125, D),
				t.trim,
				o({ material = "Neon" })
			)
		else
			-- race: a checkered strip on top of the beam (white strip, black squares on it)
			local n = 6
			local len = beamW - 0.4
			add("Arch", "Checker", v(len, 0.8, 1), v(0, beamY + 1.7, D), t.board, noHit)
			local sq = len / (2 * n)
			for i = 1, n do
				local x = -len / 2 + (2 * i - 1.5) * sq
				local y = beamY + 1.7 + (if i % 2 == 0 then 0.2 else -0.2)
				add("Arch", "Checker", v(sq, 0.4, 1.04), v(x, y, D), t.trim, noHit)
			end
		end
	end
	-- the driver's name goes on this board (LobbyBuilder puts a SurfaceGui on its road side)
	if kind == "rock" then
		add(
			"Arch",
			"NameBoard",
			v(14, 2, 0.1),
			v(0, beamY, D + 0.35),
			t.board,
			o({ material = "WoodPlanks" })
		)
	else
		add("Arch", "NameBoard", v(2 * G - 2.4, 2, 0.1), v(0, beamY, D + 0.65), t.board, noHit)
	end
	-- lanterns on the pillar tops
	for _, sx in { -1, 1 } do
		add(
			"Arch",
			"Lantern",
			v(1, 1, 1),
			v(sx * px, topY + 0.5, D),
			{ 255, 226, 150 },
			o({ material = "Neon" })
		)
	end

	-- bunting: a rope from each pillar top down to a lantern post on the front corner
	local POST_H = 6
	for _, sx in { -1, 1 } do
		local cx = sx * (W - 0.3)
		add("Bunting", "Post", v(0.5, POST_H, 0.5), v(cx, POST_H / 2, D), t.pillar)
		add(
			"Bunting",
			"Lantern",
			v(0.9, 0.9, 0.9),
			v(cx, POST_H + 0.45, D),
			{ 255, 226, 150 },
			o({ material = "Neon" })
		)
		local x0, y0 = sx * (px + PILLAR / 2), topY - 0.4
		local x1, y1 = cx, POST_H - 0.1
		local dx, dy = x1 - x0, y1 - y0
		local len = math.sqrt(dx * dx + dy * dy)
		local slope = math.deg(math.atan2(dy, dx))
		add(
			"Bunting",
			"Rope",
			v(len, 0.1, 0.1),
			v((x0 + x1) / 2, (y0 + y1) / 2, D),
			{ 60, 60, 64 },
			o({ rot = v(0, 0, slope) })
		)
		local n = 4
		for i = 1, n do
			local f = i / (n + 1)
			local fx, fy = x0 + dx * f, y0 + dy * f
			add(
				"Bunting",
				"Pennant",
				v(0.85, 0.85, 0.08),
				v(fx, fy - 0.6, D),
				t.flags[(i - 1) % #t.flags + 1],
				o({ rot = v(0, 0, 45) })
			)
		end
	end

	-- two tall flags at the back corners, seen from down the street
	local FLAG_H = 14
	for i, sx in { -1, 1 } do
		local fx, fz = sx * (W - 0.3), -D + 0.3
		add("Flags", "Pole", v(0.35, FLAG_H, 0.35), v(fx, FLAG_H / 2, fz), { 225, 225, 230 })
		add(
			"Flags",
			"Ball",
			v(0.7, 0.7, 0.7),
			v(fx, FLAG_H + 0.3, fz),
			{ 255, 210, 63 },
			o({ shape = "Ball" })
		)
		-- the cloth points inward, over the plot
		add(
			"Flags",
			"Cloth",
			v(3.6, 2.2, 0.1),
			v(fx - sx * 1.9, FLAG_H - 1.3, fz),
			t.flags[i],
			noHit
		)
	end

	-- the booth in the right front corner: counter facing the gate, back panel, awning
	local b = PlotDecor.BOOTH
	local BW, BD = 8, 4.5 -- along x, along z
	add("Booth", "Counter", v(BW, 1.4, 1.2), v(b.x, 0.7, b.z + BD / 2 - 0.6), t.pillar)
	add("Booth", "CounterTop", v(BW + 0.4, 0.2, 1.6), v(b.x, 1.5, b.z + BD / 2 - 0.6), t.board)
	add("Booth", "Back", v(BW, 4.4, 0.4), v(b.x, 2.2, b.z - BD / 2 + 0.2), t.pillar)
	for _, sx in { -1, 1 } do
		add(
			"Booth",
			"Post",
			v(0.35, 4.4, 0.35),
			v(b.x + sx * (BW / 2 - 0.2), 2.2, b.z + BD / 2 - 0.2),
			t.board
		)
	end
	if kind == "race" then
		-- striped awning, sloping down toward the gate
		local stripes = 4
		local sw = (BW + 0.6) / stripes
		for i = 1, stripes do
			add(
				"Booth",
				"Awning",
				v(sw, 0.2, BD + 1),
				v(b.x - (BW + 0.6) / 2 + (i - 0.5) * sw, 4.7, b.z + 0.3),
				if i % 2 == 1 then t.pillar else t.board,
				o({ rot = v(-10, 0, 0) })
			)
		end
	else
		add(
			"Booth",
			"Awning",
			v(BW + 0.6, 0.3, BD + 1),
			v(b.x, 4.7, b.z + 0.3),
			if kind == "drift" then t.pillar else t.trim,
			o({ rot = v(-10, 0, 0), material = if kind == "rock" then "WoodPlanks" else nil })
		)
		if kind == "drift" then
			add(
				"Booth",
				"Glow",
				v(BW + 0.6, 0.2, 0.15),
				v(b.x, 4.2, b.z + BD / 2 + 0.8),
				t.cap,
				o({ material = "Neon" })
			)
			-- street-car underglow: a thin neon strip on the floor under the counter
			add(
				"Booth",
				"Underglow",
				v(BW - 0.4, 0.06, 0.5),
				v(b.x, 0.03, b.z + BD / 2 - 0.1),
				t.cap,
				o({ material = "Neon", light = 8 })
			)
		end
	end
	add(
		"Booth",
		"Light",
		v(0.6, 0.3, 0.6),
		v(b.x, 4.25, b.z),
		{ 255, 236, 190 },
		o({ material = "Neon", light = 12 })
	)

	-- the pit canopy in the left front corner: four legs and a roof
	local c = PlotDecor.CANOPY
	local CW, CD, CH = 7, 7, 4.6
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Canopy",
				"Leg",
				v(0.25, CH, 0.25),
				v(c.x + sx * (CW / 2 - 0.2), CH / 2, c.z + sz * (CD / 2 - 0.2)),
				{ 200, 202, 208 }
			)
		end
	end
	add("Canopy", "Roof", v(CW, 0.3, CD), v(c.x, CH + 0.15, c.z), t.trim, noHit)
	add("Canopy", "Valance", v(CW, 0.6, 0.1), v(c.x, CH - 0.2, c.z + CD / 2), t.cap, noHit)
	if kind ~= "drift" then
		-- the roof's colour on the front edge would match; give drift its neon, others a peak
		add(
			"Canopy",
			"Peak",
			v(CW - 1, 0.6, CD - 1),
			v(c.x, CH + 0.6, c.z),
			t.pillar,
			o({ material = if kind == "rock" then "Fabric" else nil })
		)
	end
	-- one thing to play on per kind, between the low wall and the parking (left of the gate):
	-- race a winners podium, rocks a boulder pile with a summit flag, drift its tyre wall (meshes)
	local f = PlotDecor.FEATURE
	if kind == "race" then
		for i, step in
			{
				{ 0, 1.6, { 255, 196, 40 } },
				{ -3, 1.1, { 196, 200, 210 } },
				{ 3, 0.7, { 205, 127, 50 } },
			}
		do
			add(
				"Podium",
				"Step" .. i,
				v(3, step[2], 3),
				v(f.x + step[1], step[2] / 2, f.z),
				step[3]
			)
		end
	elseif kind == "rock" then
		add(
			"RockPile",
			"Rock",
			v(5, 1.4, 4),
			v(f.x, 0.7, f.z),
			{ 128, 124, 118 },
			{ rot = v(0, 12, 0), material = "Slate" }
		)
		add(
			"RockPile",
			"Rock",
			v(3.2, 1.2, 3),
			v(f.x + 0.6, 1.9, f.z - 0.2),
			{ 140, 136, 128 },
			{ rot = v(0, -20, 0), material = "Slate" }
		)
		add(
			"RockPile",
			"Rock",
			v(2.6, 1.6, 2.4),
			v(f.x - 3.4, 0.8, f.z + 0.6),
			{ 116, 112, 106 },
			{ rot = v(0, 30, 0), material = "Slate" }
		)
		add(
			"RockPile",
			"Pole",
			v(0.2, 3, 0.2),
			v(f.x + 0.6, 4, f.z - 0.2),
			{ 225, 225, 230 },
			noHit
		)
		add("RockPile", "Flag", v(1.4, 0.9, 0.08), v(f.x + 1.35, 5, f.z - 0.2), t.trim, noHit)
	end
	return out
end

-- carter's Meshy props on the booth counter and under the canopy, per kind (Garage.Mesh;
-- group "Extras": they only show up when imported, no block stand-ins).
function PlotDecor.meshes(kind: string): { Mesh }
	local b, c = PlotDecor.BOOTH, PlotDecor.CANOPY
	local counterZ = b.z + 4.5 / 2 - 0.6
	local list: { { any } } = if kind == "drift"
		then {
			{ "Speaker", v(b.x - 3, 1.6, counterZ), v(1.2, 1.6, 1.2), 180 }, -- came in backwards
			{ "Speaker", v(b.x + 3, 1.6, counterZ), v(1.2, 1.6, 1.2), 180 },
			{ "TireStack", v(c.x - 1.5, 0, c.z - 1), v(2, 2.6, 2) },
			{ "TireStack", v(c.x + 1.6, 0, c.z - 1.6), v(2, 1.8, 2) },
			{ "GasCan", v(c.x, 0, c.z + 1.8), v(0.9, 1.1, 0.7) },
			-- a little tyre wall along the low wall
			{ "TireStack", v(PlotDecor.FEATURE.x - 4.5, 0, PlotDecor.FEATURE.z), v(2.2, 2.2, 2.2) },
			{ "TireStack", v(PlotDecor.FEATURE.x - 2.2, 0, PlotDecor.FEATURE.z), v(2.2, 1.6, 2.2) },
			{ "TireStack", v(PlotDecor.FEATURE.x + 0.1, 0, PlotDecor.FEATURE.z), v(2.2, 2.2, 2.2) },
			{ "TireStack", v(PlotDecor.FEATURE.x + 2.4, 0, PlotDecor.FEATURE.z), v(2.2, 1.6, 2.2) },
		}
		elseif kind == "rock" then {
			{ "Bucket", v(b.x - 2.5, 1.6, counterZ), v(1, 1, 1) },
			{ "Toolbox", v(b.x + 2, 1.6, counterZ), v(1.6, 0.9, 0.8) },
			{ "HayBale", v(c.x - 1, 0, c.z - 1.5), v(2.6, 1.6, 1.8) },
			{ "Crate", v(c.x + 1.8, 0, c.z + 1.2), v(1.4, 1.4, 1.4) },
			{ "Log", v(c.x, 0, c.z + 3), v(4, 0.8, 0.8) },
		}
		else {
			{ "Toolbox", v(b.x - 2.4, 1.6, counterZ), v(1.6, 0.9, 0.8) },
			{ "Battery", v(b.x + 2.2, 1.6, counterZ), v(1, 0.8, 0.6) },
			{ "WheelRack", v(c.x - 1.4, 0, c.z - 2), v(3, 2.6, 1.2) },
			{ "TireStack", v(c.x + 2, 0, c.z + 1), v(2, 2, 2) },
			{ "GasCan", v(c.x - 1.5, 0, c.z + 1.6), v(0.9, 1.1, 0.7) },
		}
	local out: { Mesh } = {}
	for _, m in list do
		local fit: V3 = m[3]
		table.insert(out, {
			model = m[1],
			group = "Extras",
			at = m[2],
			fit = fit,
			long = if fit.z > fit.x then "z" else "x",
			keep = {},
			collide = false,
			yaw = m[4],
		})
	end
	return out
end

-- Spectator steps in the grass gaps between plots (world space): three stacked slabs, so you
-- can climb from either plot's side and look over both walls. Clear of the lamp at the gap's
-- front and the tree at its back.
PlotDecor.STEPS_LEN = 34 -- along x
PlotDecor.STEPS = { 6, 4, 2 } -- width (along z) of each slab, bottom first
PlotDecor.STEP_H = 0.9
function PlotDecor.gapSteps(): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local L = LobbyLayout
	local midX = L.EDGE + L.PLOT_D / 2
	for row = 1, L.ROWS - 1 do
		local z = L.FIRST_Z + (row - 0.5) * L.STEP
		for _, side in { -1, 1 } do
			for i, w in PlotDecor.STEPS do
				add(
					"Steps",
					"Step",
					v(PlotDecor.STEPS_LEN - (i - 1) * 2, PlotDecor.STEP_H, w),
					v(side * midX, (i - 0.5) * PlotDecor.STEP_H, z),
					if i % 2 == 1 then { 214, 206, 190 } else { 190, 180, 162 },
					{ material = "Concrete" }
				)
			end
		end
	end
	return out
end

return PlotDecor
