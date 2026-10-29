--!strict
-- Hits you can feel (JUICE row, auditor "Road to 9/10" items 2 and 3): the pure numbers behind
-- client/SmashHits. The server decides every hit; the client only sees a kart's Health go down
-- (the MatchBoard row) and the WeaponFx remote's shots and booms, so this works out which weapon
-- it was (for the number's colour, the sound and the log), merges a gun burst into one number,
-- times the spawn bubble, and gates the Studio-only slow-mo test hook. Plain maths: Lune tests it.

local SmashHits = {}

-- ===== the damage number and the victim flash =====
SmashHits.MERGE = 0.15 -- s: hits closer than this make one number (a gun burst, a bump scrape)
SmashHits.MERGE_MAX = 0.5 -- s: a number shows at most this long after its first hit
SmashHits.NUMBER_SECONDS = 0.9 -- s the number floats up and fades (≥ 0.3 s on screen)
SmashHits.FLASH_SECONDS = 0.35 -- s the victim's white-to-red flash fades
SmashHits.LOOK_BACK = 0.6 -- s: shots and booms this old can still be the hit's cause
SmashHits.NEAR = 1.6 -- kart lengths: how close a bullet's or bolt's end is to count
-- studs of slack on every reach: the kart on your screen is ~0.1-0.3 s behind the server's
-- (a kart at RC top speed moves ~5 studs in 0.2 s)
SmashHits.SLACK = 4
SmashHits.SOUND_WAIT = 0.1 -- s the hit sound waits for the shot or boom (sent just after Health)

-- the number's colour by weapon (the shot's own colour, so you can tell what hit you)
SmashHits.COLORS = {
	rocket = { 255, 130, 30 },
	nuke = { 230, 40, 60 }, -- (cherry: clearly not the gun's yellow)
	gun = { 255, 230, 120 },
	mine = { 255, 111, 181 },
	freeze = { 150, 220, 255 },
	bump = { 255, 255, 255 },
} :: { [string]: { number } }

-- "-34" (whole numbers; anything under 1 rounds up so a hit never says -0)
function SmashHits.text(amount: number): string
	return "-" .. tostring(math.max(1, math.floor(amount + 0.5)))
end

-- ===== which weapon was it =====
-- A shot or boom the WeaponFx remote showed: where it ended (x, z), who fired it, and for the
-- freeze, the kart it froze.
export type Shot = {
	t: number,
	kind: string, -- the WeaponFx kind: RocketBoom, GunShot, MineBoom, FreezeShot, FreezeHit, Shatter
	x: number,
	z: number,
	owner: number?,
	id: number?, -- the kart (FreezeHit, Shatter)
	nuke: boolean?, -- a RocketBoom from the nuke
	hit: boolean?, -- GunShot / FreezeShot: it hit a kart
}

-- how far a shot's end can be from the kart and still be its hit (studs; kart = `kart` studs)
local function reach(s: Shot, kart: number, rocketSplash: number, nukeSplash: number, mine: number)
	if s.kind == "RocketBoom" then
		return (if s.nuke then nukeSplash else rocketSplash) + kart * 0.5 + SmashHits.SLACK
	elseif s.kind == "MineBoom" then
		return mine + kart * 0.5 + SmashHits.SLACK
	end
	return kart * SmashHits.NEAR + SmashHits.SLACK
end

local WEAPON_OF: { [string]: string } = {
	RocketBoom = "rocket",
	GunShot = "gun",
	MineBoom = "mine",
	FreezeShot = "freeze",
	FreezeHit = "freeze",
	Shatter = "freeze",
}

-- The weapon behind kart `id` losing health at time `t` at (x, z): the newest shot near it in the
-- last LOOK_BACK s (and up to `after` s later: the remote and the Health can land a frame apart).
-- Nothing near = a bump. Returns the weapon word and who fired it (nil for a bump).
function SmashHits.guess(
	shots: { Shot },
	id: number,
	x: number,
	z: number,
	t: number,
	sizes: { kart: number, rocket: number, nuke: number, mine: number },
	after: number?
): (string, number?)
	local best: Shot? = nil
	for _, s in shots do
		if s.t >= t - SmashHits.LOOK_BACK and s.t <= t + (after or 0) and s.owner ~= id then
			local near
			if s.kind == "FreezeHit" or s.kind == "Shatter" then
				near = s.id == id
			elseif (s.kind == "GunShot" or s.kind == "FreezeShot") and s.hit ~= true then
				near = false
			elseif WEAPON_OF[s.kind] then
				local d = math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2)
				near = d <= reach(s, sizes.kart, sizes.rocket, sizes.nuke, sizes.mine)
			else
				near = false
			end
			if near and (best == nil or s.t > best.t) then
				best = s
			end
		end
	end
	if not best then
		return "bump", nil
	end
	local w = WEAPON_OF[best.kind]
	if best.kind == "RocketBoom" and best.nuke then
		w = "nuke"
	end
	return w, best.owner
end

-- drop shots older than LOOK_BACK (+ a little) from the list, oldest first
function SmashHits.prune(shots: { Shot }, now: number)
	local keep = now - SmashHits.LOOK_BACK - 0.5
	while shots[1] and shots[1].t < keep do
		table.remove(shots, 1)
	end
end

-- ===== one kart's hits merged into one number =====
export type Pending = { first: number, last: number, amount: number, x: number?, z: number? }

-- a hit of `amount` at `t`: add it to `p` (or start one); returns the pending number
function SmashHits.add(p: Pending?, amount: number, t: number): Pending
	if p and t - p.last <= SmashHits.MERGE and t - p.first <= SmashHits.MERGE_MAX then
		p.amount += amount
		p.last = t
		return p
	end
	return { first = t, last = t, amount = amount }
end

-- is it time to show `p` (no new hit for MERGE s, or it has waited MERGE_MAX)?
function SmashHits.due(p: Pending, t: number): boolean
	return t - p.last >= SmashHits.MERGE or t - p.first >= SmashHits.MERGE_MAX
end

-- ===== the spawn bubble =====
-- A respawn (Health from 0 back up) puts it up for `seconds` (Match.SHIELD). Players also carry
-- the server's Shield attribute, which wins for them.
SmashHits.BUBBLE_SIZE = 1.45 -- kart lengths across
SmashHits.BUBBLE_POP = 0.2 -- s it grows and fades when it ends

-- how big (0..1 of full) and how see-through the bubble is `t` s after it went up: it pops in
-- over 0.15 s, then breathes
function SmashHits.bubble(t: number): (number, number)
	local grow = math.clamp(t / 0.15, 0, 1)
	local scale = (0.6 + 0.4 * grow) * (1 + 0.04 * math.sin(t * 9))
	local see = 0.15 + 0.1 * (0.5 + 0.5 * math.sin(t * 6))
	return scale, see
end

-- ===== the Studio-only slow-mo test hook =====
-- workspace:SetAttribute("TestSlowMo", true) (or a number of seconds, 0.5 to 10): each shot,
-- boom and hit is frozen on screen for that long (true = 3 s), so Studio can take a picture of
-- every weapon's fire, travel and hit. Off in a live game whatever the attribute says.
SmashHits.ATTR = "TestSlowMo"
SmashHits.HOLD = 3
function SmashHits.hold(isStudio: boolean, attr: unknown): number?
	if not isStudio then
		return nil
	end
	if attr == true then
		return SmashHits.HOLD
	elseif type(attr) == "number" and attr == attr and attr > 0 then
		return math.clamp(attr, 0.5, 10)
	end
	return nil
end

return SmashHits
