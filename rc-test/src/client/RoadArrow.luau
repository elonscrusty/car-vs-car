--!strict
-- A glowing double arrow on the road a little ahead of the car, pointing to the next gate, so a
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
local ARM = 6 -- arm length (big units)
local WIDE = 1.4 -- arm width (big units)
local ANGLE = math.rad(38) -- how far each arm leans back

function RoadArrow.new(ignore: { Instance }): RoadArrow
	local model = Instance.new("Model")
	model.Name = "RoadArrow"
	local arms: { BasePart } = {}
	for _ = 1, 4 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = COLOR
		p.Parent = model
		table.insert(arms, p)
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
		local base = CFrame.lookAt(Vector3.new(wx, y, wz), Vector3.new(wx + fx, y, wz + fz))
		local arm, wide = ARM * s, WIDE * s
		local glow = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		for i, p in arms do
			local chevron = (i - 1) // 2 -- 0 = front, 1 = behind it
			local sideSign = if i % 2 == 0 then 1 else -1
			local tip = Vector3.new(0, 0, -arm * 0.4 + chevron * arm * 0.75)
			local back = Vector3.new(sideSign * math.sin(ANGLE), 0, math.cos(ANGLE))
			p.Size = Vector3.new(wide, 0.08, arm)
			p.CFrame = base
				* CFrame.new(tip + back * (arm / 2))
				* CFrame.Angles(0, sideSign * ANGLE, 0)
			p.Transparency = glow + chevron * 0.25
		end
		model.Parent = workspace
	end

	return { update = update, hide = hide }
end

return RoadArrow
