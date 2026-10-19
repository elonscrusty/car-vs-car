--!strict
-- Pure fight rules: ring-out. No Roblox calls so Lune can test it.

local Fight = {}

-- Beyond the rim (plus a margin) the car is out of the ring.
function Fight.isRingOut(horizDist: number, rimRadius: number, margin: number): boolean
	return horizDist > rimRadius + margin
end

-- How far out a spot is: round arenas count the straight distance, square ones the larger of |x|
-- and |z| (so the corners are not extra safe floor).
function Fight.edgeDistance(x: number, z: number, square: boolean): number
	if square then
		return math.max(math.abs(x), math.abs(z))
	end
	return math.sqrt(x * x + z * z)
end

return Fight
