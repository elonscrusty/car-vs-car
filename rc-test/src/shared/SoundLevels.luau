--!strict
-- How loud every sound in the game is (Sound.Volume), in one place so none drowns the others.
-- The race start beeps (and GO) are the loudest thing in a race; the lobby music is the
-- quietest and fades out while you drive. tests/sound_levels.test.luau keeps that order.

local SoundLevels = {
	START_BEEP = 0.9, -- the 3-2-1 lamps and GO (one sound, pitched up for GO)
	NEW_CAR = 0.6, -- the two-note ping when a new car is yours
	COIN = 0.3, -- a coin lands in the coins number (pitch climbs per coin)
	LEVEL_UP = 0.5, -- plot level bought
	FINISH = 0.5, -- your car crosses the line
	CRATE = 0.5, -- a crate opens
	TROPHY = 0.55, -- a podium trophy
	TRAIN = 0.15, -- a station tick (quiet: it repeats)
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
