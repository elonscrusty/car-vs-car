--!strict
-- The crowd hops and cheers when a car is knocked out: every "Fan" dot in the stadium jumps a
-- little, each a beat apart. Local only (the server never moves the fans).

local RunService = game:GetService("RunService")

local CrowdFx = {}

local HOP_SECONDS = 0.7
local HOP_HEIGHT = 2.6
local MAX_DELAY = 0.35

type Fan = { part: BasePart, home: CFrame, delay: number }

local running: RBXScriptConnection? = nil

local function findFans(): { Fan }
	local fans: { Fan } = {}
	local rng = Random.new()
	for _, arena in workspace:GetChildren() do
		if arena.Name == "Arena" then
			local stadium = arena:FindFirstChild("Stadium")
			if stadium then
				for _, p in stadium:GetChildren() do
					if p:IsA("BasePart") and p.Name == "Fan" then
						table.insert(
							fans,
							{ part = p, home = p.CFrame, delay = rng:NextNumber() * MAX_DELAY }
						)
					end
				end
			end
		end
	end
	return fans
end

-- Makes the whole crowd hop once. A second cheer while one is running restarts it cleanly.
function CrowdFx.cheer()
	if running then
		running:Disconnect()
		running = nil
	end
	local fans = findFans()
	if #fans == 0 then
		return
	end
	local start = os.clock()
	running = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local alive = false
		for _, f in fans do
			if f.part.Parent ~= nil then
				local k = (t - f.delay) / HOP_SECONDS
				if k >= 0 and k < 1 then
					alive = true
					f.part.CFrame = f.home + Vector3.new(0, math.sin(k * math.pi) * HOP_HEIGHT, 0)
				else
					f.part.CFrame = f.home
					alive = alive or k < 0
				end
			end
		end
		if not alive and running then
			running:Disconnect()
			running = nil
		end
	end)
end

return CrowdFx
