--!strict
-- Health wrenches in the Smash arena (carter yes 10-29; carter picked "A Big Wrench", 10-31).
-- A wrench sits on a pad at a fixed spot. A kart that is hurt and drives onto it gets 40% of its
-- health back; the wrench is gone for BACK_IN seconds, then comes back. A kart at full health
-- leaves it for someone else. The server alone decides (server/WrenchServer); the client only
-- draws it (client/WrenchFx). Plain numbers + `vector`, so Lune tests run it.
-- Sizes are big units (a kart is 3 x 5.5 big); the arena is built big then scaled by SCALE.

local Wrenches = {}

Wrenches.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
Wrenches.HEAL = 0.4 -- the share of a kart's full health it gives back
Wrenches.BACK_IN = 25 -- seconds until a taken wrench is back
Wrenches.SHOW_GAP = 0.4 -- a wrench that's back shows this long before anyone can take it
Wrenches.RADIUS = 12 -- big, flat reach from the wrench's middle (about 2 kart lengths)
Wrenches.HEIGHT = 6 -- big, up or down still counted as touching
Wrenches.LIFT = 3.4 -- big, the wrench's middle above the floor
Wrenches.NAME = "Wrench"

-- Where the wrenches are, in picture units (the arena's 240 x 240 picture): three spread out
-- open flat spots, away from the hills, sand, starts, kegs, drums, pits, crates and the crane.
-- tests/wrenches.test checks the gaps.
Wrenches.SPOTS = {
	{ 35, 145 }, -- west
	{ 195, 55 }, -- north-east
	{ 120, 215 }, -- south
} :: { { number } }

export type Kart = { id: any, position: vector, alive: boolean, hurt: boolean }
export type Item = { pos: vector, up: boolean, backAt: number, readyAt: number }
export type State = { items: { Item } }

function Wrenches.new(spots: { vector }): State
	local items: { Item } = {}
	for _, p in spots do
		table.insert(items, { pos = p, up = true, backAt = 0, readyAt = 0 })
	end
	return { items = items }
end

-- Round start: every wrench up.
function Wrenches.reset(s: State)
	for _, it in s.items do
		it.up = true
		it.backAt, it.readyAt = 0, 0
	end
end

-- Is the kart on the wrench's pad?
function Wrenches.touching(it: Item, kart: vector, scale: number?): boolean
	local sc = scale or Wrenches.SCALE
	if math.abs(kart.y - it.pos.y) / sc > Wrenches.HEIGHT then
		return false
	end
	local dx, dz = kart.x - it.pos.x, kart.z - it.pos.z
	return math.sqrt(dx * dx + dz * dz) / sc <= Wrenches.RADIUS
end

-- One check at time `now`. Wrenches whose time is up come back; each up wrench goes to the first
-- live, hurt kart on it that `take(kartId)` accepts. Returns the { wrench index, kart id } pairs
-- taken this check and the indexes of wrenches that came back.
function Wrenches.step(
	s: State,
	karts: { Kart },
	now: number,
	take: (any, number) -> boolean,
	scale: number?
): ({ { item: number, kart: any } }, { number })
	local taken, back = {}, {}
	for i, it in s.items do
		if not it.up and now >= it.backAt then
			it.up = true
			it.readyAt = now + Wrenches.SHOW_GAP
			table.insert(back, i)
		end
		if it.up and now >= it.readyAt then
			for _, k in karts do
				if
					k.alive
					and k.hurt
					and Wrenches.touching(it, k.position, scale)
					and take(k.id, i)
				then
					it.up = false
					it.backAt = now + Wrenches.BACK_IN
					table.insert(taken, { item = i, kart = k.id })
					break
				end
			end
		end
	end
	return taken, back
end

return Wrenches
