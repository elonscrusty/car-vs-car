--!strict
-- The lake comes alive on this player's screen only (LobbyLake.motions / sparkle): the
-- sailboats drift and bob at anchor, the ducks paddle round their loop, and glints of light
-- flash on the water. Looks only; nothing moves when the camera is far from the lake, so it
-- costs nothing while you are not near it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyLake = require(ReplicatedStorage.Shared.LobbyLake)
local LobbyWater = require(ReplicatedStorage.Shared.LobbyWater)

local LakeLife = {}

LakeLife.NEAR = 350 -- the lake moves only when the camera is this close to its middle

local started = false

function LakeLife.start()
	if started then
		return
	end
	started = true

	local motions = LobbyLake.motions()
	local models: { [string]: Model } = {}
	local function model(id: string): Model?
		local m = models[id]
		if m and m.Parent then
			return m
		end
		local lobby = workspace:FindFirstChild("Lobby")
		local water = lobby and lobby:FindFirstChild("Water")
		local found = water and water:FindFirstChild(id)
		if found and found:IsA("Model") then
			models[id] = found
			return found
		end
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "LakeLife"
	folder.Parent = workspace
	local glints: { BasePart } = {}
	for _ = 1, LobbyLake.SPARKLES do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 255, 255)
		p.Size = Vector3.new(0.9, 0.05, 0.9)
		p.Transparency = 1
		p.Parent = folder
		table.insert(glints, p)
	end
	local glintCFrames: { CFrame } = table.create(#glints)

	local l = LobbyWater.lakeBox()
	local middle = Vector3.new((l.minX + l.maxX) / 2, 0, (l.minZ + l.maxZ) / 2)
	local y = LobbyWater.WATER_TOP + 0.03
	local t0 = os.clock()

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - middle).Magnitude > LakeLife.NEAR then
			return
		end
		local t = os.clock() - t0
		for _, mo in motions do
			local m = model(mo.id)
			if m then
				local x, py, z, ry, roll = LobbyLake.pose(mo, t)
				m:PivotTo(
					CFrame.new(x, py, z)
						* CFrame.Angles(0, math.rad(ry), 0)
						* CFrame.Angles(0, 0, math.rad(roll))
				)
			end
		end
		for i, g in glints do
			local x, z, bright = LobbyLake.sparkle(i, t)
			glintCFrames[i] = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(45), 0)
			g.Transparency = 1 - 0.85 * bright
		end
		workspace:BulkMoveTo(glints, glintCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return LakeLife
