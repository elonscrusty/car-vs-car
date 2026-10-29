-- Studio command bar, EDIT mode, after carter imported the kart .fbx files (File > Import 3D, see
-- /mnt/project-files/car-vs-car/cars/import/IMPORT-STEPS.md). Moves every imported Kart_* model from
-- Workspace into ReplicatedStorage.CarSkins (where CarSkin looks for karts by name), makes its parts
-- look-only, drops any texture the importer added (CarSkin paints each part by its name), and
-- checks it has Body and WheelFL/FR/RL/RR. Safe to run again. Then save the place (Ctrl+S).
local RS = game:GetService("ReplicatedStorage")
local skins = RS:FindFirstChild("CarSkins")
if not skins then
	skins = Instance.new("Folder")
	skins.Name = "CarSkins"
	skins.Parent = RS
end
local NEED = { "Body", "WheelFL", "WheelFR", "WheelRL", "WheelRR" }
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and m.Name:match("^Kart_") then
		local old = skins:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		for _, d in m:GetDescendants() do
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
		m.WorldPivot = CFrame.new(m:GetPivot().Position) -- (no tilt: CarSkin turns it round its pivot)
		m.Parent = skins
		print(m.Name, if #missing == 0 then "OK" else "MISSING " .. table.concat(missing, ", "))
	end
end
print("CarSkins now holds:", #skins:GetChildren(), "models. Save the place (Ctrl+S).")
