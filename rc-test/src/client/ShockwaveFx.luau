--!strict
-- The Ice Viper's Shockwave, drawn (carter picked "Ice Rings" 10-29). The server decides who is
-- hit (server/weapons/Shockwave); client/WeaponFx hands this module three WeaponFx kinds:
--   Shockwave { from, dir, owner, charge, range, speed, arc }  the Nose Cannon glows for `charge`
--             seconds, then three bright arcs roll out of the muzzle across the ground
--   ShockHit  { id, position }  a white flash and ice chips where a kart was hit
--   Knock     { v, up }  sent to the player it shoves: their own client moves their own car
-- Look rule: low-poly, SmoothPlastic + Neon, no text.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local me = Players.LocalPlayer

local ShockwaveFx = {}

local ICE = Color3.fromRGB(70, 205, 255)
local WHITE = Color3.fromRGB(232, 251, 255)

-- the arena is RC size (TrackData.RC_SCALE): sizes below are in big units times S
local S = 0.25
-- parts a ring is cut into, and a cap on rings alive at once (a phone moves every part each frame)
local SEGMENTS = 12
local MAX_LIVE = 3
local KNOCK_MAX = 40 -- studs/s: the most a Knock may add (the server's PUSH is 20)

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

local function part(name: string, color: Color3, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = bits
	return p
end

local function vec(data: any, key: string): Vector3?
	local v = type(data) == "table" and data[key]
	return if typeof(v) == "Vector3" then v else nil
end

local function num(data: any, key: string, fallback: number, lo: number, hi: number): number
	local v = type(data) == "table" and data[key]
	return if type(v) == "number" and v == v then math.clamp(v, lo, hi) else fallback
end

local function flash(at: Vector3, color: Color3, from: number, to: number, seconds: number)
	local b = part("ShockFlash", color, Vector3.one * from * S)
	b.Shape = Enum.PartType.Ball
	b.Position = at
	b.Transparency = 0.1
	TweenService:Create(
		b,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * to * S, Transparency = 1 }
	):Play()
	task.delay(seconds + 0.05, function()
		b:Destroy()
	end)
end

type Ring = { segs: { Part }, color: Color3, late: number, width: number }
type Wave = {
	from: Vector3,
	yaw: number, -- the fan's middle, radians around Y (0 = +X)
	arc: number, -- radians
	range: number,
	speed: number,
	age: number, -- seconds since the rings left
	rings: { Ring },
}
local live: { Wave } = {}

local function makeRing(color: Color3, late: number, width: number): Ring
	local segs = {}
	for _ = 1, SEGMENTS do
		table.insert(segs, part("ShockRing", color, Vector3.new(width, 0.1 * S * 2, 1)))
	end
	return { segs = segs, color = color, late = late, width = width }
end

local function place(w: Wave)
	for _, r in w.rings do
		local k = w.age - r.late
		local radius = math.max(0.2, k * w.speed)
		local fade = math.clamp(1 - radius / w.range, 0, 1)
		for i, seg in r.segs do
			if k < 0 or fade <= 0 then
				seg.Transparency = 1
				continue
			end
			local a = w.yaw + (((i - 0.5) / SEGMENTS) - 0.5) * w.arc
			local pos = w.from + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
			local len = radius * w.arc / SEGMENTS * 1.15
			seg.Size = Vector3.new(len, r.width, r.width)
			seg.CFrame = CFrame.lookAt(
				Vector3.new(pos.X, w.from.Y - 0.6 * S, pos.Z),
				Vector3.new(pos.X, w.from.Y - 0.6 * S, pos.Z)
					+ Vector3.new(-math.sin(a), 0, math.cos(a))
			) * CFrame.Angles(0, math.rad(90), 0)
			seg.Transparency = 1 - 0.9 * fade
		end
	end
end

local function drop(w: Wave)
	for _, r in w.rings do
		for _, seg in r.segs do
			seg:Destroy()
		end
	end
end

local function onShockwave(data: any)
	local from, dir = vec(data, "from"), vec(data, "dir")
	if not from or not dir then
		return
	end
	local flatLen = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
	if flatLen < 1e-3 then
		return
	end
	local charge = num(data, "charge", 0.6, 0, 2)
	local range = num(data, "range", 12, 2, 60)
	local speed = num(data, "speed", 15, 2, 80)
	local arc = math.rad(num(data, "arc", 126, 20, 240))
	local yaw = math.atan2(dir.Z, dir.X)
	-- the cannon glows and swells while it charges
	flash(from, ICE, 1, 5, charge)
	task.delay(charge, function()
		flash(from, WHITE, 3, 8, 0.25)
		while #live >= MAX_LIVE do
			drop(table.remove(live, 1) :: Wave)
		end
		local w: Wave = {
			from = from,
			yaw = yaw,
			arc = arc,
			range = range,
			speed = speed,
			age = 0,
			rings = {
				makeRing(WHITE, 0, 0.5 * S),
				makeRing(ICE, 0.12, 0.45 * S),
				makeRing(ICE, 0.24, 0.4 * S),
			},
		}
		table.insert(live, w)
		place(w)
	end)
end

local function onShockHit(data: any)
	local at = vec(data, "position")
	if not at then
		return
	end
	flash(at + Vector3.new(0, S, 0), WHITE, 2, 9, 0.25)
end

-- The server shoves this player's car: their client owns it, so it adds the velocity itself.
local function onKnock(data: any)
	local v = vec(data, "v")
	if not v then
		return
	end
	local model = workspace:FindFirstChild("Car_" .. me.UserId)
	local body = model and model:IsA("Model") and (model :: Model).PrimaryPart
	if not body or body.Anchored then
		return -- (smashed and held still: nothing to shove)
	end
	local flatV = Vector3.new(v.X, 0, v.Z)
	if flatV.Magnitude > KNOCK_MAX then
		flatV = flatV.Unit * KNOCK_MAX
	end
	local up = num(data, "up", 0, 0, 12)
	body.AssemblyLinearVelocity += flatV + Vector3.new(0, up, 0)
end

function ShockwaveFx.handle(kind: string, data: any)
	if kind == "Shockwave" then
		onShockwave(data)
	elseif kind == "ShockHit" then
		onShockHit(data)
	elseif kind == "Knock" then
		onKnock(data)
	end
end

RunService.RenderStepped:Connect(function(dt: number)
	local i = 1
	while i <= #live do
		local w = live[i]
		w.age += dt
		if w.age * w.speed > w.range + 1 or w.age > 3 then
			drop(w)
			table.remove(live, i)
		else
			place(w)
			i += 1
		end
	end
end)

return ShockwaveFx
