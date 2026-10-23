--!strict
-- Builds the water round the lobby (LobbyWater: bank, shore, water, docks, island, footbridge)
-- into workspace.Lobby.Water. Looks only. Called at the end of LobbyBuilder.build().
-- carter's Meshy props (MeshProps) replace the block ones when imported: Footbridge copies span
-- the island gap over an invisible flat walkway; Rowboat and LifeRing take the block boat's and
-- rings' places.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyWater = require(ReplicatedStorage.Shared.LobbyWater)
local LobbyProps = require(script.Parent.LobbyProps)
local MeshProps = require(script.Parent.MeshProps)

local LobbyWaterBuilder = {}

-- World-aligned box round every part of a model.
local function extents(m: Model): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, h = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	return lo, hi
end

-- Box round every part of a model, measured in `frame`'s own axes.
local function extentsIn(m: Model, frame: CFrame): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, h = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = frame:PointToObjectSpace(
							cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						)
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	return lo, hi
end

-- Turn a placed model round its pivot by `turn` (in `frame`'s axes), keeping it on its spot.
local function turnIn(m: Model, frame: CFrame, turn: CFrame)
	local rel = frame:ToObjectSpace(m:GetPivot())
	m:PivotTo(frame * turn * rel)
end

-- Move a model so its box (in `frame`'s axes) has its middle at local `mid`, or its bottom at
-- local mid.Y when `bottom` is set.
local function boxTo(m: Model, frame: CFrame, mid: Vector3, bottom: boolean?)
	local lo, hi = extentsIn(m, frame)
	local now = (lo + hi) / 2
	if bottom then
		now = Vector3.new(now.X, lo.Y, now.Z)
	end
	m:PivotTo(m:GetPivot() + frame:VectorToWorldSpace(mid - now))
end

-- carter's Rowboat at the boat spot: long side along the bow line, `len` studs long, sitting
-- low in the water. false when it isn't imported.
local function meshBoat(folder: Instance, len: number): boolean
	local x, z, ry = LobbyWater.boatSpot()
	local frame = CFrame.new(x, LobbyWater.WATER_TOP, z) * CFrame.Angles(0, math.rad(ry), 0)
	-- MeshProps looks along -z of its CFrame; our frame's front is +z, so turn it round
	local m = MeshProps.place(folder, "Rowboat", frame * CFrame.Angles(0, math.pi, 0), 2)
	if not m then
		return false
	end
	local lo, hi = extentsIn(m, frame)
	if hi.X - lo.X > hi.Z - lo.Z then
		turnIn(m, frame, CFrame.Angles(0, math.pi / 2, 0)) -- long side runs across: turn it
		lo, hi = extentsIn(m, frame)
	end
	m:ScaleTo(m:GetScale() * len / (hi.Z - lo.Z))
	lo, hi = extentsIn(m, frame)
	boxTo(m, frame, Vector3.new(0, -(hi.Y - lo.Y) * 0.4, 0), true)
	return true
end

-- carter's LifeRing hanging on each ring post, standing up and facing the deck, `across` studs
-- wide. false when it isn't imported.
local function meshRings(folder: Instance, across: number): boolean
	if not MeshProps.has("LifeRing") then
		return false
	end
	for _, r in LobbyWater.ringSpots() do
		local frame = CFrame.new(r.x, LobbyWater.DECK_TOP + LobbyWater.RING_UP, r.z)
			* CFrame.Angles(0, math.rad(r.ry), 0)
			* CFrame.new(0, 0, 0.5)
		local m =
			MeshProps.place(folder, "LifeRing", frame * CFrame.Angles(0, math.pi, 0), 1) :: Model
		-- the thin side must face the deck (local z)
		local lo, hi = extentsIn(m, frame)
		local size = hi - lo
		if size.Y < size.Z and size.Y < size.X then
			turnIn(m, frame, CFrame.Angles(math.pi / 2, 0, 0)) -- lying flat: stand it up
		elseif size.X < size.Z then
			turnIn(m, frame, CFrame.Angles(0, math.pi / 2, 0))
		end
		lo, hi = extentsIn(m, frame)
		m:ScaleTo(m:GetScale() * across / math.max(hi.X - lo.X, hi.Y - lo.Y))
		boxTo(m, frame, Vector3.zero)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	return true
end

-- Meshy footbridges end to end from x0 to x1 at depth z, plus the walkway you actually walk on.
-- false when the mesh isn't imported.
local function meshBridge(folder: Instance, x0: number, x1: number, z: number): boolean
	if not MeshProps.has("Footbridge") then
		return false
	end
	local gap = x1 - x0
	local deck = LobbyWater.DECK_TOP
	-- one copy to measure: which way is it long, and how long
	local look = CFrame.lookAt(Vector3.new(x0, 0, z), Vector3.new(x0 + 1, 0, z))
	local probe = MeshProps.place(folder, "Footbridge", look, 3.5) :: Model
	local lo, hi = extents(probe)
	if hi.Z - lo.Z > hi.X - lo.X then
		look *= CFrame.Angles(0, math.pi / 2, 0) -- its long side runs across: turn it
		probe:PivotTo(look)
		lo, hi = extents(probe)
	end
	probe:Destroy()
	local len, height = hi.X - lo.X, hi.Y - lo.Y
	local n = math.max(1, math.floor(gap / len + 0.5))
	local scale = gap / n / len -- stretch evenly so the copies meet both ends
	for i = 0, n - 1 do
		local m = MeshProps.place(folder, "Footbridge", look, height * scale) :: Model
		local a, b = extents(m)
		-- its deck sits about a third of the way up; put that at deck height
		local target = Vector3.new(x0 + gap * i / n, deck - (b.Y - a.Y) * 0.35, z - (b.Z - a.Z) / 2)
		m:PivotTo(m:GetPivot() + (target - a))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	local walk = LobbyProps.part(
		folder,
		"BridgeWalk",
		Vector3.new(gap + 1, 0.5, 4.5),
		CFrame.new((x0 + x1) / 2, deck - 0.25, z),
		Color3.new()
	)
	walk.Transparency = 1
	return true
end

function LobbyWaterBuilder.build(lobby: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Water"
	local x0, x1, bz = LobbyWater.bridgeSpan()
	local meshy = meshBridge(folder, x0, x1, bz)
	local meshyBoat = meshBoat(folder, 7.5)
	local meshyRings = meshRings(folder, 2.2)
	for _, pc in LobbyWater.pieces() do
		if meshy and string.sub(pc.name, 1, 6) == "Bridge" then
			continue
		elseif meshyBoat and string.sub(pc.name, 1, 4) == "Boat" then
			continue
		elseif meshyRings and pc.name == "Buoy" then
			continue
		end
		local cf = CFrame.new(pc.x, pc.y, pc.z)
			* CFrame.Angles(0, math.rad(pc.ry), 0)
			* CFrame.Angles(0, 0, math.rad(pc.rz))
		local size = Vector3.new(pc.sx, pc.sy, pc.sz)
		if pc.round then
			-- a Cylinder's round faces point along its X, so stand it up
			cf *= CFrame.Angles(0, 0, math.rad(90))
			size = Vector3.new(pc.sy, pc.sx, pc.sz)
		end
		local p = LobbyProps.part(
			folder,
			pc.name,
			size,
			cf,
			Color3.fromRGB(pc.color[1], pc.color[2], pc.color[3]),
			if pc.round then Enum.PartType.Cylinder else nil
		)
		p.CanCollide = pc.collide
		if not pc.collide then
			p.CanQuery = false
			p.CanTouch = false
		end
		if pc.hidden then
			p.Transparency = 1
		end
		-- nothing here moves, so let the engine skip shadows on the big flat sheets
		if pc.sx * pc.sz > 2000 then
			p.CastShadow = false
		end
	end
	folder.Parent = lobby
end

return LobbyWaterBuilder
