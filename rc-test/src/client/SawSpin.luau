--!strict
-- The Road Saw car's blades (car 7), drawn. Blade parts of a skin carry a "SpinAxis" attribute
-- (model space); CarSkin turns them about it every frame by the angle this module gives.
-- Idle: a slow turn so the blades always look alive. Revved: the server sent "SawRev"
-- { owner, seconds } (WeaponFx forwards it), the blades whirl until the time is up, then ease
-- back down. The server decides every cut; this only draws.
-- (services are fetched when a spark is drawn, so Lune tests can load this file)
local SawSpin = {}

SawSpin.IDLE = 3 -- radians a second
SawSpin.REV = 45 -- radians a second while revved (a blur: about 7 turns a second)
SawSpin.EASE = 6 -- how fast the speed follows the wanted one (per second)

type State = { angle: number, speed: number, last: number }
local states: { [Instance]: State } = {}
-- kart model name ("Car_<id>") -> os.clock() time the rev ends
local revUntil: { [string]: number } = {}

-- The speed wanted now, from how long the rev has left. Plain numbers, so tests can run it.
function SawSpin.wanted(left: number): number
	return if left > 0 then SawSpin.REV else SawSpin.IDLE
end

-- Move `speed` toward `want` over dt (never overshoots).
function SawSpin.ease(speed: number, want: number, dt: number): number
	local k = math.clamp(SawSpin.EASE * dt, 0, 1)
	return speed + (want - speed) * k
end

-- The angle the blades of `model` (the kart's server model, Car_<id>) are turned to now. Call it
-- once a frame per kart: it moves the angle on by the time since its last call.
function SawSpin.angle(model: Instance): number
	local now = os.clock()
	local s = states[model]
	if not s then
		s = { angle = 0, speed = SawSpin.IDLE, last = now }
		states[model] = s
	end
	local dt = math.clamp(now - s.last, 0, 0.1)
	s.last = now
	local left = (revUntil[model.Name] or 0) - now
	s.speed = SawSpin.ease(s.speed, SawSpin.wanted(left), dt)
	s.angle = (s.angle + s.speed * dt) % (2 * math.pi)
	return s.angle
end

-- Is this kart's saw revving right now? (sparks and sound want to know)
function SawSpin.revving(modelName: string): boolean
	return (revUntil[modelName] or 0) > os.clock()
end

-- ===== sparks: "Orange Shower" (carter's pick, 10-31): little neon chips thrown up and ahead =====
SawSpin.CHIPS = 14
local SCALE = 0.25 -- RC size (TrackData.RC_SCALE)
local COLORS = {
	Color3.fromRGB(255, 170, 40),
	Color3.fromRGB(255, 225, 90),
	Color3.fromRGB(255, 120, 20),
}
type Chip = { part: Part, vel: Vector3, age: number, life: number, size: number }
local chips: { Chip } = {}
local conn: RBXScriptConnection? = nil

local function stepChips(dt: number)
	for i = #chips, 1, -1 do
		local c = chips[i]
		c.age += dt
		if c.age >= c.life or c.part.Parent == nil then
			c.part:Destroy()
			table.remove(chips, i)
			continue
		end
		c.vel += Vector3.new(0, -16 * SCALE * 4 * dt, 0)
		c.part.Position += c.vel * dt
		c.part.Size = Vector3.one * c.size * (0.4 + 0.6 * (1 - c.age / c.life))
	end
	if #chips == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

local function burst(at: Vector3)
	for _ = 1, SawSpin.CHIPS do
		local size = (0.08 + math.random() * 0.08) * SCALE * 4
		local p = Instance.new("Part")
		p.Name = "SawChip"
		p.Size = Vector3.one * size
		p.Position = at
		p.Color = COLORS[math.random(1, #COLORS)]
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = workspace
		local life = 0.45 + math.random() * 0.4
		game:GetService("Debris"):AddItem(p, life + 0.5)
		local k = SCALE * 4
		local sx = (math.random() - 0.5) * 5 * k
		local sz = (math.random() - 0.5) * 5 * k
		local vel = Vector3.new(sx, (2.5 + math.random() * 4.5) * k, sz)
		table.insert(chips, {
			part = p,
			vel = vel,
			age = 0,
			life = life,
			size = size,
		})
	end
	if not conn then
		conn = game:GetService("RunService").RenderStepped:Connect(stepChips)
	end
end

function SawSpin.handle(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "SawRev" and data.owner ~= nil and type(data.seconds) == "number" then
		revUntil["Car_" .. tostring(data.owner)] = os.clock() + math.clamp(data.seconds, 0, 10)
	elseif kind == "SawHit" and typeof(data.position) == "Vector3" then
		burst(data.position)
	end
end

return SawSpin
