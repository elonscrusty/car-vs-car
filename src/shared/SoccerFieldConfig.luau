--!strict
-- Numbers for the small car soccer field (pure data, placeholder values: change freely).
-- Field coordinates are relative to the arena slot origin: X runs along the field (goals at
-- the two short ends), Z across it. Team 1 defends the -X goal, team 2 the +X goal.
-- The floor top sits at y = 0. Team size lives in ModesConfig.Soccer.teamSize.

return {
	length = 120, -- studs along X (goal line to goal line)
	width = 70, -- studs along Z
	wallHeight = 30, -- walls are tall: the ball and cars stay in
	wallThick = 3,
	ceilingHeight = 60, -- invisible lid so nothing flies out over the walls (0 = no lid)
	cornerCut = 14, -- corners are cut at 45 degrees this many studs (no sharp corner for the ball)
	goalWidth = 24, -- goal mouth, centered on each short end
	goalDepth = 10, -- how far the net reaches behind the goal line
	goalHeight = 12, -- crossbar height
	ballDiameter = 9,
	ballDensity = 0.3, -- low = a hit moves it
	ballFriction = 0.3,
	ballElasticity = 0.7, -- bouncy off the walls
	ballMaxSpeed = 100, -- the server never lets the ball go faster
	kickoffLift = 0.5, -- ball starts this far above the floor (drops onto it)
	spawnX = 38, -- team start spots, studs from the middle along X
	spawnSpreadZ = 18, -- studs between cars of the same team
	lostMargin = 12, -- ball or car this far outside the field (or under the floor) is put back
	stuckSpeed = 1.5, -- ball slower than this ...
	stuckSeconds = 6, -- ... for this long = back to the middle
	botOffset = 10, -- bots aim this far behind the ball, away from the goal they attack
	botNear = 7, -- once this close to the aim point a bot drives straight into the ball
	stuckWarnSeconds = 2, -- the "ball stuck" warning shows this long before the reset
	-- Goalkeeper bot (one bot per team): waits on its own goal line, follows the ball sideways
	keeperDepth = 9, -- studs in front of its own goal line
	keeperRange = 9, -- sideways limit from the goal middle (goal half width is 12)
	keeperClearRadius = 26, -- ball this close to its own goal middle = the keeper drives out to clear it
	-- Camera: high behind your car, on the line from the ball through the car
	camBack = 30, -- studs behind the car
	camUp = 30, -- base height
	camUpPerBallDist = 0.3, -- extra height per stud between car and ball (keeps both in frame)
	camMaxUp = 62,
	camLookBall = 0.5, -- look point: 0 = your car, 1 = the ball
	camDirBlend = 14, -- ball closer than this to the car: swing toward the car's own back (no jitter)
	camMargin = 14, -- the camera stays inside the field plus this many studs
	-- Looks
	grass = { 64, 140, 70 },
	grassAlt = { 58, 128, 64 }, -- every other stripe
	stripes = 8,
	lineColor = { 240, 240, 240 },
	lineThick = 0.6,
	centerCircleRadius = 10,
	wallColor = { 70, 76, 92 },
	postColor = { 235, 235, 235 },
	netColor = { 230, 230, 230 },
	netTransparency = 0.6,
	goalZone = { { 70, 150, 255 }, { 255, 90, 70 } }, -- team 1 blue, team 2 red floor strip in front of each goal
}
