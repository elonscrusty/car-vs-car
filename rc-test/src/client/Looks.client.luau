--!strict
-- Small life on the star looks (PlotLooks): fans bob and cheer, searchlights sweep. On this
-- screen only (the server never moves them), a few times a second is plenty, and only for
-- plots near the camera.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NEAR = 220 -- studs from the camera
local base: { [BasePart]: CFrame } = {}

local function track(p: Instance)
	if p:IsA("BasePart") then
		base[p] = p.CFrame
	end
end
local function drop(p: Instance)
	if p:IsA("BasePart") then
		base[p] = nil
	end
end
for _, tag in { "StarFan", "StarSearch" } do
	for _, p in CollectionService:GetTagged(tag) do
		track(p)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(drop)
end

local acc = 0
RunService.RenderStepped:Connect(function(dt: number)
	acc += dt
	if acc < 1 / 20 then
		return
	end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local t = os.clock()
	for p, cf in base do
		if (cf.Position - eye).Magnitude > NEAR then
			continue
		end
		if CollectionService:HasTag(p, "StarSearch") then
			-- sweep side to side and a little up and down, each lamp on its own beat
			local phase = cf.Position.X * 0.05
			p.CFrame = cf
				* CFrame.Angles(0, math.sin(t * 0.5 + phase) * 1.1, 0)
				* CFrame.Angles(0.5 + math.sin(t * 0.8 + phase) * 0.15, 0, 0)
		else
			-- each fan (body, head, arms share x/z) bounces on its own beat
			local phase = cf.Position.Z * 0.7 + cf.Position.X * 0.3
			local up = math.max(math.sin(t * 6 + phase), 0) * 0.25
			p.CFrame = cf + Vector3.new(0, up, 0)
		end
	end
end)
