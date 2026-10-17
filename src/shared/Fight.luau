--!strict
-- Pure fight rules: ring-out. No Roblox calls so Lune can test it.

local Fight = {}

-- Beyond the rim (plus a margin) the car is out of the ring.
function Fight.isRingOut(horizDist: number, rimRadius: number, margin: number): boolean
	return horizDist > rimRadius + margin
end

return Fight
