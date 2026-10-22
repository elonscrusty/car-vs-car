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
	maxSusp = 2.0, -- longest the spring can be
	springOmega = 14, -- stiffness (rad/s). Higher = harder
	springZeta = 0.4, -- bounciness. Lower = boingier
	bumpStop = 6, -- extra push when the wheel is crushed flat

	-- Engine and brakes (studs/s^2)
	accel = 60,
	crawlBoost = 150, -- extra push at crawling speed so it can climb steep rocks
	crawlSpeed = 18,
	topSpeed = 95,
	reverseTop = 35,
	brakeAccel = 170,
	coastDrag = 0.5,
	holdSpeed = 4, -- under this, with no pedals, the car holds still on hills
	frontDrive = 0.35, -- share of power sent to the front wheels at speed
	crawlFrontDrive = 0.5, -- at crawling speed: even 4x4 so it can climb

	-- Grip
	baseMu = 1.1,
	gripResponse = 0.5, -- most of the sideways slide a tyre can stop in one frame
	peakSlip = 0.14, -- tyre angle (rad) where grip is full; below it the car slips a little
	driftAngleMax = 0.6, -- body slide angle (rad) the car settles at in a drift
	driftYawPush = 8,
	handbrakeRearGrip = 0.55, -- rear grip left while the drift button is held
	handbrakeBleed = 0.3,
	maxYaw = 3, -- rad/s: hard cap on spinning so drifts stay catchable
	minLatShare = 0.35,
	downforce = 0.5, -- extra push down at top speed, in gravities

	-- Steering (radians)
	steerLow = 0.6, -- wheel angle at a standstill
	steerHigh = 0.1, -- wheel angle at top speed
	steerCurve = 0.6,
	steerMax = 0.75,
	counterSteer = 1.1,
	counterMax = 0.6,
	steerRate = 7, -- rad/s turning in
	steerReturn = 10, -- rad/s turning back

	-- Camera
	camDistance = 10, -- low chase cam, close behind like an RC chase
	camHeight = 3,
	camFovLow = 70,
	camFovHigh = 92,
	orbitDistance = 13,
	orbitHeight = 3.5,
	driverWidth = 28, -- driver view zooms so about this much ground fits around the car
	driverFovMin = 10,
	driverFovMax = 70,
	driverLiftMax = 40, -- driver view rises up to this much to see the car over a wall
	orbitSpeed = 0.35, -- rad/s the show-off camera circles the car

	-- Gas while sliding keeps the back loose (0 = off). Only the drift track turns it on.
	powerSlide = 0,
	driftThrust = 0, -- push along the slide while on the gas, so drifts keep their speed
	lowGear = 0, -- 1 = the engine holds the top speed going downhill too

	-- Size of the whole world for the car. 1 = big test size, 0.25 = real RC size next to a player.
	-- Lengths, speeds, pushes and the car's own gravity all shrink together, so it drives the same.
	scale = 1,
}

-- Each track can change some numbers. Anything not listed uses the base value above.
local MODES: { [string]: { [string]: number } } = {
	-- Tokyo drift: easy to throw sideways, gas holds the slide, deep held angles.
	drift = {
		driftAngleMax = 0.75,
		driftYawPush = 12,
		handbrakeRearGrip = 0.4,
		frontDrive = 0.15,
		powerSlide = 0.4,
		driftThrust = 32,
		counterMax = 0.85,
		steerMax = 0.95,
		steerHigh = 0.2,
		-- Slow and long: lower speed, softer grip and a slower spin, so each slide lasts and is easy to watch.
		topSpeed = 60,
		accel = 40,
		baseMu = 0.9,
		maxYaw = 1.7,
		steerRate = 5,
		-- Higher, further back camera so the next corner is in view.
		camDistance = 14,
		camHeight = 6,
	},
	-- Rock crawler: slow, strong, soft long springs you can watch flex, sticky tyres.
	rock = {
		topSpeed = 11, -- walking pace, so you can watch every spring work over the rocks
		accel = 110,
		crawlBoost = 60,
		crawlSpeed = 6,
		frontDrive = 0.5,
		maxSusp = 4, -- long travel: wheels droop into holes and tuck up over rocks
		springOmega = 9.5,
		springZeta = 0.45,
		baseMu = 1.6,
		steerLow = 0.4,
		steerHigh = 0.4,
		steerRate = 2, -- gentle steering while crawling, so short taps don't swing the car
		reverseTop = 8,
		downforce = 0,
		lowGear = 1,
		coastDrag = 2.5,
	},
}

-- Numbers that are lengths, speeds or pushes: these shrink with `scale`.
local SCALED = {
	"bodyX",
	"bodyY",
	"bodyZ",
	"wheelRadius",
	"wheelWidth",
	"wheelX",
	"wheelZ",
	"attachY",
	"maxSusp",
	"accel",
	"crawlBoost",
	"crawlSpeed",
	"topSpeed",
	"reverseTop",
	"brakeAccel",
	"holdSpeed",
	"driftThrust",
	"camDistance",
	"camHeight",
	"driverWidth",
	"driverLiftMax",
	"orbitDistance",
	"orbitHeight",
}

local base: { [string]: any } = table.clone(Tuning)
local currentMode = "race"
local currentScale = 1

local function apply()
	local t = Tuning :: any
	for key, value in base do
		t[key] = value
	end
	local mode = MODES[currentMode]
	if mode then
		for key, value in mode do
			t[key] = value
		end
	end
	for _, key in SCALED do
		t[key] *= currentScale
	end
	t.scale = currentScale
end

-- Switch to a track's numbers ("race" or unknown = base numbers).
local function setMode(id: string)
	currentMode = id
	apply()
end

-- Switch the size of everything (1 = big, 0.25 = real RC).
local function setScale(s: number)
	currentScale = s
	apply()
end

return setmetatable(Tuning, { __index = { setMode = setMode, setScale = setScale } })
