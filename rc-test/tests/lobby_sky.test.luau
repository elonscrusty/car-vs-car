--!strict
-- Lobby sky and light (LobbySkyLook.luau): a sunny day with a gentle far haze.
local H = require("./harness")
local S = require("../src/shared/LobbySkyLook")

local test, truthy = H.test, H.truthy

local function eq3(c: { number })
	H.eq(#c, 3, "rgb")
	for _, v in c do
		truthy(v >= 0 and v <= 255, "0-255")
	end
end

print("Lobby sky")

test("daytime sun, soft shadows", function()
	truthy(S.lighting.ClockTime >= 10 and S.lighting.ClockTime <= 15, "midday-ish")
	truthy(S.lighting.ShadowSoftness > 0.2 and S.lighting.ShadowSoftness < 0.8, "soft, not blurry")
	truthy(S.lighting.Brightness >= 1.5 and S.lighting.Brightness <= 4, "bright, not blown out")
end)

test("haze is gentle so the lobby stays clear", function()
	truthy(S.atmosphere.Density > 0.1 and S.atmosphere.Density < 0.4, "some far haze, not fog")
	for _, c in { S.atmosphere.color, S.atmosphere.decay, S.ambient, S.outdoorAmbient } do
		eq3(c)
	end
	truthy(S.atmosphere.color[3] > S.atmosphere.color[1], "light blue, not grey or orange")
end)
