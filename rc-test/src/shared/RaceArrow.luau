--!strict
-- The glowing arrow on the road in a race: where it sits and which way it points, a little ahead
-- of the car toward the next gate. Plot-local big units, like the gates. Pure maths, so Lune can
-- test it; client/RoadArrow draws it (looks only).
local RaceArrow = {}

RaceArrow.AHEAD = 44 -- how far in front of the car (big units): clear of the car in chase view
RaceArrow.NEAR = 50 -- closer than this to the gate: point the way the gate faces
RaceArrow.MIN = 4 -- closer than this: no arrow (the next one takes over after the gate)

export type Gate = { x: number, y: number, z: number, dx: number, dz: number }

-- the gate to drive to next: gate 1 before the clock runs, else the timer's next one (wrapped)
function RaceArrow.nextGate(gates: { Gate }, nextIndex: number, running: boolean): Gate?
	if #gates == 0 then
		return nil
	end
	if not running then
		return gates[1]
	end
	return gates[((nextIndex - 1) % #gates) + 1]
end

-- spot (x, z) and unit direction (dx, dz) of the arrow, or nil when the car is at the gate
function RaceArrow.place(cx: number, cz: number, g: Gate): (number?, number?, number?, number?)
	local tx, tz = g.x - cx, g.z - cz
	local dist = math.sqrt(tx * tx + tz * tz)
	if dist < RaceArrow.MIN then
		return nil, nil, nil, nil
	end
	local dx, dz = tx / dist, tz / dist
	if dist < RaceArrow.NEAR then
		dx, dz = g.dx, g.dz
	end
	local ahead = math.min(RaceArrow.AHEAD, dist)
	return cx + tx / dist * ahead, cz + tz / dist * ahead, dx, dz
end

return RaceArrow
