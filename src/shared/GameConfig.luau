--!strict
-- Game-wide numbers. Change these to change how the duel FEELS.
-- Pure data only (no Roblox calls) so unit tests can load it.

local GameConfig = {
	-- Which way a match plays. autoFight = true: build-and-watch (the cars drive and fight by
	-- themselves, you only watch). autoFight = false: you aim, launch, then steer your own car.
	-- useBuild = true: the garage car and its parts are what you fight with (no "pick 1 of 3").
	Mode = {
		autoFight = false,
		useBuild = true,
		readySeconds = 3, -- auto fight: "get ready" countdown before the cars go
		koFreezeSeconds = 0.35, -- auto fight: the finishing hit freezes the screen for this long
	},
	-- Bowl arena. Bigger tiltDeg = steeper bowl = cars roll back to the middle faster.
	Arena = {
		flatRadius = 50, -- flat middle disc (studs from center)
		rimRadius = 85, -- where the slope ends (same as flatRadius = no slope, a flat arena)
		tiltDeg = 28, -- slope angle of the bowl (0 = flat arena)
		wallHeight = 3, -- a low lip: hit hard enough and you fly over it (= ring out) -- walls on the rim
		segments = 48, -- slabs around the bowl (more = rounder)
		baseY = 300, -- height of arena in the world (far above the baseplate)
		slotSpacing = 1000, -- each player gets own arena this far apart on X
		spawnRadius = 68, -- launch spots, studs from center
		-- Things to hit and hide behind. x/z = studs from center. Keep them mirrored (x,z -> -x,-z)
		-- so neither side is lucky. "block" = box (sx, sy, sz); "pillar" = round (sx = width);
		-- "ramp" = a slope to jump off (sx wide, sz long, yaw = turn in degrees, climbs toward -Z at 0);
		-- "spinner" = a bar (sx long, sy high) that turns around (x, z) at `spin` rad/sec.
		obstacles = {},
	},
	Match = {
		aimTimeout = 6, -- seconds to aim before the server launches for you
		roundEndDelay = 3.5, -- seconds to watch the dummy fly
		maxMatchSeconds = 120, -- time up: higher HP wins, equal HP = next hit wins
		outOfBoundsHeight = 120, -- car this far above the arena = flying cheat, counts as dead
		outOfBoundsDrop = 40, -- car this far below the arena = counts as dead
	},
	Launch = {
		minSpeed = 70, -- studs/sec at 0% power
		maxSpeed = 150, -- studs/sec at 100% power
	},
	-- Drag-to-launch (phone + mouse): pull back like a slingshot, let go to launch.
	Drag = {
		minFrac = 0.03, -- drags shorter than this share of the screen do nothing
		maxFrac = 0.3, -- a drag this long = 100% power
	},
	Damage = {
		scale = 0.45, -- damage = impact speed x car multiplier x this
		minImpactSpeed = 12, -- slower bumps do nothing
		hitCooldown = 0.5, -- seconds between counted hits
	},
	Flip = {
		upsideDownUpY = 0.2, -- car "up" below this = upside down / on side
		afterSeconds = 1, -- flip back after this long
	},
	Feel = {
		bigHitSpeed = 70, -- impact speed that counts as a full-strength hit
		hitStopMin = 0.04, -- freeze length (seconds) for a medium hit
		hitStopMax = 0.12, -- freeze length for a full-strength hit
		hitStopFrom = 0.4, -- hits weaker than this (0..1) do not freeze
		shakeMax = 1.6, -- camera shake size (studs) for a full-strength hit
		shakeTime = 0.4, -- seconds a shake lasts
		normalFov = 65,
		koFov = 42, -- camera zooms in to this on a knockout
		koCamUp = 10, -- KO camera height above the dummy
		koCamBack = 20, -- KO camera distance from the dummy
		smokeBelow = 0.35, -- car smokes when HP is under this share
		flashFrom = 0.25, -- client "HIT!" flash starts at this hit strength (0..1)
		strongFrom = 0.6, -- ...and gets big (bigger number, extra shake) from this strength
		extraShake = 0.5, -- extra camera shake (x strength) on strong hits: carries the feel when there is no hit-stop
		-- Calm effects (audit #86): a client-only flag, no button yet. A UI sets the SoundService
		-- attribute named here to true; HitFlash and CameraDirector then tone things down.
		calmAttribute = "CalmEffects",
		calmFlashScale = 0.35, -- flash strength x this when calm
		calmShakeScale = 0.3, -- camera shake and FOV punches x this when calm
		maxFlashesPerSecond = 3, -- the hit flash never fires more often than this (shake still does)
		-- Chase camera (every mode except the bowl): sits behind the car, turns with it
		chaseBack = 24, -- studs behind the car
		chaseUp = 12, -- studs above the car
		chaseAhead = 14, -- look this far in front of the car
		chaseSpeedBack = 0.12, -- extra studs back per stud/s of speed
		chaseYawRate = 5, -- how fast the camera swings round after the car turns (per second)
		chaseBallShare = 0.35, -- soccer: swing this share of the way toward the ball...
		chaseBallMax = 0.6, -- ...but never more than this many radians (about 34 degrees)
		chaseFollow = 14, -- how tightly the camera sticks to the spot behind the car (per second)
		chaseSpeedFov = 12, -- FOV widens up to this much at top speed
		-- Soccer camera (audit #15): the pure framing in FeelRules.soccerCamera
		soccerCamBackMult = 1.35, -- camera sits this much further back than SoccerFieldConfig.camBack
		soccerCamUpMult = 1.3, -- ...and this much higher than camUp
		soccerCamMaxGrow = 1.8, -- the fit step never pushes the camera out more than this x
		soccerFrameMargin = 0.9, -- targets must sit inside this share of the view (1 = the very edge)
		soccerAspect = 1.8, -- screen width / height assumed for the fit (phone landscape)
		wallFadeTransparency = 0.85, -- LocalTransparencyModifier of walls between the camera and your car
		wallFadePad = 5, -- studs the see-through test inflates a wall by (fades grazing walls too)
		wallFadeRate = 6, -- fade in/out speed (per second)
		-- Goal burst (audit #23): everything finishes inside the 2.5 s goal pause
		goalSnapSeconds = 1, -- camera looks at the ball this long
		goalSnapBlendOut = 0.35, -- ...then eases back over this long
		goalSnapFov = 50,
		goalBurstSeconds = 2.2, -- confetti and label live this long (under 2.5)
		goalConfetti = 70,
		-- Ball feel (audit #91)
		ballTrailMinSpeed = 18, -- ball slower than this leaves no trail
		ballTrailMaxSeconds = 0.6, -- trail lifetime at ballTrailFullSpeed
		ballTrailFullSpeed = 100,
		kickMinDelta = 22, -- a one-frame speed-vector change this big near a car = a kick
		kickFullDelta = 70, -- ...and this big = a full-strength kick
		kickSparkFrom = 0.4, -- sparks (and the kick sound) from this strength
		kickCooldown = 0.25,
		kickCarReach = 10, -- a car body this close to the ball edge counts as the kicker
		-- Boost feel (audit #92)
		boostFovAdd = 9, -- degrees of extra FOV at the peak of a boost
		boostFxSeconds = 0.8,
		boostLines = 14, -- speed lines on screen
		-- Bowl / duel camera (audit #99): closer behind your car than the old 40 / 48
		bowlCamBack = 30,
		bowlCamUp = 38,
		bowlCamShift = 0.75, -- how far the view follows your car off the middle (0..1)
		-- Touch steering (audit #52): small cars (turnRate at or above this) ease the stick
		smallCarTurnRate = 4,
		touchSteerRate = 9, -- stick steer eases at this many units per second on small cars
		touchSteerCurve = 1.35, -- >1 = gentler near the middle of the stick
		-- Graphics quality (audit #88): the average frame time decides the particle scale
		quality = {
			lowFrameTime = 1 / 28, -- average slower than this (seconds) = low quality
			okFrameTime = 1 / 42, -- average faster than this again = back to full
			window = 2, -- seconds the average looks back over
			warmup = 4, -- seconds after start before it may switch
			minHold = 5, -- seconds a level is kept before it may switch again
			lowScale = 0.35, -- particle counts x this on low quality
		},
	},
	-- Pushed past the rim = ring-out = lose the round.
	RingOut = { margin = 3 },
	Drive = {
		turnGain = 8, -- how hard the car steers toward target
		groundFriction = 0.4, -- floor + car friction. Lower = slides more, keeps speed
		slopeAssist = 1, -- 0..1: how much of the uphill gravity pull the gas cancels
		grip = 24, -- side slide killing (higher = less drifting)
		humanGrip = 36, -- ...the same for a player-driven car: glued to the road, snappy turns
		humanAccel = 1.4, -- player cars speed up this x faster than the car's accel number
		brakeMult = 2.5, -- pressing the opposite way of travel brakes this x harder than normal gas
		coastDrag = 2.2, -- no gas: forward speed fades at this share per second (stops, no ice-gliding)
		turnMinShare = 0.55, -- turn rate at a standstill = this share of full (you can still aim)
		turnFullSpeed = 22, -- ...and reaches full turn rate at this flat speed (studs/s)
		groundRayExtra = 2.5, -- studs below car that still count as "on ground"
		manualTurn = 2.4, -- human steering: full steer input = this x the car's turnRate
		manualTurnMin = 4, -- ...but never slower than this (radians/sec) so heavy cars still turn
		speedCapSlack = 1.5, -- server slows a player-driven car past (legit top speed x this)
		manualTurnMax = 7.5, -- ...and never faster than this so light cars do not spin like tops
	},
	-- Human steering input (the player turns, the server keeps the gas on)
	Steer = {
		smoothRate = 25, -- input units per second the steer eases at (0 -> 1 in ~0.04 s)
		staleSeconds = 0.5, -- no update this long = treat the input as 0
		resendSeconds = 0.1, -- client re-sends the held value this often
	},
	-- Auto-pilot behavior numbers (bot cars drive themselves after the launch; humans steer)
	Ai = {
		chargeMax = 3, -- Heavy: longest straight charge before backing up
		retreatTime = 1.1, -- after a hit: seconds driving away for a run-up
		retreatDist = 42, -- how far away it aims during the run-up
		maxRadius = 66, -- run-up target stays this close to bowl center
		circleTime = 0.7, -- Light: seconds spent circling (short: go for the enemy sooner)
		diveMax = 1.5, -- Light: longest dive before circling again
		circleRadius = 16, -- Light: circle distance around enemy
		circleAngleDeg = 40, -- Light: how far around enemy to aim each step
		stuckSeconds = 0.8, -- barely moving this long = nose-to-nose standoff, back up
		-- Rim guard: the bowl rim is Arena.rimRadius; the guard keeps bots well inside it.
		edgeRadius = 74, -- predicted distance from center that makes the bot turn for the middle
		edgeLook = 0.15, -- reaction seconds added to the guard's stopping-distance guess
		leadAfter = 1.5, -- seconds with no hit before the bot aims where the enemy will be
		leadRamp = 5, -- ...then over this many more seconds the lead grows to a full intercept
		ambushAfter = 8, -- seconds with no hit before one of two orbiting cars cuts through the middle
		ambushHold = 30, -- ...and waits once it is this close to the middle
		leadMax = 1.2, -- longest look-ahead (seconds) of that
		turnInDeg = 30, -- chasing with the enemy this far off the nose: check the turn is possible
		turnInSlack = 1.1, -- brake when faster than (turn rate x needed radius) x this
		turnInMinSpeed = 22, -- ...but never slow below this
		brakeShare = 0.9, -- share of the car's accel the guard counts on when braking (lower = brakes earlier)
		brakeSpeed = 18, -- going out faster than this at the edge = reverse gas to brake
		-- Pacing: no circling forever, no sitting nose-to-nose.
		commitAfter = 3, -- seconds with no hit before a circler just dives in
		backupDist = 30, -- Heavy only backs up when the enemy is this close
		closeDist = 15, -- "nose-to-nose" distance
		closeSeconds = 1.2, -- this long that close with no hit = back off for a run-up
		-- Boost and ability use (the level's moveUse says how often a good chance is taken)
		useMoves = true, -- bots press boost / ability (server/BotMoves); false = they never do
		moveCheck = 0.25, -- seconds between "use a move now?" rolls
		boostMinDist = 20,
		boostMaxDist = 95,
		boostAimDeg = 30, -- boost only when pointing this close to the enemy
		boostTopShare = 1.6, -- top speed in a boost vs normal (= 1 + MovesConfig.Boost.speedBonus); used to check braking room
		moveSpeedShare = 1.05, -- boost or dash only while slower than this share of top speed
		lowHp = 0.35, -- under this HP share the bot panics and fires its ability early
	},
	Dummy = {
		launchUp = 70, -- upward speed of the crash dummy (studs/sec)
		launchSpread = 25, -- sideways speed random
		lifetime = 8, -- seconds before dummy is cleaned up
	},
	-- Pacing target: the first hit should land within this many seconds of the aim phase starting.
	Pacing = {
		targetSeconds = 8,
		detour = 1.5, -- path stretch for imperfect aim and turning (pessimistic)
	},
	Remote = {
		maxPerWindow = 6, -- calls allowed per window per player
		windowSeconds = 2,
		steerMaxPerWindow = 60, -- Steer remote: calls allowed per window per player
		steerWindowSeconds = 1,
	},
}

return GameConfig
