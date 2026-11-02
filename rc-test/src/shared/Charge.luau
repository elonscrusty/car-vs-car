--!strict
-- A kart's ONE special (carter 10-29 22:30): no random weapon boxes, a gold box CHARGES it. It
-- also fills slowly on its own. The level is 0..1 and the SPECIAL button lights at 1.
-- Plain numbers (no Instances), so Lune can test it: server/SpecialCharge keeps one slot per kart,
-- client/BoxFx and the SPECIAL button read the level with `level`.

local Charge = {}

Charge.PER_BOX = 1 / 3 -- one gold box = a third (same number as Boxes.CHARGE)
Charge.PIPS = 3 -- the dots shown over a kart that grabs a box
Charge.FILL_SECS = 45 -- seconds to fill from empty with no box (numbers can change)

local EPS = 1e-6

-- `base` is the level at time `at`; from then it grows by 1 / FILL_SECS a second.
export type Slot = { base: number, at: number }

function Charge.slot(now: number): Slot
	return { base = 0, at = now }
end

-- How full the special is at `now`, 0..1.
function Charge.level(slot: Slot, now: number): number
	return math.clamp(slot.base + math.max(now - slot.at, 0) / Charge.FILL_SECS, 0, 1)
end

function Charge.full(slot: Slot, now: number): boolean
	return Charge.level(slot, now) >= 1 - EPS
end

-- A box: adds `amount` (default PER_BOX). Returns the new level, or nil when the special is
-- already full (the box stays for someone else).
function Charge.add(slot: Slot, now: number, amount: number?): number?
	local level = Charge.level(slot, now)
	if level >= 1 - EPS then
		return nil
	end
	local add = amount or Charge.PER_BOX
	if add ~= add or add <= 0 then
		return nil
	end
	slot.base = math.min(1, level + add)
	slot.at = now
	return slot.base
end

-- The SPECIAL button: spends a FULL special and empties it. false = not full yet.
function Charge.use(slot: Slot, now: number): boolean
	if not Charge.full(slot, now) then
		return false
	end
	slot.base = 0
	slot.at = now
	return true
end

-- How many of the PIPS dots are lit at `level` (a third fills one dot).
function Charge.pips(level: number): number
	return math.clamp(math.floor(level * Charge.PIPS + EPS), 0, Charge.PIPS)
end

return Charge
