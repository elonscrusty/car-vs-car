--!strict
-- Race looks, the pure part (carter's picks 15, 10-26): when a hit is hard enough for sparks.
-- RaceFx draws them. Looks only: race feel stays LOCKED.

local RaceLooks = {}

-- Did the car just slam into something? Its flat speed (studs/s) fell this much in one frame:
-- a hard stop, not braking (brakes take many frames). scale = Tuning.scale (the car's size).
function RaceLooks.slammed(before: number, after: number, scale: number): boolean
	return before - after > 18 * scale and after < before * 0.6
end

return RaceLooks
