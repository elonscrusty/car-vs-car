--!strict
-- The Fire Drake dragon head (carter's pick 1 "Fender Heads", 2026-10-29), as a list of simple
-- parts. Plain numbers only, so tests can check it. FireDrake (client) turns it into real parts
-- and adds a head on each fender of the black+red car.
--
-- Made from the preview page's dragonPod() (kart-preview/swarm-pick-5.html), but cut down to the
-- parts you can see (about 33 per head): every part is one more thing for a phone to move.
--
-- Units are the preview car's: the car is 9.9 long, 4.9 wide, its roof 3.0 high. Axes are the
-- car model's: +Z nose, +Y up, +X out to the side. The list is for the +X head; the -X head is its
-- mirror (FireDrakeData.mirror). Rotations are degrees, applied like CFrame.Angles(x, y, z).
-- A wedge's tall edge is at its +Z end (see ArenaBuilder), so a "spike" is a wedge turned so its
-- point goes the way we want.

local FireDrakeData = {}

export type Spec = {
	name: string,
	shape: "Block" | "Wedge" | "Cylinder",
	mat: string, -- a key of FireDrakeData.COLORS
	neon: boolean?,
	size: { number },
	at: { number }, -- the part's middle, from the head's own origin (its saddle on the fender)
	rot: { number },
}

FireDrakeData.DESIGN_LENGTH = 9.9 -- the preview car, bumper to bumper
-- where the head sits on the car: as a fraction of the body's size (x: of width, from the middle;
-- y: of height, from the bottom; z: of length, from the middle). From the preview: (2.15, 2.2, 2.55)
FireDrakeData.PLACE = { x = 2.15 / 4.9, y = (2.2 - 0.36) / 2.64, z = 2.55 / 9.9 }
FireDrakeData.SCALE = 1.4 -- the preview drew each head 1.4 times its own size

FireDrakeData.COLORS = {
	skin = { 26, 18, 22 },
	trim = { 44, 18, 24 },
	horn = { 232, 32, 47 },
	frill = { 176, 16, 32 },
	eye = { 255, 194, 26 },
	tooth = { 241, 236, 224 },
	gun = { 42, 44, 51 },
	throat = { 255, 106, 16 },
} :: { [string]: { number } }

local K = FireDrakeData.SCALE
local rad, deg = math.rad, math.deg
-- (the preview's x runs to the nose, y up, z to the side: here that is Z, Y, X)
local function at(px: number, py: number, pz: number): { number }
	return { pz * K, py * K, px * K }
end

local function box(
	list: { Spec },
	name: string,
	mat: string,
	size: { number }, -- nose, up, side (preview order)
	px: number,
	py: number,
	pz: number,
	tilt: number?, -- degrees, nose up (the preview's rotation about its z)
	neon: boolean?
)
	table.insert(list, {
		name = name,
		shape = "Block",
		mat = mat,
		neon = neon,
		size = { size[3] * K, size[2] * K, size[1] * K },
		at = at(px, py, pz),
		rot = { -(tilt or 0), 0, 0 },
	})
end

-- a wedge whose point (the top of its tall edge) is at the far end of its base
-- base: where the middle of its base sits; h: how far the point rises; len: base length (nose to
-- tail); t: how thick (side to side); how: "back" = a horn swept to the tail, "front" = a tooth
-- up, "down" = a fang hanging from the top jaw, "fin" = a flat fin whose point is at the tail
local function spike(
	list: { Spec },
	name: string,
	mat: string,
	px: number,
	py: number,
	pz: number,
	h: number,
	len: number,
	t: number,
	how: string,
	lean: number?, -- degrees swept back (back only)
	out: number? -- degrees leaning outward (back only)
)
	local l, o = lean or 0, out or 0
	local rot, up
	if how == "down" then
		rot, up = { 0, 0, 180 }, { 0, -1, 0 }
	elseif how == "front" then
		rot, up = { 0, 0, 0 }, { 0, 1, 0 }
	else -- "back" and "fin"
		rot = { -l, 180, o }
		up = {
			math.sin(rad(o)),
			math.cos(rad(o)) * math.cos(rad(l)),
			-math.cos(rad(o)) * math.sin(rad(l)),
		}
	end
	local base = at(px, py, pz)
	table.insert(list, {
		name = name,
		shape = "Wedge",
		mat = mat,
		size = { t * K, h * K, len * K },
		at = {
			base[1] + up[1] * h * K / 2,
			base[2] + up[2] * h * K / 2,
			base[3] + up[3] * h * K / 2,
		},
		rot = rot,
	})
end

local cached: { Spec }? = nil

-- the parts of the +X head
function FireDrakeData.pod(): { Spec }
	if cached then
		return cached
	end
	local L: { Spec } = {}
	-- the saddle on the fender and the neck: five plates, each tilted up, two with a back spike
	box(L, "Saddle", "gun", { 0.9, 0.26, 0.7 }, -0.8, -0.5, 0)
	local tilt = 0.5
	for i = 0, 4 do
		local sx, sy = -1.0 + i * 0.2, -0.36 + i * 0.14
		box(
			L,
			`Neck{i}`,
			if i % 2 == 0 then "skin" else "trim",
			{ 0.34, 0.34 - math.min(i, 4) * 0.015, 0.62 - math.min(i, 4) * 0.05 },
			sx,
			sy,
			0,
			deg(tilt)
		)
		if i == 1 or i == 3 then
			-- (the preview put the spike .2 above the plate's middle, leaning on past the plate)
			local c, s = math.cos(tilt), math.sin(tilt)
			spike(
				L,
				`NeckSpike{i}`,
				"horn",
				sx - 0.2 * s,
				sy + 0.2 * c,
				0,
				0.3 + i * 0.04,
				0.2,
				0.1,
				"back",
				deg(tilt) + 30,
				0
			)
		end
	end
	-- the head sits at (-.15, .12); its upper jaw .3 above that, its lower jaw .02 above it
	local ux, uy, lx, ly = -0.15, 0.42, -0.15, 0.14
	box(L, "Cranium", "skin", { 0.95, 0.44, 1.0 }, ux + 0.45, uy, 0)
	box(L, "Snout", "skin", { 0.8, 0.3, 0.7 }, ux + 1.15, uy - 0.04, 0, -4)
	box(L, "Muzzle", "trim", { 0.28, 0.2, 0.62 }, ux + 1.55, uy - 0.06, 0)
	-- the throat glows between the jaws
	box(L, "Throat", "throat", { 0.5, 0.1, 0.5 }, ux + 0.3, uy - 0.23, 0, 0, true)
	for _, sd in { 1, -1 } do
		local tag = if sd > 0 then "R" else "L"
		-- glowing eyes under a heavy brow ridge
		box(L, "Eye" .. tag, "eye", { 0.14, 0.14, 0.1 }, ux + 0.85, uy + 0.14, sd * 0.5, 0, true)
		box(L, "Brow" .. tag, "horn", { 0.6, 0.1, 0.22 }, ux + 0.9, uy + 0.26, sd * 0.34, 6)
		-- the big swept horn and the small one
		spike(
			L,
			"Horn" .. tag,
			"horn",
			ux + 0.25,
			uy + 0.33,
			sd * 0.4,
			1.1,
			0.3,
			0.22,
			"back",
			66,
			sd * 14
		)
		spike(
			L,
			"HornSmall" .. tag,
			"horn",
			ux + 0.25,
			uy + 0.19,
			sd * 0.52,
			0.55,
			0.2,
			0.16,
			"back",
			46,
			sd * 28
		)
		-- two long fangs hang from the top jaw, two teeth stand up from the bottom one
		for j, x in { 1.23, 1.4 } do
			spike(L, `Fang{tag}{j}`, "tooth", ux + x, uy - 0.2, sd * 0.3, 0.38, 0.1, 0.08, "down")
		end
		for j, x in { 0.85, 1.15 } do
			spike(L, `Tooth{tag}{j}`, "tooth", lx + x, ly + 0.1, sd * 0.3, 0.2, 0.1, 0.07, "front")
		end
	end
	-- the tall fin behind the head, point to the tail
	spike(L, "Frill", "frill", ux + 0.1, uy + 0.22, 0, 0.95, 1.0, 0.08, "fin")
	-- the lower jaw
	box(L, "Jaw", "skin", { 1.25, 0.16, 0.84 }, lx + 0.62, ly - 0.02, 0)
	box(L, "JawFront", "trim", { 0.3, 0.14, 0.6 }, lx + 1.3, ly - 0.03, 0)
	-- the Fire Swarm tubes rest between the jaws: the weapon is part of the head
	for _, sd in { 1, -1 } do
		table.insert(L, {
			name = if sd > 0 then "TubeR" else "TubeL",
			shape = "Cylinder",
			mat = "gun",
			size = { 0.3 * K, 0.34 * K, 0.34 * K },
			at = at(lx + 0.95, ly + 0.14, sd * 0.22),
			rot = { 0, 90, 0 },
		})
	end
	cached = L
	return L
end

-- the same part on the -X head: across the car's middle
function FireDrakeData.mirror(s: Spec): Spec
	return {
		name = s.name,
		shape = s.shape,
		mat = s.mat,
		neon = s.neon,
		size = s.size,
		at = { -s.at[1], s.at[2], s.at[3] },
		rot = { s.rot[1], -s.rot[2], -s.rot[3] },
	}
end

return FireDrakeData
