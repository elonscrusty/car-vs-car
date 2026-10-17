--!strict
-- Look of the whole game: lighting, a little haze, bloom for the neon, and gentle colour grading.
-- Built once at start. Cheap on purpose (no depth of field, no shadows from small stuff) so it
-- runs fine on phones. Existing effects of the same kind are reused, not doubled.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

local function effect<T>(className: string, name: string): T
	local old = Lighting:FindFirstChild(name)
	if old and old.ClassName == className then
		return old :: any
	end
	if old then
		old:Destroy()
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e :: any
end

function Atmosphere.apply()
	Lighting.ClockTime = 15
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(78, 84, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 126, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	local haze: Atmosphere = effect("Atmosphere", "GameAtmosphere")
	haze.Density = 0.22
	haze.Offset = 0.15
	haze.Color = Color3.fromRGB(190, 205, 230)
	haze.Decay = Color3.fromRGB(110, 120, 150)
	haze.Glare = 0
	haze.Haze = 0.8

	local bloom: BloomEffect = effect("BloomEffect", "GameBloom")
	bloom.Intensity = 0.12
	bloom.Size = 12
	bloom.Threshold = 1.4

	local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect", "GameGrade")
	grade.Saturation = 0.14
	grade.Contrast = 0.1
	grade.Brightness = 0.02
	grade.TintColor = Color3.fromRGB(255, 249, 242)

	local rays: SunRaysEffect = effect("SunRaysEffect", "GameSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

return Atmosphere
