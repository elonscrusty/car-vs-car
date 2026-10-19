--!strict
local H = require("./harness")
local SoundConfig = require("../src/shared/SoundConfig")
local Sounds = require("../src/shared/Sounds")

print("Sounds")

local required = {
	"hitSoft",
	"hitHard",
	"boost",
	"ability",
	"win",
	"lose",
	"click",
	"claw",
	"coin",
	"ballKick",
	"goal",
	"countdownTick",
	"countdownGo",
	"music_lobby",
	"music_arena",
}

H.test("every event exists, ships with an empty id, sane numbers", function()
	for _, name in required do
		local e = SoundConfig.Events[name]
		H.truthy(e ~= nil, name)
		H.eq(e.id, "", name) -- no invented ids
		H.truthy(e.volume >= 0 and e.volume <= SoundConfig.MaxVolume, name)
		H.truthy(e.pitchVariance >= 0 and e.pitchVariance < 1, name)
	end
	H.eq(SoundConfig.Events.music_lobby.looped, true)
	H.eq(SoundConfig.Events.music_arena.looped, true)
end)

H.test("empty id or unknown event resolves to nil", function()
	H.eq(Sounds.resolve("win"), nil)
	H.eq(Sounds.resolve("nope"), nil)
end)

H.test("filled id resolves with pitch variance and clamped volume", function()
	local ev: { [string]: SoundConfig.Entry } = {
		a = { id = "rbxassetid://1", volume = 5, pitchVariance = 0.2 },
		m = { id = "rbxassetid://2", volume = 0.3, pitchVariance = 0, looped = true, music = true },
	}
	local mid = Sounds.resolve("a", 0.5, ev) :: Sounds.Spec
	H.eq(mid.pitch, 1)
	H.eq(mid.volume, SoundConfig.MaxVolume)
	H.near((Sounds.resolve("a", 0, ev) :: Sounds.Spec).pitch, 0.8, 1e-9)
	H.near((Sounds.resolve("a", 1, ev) :: Sounds.Spec).pitch, 1.2, 1e-9)
	local m = Sounds.resolve("m", nil, ev) :: Sounds.Spec
	H.eq(m.looped, true)
	H.eq(m.music, true)
	H.eq(m.pitch, 1)
end)

H.test("hit strength picks soft or hard", function()
	H.eq(Sounds.hitEvent(0), "hitSoft")
	H.eq(Sounds.hitEvent(nil), "hitSoft")
	H.eq(Sounds.hitEvent(SoundConfig.HitHardAt - 0.01), "hitSoft")
	H.eq(Sounds.hitEvent(SoundConfig.HitHardAt), "hitHard")
	H.eq(Sounds.hitEvent(1), "hitHard")
	H.eq(Sounds.hitEvent(0 / 0), "hitSoft")
end)

H.test("volume clamp", function()
	H.eq(Sounds.clampVolume(-1), 0)
	H.eq(Sounds.clampVolume(0 / 0), 0)
	H.eq(Sounds.clampVolume(99), SoundConfig.MaxVolume)
	H.eq(Sounds.clampVolume(0.4), 0.4)
end)

H.test("countdown banner text picks tick or go", function()
	H.eq(Sounds.countdownEvent("3"), "countdownTick")
	H.eq(Sounds.countdownEvent("1"), "countdownTick")
	H.eq(Sounds.countdownEvent("GO!"), "countdownGo")
	H.eq(Sounds.countdownEvent("0"), nil)
	H.eq(Sounds.countdownEvent("10"), nil)
	H.eq(Sounds.countdownEvent("3.0"), nil)
	H.eq(Sounds.countdownEvent("YOU 1 - 0 THEM"), nil)
	H.eq(Sounds.countdownEvent(""), nil)
end)
