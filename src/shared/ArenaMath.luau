--!strict
-- Bowl shape math (pure numbers). Height of the bowl surface at a distance from center.

local ArenaMath = {}

-- Flat in the middle, then a straight slope going up to the rim.
function ArenaMath.surfaceHeight(
	r: number,
	flatRadius: number,
	rimRadius: number,
	tiltDeg: number
): number
	local clamped = math.min(math.max(r, flatRadius), rimRadius)
	return (clamped - flatRadius) * math.tan(math.rad(tiltDeg))
end

-- Length of one slope slab, measured along the slope.
function ArenaMath.slopeLength(flatRadius: number, rimRadius: number, tiltDeg: number): number
	return (rimRadius - flatRadius) / math.cos(math.rad(tiltDeg))
end

-- Width a slab needs so neighbors overlap at the rim.
function ArenaMath.slabWidth(rimRadius: number, segments: number): number
	return 2 * math.pi * rimRadius / segments * 1.08
end

return ArenaMath
