--!strict
-- Puts the lobby's sky and light (LobbySkyLook) on Lighting while walking in the lobby, and the
-- light that was there before back while driving, so the plots keep their own look.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbySkyLook = require(ReplicatedStorage.Shared.LobbySkyLook)

local LobbySky = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local saved: { [string]: any }? = nil
local hidden: { Instance } = {} -- the place's own sky/atmosphere/effects, parked while walking
local added: { Instance } = {}

local LOOK_CLASSES = { "Sky", "Atmosphere", "ColorCorrectionEffect", "BloomEffect" }

-- Walking in the lobby (true) or driving (false).
function LobbySky.set(lobby: boolean)
	if lobby and not saved then
		local s: { [string]: any } = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
		}
		for key, value in LobbySkyLook.lighting do
			s[key] = (Lighting :: any)[key];
			(Lighting :: any)[key] = value
		end
		saved = s
		Lighting.Ambient = rgb(LobbySkyLook.ambient)
		Lighting.OutdoorAmbient = rgb(LobbySkyLook.outdoorAmbient)
		for _, child in Lighting:GetChildren() do
			if table.find(LOOK_CLASSES, child.ClassName) then
				table.insert(hidden, child)
				child.Parent = nil
			end
		end

		local a = LobbySkyLook.atmosphere
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = a.Density
		atmosphere.Offset = a.Offset
		atmosphere.Glare = a.Glare
		atmosphere.Haze = a.Haze
		atmosphere.Color = rgb(a.color)
		atmosphere.Decay = rgb(a.decay)
		local sky = Instance.new("Sky") -- Roblox's own sky pictures; only the sun and stars change
		sky.SunAngularSize = LobbySkyLook.sky.SunAngularSize
		sky.MoonAngularSize = LobbySkyLook.sky.MoonAngularSize
		sky.StarCount = LobbySkyLook.sky.StarCount
		local cc = Instance.new("ColorCorrectionEffect")
		local c = LobbySkyLook.colorCorrection
		cc.Brightness = c.Brightness
		cc.Contrast = c.Contrast
		cc.Saturation = c.Saturation
		cc.TintColor = rgb(c.tint)
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = LobbySkyLook.bloom.Intensity
		bloom.Size = LobbySkyLook.bloom.Size
		bloom.Threshold = LobbySkyLook.bloom.Threshold
		for _, inst in { atmosphere, sky, cc, bloom } :: { Instance } do
			inst.Name = "Lobby" .. inst.ClassName
			inst.Parent = Lighting
			table.insert(added, inst)
		end
	elseif not lobby and saved then
		for key, value in saved do
			(Lighting :: any)[key] = value
		end
		saved = nil
		for _, inst in added do
			inst:Destroy()
		end
		added = {}
		for _, inst in hidden do
			inst.Parent = Lighting
		end
		hidden = {}
	end
end

return LobbySky
