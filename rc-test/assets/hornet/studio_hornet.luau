-- Studio command bar, EDIT mode, after carter imported the Hornet .obj files (File > Import 3D, see README.md
-- here). Sorts every imported "Hornet__<Part>", "HornetNose__<Part>" and "HornetFender__<Part>" mesh into three
-- models in ReplicatedStorage.CarSkins: the Hood Twins main look and two gun skins (same car, other gun
-- places). It paints each part (the car keeps its own colours) and checks each model has Body, WheelFL/FR/RL/RR
-- and Headlights (CarSkin finds the nose by them). Safe to run again. Then save the place (Ctrl+S).
--
-- Each model carries Kart + Extras attributes like CarSkins.ice_viper: CarSkin sizes it by its tyres and carries
-- every other part on the body. Rim pieces named Rim<anything><FL|FR|RL|RR> turn with that wheel. Nose at +Z,
-- car's left at +X. Gun parts: Gun* (fixed), SpinL* / SpinR* (the 6 barrels, turn about the gun's own axis, the
-- Z axis through PivotL / PivotR), MuzzleL / MuzzleR (where shots leave). The Pivot and Muzzle parts are see-through.
local SKINS = {
	{ id = "hornet", tag = "Hornet", label = "Hood Twins" }, -- rename the ids to CarCatalog's when it has them
	{ id = "hornet_nose", tag = "HornetNose", label = "Nose Guns" },
	{ id = "hornet_fender", tag = "HornetFender", label = "Fender Pods" },
}
local MAX_TURN = 0.35 -- how far the front wheels are drawn turned (radians), to stay in the arches

local RS = game:GetService("ReplicatedStorage")
local skins = RS:FindFirstChild("CarSkins")
if not skins then
	skins = Instance.new("Folder")
	skins.Name = "CarSkins"
	skins.Parent = RS
end

local STEEL = { Enum.Material.Metal, 0.2 }
local CHROME = { Enum.Material.Metal, 0.35 }
local BRASS = { Enum.Material.Metal, 0.15 }
local PLASTIC = { Enum.Material.SmoothPlastic, 0 }
local NEON = { Enum.Material.Neon, 0 }
-- part name -> colour, material, reflectance (the preview page's colours)
local LOOKS: { [string]: { color: Color3, mat: { any } } } = {
	Body = { color = Color3.fromRGB(218, 80, 12), mat = { Enum.Material.SmoothPlastic, 0.06 } },
	Racing = { color = Color3.fromRGB(18, 18, 22), mat = PLASTIC },
	Accent = { color = Color3.fromRGB(255, 190, 40), mat = BRASS },
	Glass = { color = Color3.fromRGB(14, 20, 32), mat = { Enum.Material.SmoothPlastic, 0.25 } },
	Chrome = { color = Color3.fromRGB(205, 210, 220), mat = CHROME },
	Steel = { color = Color3.fromRGB(150, 155, 165), mat = STEEL },
	Dark = { color = Color3.fromRGB(9, 9, 11), mat = PLASTIC },
	Trim = { color = Color3.fromRGB(38, 40, 46), mat = PLASTIC },
	Plate = { color = Color3.fromRGB(235, 240, 225), mat = PLASTIC },
	Headlights = { color = Color3.fromRGB(255, 238, 150), mat = NEON },
	Glow = { color = Color3.fromRGB(255, 140, 40), mat = NEON },
	Taillights = { color = Color3.fromRGB(255, 36, 36), mat = NEON },
}
-- gun parts, by what is left of the name after Gun / SpinL / SpinR
local GUNLOOKS: { [string]: { color: Color3, mat: { any } } } = {
	Gunmetal = { color = Color3.fromRGB(52, 56, 64), mat = STEEL },
	Steel = { color = Color3.fromRGB(112, 118, 130), mat = STEEL },
	Steel2 = { color = Color3.fromRGB(150, 155, 165), mat = STEEL },
	Chrome = LOOKS.Chrome,
	Trim = LOOKS.Trim,
	Dark = LOOKS.Dark,
	Brass = LOOKS.Accent,
	Lamp = LOOKS.Headlights,
}
local TYRE = { color = Color3.fromRGB(22, 22, 26), mat = PLASTIC }
local WHEELS = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

local function isWeapon(name: string): boolean
	return string.match(name, "^Gun") ~= nil
		or string.match(name, "^Spin[LR]") ~= nil
		or string.match(name, "^Pivot[LR]$") ~= nil
		or string.match(name, "^Muzzle[LR]$") ~= nil
end

local function isMarker(name: string): boolean
	return string.match(name, "^Pivot[LR]$") ~= nil or string.match(name, "^Muzzle[LR]$") ~= nil
end

local function lookOf(name: string)
	if LOOKS[name] then
		return LOOKS[name]
	elseif string.sub(name, 1, 5) == "Wheel" then
		return TYRE
	elseif string.sub(name, 1, 8) == "RimChrome" then
		return LOOKS.Chrome
	elseif string.sub(name, 1, 7) == "RimDark" then
		return LOOKS.Dark
	elseif string.sub(name, 1, 3) == "Rim" then
		return LOOKS.Accent
	end
	local gun = string.match(name, "^Gun(%a+%d?)$") or string.match(name, "^Spin[LR](%a+%d?)$")
	if gun then
		return GUNLOOKS[gun]
	end
	return nil
end

-- the imported meshes, wherever the importer put them (the name may be on the part or on its node)
local found: { [string]: { [string]: BasePart } } = {}
local imports: { Instance } = {}
for _, top in workspace:GetChildren() do
	local all = top:GetDescendants()
	table.insert(all, top)
	local hit = false
	for _, d in all do
		local tag, base = string.match((d.Name:gsub("%.%d+$", "")), "^(Hornet%a*)__(.+)$")
		if tag and base then
			hit = true
			local part: BasePart? = if d:IsA("BasePart") then d else d:FindFirstChildWhichIsA("BasePart", true)
			if part then
				found[tag] = found[tag] or {}
				if found[tag][base] and found[tag][base] ~= part then
					warn(tag, base, "imported twice, left one in", part:GetFullName())
				else
					found[tag][base] = part
				end
			end
		end
	end
	if hit then
		table.insert(imports, top)
	end
end

local function paint(part: BasePart, name: string)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	for _, c in part:GetChildren() do
		if c:IsA("SurfaceAppearance") or c:IsA("Texture") or c:IsA("Decal") then
			c:Destroy() -- (the importer's own look would hide the paint)
		end
	end
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	if isMarker(name) then
		part.Transparency = 1
		part:SetAttribute("Marker", name)
		return
	end
	local side = string.match(name, "^Spin([LR])")
	if side then
		part:SetAttribute("SpinSide", side)
	end
	local look = lookOf(name)
	if look then
		part.Color = look.color
		part.Material = look.mat[1]
		part.Reflectance = look.mat[2]
	else
		warn("no look for part", name)
	end
end

-- the car without guns: every imported "Hornet__" part that is not a weapon part
local baseParts: { [string]: BasePart } = {}
for name, part in found.Hornet or {} do
	if not isWeapon(name) then
		baseParts[name] = part
	end
end

local function fixOrientation(model: Model)
	local body = model:FindFirstChild("Body") :: BasePart
	local centre = body.Position
	-- nose at +Z: if the importer turned it round, turn the whole car back
	if (model.Headlights :: BasePart).Position.Z < centre.Z then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CFrame = CFrame.new(centre) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(-centre) * p.CFrame)
			end
		end
		print(model.Name, "turned the car round (its nose was at -Z)")
	end
	-- left at +X: if the importer mirrored it, swap the left and right names
	if (model.WheelFL :: BasePart).Position.X < centre.X then
		for _, p in model:GetChildren() do
			local pre, side = string.match(p.Name, "^(.-)([FR][LR])$")
			if pre and (pre == "Wheel" or string.sub(pre, 1, 3) == "Rim") then
				local swapped = (if string.sub(side, 2, 2) == "L" then "R" else "L")
				p.Name = pre .. string.sub(side, 1, 1) .. swapped
			else
				local a, s2, b = string.match(p.Name, "^(%a-)([LR])([%w]*)$")
				if a and (a == "Spin" or a == "Pivot" or a == "Muzzle") then
					p.Name = a .. (if s2 == "L" then "R" else "L") .. b
					p:SetAttribute("SpinSide", string.match(p.Name, "^Spin([LR])"))
				end
			end
		end
		print(model.Name, "swapped left and right (the importer mirrored X)")
	end
end

local made = 0
local firstSkin = true
for _, skin in SKINS do
	local weapon = found[skin.tag]
	if not weapon then
		warn(skin.label, "has no imported parts, skipped")
		continue
	end
	local model = Instance.new("Model")
	model.Name = skin.id
	for name, part in baseParts do
		-- the first model takes the imported parts, the others get copies
		local p = if firstSkin then part else part:Clone()
		p.Parent = model
		paint(p, name)
	end
	local gunCount = 0
	for name, part in weapon do
		if isWeapon(name) then
			part.Parent = model
			paint(part, name)
			gunCount += 1
		end
	end
	firstSkin = false

	local missing = {}
	for _, need in { "Body", "Headlights" } do
		if not model:FindFirstChild(need) then
			table.insert(missing, need)
		end
	end
	for _, need in WHEELS do
		if not model:FindFirstChild(need) then
			table.insert(missing, need)
		end
	end
	if gunCount == 0 then
		table.insert(missing, "gun parts")
	end
	if #missing > 0 then
		warn("Hornet (" .. skin.label .. ") is missing:", table.concat(missing, ", "), "- import the .obj files again")
		model:Destroy()
		continue
	end
	fixOrientation(model)
	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	model:SetAttribute("Kart", true)
	model:SetAttribute("Extras", true)
	model:SetAttribute("MaxTurn", MAX_TURN)
	model:SetAttribute("Look", skin.label)
	local old = skins:FindFirstChild(skin.id)
	if old then
		old:Destroy()
	end
	model.Parent = skins
	made += 1
	print("CarSkins." .. skin.id, "(" .. skin.label .. ") made with", #model:GetChildren(), "parts")
end

-- the importer's empty wrappers go (never one that still holds a part)
for _, top in imports do
	if top.Parent and not top:IsDescendantOf(skins) then
		local holdsPart = top:IsA("BasePart")
		for _, d in top:GetDescendants() do
			holdsPart = holdsPart or d:IsA("BasePart")
		end
		if not holdsPart then
			top:Destroy()
		end
	end
end
print("Hornet:", made, "of", #SKINS, "looks made. Save the place (Ctrl+S).")
