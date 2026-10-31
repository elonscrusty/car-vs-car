--!strict
-- How loud every sound in the game is (Sound.Volume), in one place so none drowns the others.
-- The race start beeps (and GO) are the loudest thing in a race; the lobby music is the
-- quietest and fades out while you drive. tests/sound_levels.test.luau keeps that order.

local SoundLevels = {
	START_BEEP = 0.9, -- the 3-2-1 lamps and GO (one sound, pitched up for GO)
	NEW_CAR = 0.6, -- the two-note ping when a new car is yours
	COIN = 0.3, -- a coin lands in the coins number (pitch climbs per coin)
	LEVEL_UP = 0.5, -- plot level bought
	BUY = 0.45, -- coins spent (crate, car, upgrade)
	UNLOCK = 0.55, -- a new training station opens
	FINISH = 0.5, -- your car crosses the line
	CRATE = 0.5, -- a crate opens
	TROPHY = 0.55, -- a podium trophy
	TRAIN = 0.15, -- a station tick (quiet: it repeats)
	DING = 0.35, -- a bar went up, or hit MAX
	COUNT = 0.8, -- the 3-2-1-GO cues (under the start beeps)
	SPARK = 0.1, -- a wall scrape tick
	SPARK_GAP = 0.15, -- seconds between scrape ticks
	FIREWORKS = 0.5, -- league up
	-- Smash arena (positional ones fade with distance; your own are full)
	PICKUP = 0.4, -- you grabbed a "?" box
	ROCKET = 0.5, -- a rocket launches
	BOOM = 0.5, -- a rocket or mine goes off
	GUN = 0.25, -- one machine-gun shot (bursts repeat it)
	GUN_GAP = 0.09, -- seconds between gun shot sounds (a real shot file: fewer overlaps, no mud)
	MINE = 0.4, -- a mine is dropped
	HIT = 0.45, -- a kart took damage
	HIT_GAP = 0.08, -- seconds between hit sounds
	BUMP = 0.4, -- two karts bump (bumps hurt too, carter 10-28)
	FREEZE = 0.45, -- freeze shot, a kart freezing, the ice shattering
	FLAME = 0.5, -- the Flame Nozzle's burst: one smooth roar, no ticking (carter 10-30)
	SMASH = 0.55, -- a kart got smashed (the crash)
	SMASH_BOOM = 0.7, -- the deep boom under it (carter picked "1 Big Boom", 10-29)
	SMASH_METAL = 0.55, -- the metal crunch
	SMASH_CROWD = 0.45, -- the crowd "oooh"
	SMASH_POP = 0.4, -- the small second pop (with the fire's second pop at 0.42 s)
	ANNOUNCE = 0.5, -- the announcer's stinger on a big word (rare)
	RESPAWN = 0.4, -- you are back in
	SHIELD = 0.35, -- the shield goes up
	MATCH = 0.8, -- match start (3-2-1-GO) and the end horn
	RESET_BEEP = 0.45, -- back at the start (fell off, stuck, R)
	SQUEAL_MAX = 0.4, -- tyres at a full slide
	MOTOR_MIN = 0.12, -- the motor at a stop
	MOTOR_MAX = 0.4, -- the motor at top speed
	TAP = 0.2, -- the tick on every button
	MUSIC = 0.15, -- lobby speakers (near them only), on foot
	MUSIC_DRIVING = 0, -- faded out while driving or racing
	HUM = 0.07, -- a training station hum, right at your plot
	HUM_RANGE = 60, -- studs from your plot where the hum is gone
	MUSIC_FADE = 1, -- seconds to fade out or back in
}

-- the station hum's volume at `dist` studs from your plot: full at the plot, gone at HUM_RANGE
function SoundLevels.humAt(dist: number): number
	return SoundLevels.HUM * math.clamp(1 - dist / SoundLevels.HUM_RANGE, 0, 1)
end

return SoundLevels
