--!strict
-- The Road Saw car's blades (car 7), drawn. Blade parts of a skin carry a "SpinAxis" attribute
-- (model space); CarSkin turns them about it every frame by the angle this module gives.
-- Idle: a slow turn so the blades always look alive. Revved: the server sent "SawRev"
-- { owner, seconds } (WeaponFx forwards it), the blades whirl until the time is up, then ease
-- back down. The server decides every cut; this only draws.
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

function SawSpin.handle(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "SawRev" and data.owner ~= nil and type(data.seconds) == "number" then
		revUntil["Car_" .. tostring(data.owner)] = os.clock() + math.clamp(data.seconds, 0, 10)
	end
end

return SawSpin
