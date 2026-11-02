--!strict
-- The damage look (carter's pick 3 "Hot Cracks, better", 2026-10-30). As a car's Health (of 100)
-- drops its body cracks open with glowing lava lines, smoke rises from the hood, sparks fly,
-- chunks fall off and, near the end, the hood burns. Plain numbers only, so tests can check them.
-- client/DamageFx turns them into parts and particles on ANY skin body (it only needs the surface
-- of the body, found with rays), so every car and weapon look gets the same damage.
--
-- From the preview page (damage-preview/damage-tries.html, STY[2]); same numbers, same names.

local DamageLookData = {}

DamageLookData.DESIGN_LENGTH = 9.9 -- a body this long is "1 unit" (the preview car, bumper to bumper)

-- Where a crack site starts, as fractions of the body's size. "top": a = across (x, from the middle),
-- b = along (z, from the middle, + is the nose). "side": a = +1 or -1 (which side), b = along,
-- h = height (from the bottom). `thr`: the site opens once Health is BELOW this.
export type Site = { thr: number, face: "top" | "side", a: number, b: number, h: number? }
DamageLookData.SITES = {
	{ thr = 92, face = "top", a = 0.27, b = 0.4 },
	{ thr = 84, face = "side", a = 1, b = 0.16, h = 0.6 },
	{ thr = 74, face = "top", a = -0.3, b = -0.06 },
	{ thr = 64, face = "side", a = -1, b = 0.3, h = 0.55 },
	{ thr = 52, face = "top", a = 0.12, b = -0.34 },
	{ thr = 40, face = "side", a = 1, b = -0.27, h = 0.6 },
	{ thr = 28, face = "top", a = -0.2, b = 0.18 },
	{ thr = 16, face = "side", a = -1, b = -0.2, h = 0.5 },
} :: { Site }

-- the hood and the boot, where smoke and fire come from (fractions: x across, z along)
DamageLookData.HOOD = { x = 0, z = 0.32 }
DamageLookData.TRUNK = { x = 0.06, z = -0.34 }

DamageLookData.ARMS = 3 -- cracks that start from a site
DamageLookData.ARM_LEN = { 2, 3.6 } -- studs (of the design car)
DamageLookData.STEP = 0.55 -- studs a crack segment
DamageLookData.WIDTH = 0.2 -- studs a crack
DamageLookData.BRANCH = 0.2 -- chance a step splits the crack (once)

DamageLookData.SMOKE_AT = 76 -- smoke starts under this Health
DamageLookData.SPARK_AT = 62
DamageLookData.FIRE_AT = 42 -- fire starts under this and is full at FIRE_AT - FIRE_RAMP
DamageLookData.FIRE_RAMP = 16
DamageLookData.CHUNK_AT = 55 -- chunks start to drop now and then under this

DamageLookData.HOT = { 255, 110, 20 } -- a crack's colour ...
DamageLookData.WHITE_HOT = { 255, 214, 110 } -- ... and how hot it throbs to
DamageLookData.SPARK = { 120, 200, 255 }
DamageLookData.SMOKE = { { 190, 110, 80 }, { 84, 66, 66 } } -- early (lava-lit) and late (sooty)
DamageLookData.CHUNK = { 24, 25, 30 }

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- 0 whole .. 1 wrecked
function DamageLookData.damage(health: number): number
	return clamp(1 - health / 100, 0, 1)
end

-- how many of the sites are open
function DamageLookData.open(health: number): number
	local n = 0
	for _, s in DamageLookData.SITES do
		if health < s.thr then
			n += 1
		end
	end
	return n
end

-- smoke particles a second (kept low: phones)
function DamageLookData.smokeRate(health: number): number
	if health >= DamageLookData.SMOKE_AT then
		return 0
	end
	return 6 + 22 * DamageLookData.damage(health)
end

-- 0 .. 1: the hood fire
function DamageLookData.fire(health: number): number
	return clamp((DamageLookData.FIRE_AT - health) / DamageLookData.FIRE_RAMP, 0, 1)
end

-- seconds to the next spark burst; r is a random 0..1. nil: no sparks yet
function DamageLookData.sparkGap(health: number, r: number): number?
	if health >= DamageLookData.SPARK_AT then
		return nil
	end
	return (0.35 + r * 1.3) * (if health < 30 then 0.55 else 1)
end

-- 0 .. 1: how hot the cracks throb now (t seconds; i the site number)
function DamageLookData.pulse(t: number, i: number): number
	return 0.5 + 0.5 * math.sin(t * 4.5 + i * 1.7)
end

-- the glow on the car's own paint: grows with the damage
function DamageLookData.glow(health: number, t: number): number
	return DamageLookData.damage(health) * (2.4 + math.sin(t * 6) * 0.5)
end

function DamageLookData.mix(a: { number }, b: { number }, t: number): { number }
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- 0 .. 1 how sooty the smoke is (0 at Health 60, 1 at 15)
function DamageLookData.soot(health: number): number
	return clamp((60 - health) / 45, 0, 1)
end

return DamageLookData
