--!strict
-- Things that move and sparkle in a match (JUICE row, auditor "Cheap tells" #1: "nothing moves or
-- sparkles"; 2+ effects in any shot). The numbers behind client/ArenaLife: dust kicked up behind
-- every kart by its speed, little exhaust puffs, sparkles over the "?" boxes that are up, and
-- sparks where two karts bump. Cheap for phones: one emitter per kart and per box, made once and
-- reused, off past FAR studs from the camera, at most MAX_PER_SECOND bits per emitter.
-- Plain maths: Lune tests it. Studs are the arena's RC size (a kart is ~1.4 studs long).

local ArenaLife = {}

ArenaLife.FAR = 45 -- studs from the camera: past this nothing is emitted
ArenaLife.MAX_PER_SECOND = 24 -- the most bits one emitter makes a second

-- dust: none when crawling, then more with speed (studs/s), up to DUST_MAX a second
ArenaLife.DUST_START = 3
ArenaLife.DUST_FULL = 18
ArenaLife.DUST_MAX = 20
-- exhaust: a slow puff while driving at all, a bit quicker on the gas
ArenaLife.PUFF_SLOW = 2.5
ArenaLife.PUFF_FAST = 5
-- box sparkles while the box is up
ArenaLife.SPARKLE_RATE = 5
-- bump sparks: bits per spark burst
ArenaLife.SPARK_BITS = 10

-- bits a second for a kart moving at `speed` studs/s, `dist` studs from the camera
function ArenaLife.dust(speed: number, dist: number): number
	if dist > ArenaLife.FAR or speed <= ArenaLife.DUST_START then
		return 0
	end
	local u = math.clamp(
		(speed - ArenaLife.DUST_START) / (ArenaLife.DUST_FULL - ArenaLife.DUST_START),
		0,
		1
	)
	return math.min(ArenaLife.DUST_MAX * u, ArenaLife.MAX_PER_SECOND)
end

function ArenaLife.puffs(speed: number, dist: number): number
	if dist > ArenaLife.FAR or speed < 0.5 then
		return 0
	end
	return if speed > ArenaLife.DUST_FULL * 0.5 then ArenaLife.PUFF_FAST else ArenaLife.PUFF_SLOW
end

function ArenaLife.sparkles(up: boolean, dist: number): number
	return if up and dist <= ArenaLife.FAR then ArenaLife.SPARKLE_RATE else 0
end

-- Whole bits to emit this frame from a running count: (bits now, what's left over)
function ArenaLife.owe(owed: number, rate: number, dt: number): (number, number)
	local total = owed + math.max(rate, 0) * math.max(dt, 0)
	local n = math.floor(total)
	return n, total - n
end

-- a kart's speed from where it was SAMPLE s or more ago (bots are moved by the server in
-- network steps, so one frame often shows no move and the next a few frames' worth): flat
-- studs/s, and a jump of more than TELEPORT studs (a respawn) reads as 0, not a dust storm
ArenaLife.SAMPLE = 0.1
ArenaLife.TELEPORT = 6
function ArenaLife.speed(dx: number, dz: number, dt: number): number
	if dt <= 0 then
		return 0
	end
	local d = math.sqrt(dx * dx + dz * dz)
	return if d > ArenaLife.TELEPORT then 0 else d / dt
end

return ArenaLife
