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
Boxes.RADIUS = 7 -- studs from the box's middle, flat; a kart is about 6 long
Boxes.HEIGHT = 8 -- studs up or down still counted as touching (boxes on the pink hills)
Boxes.CHECK_HZ = 10 -- pickup checks a second; at 40 studs/s a kart moves 4 studs a check, under RADIUS
Boxes.MAX_SAME = 2 -- one kart gets the same weapon at most this many times in a row

export type Box = {
	x: number,
	y: number,
	z: number,
	up: boolean,
	backAt: number, -- when a taken box comes back (0 while up)
}

export type Kart = {
	id: any,
	x: number,
	y: number,
	z: number,
	alive: boolean,
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

-- A fresh box at every spot, all up.
function Boxes.new(spots: { { x: number, y: number, z: number } }): { Box }
	local out = {}
	for _, s in spots do
		table.insert(out, { x = s.x, y = s.y, z = s.z, up = true, backAt = 0 })
	end
	return out
end

-- Is the kart touching the box?
function Boxes.touching(box: Box, k: Kart): boolean
	local dx, dz = k.x - box.x, k.z - box.z
	return dx * dx + dz * dz <= Boxes.RADIUS * Boxes.RADIUS
		and math.abs(k.y - box.y) <= Boxes.HEIGHT
end

-- One check at time `now`: boxes whose time is up come back; then each up box goes to the first
-- live kart touching it that `take(kartId)` accepts (take returns false when that kart can't hold
-- another weapon, and the box stays for someone else). Returns the {box index, kart id} pairs
-- taken this check, and the indexes of boxes that came back (a box back and taken in the same check
-- is only in the taken list, so it never shows up for a moment while nobody can take it).
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
		local cameBack = false
		if not box.up and now >= box.backAt then
			box.up = true
			box.backAt = 0
			cameBack = true
		end
		local gone = false
		if box.up then
			for _, k in karts do
				if k.alive and not gotOne[k.id] and Boxes.touching(box, k) and take(k.id, i) then
					box.up = false
					box.backAt = now + Boxes.BACK_IN
					gotOne[k.id] = true
					gone = true
					table.insert(taken, { box = i, kart = k.id })
					break
				end
			end
		end
		if cameBack and not gone then
			table.insert(back, i)
		end
	end
	return taken, back
end

-- Every box up again (a new match).
function Boxes.reset(boxes: { Box })
	for _, box in boxes do
		box.up = true
		box.backAt = 0
	end
end

return Boxes
