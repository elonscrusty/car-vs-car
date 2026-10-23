--!strict
-- Builds the lake at the end of the lobby street (LobbyWater: bank, beach, water, docks, boats;
-- LobbyLake: fishing spots, raft, sailboat, beaches, ducks) into workspace.Lobby.Water. Called at
-- the end of LobbyBuilder.build().
-- carter's Meshy props (MeshProps) replace the block ones when imported: Rowboat and LifeRing
-- take the block boats' and rings' places, and each LobbyLake spot's mesh its block group.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyWater = require(ReplicatedStorage.Shared.LobbyWater)
local LobbyLake = require(ReplicatedStorage.Shared.LobbyLake)
local LobbyProps = require(script.Parent.LobbyProps)
local MeshProps = require(script.Parent.MeshProps)

local LobbyWaterBuilder = {}

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

-- carter's Rowboat at each boat spot: long side along the bow line, `len` studs long, sitting
-- low in the water. false when it isn't imported.
local function meshBoats(folder: Instance, len: number): boolean
	if not MeshProps.has("Rowboat") then
		return false
	end
	for _, b in LobbyWater.boatSpots() do
		local frame = CFrame.new(b.x, LobbyWater.WATER_TOP, b.z)
			* CFrame.Angles(0, math.rad(b.ry), 0)
		-- MeshProps looks along -z of its CFrame; our frame's front is +z, so turn it round
		local m =
			MeshProps.place(folder, "Rowboat", frame * CFrame.Angles(0, math.pi, 0), 2) :: Model
		local lo, hi = extentsIn(m, frame)
		if hi.X - lo.X > hi.Z - lo.Z then
			turnIn(m, frame, CFrame.Angles(0, math.pi / 2, 0)) -- long side runs across: turn it
			lo, hi = extentsIn(m, frame)
		end
		m:ScaleTo(m:GetScale() * len / (hi.Z - lo.Z))
		lo, hi = extentsIn(m, frame)
		boxTo(m, frame, Vector3.new(0, -(hi.Y - lo.Y) * 0.4, 0), true)
	end
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

-- One block piece as a Part (or a Seat).
local function makePart(folder: Instance, pc: LobbyLake.Piece)
	local cf = CFrame.new(pc.x, pc.y, pc.z)
		* CFrame.Angles(0, math.rad(pc.ry), 0)
		* CFrame.Angles(0, 0, math.rad(pc.rz))
	local size = Vector3.new(pc.sx, pc.sy, pc.sz)
	local color = Color3.fromRGB(pc.color[1], pc.color[2], pc.color[3])
	local p: BasePart
	if pc.seat then
		local seat = Instance.new("Seat")
		seat.Name = pc.name
		seat.Anchored = true
		seat.Size = size
		seat.CFrame = cf
		seat.Color = color
		seat.Material = Enum.Material.SmoothPlastic
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.Parent = folder
		p = seat
	else
		if pc.round then
			-- a Cylinder's round faces point along its X, so stand it up
			cf *= CFrame.Angles(0, 0, math.rad(90))
			size = Vector3.new(pc.sy, pc.sx, pc.sz)
		end
		p = LobbyProps.part(
			folder,
			pc.name,
			size,
			cf,
			color,
			if pc.round
				then Enum.PartType.Cylinder
				elseif pc.wedge then Enum.PartType.Wedge
				elseif pc.ball then Enum.PartType.Ball
				else nil
		)
	end
	p.CanCollide = pc.collide
	if not pc.collide then
		p.CanQuery = false
		p.CanTouch = false
	end
	if pc.hidden then
		p.Transparency = 1
	end
	if pc.neon then
		p.Material = Enum.Material.Neon
		p.CastShadow = false
	end
	if pc.light then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 170, 90)
		l.Range = 16
		l.Brightness = 1.5
		l.Parent = p
	end
	-- nothing here moves, so let the engine skip shadows on the big flat sheets
	if pc.sx * pc.sz > 2000 then
		p.CastShadow = false
	end
end

function LobbyWaterBuilder.build(lobby: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Water"
	local meshyBoats = meshBoats(folder, 7.5)
	local meshyRings = meshRings(folder, 2.2)
	for _, pc in LobbyWater.pieces() do
		if meshyBoats and string.sub(pc.name, 1, 4) == "Boat" then
			continue
		elseif meshyRings and pc.name == "Buoy" then
			continue
		end
		makePart(folder, pc)
	end

	local pieces, spots = LobbyLake.build()
	local meshed: { [string]: boolean } = {}
	for _, s in spots do
		local at = CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, math.rad(s.ry) + math.pi, 0)
		if MeshProps.place(folder, s.mesh, at, s.height) then
			meshed[s.id] = true
		end
	end
	for _, pc in pieces do
		if not (pc.group and meshed[pc.group]) then
			makePart(folder, pc)
		end
	end
	folder.Parent = lobby
end

return LobbyWaterBuilder
