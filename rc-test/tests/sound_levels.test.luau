--!strict
-- Sound balance: the start beeps lead a race, the music never covers a game sound.
local H = require("./harness")
local S = require("../src/shared/SoundLevels")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Sound levels")

test("the start beeps and GO are the loudest sound in a race", function()
	for name, v in S :: any do
		if
			type(v) == "number"
			and name ~= "START_BEEP"
			and name ~= "MUSIC_FADE"
			and name ~= "HUM_RANGE"
		then
			truthy(v < S.START_BEEP, `{name} {v} is as loud as the start beeps`)
		end
	end
end)

test("the music is under every game sound, and gone while driving", function()
	truthy(S.MUSIC < S.MOTOR_MAX and S.MUSIC < S.RESET_BEEP and S.MUSIC < S.NEW_CAR)
	eq(S.MUSIC_DRIVING, 0)
	truthy(S.MOTOR_MIN < S.MOTOR_MAX)
	truthy(S.SQUEAL_MAX + S.MOTOR_MAX < S.START_BEEP) -- full slide at top speed still under the beeps
end)

test("coin, level and finish cues sit under the start beeps", function()
	truthy(S.COIN > 0 and S.LEVEL_UP > 0 and S.FINISH > 0)
	truthy(S.COIN < S.LEVEL_UP) -- a stream of coins stays quieter than a level
end)

test("crate, trophy and training cues sit under the start beeps; training is quietest", function()
	truthy(S.CRATE > 0 and S.TROPHY > 0 and S.TRAIN > 0)
	truthy(S.TRAIN < S.COIN) -- it repeats all day
end)

test("the station hum is quiet, full at the plot and gone past its range", function()
	truthy(S.HUM < S.COIN)
	eq(S.humAt(0), S.HUM)
	eq(S.humAt(S.HUM_RANGE), 0)
	eq(S.humAt(S.HUM_RANGE * 3), 0)
	truthy(S.humAt(S.HUM_RANGE / 2) < S.HUM)
end)
