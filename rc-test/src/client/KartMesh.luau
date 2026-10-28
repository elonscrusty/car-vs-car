--!strict
-- The karts (KartMeshData, made in assets/karts/: 6 from Blender, carter's own Meshy one) built as MeshParts while the game runs
-- (EditableMesh), so nobody has to import a model in Studio. KartMesh.get(name, rim) gives that
-- kart as a Model (nose +Z, ground at y = 0, parts named for ToyCars.kartPaint), or nil while it is
-- still being built, or for good when this device can't build meshes: then the part toy car shows.
-- The wheels carry their rim colour in the mesh (tyre dark, rim coloured), so they're built per rim.
-- carter's own models in ReplicatedStorage.CarSkins still win over these (CarSkin.kartFor).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KartMeshData = require(ReplicatedStorage.Shared.KartMeshData)

local KartMesh = {}

local TIRE = Color3.fromRGB(28, 28, 30)
local WHEELS = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

local bodies: { [string]: { BasePart } } = {} -- a kart's parts but its wheels, by kart name
local wheels: { [string]: { BasePart } } = {} -- a kart's 4 wheels, by kart name and rim colour
local made: { [string]: Model } = {}
local busy: { [string]: boolean } = {}
local broken = false -- one build failed: this device can't, so stop trying

local function nums(s: string): { number }
	local out = {}
	for n in string.gmatch(s, "-?%d+") do
		table.insert(out, tonumber(n) :: number)
	end
	return out
end

type Piece = { mesh: KartMeshData.Mesh, color: Color3? }

-- One MeshPart from one or more pieces of the data. A piece with a colour gets it as vertex colours
-- (the wheels: tyre and rim in one spinning part, the part itself white); the others take the
-- part's Color (CarSkin.paintKart). Flat shaded: every face has its own normal. Placed at its middle.
local function meshPart(name: string, pieces: { Piece }): MeshPart
	local all: { { number } } = {}
	local lo = Vector3.one * math.huge
	local hi = -lo
	for i, piece in pieces do
		local v = nums(piece.mesh.v)
		all[i] = v
		for k = 1, #v, 3 do
			local p = Vector3.new(v[k], v[k + 1], v[k + 2]) / 100
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
	local mid = (lo + hi) / 2
	local em: any = (AssetService :: any):CreateEditableMesh()
	if not em then
		error("no EditableMesh (memory budget)")
	end
	for i, piece in pieces do
		local v = all[i]
		local ids: { number } = {}
		local at: { Vector3 } = {}
		for k = 1, #v, 3 do
			local p = Vector3.new(v[k], v[k + 1], v[k + 2]) / 100 - mid
			table.insert(at, p)
			table.insert(ids, em:AddVertex(p))
		end
		local col = if piece.color then em:AddColor(piece.color, 1) else nil
		local t = nums(piece.mesh.t)
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
	local part: MeshPart = (AssetService :: any):CreateMeshPartAsync(Content.fromObject(em))
	part.Name = name
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(mid)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function build(name: string, rim: Color3, key: string): Model
	local data = KartMeshData[name]
	local own = bodies[name]
	if not own then
		own = {}
		for g, mesh in data do
			if string.sub(g, 1, 5) ~= "Wheel" and string.sub(g, 1, 3) ~= "Rim" then
				table.insert(own, meshPart(g, { { mesh = mesh } }))
			end
		end
		bodies[name] = own
	end
	local round = wheels[key]
	if not round then
		round = {}
		for _, w in WHEELS do
			local pieces: { Piece } = { { mesh = data[w], color = TIRE } }
			local r = data["Rim" .. string.sub(w, 6)]
			if r then
				table.insert(pieces, { mesh = r, color = rim })
			end
			local p = meshPart(w, pieces)
			-- (its colours are in the mesh: CarSkin.paintKart leaves it white)
			p:SetAttribute("Baked", true)
			table.insert(round, p)
		end
		wheels[key] = round
	end
	local m = Instance.new("Model")
	m.Name = name
	for _, p in own do
		p:Clone().Parent = m
	end
	for _, p in round do
		p:Clone().Parent = m
	end
	m.WorldPivot = CFrame.identity -- (the data's origin: the ground under the kart's middle)
	return m
end

-- The kart `name` with `rim` coloured rims, or nil while it is being built (call again next frame;
-- the build starts on the first call) or when this device can't build meshes.
function KartMesh.get(name: string, rim: { number }): Model?
	local key = name .. "/" .. table.concat(rim, ",")
	local m = made[key]
	if m or broken or busy[key] or not KartMeshData[name] then
		return m
	end
	busy[key] = true
	task.spawn(function()
		local ok, res = pcall(build, name, Color3.fromRGB(rim[1], rim[2], rim[3]), key)
		if ok then
			made[key] = res
		else
			broken = true
			warn(`KartMesh: can't build karts here, the toy cars show instead ({res})`)
		end
		busy[key] = nil
	end)
	return nil
end

return KartMesh
