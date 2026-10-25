--!strict
-- Sound balance: the start beeps lead a race, the music never covers a game sound.
local H = require("./harness")
local S = require("../src/shared/SoundLevels")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Sound levels")

test("the start beeps and GO are the loudest sound in a race", function()
	for name, v in S :: any do
		if name ~= "START_BEEP" and name ~= "MUSIC_FADE" then
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
