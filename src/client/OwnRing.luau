--!strict
-- A glowing ring on the floor under YOUR car (so you can find it in the crowd). Client only: the
-- server just marks the model with OwnerUserId. The ring follows the body every frame; no physics.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local OwnRing = {}

local RING_COLOR = Color3.fromRGB(90, 255, 140)
local started = false
local SCAN_EVERY = 0.5 -- seconds between looks for my car (searching every frame is wasteful)

function OwnRing.start()
	if started then
		return
	end
	started = true
	local me = Players.LocalPlayer
	local ring: Part? = nil
	local target: BasePart? = nil
	local lastScan = 0

	local function drop()
		if ring then
			ring:Destroy()
		end
		ring, target = nil, nil
	end

	RunService.RenderStepped:Connect(function()
		if target and target.Parent == nil then
			drop()
		end
		if target == nil and os.clock() - lastScan >= SCAN_EVERY then
			lastScan = os.clock()
			for _, m in workspace:GetDescendants() do
				if m:IsA("Model") and m:GetAttribute("OwnerUserId") == me.UserId then
					local body = m:FindFirstChild("Body")
					if body and body:IsA("BasePart") then
						target = body
						local r = Instance.new("Part")
						r.Name = "OwnCarRing"
						r.Shape = Enum.PartType.Cylinder
						r.Anchored = true
						r.CanCollide = false
						r.CanQuery = false
						r.CanTouch = false
						r.CastShadow = false
						r.Material = Enum.Material.Neon
						r.Color = RING_COLOR
						r.Transparency = 0.35
						local d = math.max(body.Size.X, body.Size.Z) + 4
						r.Size = Vector3.new(0.15, d, d)
						r.Parent = workspace
						ring = r
						break
					end
				end
			end
		end
		if ring and target then
			local pos = target.Position - Vector3.new(0, target.Size.Y / 2 + 0.2, 0)
			ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		end
	end)
end

return OwnRing
