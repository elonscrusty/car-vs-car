--!strict
-- Game-wide numbers. Change these to change how the duel FEELS.
-- Pure data only (no Roblox calls) so unit tests can load it.

local GameConfig = {
	-- Bowl arena. Bigger tiltDeg = steeper bowl = cars roll back to the middle faster.
	Arena = {
		flatRadius = 25, -- flat middle disc (studs from center)
		rimRadius = 62, -- where the slope ends (~124 studs across)
		tiltDeg = 20, -- slope angle of the bowl
		wallHeight = 7, -- low bumper walls on the rim
		segments = 32, -- slabs around the bowl (more = rounder)
		baseY = 300, -- height of arena in the world (far above the baseplate)
		slotSpacing = 600, -- each player gets own arena this far apart on X
		spawnRadius = 50, -- launch spots, studs from center
	},
	Match = {
		hearts = 3,
		aimTimeout = 20, -- seconds before the server auto launches for you
		roundEndDelay = 3.5, -- seconds to watch the dummy fly
		aimMaxDeg = 40, -- aim left/right limit
		outOfBoundsDrop = 40, -- car this far below the arena = counts as dead
	},
	Launch = {
		minSpeed = 60, -- studs/sec at 0% power
		maxSpeed = 140, -- studs/sec at 100% power
		powerPeriod = 1.2, -- seconds for power bar to go up and down once
		aimDegPerSec = 60, -- how fast A/D turns the arrow
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
	Drive = {
		turnGain = 6, -- how hard the car steers toward target
		groundFriction = 0.05, -- floor + car friction. Lower = slides more, keeps speed
		grip = 6, -- side slide killing (higher = less drifting)
		groundRayExtra = 2.5, -- studs below car that still count as "on ground"
	},
	-- Bot / auto-pilot behavior numbers
	Ai = {
		chargeMax = 3, -- Heavy: longest straight charge before backing up
		retreatTime = 1.6, -- after a hit: seconds driving away for a run-up
		retreatDist = 35, -- how far away it aims during the run-up
		maxRadius = 45, -- run-up target stays this close to bowl center
		circleTime = 2, -- Light: seconds spent circling
		diveMax = 1.5, -- Light: longest dive before circling again
		circleRadius = 22, -- Light: circle distance around enemy
		circleAngleDeg = 40, -- Light: how far around enemy to aim each step
		stuckSeconds = 0.8, -- barely moving this long = nose-to-nose standoff, back up
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
	Boost = {
		duration = 0.8, -- seconds of extra speed
		cooldown = 5, -- seconds until the next boost (counts from the start)
		speedMult = 1.6, -- top speed x this while boosting
		accelMult = 3, -- acceleration x this while boosting
		botMinDist = 18, -- bot only boosts when the enemy is this far or more
		botMaxDist = 60, -- ...and not farther than this
	},
	Dummy = {
		launchUp = 70, -- upward speed of the crash dummy (studs/sec)
		launchSpread = 25, -- sideways speed random
		lifetime = 8, -- seconds before dummy is cleaned up
	},
	Remote = {
		maxPerWindow = 6, -- calls allowed per window per player
		windowSeconds = 2,
	},
}

return GameConfig
