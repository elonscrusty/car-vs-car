--!strict
-- Builds every plot: the shared base (floor, outer walls, front area) plus the plot's own track
-- from Plots/<Type>.luau. Each kind of plot is built big once (kept out of the world), then
-- copied, shrunk to real RC size and turned onto every lobby plot of that kind
-- (workspace.Plots.<slot>_<id>): the lobby plots are the tracks. A plot's own track sits in its
-- "Track" model, so one plot's track can be swapped later (rebuild: an owner's tile track).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Kit = require(ReplicatedStorage.Shared.Plots.Kit)

local C = Kit.COLORS

local TrackBuilder = {}

local rebuiltEvent = Instance.new("BindableEvent")
TrackBuilder.rebuilt = rebuiltEvent.Event -- (slot) after rebuild() swapped that plot's track

-- walls are slippery and a little bouncy: the car pushes off instead of grinding along
local function slippery(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "Wall") then
			d.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.45, 100, 100)
		end
	end
end

-- The part every plot shares. Plot-local, big size.
local function buildBase(parent: Instance, origin: CFrame, grip: number)
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

	-- front area: a line across, the stand spot and the entrance path (the lobby puts the name
	-- sign by the road; the car show on the left is PlotStands')
	local front = Kit.FRONT_Z
	-- low wall between the track and the front area: the car stays on its side, people can
	-- still see over it
	Kit.part(parent, "Wall", origin, Vector3.new(w, 3, 2), CFrame.new(0, 1.5, front), C.white)
	-- (not in Car VS Car: there you train cars on your plot and race from the map's stand)
	if not Features.CVC then
		-- raised driver stand: the person watches the whole plot from up here. A deck on four thin
		-- legs (so people walking past can still see into the plot) with steps up the side.
		local sx, sz, sh = Kit.STAND.x, Kit.STAND.z, Kit.STAND_H
		Kit.part(
			parent,
			"StandPad",
			origin,
			Vector3.new(28, 2, 28),
			CFrame.new(sx, sh - 1, sz),
			C.pad
		)
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
end

-- Builds each kind of plot big, then a real-size copy on every lobby plot of that kind.
function TrackBuilder.build()
	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = workspace
	local big: { [string]: Model } = {}
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		local plot = TrackData.plot(id)
		local origin = CFrame.new(t.originX, 0, 0)
		local m = Instance.new("Model")
		m.Name = id
		buildBase(m, origin, t.grip)
		local track = Instance.new("Model")
		track.Name = "Track"
		plot.build(track, origin)
		track.Parent = m
		slippery(m)
		m.WorldPivot = origin
		big[id] = m
	end
	for _, slot in LobbyLayout.slots() do
		local copy = big[slot.id]:Clone()
		copy.Name = slot.index .. "_" .. slot.id
		copy:ScaleTo(TrackData.RC_SCALE)
		copy:PivotTo(CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0))
		copy.Parent = root
	end
	for _, m in big do
		m:Destroy()
	end
end

-- Swap one lobby plot's own track (the base, decor, stands and looks stay): `build(parent,
-- origin)` makes the new track at big size like a Plots/<Type>.build, plot-local around origin.
function TrackBuilder.rebuild(slotIndex: number, build: (parent: Instance, origin: CFrame) -> ())
	local slot = LobbyLayout.slots()[slotIndex]
	local plot = slot and workspace.Plots:FindFirstChild(slotIndex .. "_" .. slot.id)
	if not plot then
		return
	end
	local track = Instance.new("Model")
	track.Name = "Track"
	build(track, CFrame.identity)
	slippery(track)
	track.WorldPivot = CFrame.identity
	track:ScaleTo(TrackData.RC_SCALE)
	track:PivotTo(CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0))
	local old = plot:FindFirstChild("Track")
	if old then
		old:Destroy()
	end
	track.Parent = plot
	rebuiltEvent:Fire(slotIndex)
end

return TrackBuilder
