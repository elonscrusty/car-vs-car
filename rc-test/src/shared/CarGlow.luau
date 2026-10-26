--!strict
-- The glow that shows a car's kind (carter's tycoon plan, 10-26): common none, rare a blue light,
-- epic a purple light with sparkles, legend a gold light with sparkles that pulses. For cars on
-- show (shops, plot stands, plot loop cars), never the car you drive. The pulse runs on each
-- screen (GlowPulse.client, tag "CarGlowPulse"), so the server sends nothing per frame.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")

local CarGlow = {}

export type Look = { brightness: number, range: number, sparkles: boolean, pulse: boolean }
CarGlow.LOOKS = {
	common = nil,
	rare = { brightness = 2, range = 9, sparkles = false, pulse = false },
	epic = { brightness = 3, range = 11, sparkles = true, pulse = false },
	legend = { brightness = 4, range = 13, sparkles = true, pulse = true },
} :: { [string]: Look }
CarGlow.PULSE_TAG = "CarGlowPulse"

-- How a kind glows (nil = no glow). Unknown kinds don't glow.
function CarGlow.look(rarity: string?): Look?
	return if rarity then CarGlow.LOOKS[rarity] else nil
end

local function host(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (best == nil or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	return best
end

-- Puts the glow for `rarity` on `model` (a car Model, or a part like a stand plate). Calling it
-- again swaps the old glow out, so a common car ends with none.
function CarGlow.apply(model: Instance, rarity: string?)
	local part = host(model)
	if not part then
		return
	end
	for _, old in part:GetChildren() do
		if old.Name == "CarGlow" then
			old:Destroy()
		end
	end
	local look = CarGlow.look(rarity)
	if not look or not rarity then
		return
	end
	local c = CarCatalog.RARITY[rarity].color
	local color = Color3.fromRGB(c[1], c[2], c[3])
	local light = Instance.new("PointLight")
	light.Name = "CarGlow"
	light.Color = color
	light.Brightness = look.brightness
	light.Range = look.range
	light.Shadows = false
	light:SetAttribute("Base", look.brightness)
	light.Parent = part
	if look.sparkles then
		local s = Instance.new("Sparkles")
		s.Name = "CarGlow"
		s.SparkleColor = color
		s.Parent = part
	end
	if look.pulse then
		game:GetService("CollectionService"):AddTag(light, CarGlow.PULSE_TAG)
	end
end

-- The glow for a car by its id.
function CarGlow.applyCar(model: Instance, carId: any)
	CarGlow.apply(model, CarCatalog.rarity(carId).id)
end

return CarGlow
