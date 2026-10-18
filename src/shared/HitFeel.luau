--!strict
-- Hit feel (pure): how loud the client's "HIT!" flash is for a hit of strength 0..1.

local HitFeel = {}

-- Which flash tier: 0 = none, 1 = normal, 2 = strong.
function HitFeel.tier(strength: number, flashFrom: number, strongFrom: number): number
	if strength >= strongFrom then
		return 2
	elseif strength >= flashFrom then
		return 1
	end
	return 0
end

-- 0..1 how far past `from` a strength is (for sizing the flash).
function HitFeel.emphasis(strength: number, from: number): number
	if from >= 1 then
		return if strength >= 1 then 1 else 0
	end
	return math.clamp((strength - from) / (1 - from), 0, 1)
end

return HitFeel
