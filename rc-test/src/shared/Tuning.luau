--!strict
-- Every number that decides how the RC car feels. Change here, drive, repeat.

local Tuning = {
	-- Car body (studs)
	bodyX = 3,
	bodyY = 1,
	bodyZ = 5.5,
	wheelRadius = 0.8,
	wheelWidth = 0.7,
	wheelX = 1.9, -- sideways distance of the wheels from the middle
	wheelZ = 2.1, -- forward/back distance of the wheels from the middle
	attachY = -0.2, -- where the springs hang from (local height)

	-- Suspension
	maxSusp = 1.6, -- longest the spring can be
	springOmega = 15, -- stiffness (rad/s). Higher = harder
	springZeta = 0.3, -- bounciness. Lower = boingier
	bumpStop = 6, -- extra push when the wheel is crushed flat

	-- Engine and brakes (studs/s^2)
	accel = 75,
	topSpeed = 95,
	reverseTop = 35,
	brakeAccel = 170,
	coastDrag = 0.5,
	holdSpeed = 4, -- under this, with no pedals, the car holds still on hills
	frontDrive = 0.35, -- share of power sent to the front wheels

	-- Grip
	baseMu = 1.4,
	gripResponse = 0.75,
	handbrakeRearGrip = 0.28, -- rear grip left while the drift button is held
	handbrakeBleed = 0.8,
	minLatShare = 0.35,
	downforce = 0.5, -- extra push down at top speed, in gravities

	-- Steering (radians)
	steerLow = 0.6, -- wheel angle at a standstill
	steerHigh = 0.1, -- wheel angle at top speed
	steerCurve = 0.6,
	steerMax = 0.75,
	counterSteer = 0.9,
	counterMax = 0.55,
	steerRate = 7, -- rad/s turning in
	steerReturn = 10, -- rad/s turning back

	-- Camera
	camDistance = 15,
	camHeight = 6,
	camFovLow = 70,
	camFovHigh = 92,
}

return Tuning
