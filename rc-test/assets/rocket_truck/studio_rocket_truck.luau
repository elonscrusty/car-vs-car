-- Studio command bar, EDIT mode, after carter imported the Rocket Truck .obj files (File > Import 3D,
-- see README.md here). For the car and each of its two skins it sorts every imported "<Prefix>__<Part>" mesh
-- into ONE model, ReplicatedStorage.CarSkins.<id>, paints each part (the car keeps its own colours), and checks
-- it has Body, WheelFL/FR/RL/RR and Headlights (CarSkin finds the nose by them). Safe to run again; a truck
-- whose files were not imported is skipped. Then save the place (Ctrl+S).
--
-- Every model carries Kart + Extras attributes like CarSkins.ice_viper: CarSkin then sizes it by its tyres and
-- carries every other part (Accent, Chrome, ...) on the body. Rim pieces named Rim<anything><FL|FR|RL|RR> turn
-- with that wheel. Nose at +Z, car's left at +X. The rocket pods are part of the body (no roof weapon spot).
local MAX_TURN = 0.35 -- how far the front wheels are drawn turned (radians), to stay in the arches

-- file prefix -> skin id (rename the ids to the ones in CarCatalog when the car gets them), accent colour
local TRUCKS = {
	{ prefix = "RocketTruck", id = "rocket_truck", accent = Color3.fromRGB(232, 40, 44) }, -- Missile Mule
	{ prefix = "RocketTruckHauler", id = "rocket_truck_hauler", accent = Color3.fromRGB(255, 112, 22) }, -- Blast Hauler
	{ prefix = "RocketTruckFury", id = "rocket_truck_fury", accent = Color3.fromRGB(255, 206, 26) }, -- Fender Fury
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
local TYRE = { color = Color3.fromRGB(22, 22, 26), mat = PLASTIC }

-- part name -> colour, material, reflectance (the preview page's colours)
local function looksFor(accent: Color3): { [string]: { color: Color3, mat: { any } } }
	return {
		Body = { color = Color3.fromRGB(22, 23, 28), mat = { Enum.Material.SmoothPlastic, 0.06 } },
		Accent = { color = accent, mat = PLASTIC },
		Warhead = { color = accent, mat = PLASTIC },
		Glass = { color = Color3.fromRGB(24, 38, 60), mat = { Enum.Material.SmoothPlastic, 0.25 } },
		Chrome = { color = Color3.fromRGB(205, 210, 220), mat = CHROME },
		Steel = { color = Color3.fromRGB(150, 155, 165), mat = STEEL },
		Dark = { color = Color3.fromRGB(9, 9, 11), mat = PLASTIC },
		Trim = { color = Color3.fromRGB(40, 42, 48), mat = PLASTIC },
		Bed = { color = Color3.fromRGB(30, 31, 37), mat = PLASTIC },
		Plate = { color = Color3.fromRGB(235, 240, 225), mat = PLASTIC },
		Headlights = { color = Color3.fromRGB(255, 238, 150), mat = NEON },
		Glow = { color = Color3.fromRGB(255, 150, 40), mat = NEON },
		Taillights = { color = Color3.fromRGB(255, 36, 36), mat = NEON },
	}
end

local function makeTruck(prefix: string, carId: string, accent: Color3)
	local looks = looksFor(accent)
	local function lookOf(name: string)
		if looks[name] then
			return looks[name]
		elseif string.sub(name, 1, 5) == "Wheel" then
			return TYRE
		elseif string.sub(name, 1, 8) == "RimChrome" then
			return looks.Chrome
		elseif string.sub(name, 1, 7) == "RimDark" then
			return looks.Dark
		elseif string.sub(name, 1, 3) == "Rim" then
			return looks.Accent
		end
		return nil
	end

	-- the imported meshes, wherever the importer put them (the name may be on the part or on its node)
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
	if next(found) == nil then
		print(prefix, "not imported, skipped")
		return
	end

	local model = Instance.new("Model")
	model.Name = carId
	local count = 0
	for name, part in found do
		local look = lookOf(name)
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
		warn(prefix, "is missing:", table.concat(missing, ", "), "- import the .obj files again")
		model:Destroy()
		return
	end

	local body = model:FindFirstChild("Body") :: BasePart
	local centre = body.Position
	-- nose at +Z: if the importer turned it round, turn the whole car back
	if (model.Headlights :: BasePart).Position.Z < centre.Z then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CFrame = CFrame.new(centre) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(-centre) * p.CFrame)
			end
		end
		print(carId, "turned the car round (its nose was at -Z)")
	end
	-- left at +X: if the importer mirrored it, swap the left and right names
	if (model.WheelFL :: BasePart).Position.X < centre.X then
		for _, p in model:GetChildren() do
			local pre, side = string.match(p.Name, "^(.-)([FR][LR])$")
			if pre and (pre == "Wheel" or string.sub(pre, 1, 3) == "Rim") then
				local swapped = (if string.sub(side, 2, 2) == "L" then "R" else "L")
				p.Name = pre .. string.sub(side, 1, 1) .. swapped
			end
		end
		print(carId, "swapped left and right (the importer mirrored X)")
	end

	model.PrimaryPart = body
	model:SetAttribute("Kart", true)
	model:SetAttribute("Extras", true)
	model:SetAttribute("MaxTurn", MAX_TURN)

	local old = skins:FindFirstChild(carId)
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
	print("CarSkins." .. carId, "made with", count, "parts.")
end

for _, t in TRUCKS do
	makeTruck(t.prefix, t.id, t.accent)
end
print("Rocket trucks done. Save the place (Ctrl+S).")
