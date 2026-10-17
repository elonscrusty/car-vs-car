--!strict
-- Real (Blender) models for the lobby. They live in ServerStorage.Models.Props, are named like
-- the file they came from, and have their pivot at the bottom centre with the front toward -Z.
-- Lobby.build and LobbyDetail.build first make plain blocks for everything; this module then swaps
-- each block set for its model. A missing model leaves the blocks in place, so nothing breaks.
-- Everything here is look only (no collision); the invisible block colliders stay.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyProps = {}

type Spot = { name: string, x: number, z: number, face: number, y: number?, scale: number? }

-- face: degrees. 0 looks toward the back wall (-Z), 180 toward the gate, 90 toward -X, -90 toward +X.
local SPOTS: { Spot } = {
	-- cones along the pad row and at the door
	{ name = "traffic_cone", x = -9, z = 40, face = 0, scale = 1.4 },
	{ name = "traffic_cone", x = 9, z = 40, face = 0, scale = 1.4 },
	-- front-left corner: gas cans, a chest and a cart
	{ name = "gas_can", x = -54, z = 40, face = 25, scale = 1.6 },
	{ name = "gas_can", x = -52.5, z = 41.5, face = -20, scale = 1.6 },
	{ name = "tool_chest_yellow", x = -42, z = 43.2, face = 0, scale = 1.3 },
	-- front-right corner: a drum cluster
	{ name = "oil_drum", x = 55, z = 37, face = 20, scale = 1.2 },
	{ name = "oil_drum_yellow", x = 53, z = 39.5, face = 70, scale = 1.2 },
	{ name = "oil_drum_red", x = 55, z = 41, face = 130, scale = 1.2 },
	-- right side: tires, a chest
	{ name = "tire_stack", x = 56, z = -8, face = 0, scale = 1.3 },
	{ name = "tire_stack", x = 53.5, z = -9.5, face = 40, scale = 1.3 },
	{ name = "tool_chest_cyan", x = 56, z = -2, face = 90, scale = 1.3 },
	{ name = "tool_cart_yellow", x = 36, z = -32, face = 90, scale = 1.2 },
	-- back wall pegboards
	{ name = "pegboard_tools", x = -28, z = -44.6, face = 180, y = 5, scale = 1.4 },
	{ name = "pegboard_tools", x = 28, z = -44.6, face = 180, y = 5, scale = 1.4 },
}

-- Names of the block parts each model replaces (all removed when the model exists).
local CART_PARTS = { "CartBody", "CartTop", "CartDrawer", "CartHandle", "CartWheel", "CartWrench" }
local RACK_PARTS = { "RackPost", "RackShelf", "RackTire" }
local SOFA_PARTS = { "SofaSeat", "SofaBack", "SofaArm", "SofaCushion" }
local DOOR_PARTS = { "RollerDoorFrame", "RollerDoor", "RollerSlat", "DoorWindow" }
local LAMP_PARTS = { "LampCord", "LampShade" }
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

local function names(list: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, n in list do
		set[n] = true
	end
	return set
end

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
		local set = names(list)
		for _, d in folder:GetChildren() do
			if set[d.Name] then
				d:Destroy()
			end
		end
	end

	local room = LobbyLayout.room
	local top = room.wallHeight + 15 -- underside of the roof

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

	-- Roof: trusses across the hall in three lines instead of the many plain cross beams.
	if has("ceiling_truss") then
		for _, b in folder:GetChildren() do
			if b.Name == "RoofBeam" and b:IsA("BasePart") and b.Size.X > 100 then
				b:Destroy()
			end
		end
		local n = 7
		local piece = room.halfW * 2 / n
		for _, z in { -28, 0, 28 } do
			for i = 1, n do
				put(
					"ceiling_truss",
					at(-room.halfW + (i - 0.5) * piece, top - 3.7, z, 0),
					piece / 16.9
				)
			end
		end
	end

	-- Lamps: a hanging lamp model at every plain lamp.
	if has("hanging_lamp") then
		for _, g in folder:GetChildren() do
			if g.Name == "LampGlow" and g:IsA("BasePart") then
				put("hanging_lamp", CFrame.new(g.Position - Vector3.new(0, 0.5, 0)), 1.3)
				g.Transparency = 1
			end
		end
		remove(LAMP_PARTS)
	end

	-- Match pads: the model is the frame under each glowing pad.
	if has("match_pad") then
		remove({ "PadBase", "PadCorner" })
		for _, p in LobbyLayout.pads do
			put("match_pad", at(p.x, -0.6, p.z, 0), LobbyLayout.padSize / 10.9)
		end
	end

	-- Hero stage.
	local sc = LobbyLayout.showcase
	if has("truck_stage") then
		remove({ "ShowcaseSteps", "StageRail", "StageRailPost", "ShowcaseRing" })
		put("truck_stage", at(sc.x, 0, sc.z, 180), 1)
		local st = folder:FindFirstChild("ShowcaseStage")
		if st and st:IsA("BasePart") then
			st.Size = Vector3.new(22, 4.4, 16)
			st.Position = origin + Vector3.new(sc.x, 2.2, sc.z)
			st.Transparency = 1
		end
	end

	-- Store: counter model on the back wall; the plain counter stays as an invisible collider.
	local s = LobbyLayout.store
	if has("store_counter") then
		remove(STORE_PARTS)
		put("store_counter", at(s.x, 0, s.z - s.d / 2 + 3, 180), s.w / 13.8)
		local c = folder:FindFirstChild("StoreCounter")
		if c and c:IsA("BasePart") then
			c.Transparency = 1
			c.Size = Vector3.new(s.w, 4, 3)
			c.Position = origin + Vector3.new(s.x, 2, s.z - s.d / 2 + 6)
		end
		local sign = folder:FindFirstChild("StoreSign")
		if sign and sign:IsA("BasePart") then
			sign.Position = origin + Vector3.new(s.x, 15.2, s.z - s.d / 2 + 5.5)
		end
	end

	-- Car lift: the model replaces the plain posts and arms; the car stays and rides up and down.
	if has("car_lift") then
		remove({ "LiftPost", "LiftBeam", "LiftArm" })
		local l = LobbyLayout.lift
		put("car_lift", at(l.x, 0, l.z, 0), 1.1)
	end

	-- Side roller doors.
	if has("roller_door") then
		remove(DOOR_PARTS)
		put(
			"roller_door",
			CFrame.lookAt(
				origin + Vector3.new(-room.halfW + 0.9, 0, 32),
				origin + Vector3.new(0, 0, 32)
			),
			1
		)
		put(
			"roller_door",
			CFrame.lookAt(
				origin + Vector3.new(room.halfW - 0.9, 0, 28),
				origin + Vector3.new(0, 0, 28)
			),
			1
		)
	end

	-- Tool carts.
	if has("tool_cart") then
		remove(CART_PARTS)
		put("tool_cart", at(-30, 0, -26, 0), 1.25)
		put("tool_cart_yellow", at(28, 0, -26, 0), 1.25)
		put("tool_cart", at(-54, 0, 28, 90), 1.25)
	end

	-- Tire rack on the right wall.
	if has("tire_rack") then
		remove(RACK_PARTS)
		put(
			"tire_rack",
			CFrame.lookAt(
				origin + Vector3.new(room.halfW - 1.8, 0, 8),
				origin + Vector3.new(0, 0, 8)
			),
			1.7
		)
	end

	-- Lounge sofa facing the TV on the left wall.
	if has("sofa_cyan") then
		remove(SOFA_PARTS)
		put("sofa_cyan", at(-room.halfW + 9.3, 0, -16, 90), 1.15)
	end

	-- Tool wall workbench (front, left) and tool chest with drums (front, right).
	if has("workbench") then
		remove({ "Workbench", "WorkbenchLeg", "Toolbox" })
		put("workbench", at(-24, 0, room.halfL - 3.2, 0), 1.2)
	end
	if has("tool_chest") then
		remove({ "ToolCabinet", "ToolCabinetTop", "OilDrum" })
		put("tool_chest", at(20.5, 0, room.halfL - 3.2, 0), 1.4)
		put("oil_drum", at(26.2, 0, room.halfL - 3.2, 0), 1.1)
		put("oil_drum_yellow", at(29.4, 0, room.halfL - 3.2, 0), 1.1)
		put("oil_drum_red", at(32.6, 0, room.halfL - 3.2, 0), 1.1)
	end

	-- Scenery from Lobby.build: bench, tires, cones, planters.
	if has("bench_cyan") then
		remove({ "Bench", "BenchBack" })
		put("bench_cyan", at(33, 0, 40, 90), 1.4)
	end
	if has("tire_stack") then
		remove({ "Tire" })
		put("tire_stack", at(33, 0, 32, 0), 1.3)
	end
	if has("traffic_cone") then
		remove({ "Cone", "ConeBase" })
		put("traffic_cone", at(27, 0, 34, 0), 1.4)
		put("traffic_cone", at(24, 0, 37, 0), 1.4)
	end
	if has("plant_box") then
		remove({ "Planter", "Plant" })
		put("plant_box", at(-33, 0, -8, 90), 1.3)
		put("plant_box_yellow", at(-33, 0, 38, 90), 1.3)
		put("plant_box", at(33, 0, 28, -90), 1.3)
	end

	for _, spot in SPOTS do
		put(spot.name, at(spot.x, spot.y or 0, spot.z, spot.face), spot.scale or 1.4)
	end
end

return LobbyProps
