--!strict
-- Look of the whole game: bright, saturated, soft cartoon lighting (toy cars, not a realistic
-- garage), a light haze, a soft glow for the neon and punchy colour grading. Built once at start. Cheap on purpose (no depth of field, no shadows from small stuff) so it
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
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(128, 130, 148) -- strong fill: shadows stay light and colourful
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 168, 190)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.1 -- almost no mirror shine: reads as plastic toys
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.85 -- soft, cartoon-like shadow edges

	local haze: Atmosphere = effect("Atmosphere", "GameAtmosphere")
	haze.Density = 0.12
	haze.Offset = 0.1
	haze.Color = Color3.fromRGB(205, 228, 255)
	haze.Decay = Color3.fromRGB(150, 190, 245)
	haze.Glare = 0
	haze.Haze = 0.4

	local bloom: BloomEffect = effect("BloomEffect", "GameBloom")
	bloom.Intensity = 0.3 -- a soft glow round the lamps and neon only (it burned bright plastic out)
	bloom.Size = 20
	bloom.Threshold = 1.5

	local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect", "GameGrade")
	grade.Saturation = 0.28
	grade.Contrast = 0.08
	grade.Brightness = 0.03
	grade.TintColor = Color3.fromRGB(255, 250, 240)

	local rays: SunRaysEffect = effect("SunRaysEffect", "GameSunRays")
	rays.Intensity = 0.03
	rays.Spread = 0.6
end

-- Night with big bright stadium lights for the fight (counted, so two fights at once do not fight
-- over the light; the day look comes back when the last fight ends).
local nightCount = 0

function Atmosphere.night()
	nightCount += 1
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(92, 100, 150) -- bright enough to read the arena at night
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 120, 175)
	Lighting.ColorShift_Top = Color3.fromRGB(190, 210, 255)
	-- Stadium lamps glow: more bloom, a deep blue haze, richer colour.
	local bloom = Lighting:FindFirstChild("GameBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.5
		bloom.Threshold = 1.2
		bloom.Size = 24
	end
	local haze = Lighting:FindFirstChild("GameAtmosphere")
	if haze and haze:IsA("Atmosphere") then
		haze.Density = 0.22
		haze.Color = Color3.fromRGB(95, 115, 190)
		haze.Decay = Color3.fromRGB(60, 70, 140)
	end
	local grade = Lighting:FindFirstChild("GameGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		grade.Saturation = 0.32
		grade.Contrast = 0.1
		grade.TintColor = Color3.fromRGB(240, 244, 255)
	end
end

function Atmosphere.day()
	nightCount = math.max(0, nightCount - 1)
	if nightCount == 0 then
		Atmosphere.apply()
	end
end

return Atmosphere
