--!strict
-- The lobby's sky and light (carter's picture): a bright sunny day, soft shadows, a light blue
-- sky and a gentle haze far out over the water. Plain numbers (Lune tests load this);
-- client/LobbySky.luau puts it on Lighting while you walk in the lobby and puts the old light
-- back when you drive, all but the brightness and ambient (raceKeeps).

export type RGB = { number }

local LobbySkyLook = {}

LobbySkyLook.lighting = {
	ClockTime = 13.5, -- early afternoon: sun high, short soft shadows
	GeographicLatitude = 30,
	Brightness = 2.6,
	ExposureCompensation = 0.1,
	ShadowSoftness = 0.45,
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.3,
}
LobbySkyLook.ambient = { 120, 125, 140 } -- shade under trees and roofs: cool, not black
LobbySkyLook.outdoorAmbient = { 150, 155, 170 }
-- what stays on while driving a race (the race map keeps its own sky, haze and time of day)
LobbySkyLook.raceKeeps = { "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient" }

-- haze that thickens with distance: the lobby stays crisp, the far lake fades into light blue
LobbySkyLook.atmosphere = {
	Density = 0.28,
	Offset = 0.15,
	Glare = 0,
	Haze = 1.2,
	color = { 205, 228, 255 },
	decay = { 150, 195, 235 },
}

LobbySkyLook.sky = { SunAngularSize = 14, MoonAngularSize = 8, StarCount = 0 }

-- a touch brighter and more colourful, a soft glow on the brightest bits
LobbySkyLook.colorCorrection =
	{ Brightness = 0.02, Contrast = 0.06, Saturation = 0.12, tint = { 255, 252, 246 } }
LobbySkyLook.bloom = { Intensity = 0.25, Size = 24, Threshold = 1.6 }

return LobbySkyLook
