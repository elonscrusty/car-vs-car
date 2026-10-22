--!strict
-- Builds every plot: the shared base (floor, outer walls, front area) plus the plot's own track
-- from Plots/<Type>.luau. Each plot is built big, then copied and shrunk to real RC size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Kit = require(ReplicatedStorage.Shared.Plots.Kit)

local C = Kit.COLORS

local TrackBuilder = {}

-- The part every plot shares. Plot-local, big size.
local function buildBase(parent: Instance, origin: CFrame, label: string, grip: number)
	local w, d = Kit.WIDTH, Kit.DEPTH
	local floor =
		Kit.part(parent, "Ground", origin, Vector3.new(w, 4, d), CFrame.new(0, -2, 0), C.ground)
	floor:SetAttribute("Grip", grip)

	-- outer walls, with a gap at the front for the entrance
	local h, gap = 6, 80
	Kit.part(parent, "Wall", origin, Vector3.new(w, h, 2), CFrame.new(0, h / 2, -d / 2), C.wall)
	for _, side in { -1, 1 } do
		Kit.part(
			parent,
			"Wall",
			origin,
			Vector3.new(2, h, d),
			CFrame.new(side * w / 2, h / 2, 0),
			C.wall
		)
		local len = (w - gap) / 2
		Kit.part(
			parent,
			"Wall",
			origin,
			Vector3.new(len, h, 2),
			CFrame.new(side * (gap / 2 + len / 2), h / 2, d / 2),
			C.wall
		)
	end

	-- front area: a line across, the stand spot, parking, the entrance path and the sign
	local front = Kit.FRONT_Z
	-- low wall between the track and the front area: the car stays on its side, people can
	-- still see over it
	Kit.part(parent, "Wall", origin, Vector3.new(w, 3, 2), CFrame.new(0, 1.5, front), C.white)
	-- raised driver stand: the person watches the whole plot from up here. A deck on four thin
	-- legs (so people walking past can still see into the plot) with steps up the side.
	local sx, sz, sh = Kit.STAND.x, Kit.STAND.z, Kit.STAND_H
	Kit.part(parent, "StandPad", origin, Vector3.new(28, 2, 28), CFrame.new(sx, sh - 1, sz), C.pad)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			Kit.part(
				parent,
				"StandLeg",
				origin,
				Vector3.new(2, sh - 2, 2),
				CFrame.new(sx + cx * 13, (sh - 2) / 2, sz + cz * 13),
				C.wall
			)
		end
	end
	local steps = 12
	for i = 1, steps do
		local top = sh * i / steps
		Kit.part(
			parent,
			"StandStep",
			origin,
			Vector3.new(8, 1, 10), -- 2 studs deep at RC size: easy to walk up
			CFrame.new(sx + 14 + (steps - i + 0.5) * 8, top - 0.5, sz + 9),
			C.pad
		)
	end
	local park = Kit.part(
		parent,
		"Parking",
		origin,
		Vector3.new(64, 0.2, 40),
		CFrame.new(-w / 2 + 72, 0.1, front + 48),
		Color3.fromRGB(170, 170, 170)
	)
	park.CanCollide = false
	for i = -1, 1 do
		Kit.line(parent, origin, -w / 2 + 72 + i * 21, 0.1, front + 48, 1, 0, 36, C.white)
	end
	local path = Kit.part(
		parent,
		"Entrance",
		origin,
		Vector3.new(gap, 0.2, 30),
		CFrame.new(0, 0.1, d / 2 - 15),
		Color3.fromRGB(201, 195, 181)
	)
	path.CanCollide = false

	local sx, sz = w / 2 - 72, front + 50
	for _, side in { -1, 1 } do
		Kit.part(
			parent,
			"SignPost",
			origin,
			Vector3.new(2, 14, 2),
			CFrame.new(sx + side * 28, 7, sz),
			C.wall
		)
	end
	local board = Kit.part(
		parent,
		"Sign",
		origin,
		Vector3.new(72, 24, 2),
		CFrame.new(sx, 24, sz),
		Color3.fromRGB(230, 230, 230)
	)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(30, 30, 34)
		text.Text = label .. " PLOT"
		text.Parent = gui
	end
end

-- Builds every plot twice: big test size, and a shrunk copy at real RC size.
function TrackBuilder.build()
	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = workspace
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		local plot = TrackData.plot(id)
		local origin = CFrame.new(t.originX, 0, 0)
		local big = Instance.new("Model")
		big.Name = id
		buildBase(big, origin, t.label, t.grip)
		plot.build(big, origin)
		-- walls are slippery and a little bouncy: the car pushes off instead of grinding along
		for _, d in big:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Wall") then
				d.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.45, 100, 100)
			end
		end
		big.WorldPivot = origin
		big.Parent = root

		local small = big:Clone()
		small.Name = id .. "_rc"
		small:ScaleTo(TrackData.RC_SCALE)
		local ox, oz = TrackData.origin(t, true)
		small:PivotTo(CFrame.new(ox, 0, oz))
		small.Parent = root
	end
end

return TrackBuilder
