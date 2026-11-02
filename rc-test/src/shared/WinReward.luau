--!strict
-- The win screen's coins + LEVEL UP (carter 10-29, try A): coins fly one by one from the winner's
-- step into the coins number with a ding each, then the level bar fills and a big LEVEL UP! slams
-- down with a burst of stars. Plain numbers only (the screen draws them): times in seconds from
-- the screen opening, places as 0..1 of the picture.
local WinReward = {}

WinReward.COINS = 14 -- coins in the stream (a pool of this many frames)
WinReward.FIRST_AT = 0.8 -- s: the first coin leaves
WinReward.GAP = 0.06 -- s between two coins leaving
WinReward.FLIGHT = 0.7 -- s in the air
WinReward.FILL_AT = 2.5 -- s: the level bar starts to fill (after the last coin has landed)
WinReward.FILL_SECS = 0.8 -- s: bar to full
WinReward.BANNER_AT = 3.35 -- s: LEVEL UP! slams down (the bar is full)
WinReward.BANNER_HOLD = 2.6 -- s on screen before it shrinks away
WinReward.STARS = 12 -- gold and green stars thrown by the banner
WinReward.STAR_LIFE = 1.4 -- s a star stays in the air

local GRAVITY = 520

local function frac(x: number): number
	return x - math.floor(x)
end

local function easeInOut(u: number): number
	u = math.clamp(u, 0, 1)
	if u < 0.5 then
		return 4 * u * u * u
	end
	return 1 - (-2 * u + 2) ^ 3 / 2
end

-- When coin k (1..COINS) leaves and when it lands.
function WinReward.leaves(k: number): number
	return WinReward.FIRST_AT + (k - 1) * WinReward.GAP
end
function WinReward.lands(k: number): number
	return WinReward.leaves(k) + WinReward.FLIGHT
end

-- The coins number after coin k has landed: it climbs in even steps and ends on exactly `total`.
function WinReward.shown(k: number, total: number): number
	if k >= WinReward.COINS then
		return total
	end
	return math.floor(total * math.max(k, 0) / WinReward.COINS)
end

-- Where coin k sideways swings to on the way (its own spread, -150..150 px of 844).
function WinReward.swing(k: number): number
	return (frac(k * 0.618) - 0.5) * 300
end

-- A coin on its way from (sx, sy) to (tx, ty) after u of its flight (0..1): up and over, then in.
-- Returns x, y in the same units, and the coin's size (1 = normal, bigger in the middle).
function WinReward.fly(
	k: number,
	u: number,
	sx: number,
	sy: number,
	tx: number,
	ty: number
): (number, number, number)
	local e = easeInOut(u)
	local cx, cy = sx + WinReward.swing(k), sy - (80 + 70 * frac(k * 0.382))
	local a, b, c = (1 - e) * (1 - e), 2 * (1 - e) * e, e * e
	return a * sx + b * cx + c * tx,
		a * sy + b * cy + c * ty,
		1 + 0.4 * math.sin(math.clamp(u, 0, 1) * math.pi)
end

-- How wide a spinning coin looks (0.18..1) a moment after it left.
function WinReward.spin(k: number, secs: number): number
	return math.max(0.18, math.abs(math.cos(k + secs * 14)))
end

-- The pulse of the coins number when a coin lands: 1 right then, back to 0 over 0.3 s.
function WinReward.pulse(since: number): number
	return math.clamp(1 - since / 0.3, 0, 1)
end

-- One star of the LEVEL UP! burst, thrown from the banner: x, y (px of 844 x 390) after `age` s,
-- nil when it is spent. Stars fly out, rise a little, then fall.
function WinReward.star(i: number, age: number, ox: number, oy: number): (number?, number?)
	if age < 0 or age > WinReward.STAR_LIFE then
		return nil, nil
	end
	local vx = (frac(i * 0.618) - 0.5) * 760
	local vy = -60 - 360 * frac(i * 0.382 + 0.2)
	return ox + vx * age * (1 - 0.5 * age), oy + vy * age + GRAVITY * age * age
end

return WinReward
