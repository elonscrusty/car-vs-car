--!strict
-- The game's one light and sky (WorldLook.luau, LOOK-BIBLE rule 8): warm sun ~40 degrees up, soft
-- shadows, light bloom, a saturation boost, no grey haze.
local H = require("./harness")
local S = require("../src/shared/WorldLook")

local test, truthy = H.test, H.truthy

local function eq3(c: { number })
	H.eq(#c, 3, "rgb")
	for _, v in c do
		truthy(v >= 0 and v <= 255, "0-255")
	end
end

print("World look (one light for the whole game)")

test("a warm sun about 40 degrees up, soft shadows, bright not blown out", function()
	local up = (18 - S.lighting.ClockTime) * 15 -- afternoon sun on the equator
	truthy(
		S.lighting.GeographicLatitude == 0 and up >= 32 and up <= 48,
		"sun ~40 degrees up: " .. up
	)
	truthy(
		S.lighting.ShadowSoftness >= 0.15 and S.lighting.ShadowSoftness <= 0.4,
		"soft edges, but shadows still clear"
	)
	truthy(S.lighting.Brightness >= 1.5 and S.lighting.Brightness <= 4, "bright, not blown out")
	truthy(S.colorCorrection.tint[1] >= S.colorCorrection.tint[3], "warm, not cold")
end)

test("shadows stay visible: the shade fill is well under the sun", function()
	truthy(S.lighting.GlobalShadows == true, "shadows on")
	truthy(S.lighting.EnvironmentDiffuseScale <= 0.3, "sky fill low enough not to wash shadows out")
	for _, c in { S.ambient, S.outdoorAmbient } do
		truthy(math.max(c[1], c[2], c[3]) <= 150, "shade not too bright")
		truthy(math.min(c[1], c[2], c[3]) >= 60, "shade never black")
	end
end)

test("no grey haze; light bloom; a little more colour", function()
	truthy(S.atmosphere.Haze <= 0.3 and S.atmosphere.Density < 0.3, "clear air, not fog")
	truthy(S.bloom.Intensity > 0 and S.bloom.Intensity <= 0.5, "a light bloom")
	truthy(
		S.colorCorrection.Saturation > 0 and S.colorCorrection.Saturation <= 0.3,
		"a saturation boost"
	)
	for _, c in
		{ S.atmosphere.color, S.atmosphere.decay, S.ambient, S.outdoorAmbient, S.clouds.color }
	do
		eq3(c)
	end
	truthy(S.atmosphere.color[3] > S.atmosphere.color[1], "light blue, not grey or orange")
	truthy(S.atmosphere.color[1] <= 170, "a real blue horizon, not pale white")
end)

test("phones keep the shadows: the place asks for light quality first", function()
	local fs = require("@lune/fs")
	local serde = require("@lune/serde")
	local proj = serde.decode("json", fs.readFile("default.project.json"))
	local light = proj.tree.Lighting["$properties"]
	truthy(light.LightingStyle == "Realistic", "realistic light and shadows")
	-- when a phone drops its graphics level, keep shadows near the camera, give up view distance
	truthy(light.PrioritizeLightingQuality == true, "shadows kept on low graphics")
end)
