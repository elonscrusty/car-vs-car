-- Studio command bar, EDIT mode (not Play), run once (Lead + carter OK needed: it uploads the kart
-- meshes as assets to carter's account; it does NOT publish the game).
-- Bakes every kart in KartMeshData into ReplicatedStorage.CarSkins.<Kart_*> as plain MeshParts, so the
-- game needs no EditableMesh at runtime (carter's PC had no EditableMesh memory; phones may not
-- either). CarSkin uses CarSkins.<Kart_*> before building anything. Wheels: tyre dark, rim white,
-- attribute RimTint (CarSkin.paintKart tints them to the rim colour). Then carter saves (Ctrl+S).
-- Needs Game Settings > Security > "Allow Mesh / Image APIs" on. Safe to re-run: done karts are skipped.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local KartCode = require(RS.Shared.KartCode)
local Data = require(RS.Shared.KartMeshData)
local skins = RS:FindFirstChild("CarSkins")
if not skins then
	skins = Instance.new("Folder")
	skins.Name = "CarSkins"
	skins.Parent = RS
end
local TIRE, RIM = Color3.fromRGB(28, 28, 30), Color3.new(1, 1, 1)
-- mesh data key -> { id, mid }: parts several karts share upload once. Kept in _G so running the
-- script again after a failure reuses what was already uploaded instead of uploading copies.
_G.KartBakeUploads = _G.KartBakeUploads or {}
local uploaded = _G.KartBakeUploads

-- same geometry as KartMesh.meshPart: centred on its middle, flat shaded, optional vertex colours
local function editable(pieces)
	local all, lo, hi = {}, Vector3.one * math.huge, -Vector3.one * math.huge
	for i, piece in pieces do
		local v = KartCode.verts(piece.mesh.v)
		all[i] = v
		for k = 1, #v, 3 do
			local p = Vector3.new(v[k], v[k + 1], v[k + 2])
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
	local mid = (lo + hi) / 2
	local em = AssetService:CreateEditableMesh()
	assert(em, "no EditableMesh memory: close other places/plugins and run again")
	for i, piece in pieces do
		local v, ids, at = all[i], {}, {}
		for k = 1, #v, 3 do
			local p = Vector3.new(v[k], v[k + 1], v[k + 2]) - mid
			table.insert(at, p)
			table.insert(ids, em:AddVertex(p))
		end
		local col = piece.color and em:AddColor(piece.color, 1)
		local t = KartCode.tris(piece.mesh.t, piece.mesh.w)
		for k = 1, #t, 3 do
			local a, b, c = t[k], t[k + 1], t[k + 2]
			local n = (at[b] - at[a]):Cross(at[c] - at[a])
			if n.Magnitude > 1e-9 then
				local f = em:AddTriangle(ids[a], ids[b], ids[c])
				local nid = em:AddNormal(n.Unit)
				em:SetFaceNormals(f, { nid, nid, nid })
				if col then
					em:SetFaceColors(f, { col, col, col })
				end
			end
		end
	end
	return em, mid
end

local function part(name, pieces, label)
	local key = ""
	for _, piece in pieces do
		key ..= piece.mesh.v .. "|" .. piece.mesh.t .. "|" .. (if piece.color then "c" else "") .. "|"
	end
	local done = uploaded[key]
	if not done then
		local em, mid = editable(pieces)
		local ok, result, newId = pcall(function()
			return AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = label })
		end)
		em:Destroy()
		assert(ok and result == Enum.CreateAssetResult.Success, `upload {label} failed: {result}`)
		done = { id = newId, mid = mid }
		uploaded[key] = done
		print("uploaded", label, newId)
	end
	local p
	for try = 1, 5 do -- a new upload can take a moment before it loads
		local ok, res = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromUri("rbxassetid://" .. done.id),
				{ CollisionFidelity = Enum.CollisionFidelity.Box }
			)
		end)
		if ok then
			p = res
			break
		end
		warn(`{label}: mesh {done.id} not ready ({res}), try {try}/5`)
		task.wait(3 * try)
	end
	assert(p, `{label}: mesh {done.id} never loaded; run the script again (uploads are reused)`)
	p.Name = name
	p.Color = Color3.new(1, 1, 1)
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.new(done.mid)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	return p
end

for kartName, kart in Data do
	if skins:FindFirstChild(kartName) then
		print("skip", kartName, "(already baked)")
		continue
	end
	local m = Instance.new("Model")
	m.Name = kartName
	for g, mesh in kart do
		if g:sub(1, 5) ~= "Wheel" and g:sub(1, 3) ~= "Rim" then
			part(g, { { mesh = mesh } }, kartName .. "_" .. g).Parent = m
		end
	end
	for _, w in { "WheelFL", "WheelFR", "WheelRL", "WheelRR" } do
		local pieces = { { mesh = kart[w], color = TIRE } }
		local rim = kart["Rim" .. w:sub(6)]
		if rim then
			table.insert(pieces, { mesh = rim, color = RIM })
		end
		local p = part(w, pieces, kartName .. "_" .. w)
		p:SetAttribute("RimTint", true)
		p.Parent = m
	end
	m.WorldPivot = CFrame.identity
	m.Parent = skins
	print("baked", kartName)
end
print(
	"kart bake done: ReplicatedStorage.CarSkins now holds",
	#skins:GetChildren(),
	"models; save the place (Ctrl+S)"
)
