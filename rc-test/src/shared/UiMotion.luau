--!strict
-- Car VS Car screens: the math behind the motion and the words (spec section 7), pure so Lune
-- tests it. client/Ui/Anim plays it with TweenService and one Heartbeat.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local UiTheme = sibling("UiTheme")

local UiMotion = {}

local P = UiTheme.PATTERN

-- How far the sliding pattern has moved at time t (0..tile px, the same right and down).
function UiMotion.patternOffset(t: number): number
	return (t % P.period) / P.period * P.tile
end

-- Ease out (cubic): fast, then settles.
function UiMotion.easeOut(f: number): number
	local x = math.clamp(f, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- A number counting up from `from` to `to` over `dur` (spec: 0.9 s, ease-out), whole numbers.
function UiMotion.countUp(from: number, to: number, t: number, dur: number?): number
	local d = dur or UiTheme.MOTION.countUp
	if d <= 0 or t >= d then
		return to
	end
	return math.floor(from + (to - from) * UiMotion.easeOut(t / d) + 0.5)
end

-- 2450 -> "2,450"; -1234 -> "-1,234"
function UiMotion.commas(n: number): string
	local whole = math.floor(math.abs(n) + 0.5)
	local s = tostring(whole)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

-- 102 -> "1:42"
function UiMotion.clock(secs: number): string
	local s = math.max(0, math.ceil(secs))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- "1 day", "3 days" (the daily gift's STREAK pill)
function UiMotion.days(n: number): string
	return tostring(n) .. (if n == 1 then " day" else " days")
end

-- 1 -> "1ST", 2 -> "2ND", 3 -> "3RD", 11 -> "11TH", 22 -> "22ND"
function UiMotion.place(n: number): string
	local teen = n % 100 >= 11 and n % 100 <= 13
	local last = n % 10
	local suffix = if teen
		then "TH"
		elseif last == 1 then "ST"
		elseif last == 2 then "ND"
		elseif last == 3 then "RD"
		else "TH"
	return tostring(n) .. suffix
end

-- The podium's shout: losing says NICE TRY!, never YOU LOST.
function UiMotion.finishShout(place: number): string
	if place == 1 then
		return "YOU WON!"
	elseif place <= 3 then
		return "TOP 3!"
	end
	return "NICE TRY!"
end

-- When the i-th item of a list starts its entrance (i from 1).
function UiMotion.stagger(i: number): number
	return (i - 1) * UiTheme.MOTION.listGap
end

-- Keyframes as { time (0..1 of the whole), scale }, eased between.
export type Keys = { { number } }
UiMotion.SHOUT_KEYS = { { 0, 0.3 }, { 0.6, 1.12 }, { 1, 1 } } :: Keys
UiMotion.GO_KEYS = { { 0, 0.2 }, { 0.35, 1.18 }, { 0.55, 0.94 }, { 0.7, 1 }, { 1, 1 } } :: Keys

function UiMotion.keyed(keys: Keys, f: number): number
	local x = math.clamp(f, 0, 1)
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if x <= b[1] then
			local span = b[1] - a[1]
			local k = if span > 0 then (x - a[1]) / span else 1
			-- smooth in and out between keys
			k = k * k * (3 - 2 * k)
			return a[2] + (b[2] - a[2]) * k
		end
	end
	return keys[#keys][2]
end

-- An idle bob: 0 at t = 0, up to -amp (screen y goes down) half a period later.
function UiMotion.bob(t: number, period: number, amp: number): number
	return -amp * (0.5 - 0.5 * math.cos(t / period * 2 * math.pi))
end

-- A round button's cooldown: how much of the clock slice is still dark (1 = just used, 0 = ready)
-- and the words in it ("0:24", "" when ready).
function UiMotion.cooldown(left: number, total: number): (number, string)
	if total <= 0 or left <= 0 then
		return 0, ""
	end
	return math.clamp(left / total, 0, 1), UiMotion.clock(left)
end

-- Odds rows: "60%", "2.5%", "0.5%"
function UiMotion.percent(p: number): string
	if math.abs(p - math.floor(p)) < 1e-6 then
		return string.format("%d%%", p)
	end
	return (string.format("%.1f", p):gsub("0+$", ""):gsub("%.$", "")) .. "%"
end

return UiMotion
