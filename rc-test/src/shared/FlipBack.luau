--!strict
-- The Smash arena: a kart upside down or on its side for a moment is set back on its wheels where
-- it is (same spot, same facing), not sent to a spawn (thumb run: flipped 41 s of 180). Numbers
-- only; Main.client does the put-back.

local FlipBack = {}

FlipBack.TILT = 0.5 -- the kart's up arrow points less up than this (60 degrees or more over) = tipped
FlipBack.WAIT = 1 -- seconds tipped before it is put back

-- One frame: `held` = seconds tipped so far, `upY` = the kart's up arrow's height (1 = flat).
-- Returns the new seconds tipped, and true when it is time to put it back (the count starts over).
function FlipBack.tick(held: number, dt: number, upY: number): (number, boolean)
	if upY >= FlipBack.TILT then
		return 0, false
	end
	held += dt
	if held >= FlipBack.WAIT then
		return 0, true
	end
	return held, false
end

-- Which way to face when put back, flat on the ground: the nose's way, or (nose straight up or
-- down) the way the roof pointed. Returns x, z of a unit direction.
function FlipBack.facing(lookX: number, lookZ: number, upX: number, upZ: number): (number, number)
	for _, d in { { lookX, lookZ }, { upX, upZ } } do
		local m = math.sqrt(d[1] * d[1] + d[2] * d[2])
		if m > 0.1 then
			return d[1] / m, d[2] / m
		end
	end
	return 0, 1
end

return FlipBack
