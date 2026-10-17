--!strict
-- Look of the whole game: bright cartoon lighting (even sky-blue ambient, soft warm sun, soft shadows,
-- no haze), punchy colours, and a tiny bloom that only catches the neon signs.
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
	-- The place file ships default Bloom, SunRays, Atmosphere and DepthOfField (Bloom at full
	-- strength washes the whole lobby out). Ours are the "Game*" ones, so drop the others.
	for _, c in Lighting:GetChildren() do
		if
			(
				c:IsA("BloomEffect")
				or c:IsA("SunRaysEffect")
				or c:IsA("Atmosphere")
				or c:IsA("DepthOfFieldEffect")
			) and string.sub(c.Name, 1, 4) ~= "Game"
		then
			c:Destroy()
		end
	end
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(150, 160, 185)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 188)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
	Lighting.ColorShift_Bottom = Color3.fromRGB(150, 190, 255)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.1
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6

	local haze: Atmosphere = effect("Atmosphere", "GameAtmosphere")
	haze.Density = 0
	haze.Offset = 0.15
	haze.Color = Color3.fromRGB(215, 214, 205)
	haze.Decay = Color3.fromRGB(140, 130, 115)
	haze.Glare = 0
	haze.Haze = 0

	local bloom: BloomEffect = effect("BloomEffect", "GameBloom")
	bloom.Intensity = 0.12
	bloom.Size = 14
	bloom.Threshold = 2.2

	local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect", "GameGrade")
	grade.Saturation = 0.28
	grade.Contrast = 0.14
	grade.Brightness = 0.01
	grade.TintColor = Color3.fromRGB(255, 249, 238)

	local rays: SunRaysEffect = effect("SunRaysEffect", "GameSunRays")
	rays.Intensity = 0
	rays.Spread = 0.6
end

return Atmosphere
