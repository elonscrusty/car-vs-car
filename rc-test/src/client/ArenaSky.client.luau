--!strict
-- The Smash arena's light (ArenaData.lighting, LOOK RULE: warm sun, bloom): on while the camera is
-- over the arena, off when it leaves. The colour grade and bloom hang under the camera (not in
-- Lighting), so the lobby's own sky swap (LobbySky) never parks or loses them.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaData = require(ReplicatedStorage.Shared.ArenaData)
local FrostYard = require(ReplicatedStorage.Shared.FrostYard)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local LobbySky = require(script.Parent.LobbySky)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- the arena's half size at RC size, plus a little room
local HALF = ArenaData.SIZE / 2 * TrackData.RC_SCALE + 5

local function inArena(p: Vector3): boolean
	return math.abs(p.X - ArenaData.RC_X) < HALF
		and math.abs(p.Z - ArenaData.RC_Z) < HALF
		and p.Y < 80
end

-- Frosty Yard (shared/FrostYard) only cools the colours: same light, bluer air and shade.
local function frosty(): boolean
	return workspace:GetAttribute(FrostYard.ATTR) == FrostYard.FROST
end

local effects: { Instance } = {}
local clouds: Clouds? = nil
local coldNow = false -- which look the effects under the camera were made for
local saved: { [string]: any }? = nil -- the light from before the arena, put back on the way out

local function on(camera: Camera)
	if not saved then
		-- the game's world light steps aside while over the arena (the arena keeps its own look
		-- until it's retuned to WorldLook)
		LobbySky.suspend()
		local old: { [string]: any } = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ColorShift_Top = Lighting.ColorShift_Top,
		}
		for key in ArenaData.lighting do
			old[key] = (Lighting :: any)[key]
		end
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			for key in ArenaData.atmosphere do
				if key ~= "color" and key ~= "decay" then
					old["Atmosphere." .. key] = (atmosphere :: any)[key]
				end
			end
			old["Atmosphere.Color"] = atmosphere.Color
			old["Atmosphere.Decay"] = atmosphere.Decay
		end
		saved = old
	end
	for key, value in ArenaData.lighting do
		if (Lighting :: any)[key] ~= value then
			(Lighting :: any)[key] = value
		end
	end
	local cold = frosty()
	Lighting.Ambient = rgb(if cold then FrostYard.sky.ambient else ArenaData.ambient)
	Lighting.OutdoorAmbient =
		rgb(if cold then FrostYard.sky.outdoorAmbient else ArenaData.outdoorAmbient)
	Lighting.ColorShift_Top =
		rgb(if cold then FrostYard.sky.colorShiftTop else ArenaData.colorShiftTop)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local a = ArenaData.atmosphere
		atmosphere.Density = a.Density
		atmosphere.Offset = a.Offset
		atmosphere.Haze = a.Haze
		atmosphere.Glare = a.Glare
		atmosphere.Color = rgb(if cold then FrostYard.sky.atmosphereColor else a.color)
		atmosphere.Decay = rgb(if cold then FrostYard.sky.atmosphereDecay else a.decay)
	end
	if not clouds or not clouds.Parent then
		clouds = Instance.new("Clouds")
		clouds.Name = "ArenaClouds"
		clouds.Cover = ArenaData.clouds.Cover
		clouds.Density = ArenaData.clouds.Density
		clouds.Parent = workspace.Terrain
	end
	if #effects == 2 and effects[1].Parent == camera and cold ~= coldNow then
		-- the look changed while over the arena: tint again
		effects[1]:Destroy()
		effects[2]:Destroy()
		effects = {}
	end
	coldNow = cold
	if #effects == 0 or effects[1].Parent ~= camera then
		for _, e in effects do
			e:Destroy()
		end
		local c = ArenaData.colorCorrection
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ArenaColor"
		cc.Brightness = c.Brightness
		cc.Contrast = c.Contrast
		cc.Saturation = c.Saturation
		cc.TintColor = rgb(if cold then FrostYard.sky.tint else c.tint)
		if cold then
			cc.Saturation = FrostYard.sky.saturation
		end
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "ArenaBloom"
		bloom.Intensity = ArenaData.bloom.Intensity
		bloom.Size = ArenaData.bloom.Size
		bloom.Threshold = ArenaData.bloom.Threshold
		effects = { cc, bloom }
		for _, e in effects do
			e.Parent = camera
		end
	end
end

local function off()
	for _, e in effects do
		e:Destroy()
	end
	effects = {}
	if clouds then
		clouds:Destroy()
		clouds = nil
	end
	if saved then
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		for key, value in saved do
			local prop = string.match(key, "^Atmosphere%.(.+)$")
			if prop then
				if atmosphere then
					(atmosphere :: any)[prop] = value
				end
			else
				(Lighting :: any)[key] = value
			end
		end
		saved = nil
		LobbySky.resume()
	end
end

while true do
	task.wait(0.25)
	local camera = workspace.CurrentCamera
	if camera and inArena(camera.Focus.Position) then
		on(camera)
	elseif saved or #effects > 0 then
		off()
	end
end
