--!strict
-- Dresses up every lobby plot TrackBuilder built (workspace.Plots.<slot>_<id>) with PlotDecor's
-- pieces for its kind: recolours the base's outer walls to the plot's theme, then adds the arch,
-- caps, bunting, flags, booth and canopy (and carter's Meshy props). Then the spectator steps
-- in the gaps between plots. Looks only: the walls keep their size and collisions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotDecor = require(ReplicatedStorage.Shared.PlotDecor)

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
		for _, d in plot:GetChildren() do
			if d:IsA("BasePart") and isBaseWall(d, pivot) then
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
		decor.Parent = plot
	end
end

return PlotDecorBuilder
