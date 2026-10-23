--!strict
-- Small life in the lobby, on this player's screen only (LobbyDecor.life()): butterflies
-- fluttering over the flower beds and planters, birds circling high over the street and
-- seagulls over the lake. Plain
-- looks-only parts moved together once a frame (BulkMoveTo); nothing moves when the camera is
-- far away, so it costs nothing while you are not near them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyDecor = require(ReplicatedStorage.Shared.LobbyDecor)

local LobbyLife = {}

LobbyLife.NEAR = 140 -- butterflies move only when the camera is this close
LobbyLife.BIRD_NEAR = 400

type Live = {
	f: LobbyDecor.Flyer,
	body: BasePart?,
	left: BasePart,
	right: BasePart,
}

local function piece(parent: Instance, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Parent = parent
	return p
end

local started = false

function LobbyLife.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "LobbyLife"
	folder.Parent = workspace

	local lives: { Live } = {}
	for _, f in LobbyDecor.life() do
		local color = Color3.fromRGB(f.color[1], f.color[2], f.color[3])
		if f.kind == "Bird" then
			table.insert(lives, {
				f = f,
				body = piece(folder, Vector3.new(0.7, 0.6, 2), color),
				left = piece(folder, Vector3.new(2.6, 0.12, 1), color),
				right = piece(folder, Vector3.new(2.6, 0.12, 1), color),
			})
		else
			table.insert(lives, {
				f = f,
				left = piece(folder, Vector3.new(0.5, 0.05, 0.6), color),
				right = piece(folder, Vector3.new(0.5, 0.05, 0.6), color),
			})
		end
	end

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local eye = cam.CFrame.Position
		local t = os.clock()
		table.clear(parts)
		table.clear(frames)
		for _, l in lives do
			local f = l.f
			local near = if f.kind == "Bird" then LobbyLife.BIRD_NEAR else LobbyLife.NEAR
			local dx, dz = f.x - eye.X, f.z - eye.Z
			if dx * dx + dz * dz > near * near then
				continue
			end
			local at: CFrame
			local flap: number
			if f.kind == "Bird" then
				-- a wide circle, a slow rise and fall, mostly gliding with a few flaps
				local a = t * f.speed * 2 * math.pi + f.phase
				local pos = Vector3.new(
					f.x + f.r * math.cos(a),
					f.y + 2 * math.sin(a * 3),
					f.z + f.r * math.sin(a)
				)
				local ahead = Vector3.new(-math.sin(a), 0, math.cos(a))
				at = CFrame.lookAt(pos, pos + ahead) * CFrame.Angles(0, 0, math.rad(-12))
				flap = math.rad(8 + 22 * math.max(0, math.sin(t * 6 + f.phase)))
				table.insert(parts, l.body :: BasePart)
				table.insert(frames, at)
				table.insert(parts, l.left)
				table.insert(frames, at * CFrame.Angles(0, 0, -flap) * CFrame.new(-1.4, 0, 0.1))
				table.insert(parts, l.right)
				table.insert(frames, at * CFrame.Angles(0, 0, flap) * CFrame.new(1.4, 0, 0.1))
			else
				-- a wandering figure-eight with a little bob, wings beating fast
				local a = t * f.speed + f.phase
				local function spot(s: number): Vector3
					return Vector3.new(
						f.x + f.r * 0.6 * math.sin(s * 1.3),
						f.y + 0.4 * math.sin(s * 5),
						f.z + f.r * math.sin(s * 0.9) * math.cos(s * 0.5)
					)
				end
				local pos, nextPos = spot(a), spot(a + 0.05)
				local ahead = nextPos - pos
				ahead = Vector3.new(ahead.X, 0, ahead.Z)
				if ahead.Magnitude < 1e-3 then
					ahead = Vector3.zAxis
				end
				at = CFrame.lookAt(pos, pos + ahead)
				flap = math.rad(10 + 60 * math.abs(math.sin(t * 14 + f.phase)))
				table.insert(parts, l.left)
				table.insert(frames, at * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.25, 0, 0))
				table.insert(parts, l.right)
				table.insert(frames, at * CFrame.Angles(0, 0, flap) * CFrame.new(0.25, 0, 0))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return LobbyLife
