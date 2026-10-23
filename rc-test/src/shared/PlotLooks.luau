--!strict
-- A plot's look grows with its owner's stars (carter's pick 2026-10-23): 10 stars = night,
-- 25 = snow, 50 = lights + fans. Each look keeps the ones below it. Looks only: never on the
-- driving line, no collisions, the track and its feel stay exactly the same.
-- Plan: /mnt/project-files/rc-game/ideas/stars-phase2-plot-looks.md
--
-- Plot-local space at real RC size, as in PlotDecor: +Z is the front (the road), x from -40 to
-- 40, z from -55 to 55, the front area (where people stand) from z 37 to 55.
-- Plain numbers (Lune tests load this); PlotLooksBuilder makes the parts.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local PlotDecor = sibling("PlotDecor")

type V3 = Garage.V3
type Piece = Garage.Piece

local PlotLooks = {}

PlotLooks.TIERS = { 10, 25, 50 } -- stars for night, snow, lights + fans
PlotLooks.NIGHT_TINT = 0.5 -- night multiplies the plot's colours by this (neon stays bright)
PlotLooks.MAX_LIGHTS = 12 -- PointLights per plot, phone budget
PlotLooks.SNOW_RATE = 20 -- snowflakes a second over one plot

-- 0 = day, 1 = night, 2 = snow, 3 = lights + fans
function PlotLooks.tier(stars: number): number
	local t = 0
	for i, need in PlotLooks.TIERS do
		if stars >= need then
			t = i
		end
	end
	return t
end

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local WARM = { 255, 214, 140 }
local SNOW = { 248, 250, 255 }
local BULBS = { { 255, 70, 70 }, { 255, 210, 60 }, { 70, 220, 110 }, { 70, 160, 255 } }
local SHIRTS = {
	{ 214, 48, 44 },
	{ 38, 104, 214 },
	{ 255, 196, 40 },
	{ 70, 190, 90 },
	{ 176, 70, 255 },
	{ 255, 130, 40 },
}
local SKIN = { { 255, 214, 170 }, { 214, 160, 110 }, { 150, 100, 66 }, { 240, 190, 140 } }

-- The extra pieces for tier `t` (only that tier's own; the builder adds every tier up to the
-- plot's one). Group names: "Night", "Snow", "Party". Lamps carry `light`.
function PlotLooks.parts(kind: string, t: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local W, D, H = PlotDecor.HALF_W, PlotDecor.HALF_D, PlotDecor.WALL_H
	local noHit = { collide = false }
	if t == 1 then
		-- four lamp posts on the side walls, warm bulbs that light the track at night
		for _, sx in { -1, 1 } do
			for _, z in { -30, 10 } do
				-- standing on the wall top, leaning over the track
				local x = sx * W
				add("Night", "LampPost", v(0.4, 5.5, 0.4), v(x, H + 2.75, z), { 50, 50, 56 }, noHit)
				add(
					"Night",
					"LampArm",
					v(1.6, 0.3, 0.3),
					v(x - sx * 0.7, H + 5.5, z),
					{ 50, 50, 56 },
					noHit
				)
				add(
					"Night",
					"Lamp",
					v(0.8, 0.5, 0.8),
					v(x - sx * 1.3, H + 5.15, z),
					WARM,
					{ material = "Neon", collide = false, light = 26 }
				)
			end
		end
	elseif t == 2 then
		-- snow on the wall tops (over PlotDecor's caps) and the arch, drifts in the front area
		local capY = H + 0.3 + 0.1
		local w = PlotDecor.WALL_T + 0.4
		for _, sx in { -1, 1 } do
			add("Snow", "WallSnow", v(w, 0.2, 2 * D + w), v(sx * W, capY, 0), SNOW, noHit)
		end
		add("Snow", "WallSnow", v(2 * W - w, 0.2, w), v(0, capY, -D), SNOW, noHit)
		local G = PlotDecor.GATE
		for _, sx in { -1, 1 } do
			local len = W - G - w / 2
			add("Snow", "WallSnow", v(len, 0.2, w), v(sx * (G + len / 2), capY, D), SNOW, noHit)
		end
		-- on top of the arch (PlotDecor: rock log top 12.7, race checker 12.4, drift beam 11.6)
		local archTop = if kind == "rock" then 12.7 elseif kind == "race" then 12.4 else 11.6
		add("Snow", "ArchSnow", v(2 * G + 2, 0.35, 1.4), v(0, archTop + 0.17, D), SNOW, noHit)
		-- flat drifts on the front area floor (thin, not solid: walking is the same)
		for _, d in
			{
				{ -33, 52, 7, 4 },
				{ -14, 40, 6, 3 },
				{ 18, 51, 8, 3.5 },
				{ 36, 47, 5, 4 },
				{ 0, 38.6, 5, 2.4 },
			}
		do
			add("Snow", "Drift", v(d[3], 0.12, d[4]), v(d[1], 0.06, d[2]), SNOW, noHit)
		end
		-- the snowfall: an invisible sheet high over the plot (the builder hangs the emitter)
		add("Snow", "SnowCloud", v(2 * W, 0.2, 2 * D), v(0, 30, 0), SNOW, noHit)
		-- a snowman by the gate
		local sx, sz = -14, 52.5
		add("Snow", "SnowmanBase", v(1.6, 1.6, 1.6), v(sx, 0.8, sz), SNOW, { shape = "Ball" })
		add("Snow", "SnowmanTop", v(1.1, 1.1, 1.1), v(sx, 2.05, sz), SNOW, {
			shape = "Ball",
			collide = false,
		})
		add(
			"Snow",
			"SnowmanNose",
			v(0.12, 0.12, 0.4),
			v(sx, 2.1, sz + 0.65),
			{ 255, 130, 30 },
			noHit
		)
		add("Snow", "SnowmanHat", v(0.8, 0.5, 0.8), v(sx, 2.8, sz), { 30, 30, 34 }, noHit)
	elseif t == 3 then
		-- string lights along both side walls, bulbs in turn
		local n = 0
		for _, sx in { -1, 1 } do
			local z = -D + 4
			while z < D - 3 do
				n += 1
				add(
					"Party",
					"Bulb",
					v(0.45, 0.45, 0.45),
					v(sx * W, H + 0.75, z),
					BULBS[n % #BULBS + 1],
					{ shape = "Ball", material = "Neon", collide = false }
				)
				z += 6
			end
		end
		-- fans along the low wall, watching the track (front area, clear of the stand and steps)
		local i = 0
		for _, x in { -9, -6, 6, 9, 12, 15, 18, 21 } do
			i += 1
			local z = PlotDecor.FRONT_Z + 1.3
			add("Party", "FanBody", v(0.9, 1.5, 0.6), v(x, 0.75, z), SHIRTS[i % #SHIRTS + 1], noHit)
			add("Party", "FanHead", v(0.75, 0.75, 0.75), v(x, 1.9, z), SKIN[i % #SKIN + 1], noHit)
			-- every other fan has an arm up, cheering
			if i % 2 == 0 then
				add(
					"Party",
					"FanArm",
					v(0.25, 1, 0.25),
					v(x + 0.55, 2, z),
					SKIN[i % #SKIN + 1],
					{ rot = v(0, 0, -20), collide = false }
				)
			end
		end
		-- two searchlight beams from the back corners, crossing over the plot
		for _, sx in { -1, 1 } do
			add(
				"Party",
				"SearchBase",
				v(1.4, 1, 1.4),
				v(sx * (W - 2), H + 0.5, -D + 2),
				{ 60, 60, 66 },
				noHit
			)
			add(
				"Party",
				"SearchBeam",
				v(1.2, 26, 1.2),
				v(sx * (W - 2) - sx * 4.4, H + 1 + 12.5, -D + 2),
				{ 255, 250, 210 },
				{ rot = v(0, 0, sx * 20), material = "Neon", collide = false }
			)
		end
	end
	return out
end

-- Every piece a plot shows at tier `t` (all looks up to it).
function PlotLooks.allParts(kind: string, t: number): { Piece }
	local out: { Piece } = {}
	for i = 1, t do
		for _, p in PlotLooks.parts(kind, i) do
			table.insert(out, p)
		end
	end
	return out
end

return PlotLooks
