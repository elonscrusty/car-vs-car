--!strict
-- Two glowing ▲ on the road a little ahead of the car, pointing to the next gate, so a
-- new player always knows where to go in a race. Looks only (no collide, query or touch), only
-- on this player's screen, only on loop tracks. Where it sits: Shared.RaceArrow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local RaceArrow = require(ReplicatedStorage.Shared.RaceArrow)
local TrackData = require(ReplicatedStorage.Shared.TrackData)

export type RoadArrow = {
	update: (t: TrackData.Track, timer: LapTimer.State, rc: boolean, lx: number, lz: number) -> (),
	hide: () -> (),
}

local RoadArrow = {}

local COLOR = Color3.fromRGB(255, 220, 60)
local LONG = 22 -- arrow length along the road (big units)
local WIDE = 14 -- arrow width (big units)

function RoadArrow.new(ignore: { Instance }): RoadArrow
	-- a flat see-through plate with two big glowing ▲ drawn on its top face (a crisp shape from
	-- any camera; on a Top face the picture's top edge is the plate's -X, so the plate is turned
	-- a quarter to put -X forward)
	local model = Instance.new("Model")
	model.Name = "RoadArrow"
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Transparency = 1
	plate.Parent = model
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Top
	face.LightInfluence = 0
	face.Brightness = 4
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 60
	face.Parent = plate
	local marks: { TextLabel } = {}
	for i = 1, 2 do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, (i - 1) * 0.46)
		t.Size = UDim2.fromScale(1, 0.54)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = "▲"
		t.TextColor3 = COLOR
		t.TextStrokeColor3 = Color3.fromRGB(120, 80, 0)
		t.TextStrokeTransparency = 0.4
		t.Parent = face
		table.insert(marks, t)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	table.insert(list, model)
	params.FilterDescendantsInstances = list

	local function hide()
		model.Parent = nil
	end

	local function update(
		t: TrackData.Track,
		timer: LapTimer.State,
		rc: boolean,
		lx: number,
		lz: number
	)
		if t.mode ~= "loop" then
			hide()
			return
		end
		local g = RaceArrow.nextGate(timer.gates, timer.next, timer.running)
		local ax, az, dx, dz
		if g then
			ax, az, dx, dz = RaceArrow.place(lx, lz, g)
		end
		if g == nil or ax == nil or az == nil or dx == nil or dz == nil then
			hide()
			return
		end
		local s = if rc then TrackData.RC_SCALE else 1
		local wx, wy, wz = TrackData.toWorld(t, rc, ax, g.y, az)
		local fx, fz = TrackData.dirToWorld(t, rc, dx, dz)
		-- sit on whatever road is under the spot
		local from = Vector3.new(wx, wy + 20 * s, wz)
		local hit = workspace:Raycast(from, Vector3.new(0, -60 * s, 0), params)
		local y = if hit then hit.Position.Y + 0.06 else wy
		plate.Size = Vector3.new(LONG * s, 0.05, WIDE * s) -- X runs along the road (see above)
		plate.CFrame = CFrame.lookAt(Vector3.new(wx, y, wz), Vector3.new(wx + fx, y, wz + fz))
			* CFrame.Angles(0, -math.pi / 2, 0)
		local glow = 0.05 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		for i, t in marks do
			t.TextTransparency = glow + (i - 1) * 0.25
		end
		model.Parent = workspace
	end

	return { update = update, hide = hide }
end

return RoadArrow
