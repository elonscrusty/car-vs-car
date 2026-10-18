--!strict
-- Fight pacing math (pure): how long until the two cars first touch. Used by a test that keeps
-- the bowl small enough for a first hit in under GameConfig.Pacing.targetSeconds.

local Pacing = {}

-- Seconds for two cars starting `gap` studs apart and driving at each other to meet.
-- Each car's speed is estimated as the average of its launch speed and its top speed;
-- `detour` (>= 1) stretches the path for imperfect aim and turning.
function Pacing.travelSeconds(
	gap: number,
	launchSpeed: number,
	topSpeed: number,
	detour: number
): number
	local each = (math.max(launchSpeed, 0) + math.max(topSpeed, 0)) / 2
	if each <= 0 then
		return math.huge
	end
	return gap * math.max(detour, 1) / (each * 2)
end

-- Expected time from the aim phase starting to the first contact, worst case: nobody launches
-- before the aim timeout.
function Pacing.firstContactSeconds(
	aimTimeout: number,
	spawnRadius: number,
	launchSpeed: number,
	topSpeed: number,
	detour: number
): number
	return aimTimeout + Pacing.travelSeconds(spawnRadius * 2, launchSpeed, topSpeed, detour)
end

return Pacing
