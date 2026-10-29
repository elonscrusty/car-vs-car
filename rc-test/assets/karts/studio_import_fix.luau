-- Studio command bar, EDIT mode, after carter imported the kart .fbx files (File > Import 3D, see
-- /mnt/project-files/car-vs-car/cars/import/IMPORT-STEPS.md). Moves every imported Kart_* model from
-- Workspace into ReplicatedStorage.CarSkins (where CarSkin looks for karts by name), makes its parts
-- look-only, drops any texture the importer added (CarSkin paints each part by its name), and
-- checks it has Body and WheelFL/FR/RL/RR. Safe to run again. Then save the place (Ctrl+S).
-- Takes the one-file import too (Karts.fbx, export_fbx.py ALL=1): parts named "Kart_Buggy__Body" are
-- sorted into one Kart_Buggy model each, wherever the importer put them, and the empty import goes.
local RS = game:GetService("ReplicatedStorage")
local skins = RS:FindFirstChild("CarSkins")
if not skins then
	skins = Instance.new("Folder")
	skins.Name = "CarSkins"
	skins.Parent = RS
end
local NEED = {
	"Body",
	"WheelFL",
	"WheelFR",
	"WheelRL",
	"WheelRR",
	"RimFL",
	"RimFR",
	"RimRL",
	"RimRR",
	"Headlights", -- (CarSkin finds the nose by it)
}
-- the one-file import: sort "Kart_X__Part" parts into a Kart_X model each
local sorted: { [string]: Model } = {}
for _, top in workspace:GetChildren() do
	local took = false
	for _, d in top:GetDescendants() do
		local kart, part = d.Name:gsub("%.%d+$", ""):match("^(Kart_%w+)__(.+)$")
		if kart and d:IsA("BasePart") then
			local m = sorted[kart]
			if not m then
				m = Instance.new("Model")
				m.Name = kart
				m.Parent = workspace
				sorted[kart] = m
			end
			d.Name = part
			d.Parent = m
			took = true
		end
	end
	if took and not top.Name:match("^Kart_%w+$") then
		local left = false
		for _, d in top:GetDescendants() do
			left = left or d:IsA("BasePart")
		end
		if not left then
			top:Destroy()
		end
	end
end

for _, m in workspace:GetChildren() do
	if m:IsA("Model") and m.Name:match("^Kart_") then
		local old = skins:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		for _, d in m:GetDescendants() do
			-- ("Body.001" from a Blender copy: CarSkin finds and paints parts by their exact name)
			d.Name = d.Name:gsub("%.%d+$", "")
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
				d:Destroy()
			end
		end
		local missing = {}
		for _, n in NEED do
			if not m:FindFirstChild(n, true) then
				table.insert(missing, n)
			end
		end
		local box = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(box.Position) -- (no tilt: CarSkin turns it round its pivot)
		m.Parent = skins
		print(m.Name, if #missing == 0 then "OK" else "MISSING " .. table.concat(missing, ", "))
	end
end
print("CarSkins now holds:", #skins:GetChildren(), "models. Save the place (Ctrl+S).")
