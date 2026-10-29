--!strict
-- The Smash arena's light (ArenaData.lighting, LOOK RULE: warm sun, bloom): on while the camera is
-- over the arena, off when it leaves. The colour grade and bloom hang under the camera (not in
-- Lighting), so the lobby's own sky swap (LobbySky) never parks or loses them.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaData = require(ReplicatedStorage.Shared.ArenaData)
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

local effects: { Instance } = {}
local saved: { [string]: any }? = nil -- the light from before the arena, put back on the way out

local function on(camera: Camera)
	if not saved then
		-- the game's world light steps aside while over the arena (the arena keeps its own look
		-- until it's retuned to WorldLook)
		LobbySky.suspend()
		local old: { [string]: any } =
			{ Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
		for key in ArenaData.lighting do
			old[key] = (Lighting :: any)[key]
		end
		saved = old
	end
	for key, value in ArenaData.lighting do
		if (Lighting :: any)[key] ~= value then
			(Lighting :: any)[key] = value
		end
	end
	Lighting.Ambient = rgb(ArenaData.ambient)
	Lighting.OutdoorAmbient = rgb(ArenaData.outdoorAmbient)
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
		cc.TintColor = rgb(c.tint)
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
	if saved then
		for key, value in saved do
			(Lighting :: any)[key] = value
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
