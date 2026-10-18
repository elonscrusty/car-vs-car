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
		rimRadius = 112, -- where the slope ends (same as flatRadius = no slope, a flat arena)
		tiltDeg = 28, -- slope angle of the bowl (0 = flat arena)
		wallHeight = 3, -- a low lip: hit hard enough and you fly over it (= ring out) -- walls on the rim
		segments = 48, -- slabs around the bowl (more = rounder)
		baseY = 300, -- height of arena in the world (far above the baseplate)
		slotSpacing = 1000, -- each player gets own arena this far apart on X
		spawnRadius = 92, -- launch spots, studs from center
		-- Things to hit and hide behind. x/z = studs from center. Keep them mirrored (x,z -> -x,-z)
		-- so neither side is lucky. "block" = box (sx, sy, sz); "pillar" = round (sx = width);
		-- "ramp" = a slope to jump off (sx wide, sz long, yaw = turn in degrees, climbs toward -Z at 0);
		-- "spinner" = a bar (sx long, sy high) that turns around (x, z) at `spin` rad/sec.
		obstacles = {},
	},
	Match = {
		aimTimeout = 8, -- seconds to aim before the server launches for you
		roundEndDelay = 3.5, -- seconds to watch the dummy fly
		maxMatchSeconds = 120, -- time up: higher HP wins, equal HP = next hit wins
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
	},
	-- Pushed past the rim = ring-out = lose the round.
	RingOut = { margin = 3 },
	Drive = {
		turnGain = 8, -- how hard the car steers toward target
		groundFriction = 0.4, -- floor + car friction. Lower = slides more, keeps speed
		slopeAssist = 1, -- 0..1: how much of the uphill gravity pull the gas cancels
		grip = 24, -- side slide killing (higher = less drifting)
		groundRayExtra = 2.5, -- studs below car that still count as "on ground"
		manualTurn = 2, -- human steering: full steer input = this x the car's turnRate
		manualTurnMin = 4, -- ...but never slower than this (radians/sec) so heavy cars still turn
		speedCapSlack = 1.5, -- server slows a player-driven car past (legit top speed x this)
		manualTurnMax = 7, -- ...and never faster than this so light cars do not spin like tops
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
		retreatDist = 55, -- how far away it aims during the run-up
		maxRadius = 88, -- run-up target stays this close to bowl center
		circleTime = 2, -- Light: seconds spent circling
		diveMax = 1.5, -- Light: longest dive before circling again
		circleRadius = 22, -- Light: circle distance around enemy
		circleAngleDeg = 40, -- Light: how far around enemy to aim each step
		stuckSeconds = 0.8, -- barely moving this long = nose-to-nose standoff, back up
	},
	Dummy = {
		launchUp = 70, -- upward speed of the crash dummy (studs/sec)
		launchSpread = 25, -- sideways speed random
		lifetime = 8, -- seconds before dummy is cleaned up
	},
	Remote = {
		maxPerWindow = 6, -- calls allowed per window per player
		windowSeconds = 2,
		steerMaxPerWindow = 60, -- Steer remote: calls allowed per window per player
		steerWindowSeconds = 1,
	},
}

return GameConfig
