--!strict
-- Numbers for the bowl power-ups. Placeholder values: change freely.

return {
	firstSpawnSeconds = 6, -- first pickup this long after the fight starts
	spawnEverySeconds = 8, -- then one this often
	maxOnFloor = 2,
	ringMin = 9, -- pickups land between these distances from the center (flat floor)
	ringMax = 32,
	minCarDistance = 14, -- never spawn closer than this to a car
	minPickupDistance = 10, -- or to another pickup
	pickupRadius = 5, -- a car this close (flat distance) collects it
	hoverHeight = 3.5, -- floating height above the floor
	kinds = { "shield", "bighit", "speed" },
	shield = { seconds = 6 }, -- absorbs the next hit or this long
	bighit = { seconds = 8, damageMult = 1.6 }, -- next hit within this time
	speed = { seconds = 5, speedMult = 1.35 },
	colors = {
		shield = { 70, 220, 110 },
		bighit = { 235, 60, 60 },
		speed = { 250, 215, 50 },
	},
	letters = { shield = "S", bighit = "B", speed = "F" },
}
