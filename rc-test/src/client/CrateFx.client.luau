--!strict
-- The breakable crates' burst on this screen (server/CrateServer decides; shared/BreakCrates has the
-- rules): when a crate breaks, planks and posts (the crate's own faceted pieces, shared/CrateData)
-- fly out and tumble to the floor, then fade, and a few dust puffs swell and rise. Looks only:
-- everything is anchored, nothing collides, and the number of bits alive is capped for phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BreakCrates = require(Shared:WaitForChild("BreakCrates"))
local GemKit = require(Shared:WaitForChild("GemKit"))

local remote = ReplicatedStorage:WaitForChild("CrateFx") :: RemoteEvent

local BITS = 14 -- flying bits per crate
local PUFFS = 4
local MAX_LIVE = 90 -- bits + puffs alive at once; a burst beyond this is skipped
local GRAVITY = 40 -- big units / s^2
local LIFE_LAND = 2.5 -- seconds a bit lies on the floor before it fades
local FADE = 0.6

local sc = BreakCrates.SCALE
local f = BreakCrates.SIZE * sc / GemKit.height("crateWhole") -- studs per data unit

local folder = Instance.new("Folder")
folder.Name = "CrateBits"
folder.Parent = workspace

-- one template of each loose piece, built once (nil when this device can't make meshes)
local templates: { MeshPart }? = nil
local dust: MeshPart? = nil
local function load()
	if templates then
		return
	end
	templates = {}
	local bitsModel = GemKit.build(
		folder,
		"crateBits",
		Vector3.new(0, -1000, 0),
		GemKit.height("crateBits") * f,
		0,
		false
	)
	if bitsModel then
		for _, d in bitsModel:GetChildren() do
			if d:IsA("MeshPart") then
				table.insert(templates :: { MeshPart }, d)
			end
		end
	end
	local dustModel = GemKit.build(
		folder,
		"crateDust",
		Vector3.new(0, -1000, 0),
		GemKit.height("crateDust") * f,
		0,
		false
	)
	if dustModel then
		for _, d in dustModel:GetChildren() do
			if d:IsA("MeshPart") then
				dust = d
			end
		end
	end
end

local live = 0

type Bit = { part: BasePart, vel: Vector3, spin: Vector3, floorY: number }
local flying: { Bit } = {}
local conn: RBXScriptConnection? = nil

local function stepAll(dt: number)
	local i = 1
	while i <= #flying do
		local b = flying[i]
		local p = b.part
		b.vel += Vector3.new(0, -GRAVITY * sc * dt, 0)
		local pos = p.Position + b.vel * dt
		if pos.Y <= b.floorY then
			-- landed: lie flat-ish where it fell, then fade
			pos = Vector3.new(pos.X, b.floorY, pos.Z)
			p.CFrame = CFrame.new(pos) * (p.CFrame - p.Position).Rotation
			table.remove(flying, i)
			task.delay(LIFE_LAND, function()
				TweenService:Create(p, TweenInfo.new(FADE), { Transparency = 1 }):Play()
				task.wait(FADE)
				p:Destroy()
				live -= 1
			end)
		else
			local r = CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			p.CFrame = CFrame.new(pos) * r * (p.CFrame - p.Position).Rotation
			i += 1
		end
	end
	if #flying == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

local function burst(at: Vector3, seed: number)
	load()
	local tpl = templates
	if tpl == nil or #tpl == 0 or live + BITS + PUFFS > MAX_LIVE then
		return
	end
	local rng = Random.new(seed)
	local mid = at + Vector3.new(0, BreakCrates.SIZE * 0.5 * sc, 0)
	for _ = 1, BITS do
		local p = tpl[rng:NextInteger(1, #tpl)]:Clone()
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
			true, false, false, false, false
		local jitter = Vector3.new(
			rng:NextNumber(-0.5, 0.5),
			rng:NextNumber(-0.3, 0.6),
			rng:NextNumber(-0.5, 0.5)
		)
		p.CFrame = CFrame.new(mid + jitter * sc)
			* CFrame.Angles(
				rng:NextNumber(0, 6.28),
				rng:NextNumber(0, 6.28),
				rng:NextNumber(0, 6.28)
			)
		local a = rng:NextNumber(0, 6.28)
		local sp = rng:NextNumber(4, 10) * sc
		table.insert(flying, {
			part = p,
			vel = Vector3.new(math.cos(a) * sp, rng:NextNumber(8, 15) * sc, math.sin(a) * sp),
			spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9)),
			floorY = at.Y + 0.12 * sc,
		})
		p.Parent = folder
		live += 1
	end
	local d = dust
	if d then
		for _ = 1, PUFFS do
			local p = d:Clone()
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
				true, false, false, false, false
			p.Material = Enum.Material.SmoothPlastic
			p.Transparency = 0.35
			local start = mid
				+ Vector3.new(
						rng:NextNumber(-1, 1),
						rng:NextNumber(-0.3, 0.3),
						rng:NextNumber(-1, 1)
					)
					* sc
			p.Size = p.Size * 0.5
			p.CFrame = CFrame.new(start)
			p.Parent = folder
			live += 1
			local grow = TweenService:Create(
				p,
				TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = p.Size * 3.2,
					Transparency = 1,
					CFrame = CFrame.new(
						start + Vector3.new(rng:NextNumber(-1, 1), 2.5, rng:NextNumber(-1, 1)) * sc
					),
				}
			)
			grow.Completed:Once(function()
				p:Destroy()
				live -= 1
			end)
			grow:Play()
		end
	end
	if conn == nil then
		conn = game:GetService("RunService").Heartbeat:Connect(stepAll)
	end
end

remote.OnClientEvent:Connect(function(kind: any, data: any)
	if kind ~= "Burst" or type(data) ~= "table" then
		return
	end
	local at, seed = data.position, data.seed
	if typeof(at) ~= "Vector3" or type(seed) ~= "number" then
		return
	end
	if at.X ~= at.X or at.Y ~= at.Y or at.Z ~= at.Z then
		return
	end
	pcall(burst, at, seed)
end)
