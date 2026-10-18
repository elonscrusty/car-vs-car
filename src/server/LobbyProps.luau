--!strict
-- Small Blender props for the lobby (roller doors, plants, cones, tires, drums). They live in
-- ServerStorage.Models.Props, are named like the file they came from, and have their pivot at the
-- bottom centre with the front toward -Z. A missing model is simply skipped. Props are look only (no collision); the booths are solid.

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
	{ name = "traffic_cone", x = -18, z = 56, face = 0, scale = 1.4 },
	{ name = "traffic_cone", x = 18, z = 56, face = 0, scale = 1.4 },
	-- Front corners, beside the store and the paint booth.
	{ name = "tire_stack", x = -58, z = 58, face = 0, scale = 1.3 },
	{ name = "tire_stack", x = 58, z = 54, face = 40, scale = 1.3 },
	{ name = "oil_drum", x = -59, z = 24, face = 20, scale = 1.2 },
	{ name = "oil_drum_yellow", x = 59, z = 26, face = 70, scale = 1.2 },
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

	local room = LobbyLayout.room

	-- Roller doors on the back wall, either side of the stage.
	if has("roller_door") then
		for _, x in { -36, -12, 12 } do
			put("roller_door", at(x, 0, -room.halfL + 0.9, 180), 0.9)
		end
	end

	-- The store and paint booths: the imported model stands where the plain booth was. The plain
	-- parts go, except the counter that carries the prompt (it stays, invisible).
	local function swapBooth(
		tag: string,
		model: string,
		x: number,
		z: number,
		face: number,
		scale: number
	)
		if not has(model) then
			return
		end
		for _, item in folder:GetChildren() do
			if item:GetAttribute("Booth") == tag then
				if item:FindFirstChildWhichIsA("ProximityPrompt") then
					for _, d in item:GetChildren() do
						if not d:IsA("ProximityPrompt") then
							d:Destroy()
						end
					end
					local holder = item :: BasePart
					holder.Transparency = 1
					holder.CanCollide = false
				else
					item:Destroy()
				end
			end
		end
		local m = put(model, at(x, 0, z, face), scale)
		if m then
			for _, d in m:GetDescendants() do -- booths are solid: walk around them
				if d:IsA("MeshPart") then
					d.CanCollide = true
				end
			end
		end
	end
	local st, pt = LobbyLayout.store, LobbyLayout.paint
	swapBooth("store", "store_booth", st.x, st.z, -90, 1.1) -- front toward +x, the lane
	swapBooth("paint", "paint_booth", pt.x, pt.z, 90, 1.1) -- front toward -x

	for _, spot in SPOTS do
		put(spot.name, at(spot.x, spot.y or 0, spot.z, spot.face), spot.scale or 1.4)
	end
end

return LobbyProps
