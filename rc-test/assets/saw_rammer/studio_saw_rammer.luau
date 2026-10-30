-- Studio command bar, EDIT mode, after carter imported the Saw Rammer .obj files (File > Import 3D,
-- see README.md here). Sorts every imported "SawRammer__<Part>" mesh into three models in
-- ReplicatedStorage.CarSkins: the car (road saw) and its two skins (big saw, twin saws). Each model is the body
-- parts plus one saw kit. Paints each part (the car keeps its own colours) and checks it has Body,
-- WheelFL/FR/RL/RR and Headlights (CarSkin finds the nose by them). Safe to run again. Then save (Ctrl+S).
--
-- The models carry Kart + Extras attributes like CarSkins.ice_viper: CarSkin sizes them by their tyres and carries
-- every other part on the body; Rim<anything><FL|FR|RL|RR> pieces turn with that wheel. Nose at +Z, left at +X.
-- Blade parts (SawBlade*, SawHub*) carry a "SpinAxis" attribute (model space): the weapon code spins them about it.
local CAR_ID = "saw_rammer" -- rename to the car's id in CarCatalog when it gets one
local SKINS = { plow = CAR_ID, big = CAR_ID .. "_big", twin = CAR_ID .. "_twin" } -- kit -> model name
local MAX_TURN = 0.35 -- how far the front wheels are drawn turned (radians), to stay in the arches
-- the generator's spin axes (nose +Z, up +Y, left +X), from `node export.js`
local SPIN_AXES = {
	plow = { SawBlade = Vector3.new(0, 1, 0), SawHub = Vector3.new(0, 1, 0) },
	big = { SawBlade = Vector3.new(0, 0.12, 0.993), SawHub = Vector3.new(0, 0.12, 0.993) },
	twin = {
		SawBladeL = Vector3.new(0.312, 0.12, 0.942),
		SawHubL = Vector3.new(0.312, 0.12, 0.942),
		SawBladeR = Vector3.new(-0.312, 0.12, 0.942),
		SawHubR = Vector3.new(-0.312, 0.12, 0.942),
	},
}

local RS = game:GetService("ReplicatedStorage")
local skins = RS:FindFirstChild("CarSkins")
if not skins then
	skins = Instance.new("Folder")
	skins.Name = "CarSkins"
	skins.Parent = RS
end

local STEEL = { Enum.Material.Metal, 0.2 }
local CHROME = { Enum.Material.Metal, 0.35 }
local PLASTIC = { Enum.Material.SmoothPlastic, 0 }
local NEON = { Enum.Material.Neon, 0 }
local ORANGE = Color3.fromRGB(255, 112, 18)
local CHROME_C = Color3.fromRGB(205, 210, 220)
local STEEL_C = Color3.fromRGB(150, 155, 165)
local DARK_C = Color3.fromRGB(9, 9, 11)
local TRIM_C = Color3.fromRGB(54, 56, 62)
-- part name -> colour, material, reflectance (the preview page's colours)
local LOOKS: { [string]: { color: Color3, mat: { any } } } = {
	Body = { color = Color3.fromRGB(34, 36, 42), mat = { Enum.Material.SmoothPlastic, 0.06 } },
	Accent = { color = ORANGE, mat = PLASTIC },
	Glass = { color = Color3.fromRGB(14, 20, 32), mat = { Enum.Material.SmoothPlastic, 0.25 } },
	Chrome = { color = CHROME_C, mat = CHROME },
	Steel = { color = STEEL_C, mat = STEEL },
	Dark = { color = DARK_C, mat = PLASTIC },
	Trim = { color = TRIM_C, mat = PLASTIC },
	Plate = { color = Color3.fromRGB(235, 240, 225), mat = PLASTIC },
	Headlights = { color = Color3.fromRGB(255, 238, 150), mat = NEON },
	Glow = { color = Color3.fromRGB(255, 150, 40), mat = NEON },
	Taillights = { color = Color3.fromRGB(255, 36, 36), mat = NEON },
	-- the saw kit
	KitAccent = { color = ORANGE, mat = PLASTIC },
	KitChrome = { color = CHROME_C, mat = CHROME },
	KitSteel = { color = STEEL_C, mat = STEEL },
	KitTrim = { color = TRIM_C, mat = PLASTIC },
	KitGlow = { color = Color3.fromRGB(255, 150, 40), mat = NEON },
}
local BLADE = { color = Color3.fromRGB(150, 156, 170), mat = { Enum.Material.Metal, 0.3 } }
local TYRE = { color = Color3.fromRGB(22, 22, 26), mat = PLASTIC }

local function lookOf(name: string)
	if LOOKS[name] then
		return LOOKS[name]
	elseif string.sub(name, 1, 5) == "Wheel" then
		return TYRE
	elseif string.sub(name, 1, 8) == "SawBlade" then
		return BLADE
	elseif string.sub(name, 1, 6) == "SawHub" then
		return LOOKS.Accent
	elseif string.sub(name, 1, 9) == "RimChrome" then
		return LOOKS.Chrome
	elseif string.sub(name, 1, 7) == "RimDark" then
		return LOOKS.Dark
	elseif string.sub(name, 1, 3) == "Rim" then
		return LOOKS.Accent
	end
	return nil
end

-- the imported meshes, wherever the importer put them (the name may be on the part or on its node)
local body: { [string]: BasePart } = {}
local kits: { [string]: { [string]: BasePart } } = { plow = {}, big = {}, twin = {} }
local imports: { Instance } = {}
for _, top in workspace:GetChildren() do
	local all = top:GetDescendants()
	table.insert(all, top)
	local hit = false
	for _, d in all do
		local base = string.match((d.Name:gsub("%.%d+$", "")), "^SawRammer__(.+)$")
		if base then
			hit = true
			local part: BasePart? = if d:IsA("BasePart")
				then d
				else d:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local kit, kitPart = string.match(base, "^(%a+)_(%w+)$")
				local into = body
				local key = base
				if kit and kits[kit] then
					into = kits[kit]
					key = kitPart
				end
				if into[key] and into[key] ~= part then
					warn(base, "imported twice, left one in", part:GetFullName())
				else
					into[key] = part
				end
			end
		end
	end
	if hit then
		table.insert(imports, top)
	end
end

local missing = {}
for _, need in { "Body", "WheelFL", "WheelFR", "WheelRL", "WheelRR", "Headlights" } do
	if not body[need] then
		table.insert(missing, need)
	end
end
for kit, parts in kits do
	if next(parts) == nil then
		table.insert(missing, "the " .. kit .. " saw files (obj/skin_" .. kit .. ")")
	end
end
if #missing > 0 then
	warn("Saw Rammer is missing:", table.concat(missing, ", "), "- import the .obj files again")
	return
end

-- nose at +Z: if the importer turned the car round, turn every part back (and the spin axes with it)
local centre = body.Body.Position
local turn = CFrame.identity
if body.Headlights.Position.Z < centre.Z then
	turn = CFrame.Angles(0, math.pi, 0)
	local function spin(p: BasePart)
		p.CFrame = CFrame.new(centre) * turn * (CFrame.new(-centre) * p.CFrame)
	end
	for _, p in body do
		spin(p)
	end
	for _, parts in kits do
		for _, p in parts do
			spin(p)
		end
	end
	print("turned the car round (its nose was at -Z)")
end
-- left at +X: if the importer mirrored it, swap the left and right names (the spin axes then lean the other way)
local mirrored = body.WheelFL.Position.X < centre.X
if mirrored then
	local swapped: { [string]: BasePart } = {}
	for name, p in body do
		local pre, side = string.match(name, "^(.-)([FR][LR])$")
		if pre and (pre == "Wheel" or string.sub(pre, 1, 3) == "Rim") then
			swapped[pre .. string.sub(side, 1, 1) .. (if string.sub(side, 2, 2) == "L"
				then "R"
				else "L")] =
				p
		else
			swapped[name] = p
		end
	end
	body = swapped
	print("swapped left and right (the importer mirrored X)")
end

local function paint(part: BasePart, name: string)
	local look = lookOf(name)
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
	if look then
		part.Color = look.color
		part.Material = look.mat[1]
		part.Reflectance = look.mat[2]
	else
		warn("no look for part", name)
	end
end

-- one model per look: every body part cloned + that look's saw kit
for kit, modelName in SKINS do
	local model = Instance.new("Model")
	model.Name = modelName
	local count = 0
	for name, part in body do
		local p = part:Clone()
		paint(p, name)
		p.Parent = model
		count += 1
	end
	for name, part in kits[kit] do
		local p = part:Clone()
		paint(p, name)
		local axis = SPIN_AXES[kit][name]
		if axis then
			p:SetAttribute(
				"SpinAxis",
				turn:VectorToWorldSpace(
					if mirrored then Vector3.new(-axis.X, axis.Y, axis.Z) else axis
				)
			)
		end
		p.Parent = model
		count += 1
	end
	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	model:SetAttribute("Kart", true)
	model:SetAttribute("Extras", true)
	model:SetAttribute("MaxTurn", MAX_TURN)
	local old = skins:FindFirstChild(modelName)
	if old then
		old:Destroy()
	end
	model.Parent = skins
	print("CarSkins." .. modelName, "made with", count, "parts")
end

-- the importer's own meshes and empty wrappers go (the models hold clones)
for _, top in imports do
	if top.Parent then
		top:Destroy()
	end
end
print("Saw Rammer done. Save the place (Ctrl+S).")
