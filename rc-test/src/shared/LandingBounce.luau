--!strict
-- Landing bounce (looks only): after a jump the car's drawn body squashes flat and wide, stretches
-- tall, then wobbles back. Pure maths so Lune can test it; the driving never reads any of this.

local LandingBounce = {}

LandingBounce.HZ = 3.8 -- wobbles per second
LandingBounce.DAMP = 0.24 -- 0 = never stops, 1 = no wobble
LandingBounce.SQUASH = 0.24 -- how much shorter the hardest landing makes the body
LandingBounce.WIDEN = 0.16 -- and how much wider
LandingBounce.LENGTH = 1.6 -- seconds until it is back to normal

export type State = { t: number, hard: number }

function LandingBounce.new(): State
	return { t = LandingBounce.LENGTH, hard = 0 }
end

-- A landing (0..1, telemetry.landed) restarts the wobble; the harder of old and new wins.
function LandingBounce.land(s: State, hard: number)
	if hard <= 0 then
		return
	end
	s.hard = math.max(hard, math.abs(s.hard * LandingBounce.damped(s.t)))
	s.t = 0
end

function LandingBounce.damped(t: number): number
	local w = 2 * math.pi * LandingBounce.HZ
	local z = LandingBounce.DAMP
	return math.exp(-z * w * t) * math.cos(w * math.sqrt(1 - z * z) * t)
end

-- Moves the wobble on by dt and gives how much to scale the body: sx (width and length), sy (height).
function LandingBounce.step(s: State, dt: number): (number, number)
	if s.t >= LandingBounce.LENGTH then
		s.hard = 0
		return 1, 1
	end
	s.t += dt
	local k = s.hard * LandingBounce.damped(s.t)
	return 1 + LandingBounce.WIDEN * k, 1 - LandingBounce.SQUASH * k
end

return LandingBounce
