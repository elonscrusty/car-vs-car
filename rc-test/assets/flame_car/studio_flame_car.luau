-- Studio command bar, EDIT mode, after carter imported the flame car .obj files (File > Import 3D,
-- see README.md here). Sorts every imported "<Prefix>__<Part>" mesh into one model per look,
-- ReplicatedStorage.CarSkins.<id>, paints each part (the look keeps its own colours), and checks
-- it has Body, WheelFL/FR/RL/RR and Headlights (CarSkin finds the nose by them). Safe to run again,
-- and fine if only some of the three looks were imported.
-- Then save the place (Ctrl+S).
--
-- The models carry Kart + Extras attributes like CarSkins.toxic_rod: CarSkin then sizes each by its
-- tyres and carries every other part (Accent, Chrome, Tank, ...) on the body. Rim pieces named
-- Rim<anything><FL|FR|RL|RR> turn with that wheel. Nose at +Z, car's left at +X.
local MAX_TURN = 0.35 -- how far the front wheels are drawn turned (radians), to stay in the arches

type Look = { color: Color3, mat: { any } }
-- the three looks: the part-name prefix of the .obj files, the model id (rename to the car's / skin's id in
-- CarCatalog when it has one), and the colours that differ per look (the preview page's colours)
local VARIANTS = {
	{
		prefix = "FlameCharger", -- car 6, the Napalm Charger
		id = "flame_charger",
		body = Color3.fromRGB(16, 17, 21),
		accent = Color3.fromRGB(255, 104, 18),
		tank = Color3.fromRGB(210, 58, 16),
		glow = Color3.fromRGB(255, 190, 60),
		fire = Color3.fromRGB(255, 214, 80),
	},
	{
		prefix = "FlameDragon", -- skin: Dragon Furnace
		id = "flame_dragon",
		body = Color3.fromRGB(84, 10, 16),
		accent = Color3.fromRGB(255, 168, 24),
		tank = Color3.fromRGB(150, 96, 36),
		glow = Color3.fromRGB(255, 120, 30),
		fire = Color3.fromRGB(255, 226, 110),
	},
	{
		prefix = "FlameTanker", -- skin: Tanker Rod
		id = "flame_tanker",
		body = Color3.fromRGB(44, 47, 52),
		accent = Color3.fromRGB(255, 208, 22),
		tank = Color3.fromRGB(120, 126, 138),
		glow = Color3.fromRGB(255, 150, 40),
		fire = Color3.fromRGB(255, 236, 120),
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

-- part name -> colour, material, reflectance
local function looksFor(v): { [string]: Look }
	return {
		Body = { color = v.body, mat = { Enum.Material.SmoothPlastic, 0.06 } },
		Accent = { color = v.accent, mat = PLASTIC },
		Glass = { color = Color3.fromRGB(14, 20, 32), mat = { Enum.Material.SmoothPlastic, 0.25 } },
		Chrome = { color = Color3.fromRGB(205, 210, 220), mat = CHROME },
		Steel = { color = Color3.fromRGB(150, 155, 165), mat = STEEL },
		Dark = { color = Color3.fromRGB(9, 9, 11), mat = PLASTIC },
		Trim = { color = Color3.fromRGB(38, 40, 46), mat = PLASTIC },
		Plate = { color = Color3.fromRGB(235, 240, 225), mat = PLASTIC },
		Tank = { color = v.tank, mat = { Enum.Material.Metal, 0.12 } },
		Bone = { color = Color3.fromRGB(226, 214, 186), mat = PLASTIC },
		Headlights = { color = Color3.fromRGB(255, 238, 120), mat = NEON },
		Glow = { color = v.glow, mat = NEON },
		FlameFire = { color = v.fire, mat = PLASTIC }, -- (the flame decals' hot core; plastic, so it never blooms)
		Taillights = { color = Color3.fromRGB(255, 36, 36), mat = NEON },
	}
end
local TYRE = { color = Color3.fromRGB(22, 22, 26), mat = PLASTIC }

local function lookOf(looks: { [string]: Look }, name: string): Look?
	if looks[name] then
		return looks[name]
	elseif string.sub(name, 1, 5) == "Wheel" then
		return TYRE
	elseif string.sub(name, 1, 9) == "RimChrome" then
		return looks.Chrome
	elseif string.sub(name, 1, 7) == "RimDark" then
		return looks.Dark
	elseif string.sub(name, 1, 3) == "Rim" then
		return looks.Accent
	end
	return nil
end

-- the imported meshes of one look, wherever the importer put them (the name may be on the part or on its node)
local function collect(prefix: string): ({ [string]: BasePart }, { Instance })
	local found: { [string]: BasePart } = {}
	local imports: { Instance } = {}
	for _, top in workspace:GetChildren() do
		local all = top:GetDescendants()
		table.insert(all, top)
		local hit = false
		for _, d in all do
			local base = string.match((d.Name:gsub("%.%d+$", "")), "^" .. prefix .. "__(.+)$")
			if base then
				hit = true
				local part: BasePart? = if d:IsA("BasePart") then d else d:FindFirstChildWhichIsA("BasePart", true)
				if part then
					if found[base] and found[base] ~= part then
						warn(base, "imported twice, left one in", part:GetFullName())
					else
						found[base] = part
					end
				end
			end
		end
		if hit then
			table.insert(imports, top)
		end
	end
	return found, imports
end

local function make(v)
	local found, imports = collect(v.prefix)
	if next(found) == nil then
		print(v.prefix, "was not imported, skipped")
		return
	end
	local looks = looksFor(v)
	local model = Instance.new("Model")
	model.Name = v.id
	local count = 0
	for name, part in found do
		local look = lookOf(looks, name)
		part.Name = name
		part.Parent = model
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
		count += 1
	end

	local missing = {}
	for _, need in { "Body", "WheelFL", "WheelFR", "WheelRL", "WheelRR", "Headlights" } do
		if not model:FindFirstChild(need) then
			table.insert(missing, need)
		end
	end
	if #missing > 0 then
		warn(v.prefix, "is missing:", table.concat(missing, ", "), "- import its .obj files again")
		model:Destroy()
		return
	end

	local body = model:FindFirstChild("Body") :: BasePart
	local centre = body.Position
	-- nose at +Z: if the importer turned it round, turn the whole car back
	if (model:FindFirstChild("Headlights") :: BasePart).Position.Z < centre.Z then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CFrame = CFrame.new(centre) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(-centre) * p.CFrame)
			end
		end
		print(v.id, "turned the car round (its nose was at -Z)")
	end
	-- left at +X: if the importer mirrored it, swap the left and right names
	if (model:FindFirstChild("WheelFL") :: BasePart).Position.X < centre.X then
		for _, p in model:GetChildren() do
			local pre, side = string.match(p.Name, "^(.-)([FR][LR])$")
			if pre and (pre == "Wheel" or string.sub(pre, 1, 3) == "Rim") then
				local swapped = (if string.sub(side, 2, 2) == "L" then "R" else "L")
				p.Name = pre .. string.sub(side, 1, 1) .. swapped
			end
		end
		print(v.id, "swapped left and right (the importer mirrored X)")
	end

	model.PrimaryPart = body
	model:SetAttribute("Kart", true)
	model:SetAttribute("Extras", true)
	model:SetAttribute("MaxTurn", MAX_TURN)

	local old = skins:FindFirstChild(v.id)
	if old then
		old:Destroy()
	end
	model.Parent = skins
	-- the importer's empty wrappers go (never one that still holds a part)
	for _, top in imports do
		if top.Parent and not top:IsDescendantOf(model) then
			local holdsPart = top:IsA("BasePart")
			for _, d in top:GetDescendants() do
				holdsPart = holdsPart or d:IsA("BasePart")
			end
			if not holdsPart then
				top:Destroy()
			end
		end
	end
	print("CarSkins." .. v.id, "made with", count, "parts. Save the place (Ctrl+S).")
end

for _, v in VARIANTS do
	make(v)
end
