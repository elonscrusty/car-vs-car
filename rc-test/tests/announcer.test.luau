--!strict
-- The announcer: rare shouts, one stinger each, never a pile-up.
local H = require("./harness")
local Announcer = require("../src/shared/Announcer")
local SoundCues = require("../src/shared/SoundCues")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Announcer")

test("announcer: FIRST SMASH! once per round, for anyone's smash", function()
	local a = Announcer.new()
	local s = a:shout(10, false, nil, 0)
	eq(s and s.text, "FIRST SMASH!")
	eq(s and s.sound, true)
	eq(a:shout(11, false, nil, 0), nil)
	eq(a:shout(30, true, nil, 1), nil)
	-- a quiet minute = a new round
	local s2 = a:shout(200, false, nil, 0)
	eq(s2 and s2.text, "FIRST SMASH!")
end)

test("announcer: your first smash keeps its Double Smash word, loud", function()
	local a = Announcer.new()
	local s = a:shout(10, true, "DOUBLE SMASH!", 2)
	eq(s and s.text, "DOUBLE SMASH!")
	eq(s and s.sound, true)
end)

test("announcer: SMASH STREAK words stay silent", function()
	local a = Announcer.new()
	a:shout(0, true, nil, 1)
	local s = a:shout(20, true, "SMASH STREAK x3!", 3)
	eq(s and s.text, "SMASH STREAK x3!")
	eq(s and s.sound, false)
end)

test("announcer: UNSTOPPABLE! on the 5th in a row, then back to quiet", function()
	local a = Announcer.new()
	a:shout(0, true, nil, 1)
	local s = a:shout(30, true, "SMASH STREAK x5!", 5)
	eq(s and s.text, "UNSTOPPABLE!")
	eq(s and s.sound, true)
	local s6 = a:shout(40, true, "SMASH STREAK x6!", 6)
	eq(s6 and s6.text, "SMASH STREAK x6!")
	eq(s6 and s6.sound, false)
end)

test("announcer: announcer-only words keep MIN_GAP apart", function()
	local a = Announcer.new()
	eq((a:shout(0, false, nil, 0) :: any).text, "FIRST SMASH!")
	-- a new round starts, but only 3 s after the last shout: FIRST SMASH! is held back
	local b = Announcer.new()
	b:shout(0, true, nil, 1)
	local s = b:shout(2, true, "SMASH STREAK x5!", 5) -- UNSTOPPABLE! too soon after FIRST
	eq(s and s.text, "SMASH STREAK x5!")
	eq(s and s.sound, false)
end)

test("announcer: the stinger is a checked sound, never an invented id", function()
	local c = SoundCues.get("announce")
	truthy(c ~= nil)
	local id = (c :: any).id
	truthy(SoundCues.CHECKED[id] ~= nil, "announce uses an unchecked id")
end)
