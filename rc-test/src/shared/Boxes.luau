--!strict
-- The "?" boxes of a smash match (plans/smash/MASTER-PLAN.md): the odds, the pickup rule and
-- when a taken box comes back. Pure numbers (no Instances), so Lune can test it; the server side
-- is server/BoxServer, the look is client/BoxFx.
--
-- Fair odds: each box rolls from the weapons that exist right now (a weapon that isn't built yet
-- is left out and the rest share its chance), and one kart never gets the same weapon 3 times in
-- a row.

local Boxes = {}

-- Chance weights (they don't have to add up to 100). Shown to players as percents by `odds`.
-- carter 10-28 22:12: rockets + nuke (WEAPONS), machine gun + mines + freeze (GUNMINE). The nuke
-- is the rare big one.
Boxes.WEIGHTS = table.freeze({
	Rockets = 30,
	Gun = 28,
	Mine = 20,
	Freeze = 14,
	Nuke = 8,
})
-- The order odds are shown in and rolled in (so a roll is the same on every machine).
Boxes.ORDER = table.freeze({ "Rockets", "Gun", "Mine", "Freeze", "Nuke" })

Boxes.BACK_IN = 6 -- seconds until a taken box is back (target: 8 or less)
-- a box that's back shows this long before anyone can take it, so a kart parked on the spot
-- can't take it the moment it's back and keep it looking gone
Boxes.SHOW_GAP = 0.4
-- Sizes are in "big" units (ArenaData: a kart is 3 x 5.5 big), times the map's scale for studs
-- (the arena is RC size: TrackData.RC_SCALE = 0.25, so a kart is about 1.4 studs long).
Boxes.KART = 5.5 -- a kart's length, big
Boxes.SCALE = 0.25 -- studs per big unit when the caller gives none (the RC arena)
-- big, flat, from the box's middle to the kart's middle: about 2 kart lengths, ~3 studs (Lead
-- 10-29, BOTS: at 1 kart length real drivers had to crawl round a box to get it)
Boxes.RADIUS = 2.2 * Boxes.KART
Boxes.RING = 9 -- big, the glowing ground ring's width (the look, not the reach)
Boxes.HEIGHT = 6 -- big, up or down still counted as touching (boxes on the pink hills)
Boxes.SIZE = 4 -- big, the box's side (a bit under a kart length)
Boxes.LIFT = 3 -- big, the box's middle above its spot on the ground
Boxes.CHECK_HZ = 10 -- pickup checks a second; between checks the kart's path is checked too
Boxes.SWEEP_MAX = 40 -- big; a move longer than this between checks is a jump, not a drive
Boxes.MAX_SAME = 2 -- one kart gets the same weapon at most this many times in a row

export type Box = {
	x: number,
	y: number,
	z: number,
	up: boolean,
	backAt: number, -- when a taken box comes back (0 while up)
	readyAt: number, -- when a box that's back can be taken (SHOW_GAP after it's back)
	r: number, -- pickup reach, studs
	h: number, -- up/down reach, studs
}

export type Kart = {
	id: any,
	x: number,
	y: number,
	z: number,
	alive: boolean,
	-- where it was at the last check (nil after a jump or when new); the path between counts
	px: number?,
	pz: number?,
}

-- Each weapon's chance as a percent, from the weapons `has` says exist (all of them if nil).
function Boxes.odds(has: ((string) -> boolean)?): { [string]: number }
	local total = 0
	for _, name in Boxes.ORDER do
		if has == nil or has(name) then
			total += Boxes.WEIGHTS[name]
		end
	end
	local out = {}
	if total <= 0 then
		return out
	end
	for _, name in Boxes.ORDER do
		if has == nil or has(name) then
			out[name] = Boxes.WEIGHTS[name] * 100 / total
		end
	end
	return out
end

-- One weapon from the box. `r` is a number in [0, 1). `last` / `streak` are the kart's last
-- weapon from a box and how many times in a row it got it; at MAX_SAME that weapon is left out
-- (unless it's the only one). Nil when no weapon exists.
function Boxes.roll(r: number, has: ((string) -> boolean)?, last: string?, streak: number?): string?
	local function ok(name: string): boolean
		return has == nil or has(name)
	end
	local blocked: string? = nil
	if last ~= nil and (streak or 0) >= Boxes.MAX_SAME then
		for _, name in Boxes.ORDER do
			if name ~= last and ok(name) then
				blocked = last -- another weapon exists, so the streak can be broken
				break
			end
		end
	end
	local total = 0
	for _, name in Boxes.ORDER do
		if name ~= blocked and ok(name) then
			total += Boxes.WEIGHTS[name]
		end
	end
	if total <= 0 then
		return nil
	end
	local pick = math.clamp(r, 0, 0.999999) * total
	local lastOk: string? = nil
	for _, name in Boxes.ORDER do
		if name ~= blocked and ok(name) then
			lastOk = name
			pick -= Boxes.WEIGHTS[name]
			if pick < 0 then
				return name
			end
		end
	end
	return lastOk
end

-- A fresh box at every spot (studs), all up. `scale` = studs per big unit (default SCALE).
function Boxes.new(spots: { { x: number, y: number, z: number } }, scale: number?): { Box }
	local sc = scale or Boxes.SCALE
	local out = {}
	for _, s in spots do
		table.insert(out, {
			x = s.x,
			y = s.y,
			z = s.z,
			up = true,
			backAt = 0,
			readyAt = 0,
			r = Boxes.RADIUS * sc,
			h = Boxes.HEIGHT * sc,
		})
	end
	return out
end

-- Is the kart touching the box, now or on its way here since the last check?
function Boxes.touching(box: Box, k: Kart): boolean
	if math.abs(k.y - box.y) > box.h then
		return false
	end
	local x, z = k.x, k.z
	local px, pz = k.px, k.pz
	if px and pz then
		-- the nearest point to the box on the straight line from the last check to now
		local sx, sz = x - px, z - pz
		local len2 = sx * sx + sz * sz
		if len2 > 1e-9 then
			local u = math.clamp(((box.x - px) * sx + (box.z - pz) * sz) / len2, 0, 1)
			x, z = px + sx * u, pz + sz * u
		end
	end
	local dx, dz = x - box.x, z - box.z
	return dx * dx + dz * dz <= box.r * box.r
end

-- One check at time `now`: boxes whose time is up come back; then each up box goes to the first
-- live kart touching it that `take(kartId)` accepts (take returns false when that kart can't hold
-- another weapon, and the box stays for someone else). Returns the {box index, kart id} pairs
-- taken this check, and the indexes of boxes that came back. A box that's back can't be taken
-- for SHOW_GAP, so everyone sees it, and the next pickup's BACK_IN starts from then.
function Boxes.step(
	boxes: { Box },
	karts: { Kart },
	now: number,
	take: (any, number) -> boolean
): ({ { box: number, kart: any } }, { number })
	local taken = {}
	local back = {}
	local gotOne: { [any]: boolean } = {} -- one box per kart per check
	for i, box in boxes do
		if not box.up and now >= box.backAt then
			box.up = true
			box.backAt = 0
			box.readyAt = now + Boxes.SHOW_GAP
			table.insert(back, i)
		elseif box.up and now >= box.readyAt then
			for _, k in karts do
				if k.alive and not gotOne[k.id] and Boxes.touching(box, k) and take(k.id, i) then
					box.up = false
					box.backAt = now + Boxes.BACK_IN
					gotOne[k.id] = true
					table.insert(taken, { box = i, kart = k.id })
					break
				end
			end
		end
	end
	return taken, back
end

-- Every box up again (a new match).
function Boxes.reset(boxes: { Box })
	for _, box in boxes do
		box.up = true
		box.backAt = 0
		box.readyAt = 0
	end
end

return Boxes
