--!strict
-- Comeback speed pop: a hurt car (low HP) gets one short burst of speed the first time it uses
-- boost or its ability. Placeholders: change freely.
return {
	enabled = true,
	belowFrac = 0.25, -- HP share at or under which the pop is allowed
	speedBonus = 0.35, -- +35% top speed at the start of the pop
	seconds = 0.9, -- how long the pop lasts (fades out linearly)
}
