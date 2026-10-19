--!strict
-- Numbers for the Crazy Race track (pure data, placeholder values: change freely).
-- Flat ground, one closed loop of road. Coordinates are relative to the arena slot origin
-- (x right, z toward the camera). Waypoint 1 is the start/finish line; the loop runs 1 -> 2 -> ... -> 1.

return {
	-- The loop, in driving order. Cars start just behind waypoint 1 and drive toward waypoint 2.
	waypoints = {
		{ x = 0, z = 0 },
		{ x = 160, z = 0 },
		{ x = 270, z = -40 },
		{ x = 330, z = -130 },
		{ x = 300, z = -230 },
		{ x = 190, z = -280 },
		{ x = 50, z = -260 },
		{ x = -70, z = -200 },
		{ x = -110, z = -100 },
		{ x = -100, z = 0 }, -- straight run-in to the line (the start grid sits here)
	},
	roadWidth = 44,
	groundMargin = 140, -- grass beyond the road on every side
	checkpointRadius = 30, -- driving this close to the next waypoint counts it
	gridColumns = 2, -- start grid: cars side by side
	gridSpacing = 14, -- studs between grid rows
	gridWidth = 14, -- studs between the two columns
	gridBack = 14, -- first row this far behind the line
	-- Jumps: a gentle hill (up slope + down slope, no steep face a slow car could hang on) in the
	-- middle of a stretch (stretch n = from waypoint n to n+1). `length` is each slope's length.
	ramps = {
		{ seg = 1, t = 0.5, width = 26, length = 20, height = 3 },
		{ seg = 4, t = 0.5, width = 26, length = 20, height = 3 },
		{ seg = 6, t = 0.4, width = 26, length = 20, height = 3 },
	},
	debug = false, -- print race progress and why it ended to the output (turn off when it plays right)
	laps = 3,
	maxSeconds = 150, -- time up: furthest along the track wins
	goSeconds = 3, -- 3-2-1 with the cars frozen
	fallBelow = -20, -- a car this far under the ground goes back to its last checkpoint
	stuckSeconds = 5, -- a bot with no progress this long is put back at its last checkpoint
	humanStuckSeconds = 6, -- a human with no progress this long is put back (audit #34)
	resetButtonSeconds = 3, -- the RESET button may be used after this long without progress
	resetCooldown = 4, -- seconds between two manual resets of the same car
	progressGain = 3, -- studs closer to the next gate (or a new gate) that count as progress
	frontRowMatches = 3, -- a player's first matches (Profile.matches below this) start on the front row (audit #33)
	ceiling = 70, -- a car this high above the ground is put back (cheat guard, audit #106)
	hudSeconds = 0.5,
	colors = {
		road = { 70, 74, 86 },
		line = { 245, 245, 245 },
		edge = { 255, 205, 60 },
		grass = { 70, 150, 80 },
		ramp = { 255, 140, 40 },
	},
}
