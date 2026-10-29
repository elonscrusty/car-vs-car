--!strict
-- The ONE light and sky for the whole game (LOOK-BIBLE.md rule 8, ARENA owns it): a warm sun
-- about 40 degrees up, soft shadows, a light bloom, a small saturation boost, a clean bright blue
-- sky with soft white clouds, and no haze that greys the colours out. Plain numbers (Lune tests
-- load this); client/LobbySky.luau puts it on Lighting once and keeps it on everywhere. Retune
-- here, not in a place's own Lighting.

export type RGB = { number }

local WorldLook = {}

WorldLook.lighting = {
	-- on the equator the sun is (18 - ClockTime) x 15 degrees up in the afternoon: 15.3 is ~40
	ClockTime = 15.3,
	GeographicLatitude = 0,
	Brightness = 3,
	ExposureCompensation = 0,
	ShadowSoftness = 0.5,
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.2,
	GlobalShadows = true,
}
WorldLook.ambient = { 112, 112, 128 } -- shade stays a soft cool blue-grey, never black
WorldLook.outdoorAmbient = { 142, 140, 156 }

-- a thin, clear atmosphere: a little depth far away, no grey haze. Its colour is a real sky blue,
-- so the horizon stays blue instead of fading to a pale white (Studio shots, 10-29)
WorldLook.atmosphere = {
	Density = 0.1,
	Offset = 0,
	Glare = 0,
	Haze = 0,
	color = { 150, 205, 255 },
	decay = { 90, 160, 235 },
}

WorldLook.sky = { SunAngularSize = 12, MoonAngularSize = 8, StarCount = 0 }
-- soft white clouds (Terrain clouds)
WorldLook.clouds = { Cover = 0.45, Density = 0.55, color = { 255, 255, 255 } }

-- warm, a touch more colour and contrast, a light glow on the brightest bits
WorldLook.colorCorrection =
	{ Brightness = 0.03, Contrast = 0.08, Saturation = 0.18, tint = { 255, 248, 236 } }
WorldLook.bloom = { Intensity = 0.35, Size = 24, Threshold = 1.7 }

return WorldLook
