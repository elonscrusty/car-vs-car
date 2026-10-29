--!strict
-- The game's one light and sky (shared/WorldLook): put on Lighting once and kept on everywhere,
-- in the lobby, the yard, the garage and the plots, so it all looks like one world. The place's
-- own Sky, Atmosphere, Clouds and effects are parked, so two skies never show. The Smash arena
-- still uses its own light for now (ArenaSky asks for the old light with suspend/resume while
-- the camera is over it).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLook = require(ReplicatedStorage.Shared.WorldLook)

local LobbySky = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local LOOK_CLASSES =
	{ "Sky", "Atmosphere", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect" }

local placeLight: { [string]: any }? = nil -- the place's own light, for suspend()
local parked: { Instance } = {} -- the place's own sky/atmosphere/effects/clouds
local added: { Instance } = {}
local applied = false
local suspended = false

local function park(inst: Instance)
	table.insert(parked, inst)
	inst.Parent = nil
end

local function apply()
	local saved: { [string]: any } =
		{ Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	for key, value in WorldLook.lighting do
		saved[key] = (Lighting :: any)[key];
		(Lighting :: any)[key] = value
	end
	placeLight = saved
	Lighting.Ambient = rgb(WorldLook.ambient)
	Lighting.OutdoorAmbient = rgb(WorldLook.outdoorAmbient)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if #added == 0 then
		-- the first time only: park the place's own look (a screen effect another script adds
		-- later, like the league-up glow, is left alone)
		for _, child in Lighting:GetChildren() do
			if table.find(LOOK_CLASSES, child.ClassName) then
				park(child)
			end
		end
		if terrain then
			for _, child in terrain:GetChildren() do
				if child:IsA("Clouds") then
					park(child)
				end
			end
		end
		local a = WorldLook.atmosphere
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = a.Density
		atmosphere.Offset = a.Offset
		atmosphere.Glare = a.Glare
		atmosphere.Haze = a.Haze
		atmosphere.Color = rgb(a.color)
		atmosphere.Decay = rgb(a.decay)
		local sky = Instance.new("Sky") -- Roblox's own bright sky pictures; only the sun changes
		sky.SunAngularSize = WorldLook.sky.SunAngularSize
		sky.MoonAngularSize = WorldLook.sky.MoonAngularSize
		sky.StarCount = WorldLook.sky.StarCount
		local cc = Instance.new("ColorCorrectionEffect")
		local c = WorldLook.colorCorrection
		cc.Brightness = c.Brightness
		cc.Contrast = c.Contrast
		cc.Saturation = c.Saturation
		cc.TintColor = rgb(c.tint)
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = WorldLook.bloom.Intensity
		bloom.Size = WorldLook.bloom.Size
		bloom.Threshold = WorldLook.bloom.Threshold
		for _, inst in { atmosphere, sky, cc, bloom } :: { Instance } do
			inst.Name = "World" .. inst.ClassName
			table.insert(added, inst)
		end
		local clouds = Instance.new("Clouds")
		clouds.Name = "WorldClouds"
		clouds.Cover = WorldLook.clouds.Cover
		clouds.Density = WorldLook.clouds.Density
		clouds.Color = rgb(WorldLook.clouds.color)
		table.insert(added, clouds)
	end
	for _, inst in added do
		inst.Parent = if inst:IsA("Clouds") then terrain else Lighting
	end
	applied = true
end

-- Called on every walk/drive switch: the world light goes on the first time and stays on.
function LobbySky.set(_lobby: boolean)
	if not applied and not suspended then
		apply()
	end
end

-- The arena's own light (ArenaSky) asks for the place's old light while the camera is over it,
-- so the arena looks just as it did until it gets retuned to WorldLook.
function LobbySky.suspend()
	if not applied or suspended then
		return
	end
	suspended = true
	if placeLight then
		for key, value in placeLight do
			(Lighting :: any)[key] = value
		end
	end
	for _, inst in added do
		inst.Parent = nil
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	for _, inst in parked do
		inst.Parent = if inst:IsA("Clouds") then terrain else Lighting
	end
end

function LobbySky.resume()
	if not suspended then
		return
	end
	suspended = false
	for _, inst in parked do
		inst.Parent = nil
	end
	applied = false
	apply()
end

return LobbySky
