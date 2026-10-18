--!strict
-- Numbers for the bowl fun-stuff: smash hits, wall boost pads, drift
-- charge and the new power-ups. Placeholder values: change freely.

return {
	Smash = {
		from = 0.6, -- hits at least this strong (0..1) are a SMASH
		upSpeed = 18, -- the car that got hit pops up this fast (x strength, studs/s)
		spin = 9, -- and spins this fast (x strength, rad/s)
		text = "SMASH!",
	},
	Pads = {
		count = 4, -- boost pads on the bowl wall
		radiusShare = 0.72, -- how far up the slope (0 = the flat edge, 1 = the rim)
		triggerRadius = 5.5, -- a car this close to a pad (flat distance) gets launched
		kick = 62, -- speed toward the middle (studs/s)
		lift = 0, -- speed upward (studs/s): 0 = no hop, just a speed burst along the ground
		cooldown = 2.5, -- seconds before the same car can use a pad again
		size = { 9, 0.4, 11 }, -- x, y, z studs
		-- Look only (the blue BOOST sign standing behind each pad):
		panelSize = { 9.5, 3.8 }, -- sign width, height (studs)
		panelBack = 6.5, -- how far up the slope behind the pad the sign stands (flat studs)
		panelLeanDeg = 50, -- how far the sign leans back from upright
		pulseSeconds = 1.2, -- one glow pulse
	},
	Drift = {
		refundPerSecond = 1.4, -- sliding gives back this many seconds of boost cooldown per second
	},
	Magnet = { seconds = 4, pull = 26, range = 48 }, -- pulls the enemy toward you (studs/s per second)
	Rocket = { seconds = 1, speed = 105 }, -- an instant dash straight at the enemy
}
