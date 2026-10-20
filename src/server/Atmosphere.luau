--!strict
-- Look of the whole game: a low-poly junkyard at sunset (carter, 2026-10-20): a low orange sun, a
-- purple haze toward the far city, warm light on the props, a soft glow for the neon. Built once at start. Cheap on purpose (no depth of field, no shadows from small stuff) so it
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
	Lighting.ClockTime = 17.8 -- the sun just over the city: the whole sky turns orange and purple
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(122, 104, 128) -- warm purple fill: shadows stay readable
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 134, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 176, 110)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.1
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6

	local haze: Atmosphere = effect("Atmosphere", "GameAtmosphere")
	haze.Density = 0.32 -- thick enough to tint the sky everywhere, not only near the sun
	haze.Offset = 0.1
	haze.Color = Color3.fromRGB(255, 160, 120) -- orange near the sun
	haze.Decay = Color3.fromRGB(110, 72, 140) -- purple away from it
	haze.Glare = 0.6
	haze.Haze = 2.2

	local bloom: BloomEffect = effect("BloomEffect", "GameBloom")
	bloom.Intensity = 0.3 -- a soft glow round the lamps and neon only (it burned bright plastic out)
	bloom.Size = 20
	bloom.Threshold = 1.5

	local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect", "GameGrade")
	grade.Saturation = 0.12
	grade.Contrast = 0.1
	grade.Brightness = 0.02
	grade.TintColor = Color3.fromRGB(255, 238, 222)

	local rays: SunRaysEffect = effect("SunRaysEffect", "GameSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

-- The fight: the same sunset a little later, the sun just under the city and the lamps on
-- (counted, so two fights at once do not fight over the light; the lobby look comes back when the
-- last fight ends).
local nightCount = 0

function Atmosphere.night()
	nightCount += 1
	Lighting.ClockTime = 17.95
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(128, 106, 140) -- bright enough to read the floor and cars
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 136, 160)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 160, 120)
	local bloom = Lighting:FindFirstChild("GameBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.45
		bloom.Threshold = 1.2
		bloom.Size = 24
	end
	local haze = Lighting:FindFirstChild("GameAtmosphere")
	if haze and haze:IsA("Atmosphere") then
		haze.Density = 0.32
		haze.Color = Color3.fromRGB(240, 140, 120)
		haze.Decay = Color3.fromRGB(96, 64, 140)
	end
	local grade = Lighting:FindFirstChild("GameGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		grade.Saturation = 0.16
		grade.Contrast = 0.12
		grade.TintColor = Color3.fromRGB(255, 232, 226)
	end
end

function Atmosphere.day()
	nightCount = math.max(0, nightCount - 1)
	if nightCount == 0 then
		Atmosphere.apply()
	end
end

return Atmosphere
