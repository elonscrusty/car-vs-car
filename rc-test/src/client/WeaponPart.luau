--!strict
-- A weapon part that clicks onto ANY car (carter 10-29 22:35: cars only look different, weapons are
-- shared parts on the roof or the front). Finds the car's Body, works out the mount spot from its
-- size (shared/WeaponMounts), builds the weapon's parts there (shared/WeaponLooks) and welds them
-- on, so the weapon is one rigid piece of the car.
--
-- Look only: the server decides every shot (server/weapons/Gun), and where a bullet leaves is the
-- Gun's own fixed muzzle, so a skin that changes the look never changes how the gun plays.
--
-- The model keeps an Attachment "WeaponMount_<Mount>" on its Body (the saddle) and a Folder
-- "Weapon<Mount>" with the parts and welds. CarSkin carries the parts on the driving car and
-- OtherCars on everyone else's (both take every loose part of the model); the welds are for models
-- that sit still in the world (the garage). To swap the look (a weapon skin): addTo again with
-- another skin id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FireDrake = require(script.Parent.FireDrake)
local WeaponLooks = require(ReplicatedStorage.Shared.WeaponLooks)
local WeaponMounts = require(ReplicatedStorage.Shared.WeaponMounts)

local WeaponPart = {}

local MIN_SIZE = 0.05 -- Roblox's smallest part

local function color(key: string): Color3
	local c = WeaponLooks.COLORS[key] or WeaponLooks.COLORS.steel
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function made(spec: WeaponLooks.Part, u: number, saddle: CFrame): BasePart
	local p: BasePart
	if spec.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = "Weapon" .. spec.name
	p.Size = Vector3.new(
		math.max(spec.size[1] * u, MIN_SIZE),
		math.max(spec.size[2] * u, MIN_SIZE),
		math.max(spec.size[3] * u, MIN_SIZE)
	)
	p.CFrame = saddle
		* CFrame.new(spec.at[1] * u, spec.at[2] * u, spec.at[3] * u)
		* CFrame.Angles(math.rad(spec.rot[1]), math.rad(spec.rot[2]), math.rad(spec.rot[3]))
	p.Color = color(spec.mat)
	p.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Massless = true
	p.CastShadow = false
	return p
end

local function weld(a: BasePart, b: BasePart, into: Instance)
	local w = Instance.new("WeldConstraint")
	w.Name = "Weld"
	w.Part0, w.Part1 = a, b
	w.Parent = into
end

-- Clicks weapon `weapon` (a shared/Weapons name) onto `model`, in the look `skin` (a WeaponLooks id;
-- nil = the weapon's own). Replaces a weapon already on that mount. False if the weapon has no
-- look or the model has no Body to click onto.
function WeaponPart.addTo(model: Model, weapon: string, skin: string?): boolean
	local look = WeaponLooks.forWeapon(weapon, skin)
	if not look then
		return false
	end
	local body = model:FindFirstChild("Body", true)
	if not (body and body:IsA("BasePart")) or body.Size.Z <= 0 then
		return false
	end
	local folderName = "Weapon" .. look.mount
	local old = model:FindFirstChild(folderName)
	if old then
		if model:GetAttribute(folderName) == look.id then
			return true
		end
		old:Destroy()
		local oldSaddle = body:FindFirstChild("WeaponMount_" .. look.mount)
		if oldSaddle then
			oldSaddle:Destroy()
		end
	end
	local nose = FireDrake.noseSign(body, model)
	local at = WeaponMounts.offset(look.mount, body.Size.X, body.Size.Y, body.Size.Z, nose)
	if not at then
		return false
	end
	local saddle = body.CFrame * CFrame.new(at.x, at.y, at.z)
	if nose < 0 then
		saddle = saddle * CFrame.Angles(0, math.pi, 0) -- (the weapon's own +Z is the nose)
	end
	local mountPoint = Instance.new("Attachment")
	mountPoint.Name = "WeaponMount_" .. look.mount
	mountPoint.CFrame = body.CFrame:ToObjectSpace(saddle)
	mountPoint.Parent = body

	local u = WeaponMounts.scale(body.Size.Z)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder:SetAttribute("WeaponMount", look.mount)
	local first: BasePart? = nil
	for _, spec in look.parts do
		local p = made(spec, u, saddle)
		p.Parent = folder
		if first then
			weld(first, p, folder)
		else
			first = p
			weld(body, p, folder) -- the first part clicks onto the car, the rest hang off it
		end
	end
	folder.Parent = model
	model:SetAttribute(folderName, look.id)
	return true
end

return WeaponPart
