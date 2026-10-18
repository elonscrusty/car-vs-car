--!strict
-- Real (Blender) models for the lobby. They live in ServerStorage.Models.Props, are named like
-- the file they came from, and have their pivot at the bottom centre with the front toward -Z.
-- Lobby.build first makes plain parts for the shell (walls, pads, stage, store, lamps); this module
-- swaps each of those for its model, then places the prop clusters (garage corner, claw corner,
-- lounge, entrance). A missing model leaves the plain parts in place, so nothing breaks.
-- Everything placed here is look only (no collision); the plain colliders stay.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyProps = {}

type Spot = { name: string, x: number, z: number, face: number, y: number?, scale: number? }

-- face: degrees. 0 looks toward the back wall (-Z), 180 toward the gate, 90 toward -X, -90 toward +X.
local SPOTS: { Spot } = {
	-- Entrance (the garages are built into the side walls, so the floor stays open).
	{ name = "plant_box", x = -32, z = 63, face = 0, scale = 1.3 },
	{ name = "plant_box_yellow", x = 32, z = 63, face = 0, scale = 1.3 },
	{ name = "traffic_cone", x = -22, z = 58, face = 0, scale = 1.4 },
	{ name = "traffic_cone", x = 22, z = 58, face = 0, scale = 1.4 },
	{ name = "traffic_cone", x = -9, z = 44, face = 0, scale = 1.4 },
	{ name = "traffic_cone", x = 9, z = 44, face = 0, scale = 1.4 },
	-- Front corners, beside the store and the paint booth.
	{ name = "tire_stack", x = -58, z = 58, face = 0, scale = 1.3 },
	{ name = "tire_stack", x = 58, z = 54, face = 40, scale = 1.3 },
	{ name = "oil_drum", x = -59, z = 24, face = 20, scale = 1.2 },
	{ name = "oil_drum_yellow", x = 59, z = 26, face = 70, scale = 1.2 },
}

local STORE_PARTS = {
	"StoreBack",
	"Shelf",
	"ShelfTire",
	"ShelfHub",
	"ShelfBox",
	"StoreRoof",
	"StorePost",
	"CounterTop",
	"CounterGlow",
}

function LobbyProps.build(folder: Folder, origin: Vector3)
	local models = ServerStorage:FindFirstChild("Models")
	local props = if models then models:FindFirstChild("Props") else nil
	if props == nil then
		return
	end
	local group = Instance.new("Folder")
	group.Name = "Props"
	group.Parent = folder

	local function has(name: string): boolean
		local m = props:FindFirstChild(name)
		return m ~= nil and m:IsA("Model")
	end

	-- Clone a model, make it look-only, scale it and set it down (cf is its bottom centre).
	local function put(name: string, cf: CFrame, scale: number): Model?
		local src = props:FindFirstChild(name)
		if src == nil or not src:IsA("Model") then
			return nil
		end
		local m = src:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		m:ScaleTo(m:GetScale() * scale)
		m:PivotTo(cf)
		m.Parent = group
		return m
	end

	-- A spot on the floor: position (local x, y, z) and the way it faces.
	local function at(x: number, y: number, z: number, faceDeg: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, math.rad(faceDeg), 0)
	end

	local function remove(list: { string })
		local set: { [string]: boolean } = {}
		for _, n in list do
			set[n] = true
		end
		for _, d in folder:GetChildren() do
			if set[d.Name] then
				d:Destroy()
			end
		end
	end

	local room = LobbyLayout.room
	local top = room.wallHeight + room.upper -- underside of the roof

	-- Lower walls: panel models in front of the plain red walls.
	if has("garage_wall_panel") then
		for _, w in folder:GetChildren() do
			if w.Name == "Wall" and w:IsA("BasePart") then
				local s = math.min(0.75, w.Size.X / 16.5)
				put(
					"garage_wall_panel",
					w.CFrame * CFrame.new(0, -w.Size.Y / 2, -w.Size.Z / 2 - 0.6),
					s
				)
			end
		end
		remove({ "WallPanel", "WallStrip" })
	end

	-- Roof: trusses across the hall in two lines (the plain beams cover the rest).
	if has("ceiling_truss") then
		local n = 11
		local piece = room.halfW * 2 / n
		local s = piece / 16.9
		for _, z in { -36, 36 } do
			for i = 1, n do
				put("ceiling_truss", at(-room.halfW + (i - 0.5) * piece, top - 3.8 * s, z, 0), s)
			end
		end
	end

	-- Lamps: a hanging lamp model at every plain lamp (the cords stay).
	if has("hanging_lamp") then
		for _, g in folder:GetChildren() do
			if g.Name == "LampGlow" and g:IsA("BasePart") then
				put("hanging_lamp", CFrame.new(g.Position - Vector3.new(0, 0.5, 0)), 1.4)
				g.Transparency = 1
			end
		end
		remove({ "LampShade" })
	end

	-- Match pads: the model is the frame under each glowing pad.
	if has("match_pad") then
		remove({ "PadBase", "PadCorner" })
		local s = LobbyLayout.padSize / 10.9
		for _, p in LobbyLayout.pads do
			put("match_pad", at(p.x, 0.8 - 1.0 * s, p.z, 0), s)
		end
	end

	-- Hero stage.
	local sc = LobbyLayout.showcase
	if has("truck_stage") then
		remove({ "ShowcaseSteps", "StageRail", "StageRailPost", "ShowcaseRing" })
		local s = sc.footprint / 24
		put("truck_stage", at(sc.x, 0, sc.z, 180), s)
		local st = folder:FindFirstChild("ShowcaseStage")
		if st and st:IsA("BasePart") then
			st.Size = Vector3.new(sc.footprint - 2, 4.4 * s, 18.1 * s - 2)
			st.Position = origin + Vector3.new(sc.x, 2.2 * s, sc.z)
			st.Transparency = 1
		end
	end

	-- Store: counter model; the plain counter stays as an invisible collider. The store is built
	-- facing +z around its centre and turned toward the lane, so everything is turned the same way.
	local s = LobbyLayout.store
	local centre = origin + Vector3.new(s.x, 0, s.z)
	local turn = CFrame.new(centre) * CFrame.Angles(0, math.rad(s.yaw), 0) * CFrame.new(-centre)
	if has("store_counter") then
		remove(STORE_PARTS)
		put("store_counter", turn * at(s.x, 0, s.z - s.d / 2 + 3, 180), s.w / 13.8)
		local c = folder:FindFirstChild("StoreCounter")
		if c and c:IsA("BasePart") then
			c.Transparency = 1
			c.Size = Vector3.new(s.w, 4, 3)
			c.CFrame = turn * CFrame.new(origin + Vector3.new(s.x, 2, s.z - s.d / 2 + 6.5))
		end
		local sign = folder:FindFirstChild("StoreSign")
		if sign and sign:IsA("BasePart") then
			sign.CFrame = turn
				* CFrame.lookAt(
					origin + Vector3.new(s.x, 15.4, s.z - s.d / 2 + 5.5),
					origin + Vector3.new(s.x, 15.4, s.z + 40)
				)
		end
	end

	-- Roller doors under the walkway on the back wall.
	if has("roller_door") then
		for _, x in { -36, -12, 12, 36 } do
			put("roller_door", at(x, 0, -room.halfL + 0.9, 180), 0.9)
		end
	end

	for _, spot in SPOTS do
		put(spot.name, at(spot.x, spot.y or 0, spot.z, spot.face), spot.scale or 1.4)
	end
end

return LobbyProps
