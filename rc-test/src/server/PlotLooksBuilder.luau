--!strict
-- Shows each lobby plot's looks (PlotLooks): watches the plot model's OwnerLooks attribute (set by
-- PlotShop from the owner's save: bought looks and star themes, minus the ones turned off), or
-- OwnerStars (Stars.server) while that isn't there. Studio-only TestLooks / TestStars win over
-- both for tests. When the looks change it rebuilds the plot's Looks folder: night tints the
-- plot and turns its lamps on, snow adds snow and a light snowfall, party adds string lights,
-- fans and searchlights; balloons, glow walls and confetti are the decor. Looks only: colours
-- change, sizes and collisions never do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotLooks = require(ReplicatedStorage.Shared.PlotLooks)
local PlotShop = require(ReplicatedStorage.Shared.PlotShop)

local PlotLooksBuilder = {}

local DAY = "DayColor" -- attribute holding a part's own colour while a look recolours it
local SNOW_GROUND = Color3.fromRGB(236, 242, 250)
local NIGHT_SKY = Color3.fromRGB(10, 14, 40)

-- grass and ground parts (snow turns these white; colour only, the material and its grip stay)
local function isGround(d: BasePart): boolean
	local m = d.Material
	return m == Enum.Material.Grass
		or m == Enum.Material.LeafyGrass
		or m == Enum.Material.Ground
		or d.Name == "Grass"
		or d.Name == "Ground"
end

-- recolour the plot's own parts (called with the Looks folder gone; neon stays bright): snow
-- whitens the grass, night darkens everything. Colours only: sizes, materials, grip never change.
local function restyle(plot: Model, night: boolean, snow: boolean)
	for _, d in plot:GetDescendants() do
		if not d:IsA("BasePart") or d.Material == Enum.Material.Neon then
			continue
		end
		local day = d:GetAttribute(DAY)
		local base = if typeof(day) == "Color3" then day else d.Color
		local c = base
		local snowy = snow and isGround(d)
		if snowy then
			c = SNOW_GROUND
		end
		if night then
			-- snow stays pale at night (moonlit), or night and snow together read as grey
			c = c:Lerp(NIGHT_SKY, if snowy then PlotLooks.SNOW_NIGHT else 1 - PlotLooks.NIGHT_TINT)
		end
		if c ~= base then
			d:SetAttribute(DAY, base)
			d.Color = c
		elseif day ~= nil then
			d.Color = base
			d:SetAttribute(DAY, nil)
		end
	end
end

local function snowfall(cloud: BasePart)
	cloud.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = PlotLooks.SNOW_RATE
	e.Lifetime = NumberRange.new(8, 10)
	e.Speed = NumberRange.new(3, 4)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(10, 10)
	e.Size = NumberSequence.new(0.45)
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = 0.3
	e.Parent = cloud
end

local CONFETTI = {
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(255, 130, 210),
}

local function confetti(cloud: BasePart)
	cloud.Transparency = 1
	for _, c in CONFETTI do
		local e = Instance.new("ParticleEmitter")
		e.Rate = PlotLooks.CONFETTI_RATE / #CONFETTI
		e.Lifetime = NumberRange.new(7, 9)
		e.Speed = NumberRange.new(2.5, 3.5)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(20, 20)
		e.Size = NumberSequence.new(0.35)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Color = ColorSequence.new(c)
		e.LightEmission = 0.2
		e.Parent = cloud
	end
end

local function apply(plot: Model, pivot: CFrame, kind: string, ids: { string })
	local night = table.find(ids, "night") ~= nil
	local old = plot:FindFirstChild("Looks")
	if old then
		old:Destroy()
	end
	restyle(plot, night, table.find(ids, "snow") ~= nil)
	-- PlotDecor's lanterns glow brighter at night
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Lantern" or d.Name == "Light") then
			local light = d:FindFirstChildOfClass("PointLight")
			if night and not light and d.Name == "Lantern" then
				local glow = Instance.new("PointLight")
				glow.Name = "NightLight"
				glow.Range = 16
				glow.Brightness = 2.5
				glow.Color = d.Color
				glow.Parent = d
			elseif not night and light and light.Name == "NightLight" then
				light:Destroy()
			end
		end
	end
	if #ids == 0 then
		return
	end
	local looks = Instance.new("Model")
	looks.Name = "Looks"
	Garage.makeParts(PlotLooks.allParts(kind, ids), looks, pivot)
	for _, d in looks:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			if d.Name == "SnowCloud" then
				snowfall(d)
			elseif d.Name == "ConfettiCloud" then
				confetti(d)
			elseif d.Name == "SearchBeam" then
				d.Transparency = 0.75
			end
		end
	end
	looks.Parent = plot
end

-- the looks this plot shows, in build order
local function looksOf(plot: Model): { string }
	if RunService:IsStudio() then
		local testLooks = plot:GetAttribute("TestLooks")
		if typeof(testLooks) == "string" then
			return PlotShop.decode(testLooks)
		end
		local test = plot:GetAttribute("TestStars")
		if typeof(test) == "number" then
			return PlotLooks.fromStars(test)
		end
	end
	local owned = plot:GetAttribute("OwnerLooks")
	if typeof(owned) == "string" then
		return PlotShop.decode(owned)
	end
	local s = plot:GetAttribute("OwnerStars")
	return PlotLooks.fromStars(if typeof(s) == "number" then s else 0)
end

function PlotLooksBuilder.start()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, slot in LobbyLayout.slots() do
		local plot = plots:FindFirstChild(slot.index .. "_" .. slot.id)
		if not (plot and plot:IsA("Model")) then
			continue
		end
		local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
		local shown = ""
		local function update()
			local ids = looksOf(plot)
			local key = table.concat(ids, ",")
			if key ~= shown then
				shown = key
				apply(plot, pivot, slot.id, ids)
			end
		end
		for _, a in { "OwnerLooks", "OwnerStars", "TestLooks", "TestStars" } do
			plot:GetAttributeChangedSignal(a):Connect(update)
		end
		update()
	end
end

return PlotLooksBuilder
