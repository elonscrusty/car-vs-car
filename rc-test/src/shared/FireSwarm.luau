--!strict
-- FIRE SWARM (Car VS Car SMASH special move, carter picked "3 Meteor Rain" 10-30): 4 small fire
-- rockets shoot up out of the car's dragon mouths, hang for a beat, then all dive onto the kart
-- the owner locked on (a red ring shows where). One special per kart, own SPECIAL button; it
-- refills with time (and a charge box adds to it: WeaponServer.chargeSpecial). The server decides
-- every hit (server/weapons/Swarm); clients only draw (client/WeaponFxSwarm, client/SpecialButton).
-- Plain numbers and math with the built-in `vector`, so Lune tests run it too.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent:WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Weapons = sibling("Weapons")
local K = Weapons.KART :: number

local FireSwarm = {}

FireSwarm.NAME = "FireSwarm"
FireSwarm.WORD = "FIRE SWARM" -- on the SPECIAL button when it is full
FireSwarm.REMOTE = "SpecialFire" -- client -> server: FireServer(aim: Vector3?)

FireSwarm.COUNT = 4 -- rockets per swarm
FireSwarm.FIRST_WAIT = 12 -- seconds from the start (or a respawn) until the first swarm
FireSwarm.REFILL = 15 -- seconds from one swarm until the next (a charge box shortens it)
FireSwarm.MAX_PENDING = 12 -- rockets on their way in the whole server, all karts together

-- the timeline of one swarm (seconds after the SPECIAL tap)
FireSwarm.DIVE_AT = 0.75 -- the first rocket starts its dive (the others follow GAP apart)
FireSwarm.GAP = 0.1
FireSwarm.DIVE = 0.35 -- from the dive start to the boom
FireSwarm.CLIMB = 0.7 -- the climb the client draws (it hangs from there to the dive)

-- aim help: the nearest live, unshielded kart within 60 degrees and 30 karts ahead; with nobody
-- there the swarm lands BLIND karts ahead (the server keeps the aim within MAX_AIM_DEG of the nose)
FireSwarm.LOCK_DEG = 60
FireSwarm.LOCK_RANGE = 30 * K
FireSwarm.BLIND = 12 * K

-- what one rocket does (health 100): a direct hit (the kart is where the boom is) or the splash.
-- 4 direct hits = 56, so a kart that drives clear of the ring takes only splash.
FireSwarm.SPEC = {
	speed = 0,
	life = 0,
	seekDeg = 0,
	seekRange = 0,
	turnDeg = 0,
	hitRadius = 1.4 * K,
	damage = 14,
	splash = 1.6 * K,
	splashDamage = 7,
	ahead = 0,
	up = 0,
} :: Weapons.Flight

-- who the swarm locks onto: a Weapons.Target or nil
function FireSwarm.lock(
	from: Vector3,
	aim: Vector3,
	targets: { Weapons.Target },
	owner: any
): Weapons.Target?
	return Weapons.cone(from, aim, targets, FireSwarm.LOCK_DEG, FireSwarm.LOCK_RANGE, owner)
end

-- seconds after the tap when rocket `i` (0 to COUNT - 1) starts its dive, and when it booms
function FireSwarm.diveTime(i: number): number
	return FireSwarm.DIVE_AT + i * FireSwarm.GAP
end
function FireSwarm.boomTime(i: number): number
	return FireSwarm.diveTime(i) + FireSwarm.DIVE
end

-- how full the special is, 0 to 1 (readyAt = the server time it is ready, from the player's
-- SpecialReadyAt attribute); bad numbers read as empty
function FireSwarm.fill(readyAt: any, now: number): number
	if type(readyAt) ~= "number" or readyAt ~= readyAt then
		return 0
	end
	return math.clamp(1 - (readyAt - now) / FireSwarm.REFILL, 0, 1)
end

-- a charge box (or anything else) adds `fraction` of a full refill: the new ready time
function FireSwarm.charged(readyAt: number, now: number, fraction: number): number
	if fraction ~= fraction or fraction <= 0 then
		return readyAt
	end
	return math.max(now, readyAt - math.min(fraction, 1) * FireSwarm.REFILL)
end

return FireSwarm
