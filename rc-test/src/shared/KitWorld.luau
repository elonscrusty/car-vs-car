--!strict
-- carter's UI kit v41 (ui-kit/v41, HUD_HANDOFF "Motion") for the bits drawn in the world and over
-- the arena: the "-N" hit number on a yellow burst, the low-health red edge, and the kit look of
-- the weapon icon floating over each kart. Looks only: the server decides every hit. Every number
-- lives here so Lune can test it; client/SmashHits, client/LowHealthEdge and
-- client/KartWeaponIcon draw them.

local KitWorld = {}

-- ===== kit colours (HUD_HANDOFF "Tokens") =====
KitWorld.INK = { 13, 44, 64 } -- #0d2c40: every outline and text stroke
KitWorld.GO = { 255, 217, 59 } -- #ffd93b: the burst
KitWorld.GO_DEEP = { 217, 154, 0 } -- #d99a00
KitWorld.DANGER = { 236, 28, 46 } -- #ec1c2e
KitWorld.PINK = { 255, 79, 154 } -- #ff4f9a: the weapon bubble (the kit's fire button with a weapon)
KitWorld.PINK_DEEP = { 200, 32, 106 } -- #c8206a
-- the red number's fill, top to bottom (ui.css .rt::after)
KitWorld.NUMBER_TOP = { 255, 217, 168 } -- #ffd9a8
KitWorld.NUMBER_MID = { 255, 122, 61 } -- #ff7a3d
KitWorld.NUMBER_LOW = { 232, 20, 44 } -- #e8142c

-- ===== the "-N" hit number =====
-- Red stroked number on a yellow burst: grows 0.4 -> 1.2 -> 1 in 0.26 s, rises 44 px over 0.9 s,
-- fades over the last 0.3 s. Pooled, at most 12 at once (the oldest is reused).
KitWorld.POP_FROM = 0.4
KitWorld.POP_PEAK = 1.2
KitWorld.POP_GROW = 0.16 -- s to the peak
KitWorld.POP_SETTLE = 0.1 -- s from the peak back to 1 (0.26 s in all)
KitWorld.RISE_PX = 44
KitWorld.SECONDS = 0.9
KitWorld.FADE = 0.3 -- s: the last part fades out
KitWorld.POOL_CAP = 12
KitWorld.NUMBER_PX = 32 -- the number's text size (the kit's 32 px at 844 x 390)
KitWorld.BURST_PX = 64 -- the burst, across
KitWorld.STROKE_PX = 4 -- the ink stroke on the number (kit: 4-7 px)
KitWorld.DROP_PX = 4 -- the ink drop under the number
KitWorld.NUMBER_SIDE = 0.75 -- the number's gui sits this many of its widths right of the kart
KitWorld.BURST_POINTS = 3 -- squares turned 0, 30 and 60 degrees: a 12-point burst
-- the number starts this far up from the kart's roof spot (px), so it never sits on the weapon
-- badge floating over other karts (auditor 10-29: "-34" sat on it); see numberAbove
KitWorld.NUMBER_LIFT = 0.4 -- studs over the kart's middle: the same spot as the badge's

-- The number's look `t` s after it shows: its scale, how far it has risen (px) and how see-through
-- it is (0 solid .. 1 gone). Reduced motion: no grow and no rise, it only fades.
function KitWorld.number(t: number, reduced: boolean?): (number, number, number)
	t = math.max(t, 0)
	local fadeFrom = KitWorld.SECONDS - KitWorld.FADE
	local see = if t <= fadeFrom then 0 else math.clamp((t - fadeFrom) / KitWorld.FADE, 0, 1)
	if reduced then
		return 1, 0, see
	end
	local scale
	if t < KitWorld.POP_GROW then
		scale = KitWorld.POP_FROM
			+ (KitWorld.POP_PEAK - KitWorld.POP_FROM) * (t / KitWorld.POP_GROW)
	elseif t < KitWorld.POP_GROW + KitWorld.POP_SETTLE then
		local u = (t - KitWorld.POP_GROW) / KitWorld.POP_SETTLE
		scale = KitWorld.POP_PEAK + (1 - KitWorld.POP_PEAK) * u
	else
		scale = 1
	end
	local rise = KitWorld.RISE_PX * math.clamp(t / KitWorld.SECONDS, 0, 1)
	return scale, rise, see
end

-- Which pooled number to use: a free one if there is one, else (all `cap` busy) the oldest busy
-- one. `busy` is the start times of the ones showing, by slot; returns the slot (a new slot when
-- there is room).
function KitWorld.pick(busy: { [number]: number? }, size: number, cap: number?): number
	local most = cap or KitWorld.POOL_CAP
	local oldest, oldestAt = nil :: number?, math.huge
	for i = 1, size do
		local at = busy[i]
		if at == nil then
			return i
		end
		if at < oldestAt then
			oldest, oldestAt = i, at
		end
	end
	if size < most then
		return size + 1
	end
	return oldest or 1
end

-- ===== the low-health edge =====
-- A soft red edge round the screen, breathing slowly (1.8 s), at 25 health and under (the kit's
-- lowHp). Never a fast full-screen flash (vault: Accessibility).
KitWorld.LOW_AT = 25 -- health (of Match.HEALTH 100) and under
KitWorld.PULSE = 1.8 -- s for one breath
KitWorld.EDGE_LOW = 0.82 -- the breath's faint end (kit @keyframes vig: opacity .82 -> 1)
KitWorld.EDGE_FADE = 0.3 -- s to come in or go away
KitWorld.EDGE_DEPTH = 0.16 -- of the screen's short side: how far the red reaches in
KitWorld.EDGE_RIM_PX = 6 -- the solid red line at the very edge
KitWorld.EDGE_RED = { 255, 34, 34 }

-- Should the edge show? Only in a match, alive, and at LOW_AT or under.
function KitWorld.low(inMatch: unknown, health: unknown): boolean
	return inMatch == true and type(health) == "number" and health > 0 and health <= KitWorld.LOW_AT
end

-- How strong (0..1) the edge is `t` s into its breathing. Reduced motion: steady, no breath.
function KitWorld.breath(t: number, reduced: boolean?): number
	if reduced then
		return 0.9
	end
	local u = 0.5 - 0.5 * math.cos(2 * math.pi * t / KitWorld.PULSE) -- 0 at the start, 1 mid-way
	return KitWorld.EDGE_LOW + (1 - KitWorld.EDGE_LOW) * u
end

-- ===== speed lines (kit "speed": white streaks at the screen's sides at top speed) =====
-- 4 thin white streaks near the left and right edges slide down and fade, a 0.45 s loop, while
-- your kart is near top speed in a match. Never in the middle of the screen; off with reduced
-- motion (the kit's prefers-reduced-motion turns .speed off).
KitWorld.LINES_FROM = 0.85 -- of top speed: the lines start to show
KitWorld.LINES_FULL = 0.97 -- of top speed: full strength
KitWorld.LINES_LOOP = 0.45 -- s for one streak to slide down
KitWorld.LINES_DROP = 200 -- px a streak slides (kit: -40 -> 160)
KitWorld.LINES_ALPHA = 0.9 -- a streak's strongest (kit opacity .9)
-- the kit's 4 streaks at 844 x 390: from the left (or right) edge, from the top, width, height,
-- and how far into the loop each starts (s)
KitWorld.LINES = {
	{ side = -1, x = 24, y = 150, w = 6, h = 70, lag = 0 },
	{ side = -1, x = 70, y = 200, w = 5, h = 56, lag = 0.2 },
	{ side = 1, x = 24, y = 140, w = 6, h = 70, lag = 0.1 },
	{ side = 1, x = 76, y = 120, w = 5, h = 56, lag = 0.3 },
}

-- How strong (0..1) the speed lines are at `share` of top speed (0 below LINES_FROM); 0 out of a
-- match and with reduced motion.
function KitWorld.speedLines(share: number, inMatch: unknown, reduced: boolean?): number
	if reduced or inMatch ~= true then
		return 0
	end
	return math.clamp(
		(share - KitWorld.LINES_FROM) / (KitWorld.LINES_FULL - KitWorld.LINES_FROM),
		0,
		1
	)
end

-- One streak `t` s into the loop: how far down it has slid (px, from its spot) and how strong
-- (0..1): it fades in over the first 30% and out to the end (kit @keyframes speed).
function KitWorld.streak(t: number): (number, number)
	local u = (t % KitWorld.LINES_LOOP) / KitWorld.LINES_LOOP
	local a = if u < 0.3 then u / 0.3 else 1 - (u - 0.3) / 0.7
	return -40 + KitWorld.LINES_DROP * u, a * KitWorld.LINES_ALPHA
end

-- ===== the weapon icon over a kart (carter 10-28: an icon, never a weapon model) =====
-- just over the roof (ICON_LIFT studs), then ICON_RAISE icon heights up on screen so it floats
-- above the YOU / name tag; ICON_PX across (ICON_PX_PHONE on a phone)
KitWorld.ICON_PX = 40
KitWorld.ICON_PX_PHONE = 26
KitWorld.ICON_LIFT = 0.4
KitWorld.ICON_RAISE = 1.4

-- How far up (px) the hit number's bottom starts from the badge's spot: clear of the top of the
-- biggest badge, with a small gap.
function KitWorld.numberAbove(): number
	return math.ceil((KitWorld.ICON_RAISE + 0.5) * KitWorld.ICON_PX) + 6
end
-- The kit look: a round pink bubble with an ink rim and a top shine (the kit's fire button with a
-- weapon), the weapon's icon in it, and a yellow ammo coin with an ink rim.
KitWorld.ICON_RIM_PX = 3
KitWorld.COIN = 0.5 -- the ammo coin, of the bubble's size
-- The picture for each weapon, once carter's 3D icons are uploaded: "rbxassetid://<number>".
-- Empty = the drawn stand-in (Ui/Icons). Never a made-up number.
KitWorld.WEAPON_IMAGES = {
	rocket = "",
	nuke = "",
	gun = "",
	mine = "",
	freeze = "",
	power = "",
	mystery = "",
} :: { [string]: string }

-- Is the icon shown over a kart? Only while it holds a weapon with ammo, and never over your own
-- kart (Lead 10-29: FIRE already shows yours, and it stacked with the YOU tag); every other kart
-- keeps it (carter 10-28).
function KitWorld.iconShown(weapon: unknown, ammo: unknown, mine: boolean): boolean
	return not mine
		and type(weapon) == "string"
		and weapon ~= ""
		and type(ammo) == "number"
		and ammo > 0
end

-- The uploaded picture for an icon key, or nil (draw the stand-in).
function KitWorld.weaponImage(key: string): string?
	local id = KitWorld.WEAPON_IMAGES[key]
	if type(id) == "string" and string.match(id, "^rbxassetid://%d+$") then
		return id
	end
	return nil
end

return KitWorld
