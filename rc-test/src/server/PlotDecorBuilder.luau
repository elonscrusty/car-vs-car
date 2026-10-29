--!strict
-- Dresses up every lobby plot TrackBuilder built (workspace.Plots.<slot>_<id>) with PlotDecor's
-- pieces for its kind: recolours the base's outer walls to the plot's theme, then adds the arch,
-- caps, bunting, flags, booth and canopy (and carter's Meshy props). Then the spectator steps
-- in the gaps between plots. Looks only: the walls keep their size and collisions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotDecor = require(ReplicatedStorage.Shared.PlotDecor)
local PropKit = require(ReplicatedStorage.Shared.PropKit)

local PlotDecorBuilder = {}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.05
end

-- Is this one of the base's outer walls (TrackBuilder.buildBase), not a track's own wall?
local function isBaseWall(p: BasePart, pivot: CFrame): boolean
	if p.Name ~= "Wall" then
		return false
	end
	local at = pivot:PointToObjectSpace(p.Position)
	local W, D = PlotDecor.HALF_W, PlotDecor.HALF_D
	-- the size in plot space (the plot is only ever turned about y by quarter turns)
	local size = pivot:VectorToObjectSpace(p.CFrame:VectorToWorldSpace(p.Size))
	local sx, sz = math.abs(size.X), math.abs(size.Z)
	return (near(math.abs(at.X), W) and near(sz, 2 * D))
		or (near(math.abs(at.Z), D) and (near(sx, 2 * W) or near(sx, W - PlotDecor.GATE)))
		or (near(at.Z, PlotDecor.FRONT_Z) and near(sx, 2 * W))
end

function PlotDecorBuilder.build()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, slot in LobbyLayout.slots() do
		local plot = plots:FindFirstChild(slot.index .. "_" .. slot.id)
		if not (plot and plot:IsA("Model")) then
			continue
		end
		local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
		local theme = PlotDecor.theme(slot.id)
		local wall = Color3.fromRGB(theme.wall[1], theme.wall[2], theme.wall[3])
		local pillar = Color3.fromRGB(theme.pillar[1], theme.pillar[2], theme.pillar[3])
		local K = PlotDecor.SMASH
		for _, d in plot:GetChildren() do
			if Features.SMASH and d:IsA("BasePart") then
				-- (LOOK-BIBLE: navy walls inside the thick skirts, a warm grey base, a sand walk-in)
				local c = if isBaseWall(d, pivot)
					then K.navy
					elseif d.Name == "Ground" then K.ground
					elseif d.Name == "Entrance" then K.entrance
					else nil
				if c then
					d.Color = Color3.fromRGB(c[1], c[2], c[3])
					d.Material = Enum.Material.SmoothPlastic
				end
				if d.Name == "Entrance" then
					-- a wide sand walk from the gate to the showroom (no grass gap at the gate)
					local depth = PlotDecor.HALF_D - PlotDecor.FRONT_Z
					d.Size = Vector3.new(2 * PlotDecor.GATE + 4, 0.2, depth)
					d.CFrame = pivot * CFrame.new(0, 0.1, PlotDecor.FRONT_Z + depth / 2)
				end
			elseif d:IsA("BasePart") and isBaseWall(d, pivot) then
				d.Color = wall
				if slot.id == "rock" then
					d.Material = Enum.Material.WoodPlanks
				end
			elseif d:IsA("BasePart") and d.Name == "StandLeg" then
				-- the driver stand's thin legs read as stray white posts through the arch:
				-- paint them like the arch's pillars
				d.Color = pillar
				if slot.id == "rock" then
					d.Material = Enum.Material.Wood
				end
			end
		end
		local decor = Instance.new("Model")
		decor.Name = "Decor"
		local groups = Garage.makeParts(PlotDecor.parts(slot.id), decor, pivot)
		local board = (groups.Arch :: Model):FindFirstChild("NameBoard")
		if board then
			-- the driver's name goes here: a SurfaceGui on the board's road side (plot +z)
			board:SetAttribute("NameBoard", true)
			board:SetAttribute("NameFace", "Back")
			board:SetAttribute("Slot", slot.index)
		end
		Garage.useMeshes(groups, pivot, PlotDecor.meshes(slot.id))
		-- carter's gate model took the block arch's place: hang the name board on its top bar
		local arch = groups.Arch
		for name, bar in PlotDecor.GATE_BAR do
			local gate = arch and arch:FindFirstChild(name)
			if board and board:IsA("BasePart") and gate and gate:IsA("Model") then
				local box, size = gate:GetBoundingBox()
				local k = PlotDecor.gateScale() -- a smaller gate (Car VS Car): a smaller board
				board.Size = Vector3.new(board.Size.X * k, board.Size.Y * k, board.Size.Z)
				local at = pivot:PointToObjectSpace(box.Position)
				local top = at.Y + size.Y / 2
				local y = top - (1 - bar.y) * size.Y
				board.CFrame = pivot * CFrame.new(0, y, at.Z + bar.z * size.X + 0.06)
			end
		end
		if Features.SMASH then
			-- the flags and theme props come from the shared PropKit (one look with the arena)
			local props = Instance.new("Model")
			props.Name = "Props"
			local a = PlotDecor.SMASH.accent[slot.id] or PlotDecor.SMASH.accent.race
			local accent = Color3.fromRGB(a[1], a[2], a[3])
			for _, p in PlotDecor.smashProps() do
				local at = (pivot * CFrame.new(p.x, 0, p.z)).Position
				if p.kind == "flag" then
					local f = p.face or { 1, 0 }
					PropKit.flag(
						props,
						at,
						p.h,
						accent,
						pivot:VectorToWorldSpace(Vector3.new(f[1], 0, f[2]))
					)
				elseif p.kind == "tyres" then
					PropKit.tyreStack(props, at, p.h)
				elseif p.kind == "barrel" then
					PropKit.barrel(props, at, p.h, accent)
				elseif p.kind == "cone" then
					PropKit.cone(props, at, p.h)
				end
			end
			props.Parent = decor
		end
		decor.Parent = plot
	end
end

return PlotDecorBuilder
