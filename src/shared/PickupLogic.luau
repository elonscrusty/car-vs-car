--!strict
-- Pure rules for the power-ups: buff state, stacking, expiry, spawn timing and positions.

local PickupLogic = {}

export type Buffs = { [string]: number } -- kind -> seconds left (absent = not active)

type Cfg = {
	shield: { seconds: number },
	bighit: { seconds: number, damageMult: number },
	speed: { seconds: number, speedMult: number },
	[string]: any,
}

function PickupLogic.newBuffs(): Buffs
	return {}
end

-- A new buff of a kind refreshes that kind; other kinds keep running. Returns its seconds.
function PickupLogic.apply(buffs: Buffs, kind: string, cfg: Cfg): number
	local entry = (cfg :: any)[kind]
	local seconds: number = if type(entry) == "table" then entry.seconds else 0
	if seconds > 0 then
		buffs[kind] = seconds
	end
	return seconds
end

-- Like apply, but the caller picks the seconds (a car ability's shield). Ignores seconds <= 0.
function PickupLogic.applySeconds(buffs: Buffs, kind: string, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	buffs[kind] = seconds
	return seconds
end

function PickupLogic.tick(buffs: Buffs, dt: number)
	for kind, left in buffs do
		if left - dt <= 0 then
			buffs[kind] = nil
		else
			buffs[kind] = left - dt
		end
	end
end

function PickupLogic.has(buffs: Buffs, kind: string): boolean
	return buffs[kind] ~= nil
end

function PickupLogic.speedMult(buffs: Buffs, cfg: Cfg): number
	return if buffs.speed then cfg.speed.speedMult else 1
end

-- Peeks at the big-hit multiplier without using it up.
function PickupLogic.peekDamageMult(buffs: Buffs, cfg: Cfg): number
	return if buffs.bighit then cfg.bighit.damageMult else 1
end

-- Uses up the big hit: returns the multiplier and removes the buff (next hit only).
function PickupLogic.takeDamageMult(buffs: Buffs, cfg: Cfg): number
	local m = PickupLogic.peekDamageMult(buffs, cfg)
	buffs.bighit = nil
	return m
end

-- Incoming damage after the shield. The shield soaks the whole hit and is used up.
function PickupLogic.absorb(buffs: Buffs, damage: number): number
	if buffs.shield and damage > 0 then
		buffs.shield = nil
		return 0
	end
	return damage
end

-- Should a pickup appear now? `lastSpawnAt` is the fight time of the previous spawn (nil = none yet).
function PickupLogic.shouldSpawn(
	elapsed: number,
	lastSpawnAt: number?,
	onFloor: number,
	firstAt: number,
	every: number,
	maxOnFloor: number
): boolean
	if onFloor >= maxOnFloor then
		return false
	end
	if lastSpawnAt == nil then
		return elapsed >= firstAt
	end
	return elapsed - lastSpawnAt >= every
end

export type Point = { x: number, z: number }

local function dist(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Picks a spot on the floor ring (relative to the center) from random values in 0..1.
-- `rolls` is a list of {angle01, radius01} tries; the first that keeps its distances wins.
function PickupLogic.pickSpot(
	rolls: { { number } },
	ringMin: number,
	ringMax: number,
	avoid: { Point }, -- car positions relative to the center
	minCarDistance: number,
	taken: { Point }, -- other pickups, relative to the center
	minPickupDistance: number
): Point?
	for _, roll in rolls do
		local a = roll[1] * math.pi * 2
		local r = ringMin + roll[2] * (ringMax - ringMin)
		local p: Point = { x = math.cos(a) * r, z = math.sin(a) * r }
		local ok = true
		for _, c in avoid do
			if dist(c, p) < minCarDistance then
				ok = false
				break
			end
		end
		if ok then
			for _, t in taken do
				if dist(t, p) < minPickupDistance then
					ok = false
					break
				end
			end
		end
		if ok then
			return p
		end
	end
	return nil
end

-- Is a car (flat position) close enough to collect a pickup?
function PickupLogic.touches(
	cx: number,
	cz: number,
	px: number,
	pz: number,
	radius: number
): boolean
	return (cx - px) ^ 2 + (cz - pz) ^ 2 <= radius * radius
end

return PickupLogic
