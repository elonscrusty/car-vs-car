--!strict
-- Numbers for the car soccer bots (pure data; every value is a first guess, tune freely).
-- Rules: shared/SoccerBotRules. Field numbers: SoccerFieldConfig. Level numbers: BotLevelsConfig.

return {
	-- Steering and gas
	steerFullRad = 0.6, -- angle to the aim point (radians) that gives full steering lock
	minThrottle = 0.15, -- gas never drops below this while pointing roughly the wrong way
	tightAngleDeg = 55, -- aim point this far off the nose and close: slow down so the car can turn in
	tightDist = 40, -- ...close means this many studs
	tightThrottle = 0.3, -- gas while turning in tight
	leadMax = 0.8, -- longest look-ahead (seconds) when aiming at where the ball will be
	aimMargin = 4, -- aim points stay this far inside the walls
	-- Going round the ball: a chaser that would touch the ball on the way to its staging point
	-- (and push it toward its own goal) swings out sideways first.
	detourClear = 9, -- path closer than this to the ball = detour
	detourSide = 15, -- the waypoint sits this far to the side of the ball
	-- Circling / standing still
	circleAngleDeg = 50, -- aim point stays this far off the nose while moving ...
	circleSeconds = 1.6, -- ... for this long = brake and turn in on the spot
	circleSpeed = 6, -- only counts as circling above this speed
	idleSpeed = 2.5, -- slower than this ...
	idleSeconds = 1.2, -- ... for this long (and not holding goal) = unstick (divided by the level's runUpMult)
	unstickSeconds = 0.9, -- how long an unstick manoeuvre lasts
	-- Reversing (only to unstick or to back off a close target) must not point at the own goal
	reverseNear = 12, -- target this close and behind the car: reversing is allowed
	reverseLook = 40, -- studs travelled backward that are checked for the own goal mouth
	reverseGoalPad = 8, -- the checked goal mouth is this much wider on each side
	-- Keeper
	keeperHold = 2.5, -- this close to its post the keeper stops driving and turns toward the ball
	-- Boost
	boostMinDist = 25, -- target at least this far away
	boostMaxDist = 110,
	boostAimDeg = 22, -- pointing this close at the aim point
	boostSpeedShare = 1.05, -- only while slower than this share of top speed (already flying: no boost)
	boostRunTime = 0.9, -- seconds of boosted travel that must be free of wall ahead
	boostTopShare = 1.6, -- top speed in a boost vs normal
	boostEnemyCone = 14, -- a rival car this close to the boost line (sideways) blocks the lane ...
	boostEnemyAhead = 45, -- ... when it is within this many studs ahead
	boostOwnGoalDot = 0.35, -- no boost when the nose points this much toward the own goal line
	moveCheck = 0.25, -- seconds between "use a move now?" rolls
	-- Abilities (kind -> rule inside SoccerBotRules)
	dashMin = 16,
	dashMax = 60,
	ramDist = 40,
	ramAngleDeg = 30,
	shieldDist = 26, -- a rival this close
	jumpDist = 12, -- ball this close (keeper clearing)
}
