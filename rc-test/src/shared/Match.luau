--!strict
-- The Smash match rules (FINISH-JOBS "Lead decisions 22:04" + "GO 22:13", plans/smash/VIDEO-STUDY.md):
-- karts with 100 health, hits and smashes, respawn after 3 s with a 2 s shield at the free spawn
-- farthest from enemies, bumps that hurt, places by smashes and the coins a round pays. Plain
-- maths, no Roblox: MatchRunner (server) is the shell around it, and Lune tests the whole flow.

local Match = {}

Match.HEALTH = 100
Match.HIT = 34 -- a rocket hit, gun burst or mine: 3 hits = a smash (carter's default)
Match.RESPAWN = 3 -- seconds smashed before you're back (automatic)
Match.SHIELD = 2 -- seconds of spawn bubble after a respawn (and at the round's start)
Match.LENGTH = 180 -- a round: 3:00
Match.BREAK = 12 -- ROUND OVER, the winner's kart, "New Round Starting In 12"
Match.MAX = 8 -- karts in a round (players + bots)

-- Coins for a round: by place, plus each smash (FINISH-JOBS: 1st/2nd/3rd + per smash).
Match.PLACE_COINS = { 50, 30, 20 }
Match.PLAY_COINS = 10 -- 4th and down: playing a round still pays
Match.SMASH_COINS = 5

-- Bumps hurt (carter 22:12): world studs and studs/s. Under RAM_MIN of speed into the other kart
-- nothing happens (a nudge); at RAM_FULL or more it's one whole hit.
Match.RAM_DIST = 1.8 -- kart centres this close = touching (RC karts are ~0.8 x 1.4 studs)
Match.RAM_MIN = 6
Match.RAM_FULL = 22
Match.RAM_COOLDOWN = 0.8 -- the same two karts hurt each other once in this long

-- The arena's top speed for everyone, players and bots (carter 10-29: "maybe the cars go too fast").
-- Players: Tuning's "arena" mode; bots: ArenaBrain.TOP_SPEED. 1 = the lobby's speed. Handling
-- (steering, grip, the accel curve) reads speed as a share of the top, so it feels the same.
Match.SPEED_SCALE = 0.8
-- New-kid safety (Lead, Studio preview-2250): in a player's first round the bots leave them alone
-- this long, and aim worse at players all round (ArenaBrain's easy bots).
Match.NEW_KID_SAFE = 15

-- The bots' names: a fixed pool, shuffled each round (no "Bot 28").
Match.BOT_NAMES = {
	"Turbo Taco",
	"Sir Bumpsalot",
	"Wobble Bob",
	"Captain Crash",
	"Zippy",
	"Rocket Raccoon",
	"Banana Blitz",
	"Dizzy Dash",
	"Pickle Pop",
	"Nitro Noodle",
	"Bubble Buggy",
	"Lil Smasher",
}

export type Kart = {
	id: number, -- a player's UserId; bots are negative
	name: string,
	human: boolean,
	health: number,
	alive: boolean,
	shieldUntil: number,
	respawnAt: number?, -- set while smashed
	smashes: number,
	deaths: number,
	streak: number, -- smashes since it was last smashed (the fire from 3: StreakFire)
	order: number, -- join order (the last tie-break)
	lastBy: number?, -- who smashed it last (the killer cam)
	hitBy: number?, -- who hurt it last, and when (bots leave a rookie's kill to the rookie)
	hitAt: number?,
	lastWeapon: string?,
}

export type State = {
	karts: { [number]: Kart },
	list: { Kart },
	startAt: number,
	endsAt: number,
	over: boolean,
	joined: number,
	rams: { [string]: number }, -- "a:b" -> when that pair last hurt each other
}

export type Point = { x: number, z: number }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Match.new(startAt: number, length: number?): State
	return {
		karts = {},
		list = {},
		startAt = startAt,
		endsAt = startAt + (length or Match.LENGTH),
		over = false,
		joined = 0,
		rams = {},
	}
end

-- A kart joins the round (shielded from the start). nil when the round is full or it's in already.
function Match.add(m: State, id: number, name: string, human: boolean, now: number): Kart?
	if m.karts[id] or #m.list >= Match.MAX then
		return nil
	end
	m.joined += 1
	local k: Kart = {
		id = id,
		name = name,
		human = human,
		health = Match.HEALTH,
		alive = true,
		shieldUntil = now + Match.SHIELD,
		respawnAt = nil,
		smashes = 0,
		deaths = 0,
		streak = 0,
		order = m.joined,
		lastBy = nil,
		lastWeapon = nil,
	}
	m.karts[id] = k
	table.insert(m.list, k)
	return k
end

function Match.remove(m: State, id: number)
	local k = m.karts[id]
	if not k then
		return
	end
	m.karts[id] = nil
	local i = table.find(m.list, k)
	if i then
		table.remove(m.list, i)
	end
end

function Match.shielded(k: Kart, now: number): boolean
	return now < k.shieldUntil
end

-- Can this kart be hit right now: in the round, alive, no bubble, and the round still on.
function Match.hittable(m: State, id: number, now: number): boolean
	local k = m.karts[id]
	return k ~= nil
		and k.alive
		and not Match.shielded(k, now)
		and not m.over
		and now >= m.startAt
		and now < m.endsAt
end

-- Hurt a kart. Returns the health taken and whether that smashed it. A kart's own hit (its mine)
-- hurts it but scores nobody; an unknown or smashed attacker still hurts (its rocket was in the
-- air). Junk amounts do nothing.
function Match.damage(
	m: State,
	victimId: number,
	attackerId: number?,
	amount: number,
	now: number,
	weapon: string?
): (number, boolean)
	if not finite(amount) or amount <= 0 or not Match.hittable(m, victimId, now) then
		return 0, false
	end
	local k = m.karts[victimId]
	local took = math.min(amount, k.health)
	k.health -= took
	if attackerId and attackerId ~= victimId then
		k.hitBy, k.hitAt = attackerId, now
	end
	if k.health > 0 then
		return took, false
	end
	k.health = 0
	k.alive = false
	k.respawnAt = now + Match.RESPAWN
	k.deaths += 1
	k.streak = 0
	k.lastBy = if attackerId ~= victimId then attackerId else nil
	k.lastWeapon = weapon
	local by = if attackerId and attackerId ~= victimId then m.karts[attackerId] else nil
	if by then
		by.smashes += 1
		by.streak += 1
	end
	return took, true
end

-- The smashed karts whose 3 s are up (in join order).
function Match.due(m: State, now: number): { Kart }
	local out = {}
	for _, k in m.list do
		if not k.alive and k.respawnAt and now >= k.respawnAt then
			table.insert(out, k)
		end
	end
	return out
end

-- Back in: full health and the bubble.
function Match.respawn(m: State, id: number, now: number)
	local k = m.karts[id]
	if not k then
		return
	end
	k.alive = true
	k.health = Match.HEALTH
	k.respawnAt = nil
	k.hitBy, k.hitAt = nil, nil
	k.shieldUntil = now + Match.SHIELD
end

-- The spawn farthest from every enemy (its nearest enemy is the farthest away); `busy` spawns
-- (someone parked on it) are skipped unless every one is busy. Ties go to the lower number.
function Match.pickSpawn(
	spawns: { Point },
	enemies: { Point },
	busy: { [number]: boolean }?
): number
	local best, bestD = 1, -1
	for pass = 1, 2 do
		for i, s in spawns do
			if pass == 1 and busy and busy[i] then
				continue
			end
			local near = math.huge
			for _, e in enemies do
				near = math.min(near, (s.x - e.x) ^ 2 + (s.z - e.z) ^ 2)
			end
			if near > bestD then
				best, bestD = i, near
			end
		end
		if bestD >= 0 then
			break
		end
	end
	return best
end

-- Best first: most smashes, then fewest times smashed, then who joined first.
function Match.places(m: State): { Kart }
	local out = table.clone(m.list)
	table.sort(out, function(a: Kart, b: Kart): boolean
		if a.smashes ~= b.smashes then
			return a.smashes > b.smashes
		end
		if a.deaths ~= b.deaths then
			return a.deaths < b.deaths
		end
		return a.order < b.order
	end)
	return out
end

-- The place a kart is shown and paid for: 1 + the karts with more smashes, so a tie shares a
-- place (SmashScreens.rank, the board and ROUND OVER use the same rule). Match.places' tie-break
-- (fewest deaths, then join order) only orders the list and picks the one "X WINS" name.
function Match.rank(m: State, id: number): number
	local k = m.karts[id]
	if not k then
		return 0
	end
	local ahead = 0
	for _, o in m.list do
		if o.smashes > k.smashes then
			ahead += 1
		end
	end
	return ahead + 1
end

-- The place a round pays for: the shared place, but a kart with no smashes is never on the
-- podium (all on 0 would all be "1st"; an idle kid isn't "2nd" behind one scorer).
function Match.payPlace(m: State, id: number): number
	local k = m.karts[id]
	if not k then
		return 0
	end
	local r = Match.rank(m, id)
	return if k.smashes > 0 then r else math.max(r, #Match.PLACE_COINS + 1)
end

function Match.placeOf(m: State, id: number): number
	for i, k in Match.places(m) do
		if k.id == id then
			return i
		end
	end
	return 0
end

-- The place a kart's Place shows: 0 (the HUD's "-") until it has a smash, so every kart on
-- 0 smashes shares it and nobody is "2nd" for joining early (SCREENS 905, Audit F11).
function Match.shownPlace(k: Kart, place: number): number
	return if k.smashes > 0 then place else 0
end

function Match.coinsFor(place: number, smashes: number): number
	local base = Match.PLACE_COINS[place] or (if place >= 1 then Match.PLAY_COINS else 0)
	return base + math.max(0, math.floor(smashes)) * Match.SMASH_COINS
end

-- A bump's damage from one kart's speed into the other (studs/s along the line between them).
function Match.ramDamage(speedInto: number): number
	if not finite(speedInto) or speedInto <= Match.RAM_MIN then
		return 0
	end
	local f = math.min(1, (speedInto - Match.RAM_MIN) / (Match.RAM_FULL - Match.RAM_MIN))
	return math.ceil(f * Match.HIT)
end

-- Two karts at (a, b) moving (va, vb): the damage each does to the other when they touch (each
-- one's speed toward the other; head-on hurts both). 0, 0 when apart, or too soon for this pair.
function Match.ram(
	m: State,
	aId: number,
	a: Point,
	va: Point,
	bId: number,
	b: Point,
	vb: Point,
	now: number
): (number, number)
	local dx, dz = b.x - a.x, b.z - a.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > Match.RAM_DIST or d < 1e-6 then
		return 0, 0
	end
	local key = if aId < bId then `{aId}:{bId}` else `{bId}:{aId}`
	local last = m.rams[key]
	if last and now - last < Match.RAM_COOLDOWN then
		return 0, 0
	end
	local ux, uz = dx / d, dz / d
	local toB = Match.ramDamage(va.x * ux + va.z * uz)
	local toA = Match.ramDamage(-(vb.x * ux + vb.z * uz))
	if toB > 0 or toA > 0 then
		m.rams[key] = now
	end
	return toB, toA
end

-- The names for a round's bots (12: a round has at most 7), in a random order (`pick(n)` returns 1..n).
function Match.botNames(pick: (number) -> number): { string }
	local names = table.clone(Match.BOT_NAMES)
	for k = #names, 2, -1 do
		local j = pick(k)
		names[k], names[j] = names[j], names[k]
	end
	return names
end

-- The chase camera lost your kart (Studio round 3: it sat ~40 studs off for 30-60 s while you
-- drove): `far` is camera-to-kart, `limit` the most a chase view is ever out. Far (or junk) for
-- CAM_LOST seconds in a row = put the camera back behind the kart. Returns the new count and
-- whether to do that now.
Match.CAM_LOST = 0.5
function Match.camLost(lostFor: number, far: number, limit: number, dt: number): (number, boolean)
	if far == far and far <= limit then
		return 0, false
	end
	lostFor += if dt == dt and dt > 0 then math.min(dt, 0.1) else 0
	if lostFor >= Match.CAM_LOST then
		return 0, true
	end
	return lostFor, false
end

export type BotView = {
	id: number,
	pos: any,
	alive: boolean,
	shield: boolean,
	human: boolean,
	model: any,
	rookie: boolean?,
	cframe: any?, -- (a rookie's facing: bots drive through an armed rookie's sights)
	hitBy: number?,
	hitAt: number?,
	rookieHit: boolean?, -- a rookie hurt it in the last ROOKIE_HIT s: bots leave the kill to them
	smashes: number?,
	deaths: number?,
}

Match.ROOKIE_HIT = 8 -- s

-- What the bots see: every kart with a place, and a new kid in their first NEW_KID_SAFE seconds
-- of the round shown as shielded (bots never pick a shielded target).
function Match.forBots(
	list: { BotView },
	newKids: { [number]: boolean },
	now: number,
	startAt: number,
	rookies: { [number]: boolean }? -- players in their first matches: bots go easy (ArenaBrain.ROOKIE)
): { BotView }
	local out = {}
	local safe = now - startAt < Match.NEW_KID_SAFE
	for _, k in list do
		if k.pos ~= nil then
			table.insert(out, {
				id = k.id,
				pos = k.pos,
				alive = k.alive,
				shield = k.shield or (safe and newKids[k.id] == true),
				human = k.human,
				model = k.model,
				rookie = rookies ~= nil and rookies[k.id] == true,
				cframe = k.cframe,
				smashes = k.smashes,
				deaths = k.deaths,
				rookieHit = rookies ~= nil
					and k.hitBy ~= nil
					and rookies[k.hitBy] == true
					and now - (k.hitAt or -math.huge) < Match.ROOKIE_HIT,
			})
		end
	end
	return out
end

return Match
