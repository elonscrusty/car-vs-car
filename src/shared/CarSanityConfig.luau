--!strict
-- Numbers for the server's check on player-driven cars (CarSanity). All PLACEHOLDERS: tune after a
-- playtest with real lag. Too tight = honest players get reset; too loose = cheats slip through.
return {
	maxStepSeconds = 0.25, -- longer frames (lag spikes) are measured as this long, so one hitch is not a "teleport"
	teleportSlack = 2.5, -- a step may move this x (speed cap x step time) before it counts as a teleport
	teleportFloor = 4, -- ...plus this many studs, for collisions and respawn nudges
	speedSlack = 1.6, -- measured speed (distance / time) may be this x the speed cap...
	graceSeconds = 0.6, -- ...or too high / too fast for this long in total before a reset
	decayRate = 0.5, -- bad time cools off at this x real time while the car behaves
	maxHeightAboveArena = 70, -- studs above the arena origin (rim is about 33 up; Match.outOfBoundsHeight is the hard stop)
	maxResets = 3, -- this many resets in one match = forfeit
}
