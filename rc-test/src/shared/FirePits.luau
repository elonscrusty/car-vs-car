--!strict
-- Fire pits in the Smash arena (arena hazard 3; carter picked "1 Scrap Fire Pit", 10-30).
-- A pit is a burning patch on the floor. A kart that drives over it burns: a little health every
-- BURN_EVERY seconds while it stays inside. Every PERIOD seconds the flames FLARE for FLARE_LEN
-- seconds and burn twice as hard. Fair on purpose: the ring on the floor shows the whole patch,
-- it flashes just before a flare, the pit is flat (nothing to get stuck on), and a flying kart is
-- safe. The server decides everything. Plain numbers + `vector`, so Lune tests run it.
-- Sizes are big units (a kart is 3 x 5.5 big); the arena is built big then scaled by SCALE.

local FirePits = {}

FirePits.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
FirePits.RADIUS = 9 -- the burning patch (the ring on the floor)
FirePits.BURN = 4 -- health lost each burn tick (a kart has 100)
FirePits.BURN_FLARE = 8 -- ... while the flames flare
FirePits.BURN_EVERY = 0.5 -- seconds between burn ticks for one kart
FirePits.PERIOD = 10 -- seconds from one flare to the next
FirePits.FLARE_LEN = 2 -- how long a flare lasts (the end of each period)
FirePits.WARN = 1 -- the ring flashes this long before a flare
FirePits.REACH_UP = 6 -- a kart this high above the floor (big units) flies over: no burn
FirePits.NAME = "Fire" -- the word the match shows when a pit smashes a kart

-- Where the pits are, in picture units (the arena's 240 x 240 picture). Open, flat, far from
-- every start spot, box and dynamite keg; tests/firepits.test checks all of it.
FirePits.SPOTS = {
	{ 25, 195 }, -- (batch 10-30: moved off the two crates at 40,70 / 50,80)
	{ 110, 85 },
	{ 88, 133 },
	{ 155, 205 },
} :: { { number } }

export type Kart = { id: any, position: vector, alive: boolean }
export type State = { pits: { vector }, last: { [any]: number } }

function FirePits.new(spots: { vector }): State
	return { pits = spots, last = {} }
end

-- Round start: nobody is mid-burn.
function FirePits.reset(s: State)
	s.last = {}
end

-- Are the flames flaring now? (the last FLARE_LEN seconds of every PERIOD)
function FirePits.flaring(now: number): boolean
	return now % FirePits.PERIOD >= FirePits.PERIOD - FirePits.FLARE_LEN
end

-- Is a flare about to start (the ring flashes)?
function FirePits.warning(now: number): boolean
	local t = now % FirePits.PERIOD
	return t >= FirePits.PERIOD - FirePits.FLARE_LEN - FirePits.WARN
		and t < FirePits.PERIOD - FirePits.FLARE_LEN
end

-- Health lost per burn tick right now.
function FirePits.burn(now: number): number
	return if FirePits.flaring(now) then FirePits.BURN_FLARE else FirePits.BURN
end

-- Is a kart on a pit? Flat distance in big units; flyers are not.
function FirePits.inside(pit: vector, kart: vector, scale: number?): boolean
	local sc = scale or FirePits.SCALE
	if math.abs(kart.y - pit.y) / sc > FirePits.REACH_UP then
		return false
	end
	local dx, dz = kart.x - pit.x, kart.z - pit.z
	return math.sqrt(dx * dx + dz * dz) / sc <= FirePits.RADIUS
end

-- One step of the rules. Returns { { id, damage } } for the karts that burn this step: a kart on
-- any pit loses BURN (or BURN_FLARE) at most every BURN_EVERY seconds, and never twice from two
-- pits at once. A kart that leaves and comes back is not burned again before BURN_EVERY is up.
function FirePits.step(s: State, karts: { Kart }, now: number, scale: number?): { any }
	local hurt = {}
	for _, c in karts do
		if c.alive then
			for _, pit in s.pits do
				if FirePits.inside(pit, c.position, scale) then
					local last = s.last[c.id]
					if last == nil or now - last >= FirePits.BURN_EVERY then
						s.last[c.id] = now
						table.insert(hurt, { id = c.id, damage = FirePits.burn(now) })
					end
					break
				end
			end
		end
	end
	return hurt
end

return FirePits
