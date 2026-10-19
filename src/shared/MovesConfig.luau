--!strict
-- Numbers for the fight moves (boost, jump, drift). Placeholders: change freely.

return {
	Names = { "boost", "jump", "special" },
	Boost = {
		duration = 1.4, -- seconds of boost
		fade = 0.3, -- last seconds of the boost: bonus fades out smoothly
		speedBonus = 0.6, -- +60% top speed
		accelBonus = 1.5, -- +150% push while boosting
		kick = 26, -- instant forward speed added when the boost starts (studs/s)
		cooldown = 4, -- seconds after the press until the next boost
	},
	Jump = {
		speed = 50, -- upward speed of the hop (studs/s)
		cooldown = 2,
	},
	Drift = {
		fullSteer = 0.95, -- steer input at least this counts as "full steer"
		startSeconds = 0.7, -- full steer held this long starts the slide
		minSpeed = 35, -- flat speed needed (studs/s)
		lingerSeconds = 0.35, -- slide lasts this long after the steer is released
		gripFactor = 0.5, -- side grip while sliding (1 = normal)
		turnBonus = 1.2, -- turn rate multiplier while sliding
	},
	Remote = {
		maxPerWindow = 8,
		windowSeconds = 2,
	},
}
