--!strict
-- The win party (carter 10-29, try A "corner guns"): two guns in the bottom corners shoot confetti,
-- then it rains lightly; the winner's kart hops 3 times, the 2nd and 3rd karts hop a little after.
-- Plain numbers only, in the picture's 844 x 390 design space (the screen draws them).
local WinParty = {}

export type Bit = {
	x: number,
	y: number,
	vx: number,
	vy: number,
	rot: number,
	vr: number,
	ph: number,
	term: number,
	kind: string,
}

WinParty.W = 844
WinParty.H = 390
WinParty.GUN_AT = 0.5 -- s: both guns go off
WinParty.GUN_BITS = 30 -- per gun
WinParty.RAIN_FROM = 1.2 -- s: the light rain starts
WinParty.RAIN_RATE = 14 -- new bits a second
WinParty.ALIVE_MAX = 46 -- the rain waits while this many are in the air
WinParty.POOL = 80 -- most pieces ever on screen (60 from the guns + rain)
local GRAVITY = 700
local DRAG = 1.6
local TERMINAL = 150 -- the fall speed of paper

local WINNER_HOPS = {
	{ at = 0.9, h = 50, d = 0.55 },
	{ at = 1.6, h = 32, d = 0.46 },
	{ at = 2.2, h = 16, d = 0.36 },
}
local CLAP = { first = 1.15, gap = 0.18, h = 16, d = 0.4 }

local function frac(x: number): number
	return x - math.floor(x)
end

-- A hop from `at` for d s, h px high: how far up (negative px) and how big (stretch on take off,
-- squash on landing), nil when it is not hopping.
function WinParty.hop(t: number, at: number, h: number, d: number): (number?, number?)
	local u = (t - at) / d
	if u < 0 or u > 1.25 then
		return nil, nil
	end
	if u <= 1 then
		local sy = 1
		if u < 0.15 then
			sy = 1 + 0.12 * (1 - u / 0.15)
		elseif u > 0.85 then
			sy = 1 - 0.14 * ((u - 0.85) / 0.15)
		end
		return -4 * h * u * (1 - u), 1 + (sy - 1) / 2
	end
	local k = (u - 1) / 0.25
	return 0, 1 + (0.14 * (1 - k)) / 2
end

-- The winner's kart: how far up (px) and its size; nil before its first hop (the entrance runs).
function WinParty.winnerPose(t: number): (number?, number?)
	if t < WINNER_HOPS[1].at then
		return nil, nil
	end
	local lastEnd = 0
	for _, hp in WINNER_HOPS do
		local y, s = WinParty.hop(t, hp.at, hp.h, hp.d)
		if y then
			return y, s
		end
		lastEnd = hp.at + hp.d * 1.25
	end
	if t < lastEnd then
		return 0, 1 -- (a moment between two hops)
	end
	return -4 * math.sin(t * 3), 1 -- (then it bobs)
end

-- The 2nd and 3rd karts (place 2, 3) clap along: one small hop each, one after the other; nil = at rest.
function WinParty.clapPose(place: number, t: number): (number?, number?)
	return WinParty.hop(t, CLAP.first + (place - 1) * CLAP.gap, CLAP.h, CLAP.d)
end

-- Bit i of a gun: side 1 = the left corner (shoots right), -1 = the right corner.
function WinParty.shot(side: number, i: number): Bit
	local a = 0.9 + 0.55 * frac(i * 0.618)
	local sp = 520 + 460 * frac(i * 0.382 + 0.3)
	return {
		x = if side > 0 then 0 else WinParty.W,
		y = WinParty.H,
		vx = side * math.cos(a) * sp * 0.7,
		vy = -math.sin(a) * sp,
		rot = i * 1.7,
		vr = (i * 37) % 15 - 7,
		ph = i * 2.3,
		term = TERMINAL,
		kind = if i % 7 == 0 then "star" else "rect",
	}
end

-- A bit of rain from three numbers between 0 and 1.
function WinParty.drop(u1: number, u2: number, u3: number): Bit
	return {
		x = u1 * WinParty.W,
		y = -16,
		vx = -20 + 40 * u2,
		vy = 60 + 50 * u3,
		rot = u1 * 6.3,
		vr = (u2 - 0.5) * 14,
		ph = u3 * 6.3,
		term = TERMINAL,
		kind = "rect",
	}
end

-- One step of fall: gravity up to the paper's slow speed, a little sideways flutter.
function WinParty.step(b: Bit, dt: number)
	b.vy = math.min(b.vy + GRAVITY * dt, b.term)
	b.vx *= 1 - DRAG * dt
	b.ph += dt * (6 + math.abs(b.vr))
	b.x += (b.vx + math.sin(b.ph * 0.6) * 30) * dt
	b.y += b.vy * dt
	b.rot += b.vr * dt
end

-- Past the bottom or the sides: its piece can be used again.
function WinParty.gone(b: Bit): boolean
	return b.y > WinParty.H + 30 or b.x < -40 or b.x > WinParty.W + 40
end

return WinParty
