--!strict
-- The fire pits, drawn (server/FirePitServer decides; this only makes the flames dance).
--   pit models (tag "FirePit"): every flame is a tall neon ball that flickers; when the pit's
--     attribute Flare is on they leap up (about twice as tall); the ring on the floor glows amber,
--     flashes yellow/red just before a flare (Warn) and stays red while it lasts.
-- Only pits near the camera are animated (light for phones). Look rule: low-poly, no studs.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NEAR = 160 -- studs: farther pits stay still

local AMBER = Color3.fromRGB(255, 138, 26)
local RED = Color3.fromRGB(255, 58, 42)
local YELLOW = Color3.fromRGB(255, 210, 63)

local rings: { [Instance]: { circle: Frame?, stroke: UIStroke? } } = {}

local function ringOf(pit: Instance): (Frame?, UIStroke?)
	local r = rings[pit]
	if not r then
		local zone = pit:FindFirstChild("Zone")
		local gui = zone and zone:FindFirstChild("Ring")
		local circle = gui and gui:FindFirstChild("Circle")
		r = {
			circle = if circle and circle:IsA("Frame") then circle else nil,
			stroke = if circle then circle:FindFirstChildOfClass("UIStroke") else nil,
		}
		rings[pit] = r
	end
	local rr = r :: { circle: Frame?, stroke: UIStroke? }
	return rr.circle, rr.stroke
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	for _, pit in CollectionService:GetTagged("FirePit") do
		if not pit:IsA("Model") then
			continue
		end
		local flare = pit:GetAttribute("Flare") == true
		local warn = pit:GetAttribute("Warn") == true
		local circle, stroke = ringOf(pit)
		if circle and stroke then
			if flare then
				stroke.Color = RED
				circle.BackgroundColor3 = RED
				circle.BackgroundTransparency = 0.78
			elseif warn then
				local on = math.sin(t * 20) > 0
				stroke.Color = if on then RED else YELLOW
				circle.BackgroundColor3 = if on then RED else YELLOW
				circle.BackgroundTransparency = 0.82
			else
				stroke.Color = AMBER
				circle.BackgroundColor3 = AMBER
				circle.BackgroundTransparency = 0.9 - 0.05 * math.sin(t * 3)
			end
		end
		if (pit:GetPivot().Position - cam.CFrame.Position).Magnitude > NEAR then
			continue
		end
		local lift = if flare then 1.9 else 1
		for _, f in pit:GetChildren() do
			if f:IsA("BasePart") and f.Shape == Enum.PartType.Ball then
				local seed = f:GetAttribute("Seed")
				local w, h = f:GetAttribute("W"), f:GetAttribute("H")
				if type(seed) == "number" and type(w) == "number" and type(h) == "number" then
					local wob = 0.78
						+ 0.22 * math.sin(t * (5 + seed % 5) + seed)
						+ 0.1 * math.sin(t * 11 + seed * 2)
					local hh = h * wob * lift
					f.Size =
						Vector3.new(w * (1 + (lift - 1) * 0.15), hh, w * (1 + (lift - 1) * 0.15))
					f.Position = Vector3.new(
						f:GetAttribute("X") :: number,
						(f:GetAttribute("Y") :: number) + hh / 2,
						f:GetAttribute("Z") :: number
					)
				end
			end
		end
	end
end)
