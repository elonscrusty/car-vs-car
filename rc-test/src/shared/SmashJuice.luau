--!strict
-- Smash juice numbers (phase 4, JUICE row): what each smash moment looks like, as pure data so
-- Lune can test it. client/SmashFx plays it.
--   * The words: "You SMASHED <name>!" on your smash, a streak word from your 2nd smash in a row
--     ("DOUBLE SMASH!" ...), and "SMASHED by <name>" when you get smashed. A streak ends when
--     you get smashed.
--   * One strength ladder drives the shake, the zoom punch and the confetti (vault "Hit-Stop
--     and Screen Shake Tuning by Numbers": shake = trauma squared, so small hits only add up;
--     trauma is capped and decays).
--   * Reduced motion keeps the words, colors and confetti, and drops the shake and zoom.
local SmashJuice = {}

-- ===== the words =====

SmashJuice.NAME_MAX = 14 -- longer names get cut, so the words fit a phone

function SmashJuice.shortName(name: string): string
	local clean = string.gsub(name, "%s+", " ")
	if utf8.len(clean) == nil then
		return "?"
	end
	if (utf8.len(clean) :: number) <= SmashJuice.NAME_MAX then
		return clean
	end
	local cut = utf8.offset(clean, SmashJuice.NAME_MAX) :: number
	return string.sub(clean, 1, cut - 1) .. "…"
end

-- streak words by how many smashes in a row (nil for the first one: "You SMASHED X" is enough)
SmashJuice.STREAK_WORDS = {
	[2] = "DOUBLE SMASH!",
	[3] = "TRIPLE SMASH!",
	[4] = "MEGA SMASH!",
	[5] = "UNSTOPPABLE!",
}

function SmashJuice.streakWord(count: number): string?
	if count < 2 then
		return nil
	end
	local w = SmashJuice.STREAK_WORDS[count]
	if w then
		return w
	end
	return `SMASH STREAK x{count}!`
end

-- ===== who did what (the SmashFeed remote) =====

-- SmashFeed sends (attacker, victim, weapon). Each side can be a Player, a bot's name (string),
-- or a table { name = string, userId = number? }. nil attacker = the arena got you (fell off).
export type Side = { name: string, me: boolean }
export type Feed = { attacker: Side?, victim: Side, weapon: string }

local function side(v: unknown, meId: number): Side?
	if typeof(v) == "Instance" and v:IsA("Player") then
		return { name = v.DisplayName, me = v.UserId == meId }
	elseif type(v) == "string" then
		return { name = v, me = false }
	elseif type(v) == "table" then
		local t = v :: { [any]: unknown }
		local name, id = t.name, t.userId
		if type(name) == "string" then
			return { name = name, me = type(id) == "number" and id == meId and meId ~= 0 }
		end
	end
	return nil
end

-- junk in → nil (the client never trusts the shape of a remote's arguments)
function SmashJuice.read(attacker: unknown, victim: unknown, weapon: unknown, meId: number): Feed?
	local v = side(victim, meId)
	if not v then
		return nil
	end
	local a = if attacker == nil then nil else side(attacker, meId)
	return {
		attacker = a,
		victim = v,
		weapon = if type(weapon) == "string" then string.sub(weapon, 1, 20) else "",
	}
end

-- ===== streaks =====

export type Streak = {
	count: number,
	smash: (self: Streak) -> number,
	reset: (self: Streak) -> (),
}

local Streak = {}
Streak.__index = Streak

function Streak.smash(self: Streak): number
	self.count += 1
	return self.count
end

function Streak.reset(self: Streak)
	self.count = 0
end

function SmashJuice.streak(): Streak
	return setmetatable({ count = 0 }, Streak) :: any
end

-- ===== how hard each moment hits =====

export type Kind = "mySmash" | "hit" | "smashed" | "boom"
export type Feel = {
	trauma: number, -- added to the shake (0..1)
	punch: number, -- camera zoom-in, degrees of field of view
	slow: number, -- seconds the zoom holds before it eases back (the little slow-mo)
	confetti: number, -- pieces
	flash: number, -- 0..1 screen edge flash (red for hits, white for your smash)
}

local NONE: Feel = { trauma = 0, punch = 0, slow = 0, confetti = 0, flash = 0 }

-- `amount` = damage for "hit" (health 100), streak count for "mySmash", studs away for "boom"
function SmashJuice.feel(kind: Kind, amount: number?, reduced: boolean?): Feel
	local n = amount or 0
	local f: Feel
	if kind == "mySmash" then
		local streak = math.max(1, n)
		f = {
			trauma = math.min(0.35 + 0.08 * (streak - 1), 0.6),
			punch = 8,
			slow = 0.18,
			confetti = math.min(24 + 8 * (streak - 1), 48),
			flash = 0.35,
		}
	elseif kind == "hit" then
		-- 10 damage is a nudge, 40+ (a rocket) is a real thump
		local s = math.clamp(n / 40, 0, 1)
		if s <= 0 then
			return NONE
		end
		f = { trauma = 0.12 + 0.28 * s, punch = 0, slow = 0, confetti = 0, flash = 0.2 + 0.35 * s }
	elseif kind == "smashed" then
		f = { trauma = 0.6, punch = 0, slow = 0, confetti = 0, flash = 0.6 }
	elseif kind == "boom" then
		-- a boom near you: full at 15 studs, nothing past 80 (smoothstep)
		local u = math.clamp((n - 15) / (80 - 15), 0, 1)
		local k = 1 - u * u * (3 - 2 * u)
		if k <= 0 then
			return NONE
		end
		f = { trauma = 0.25 * k, punch = 0, slow = 0, confetti = 0, flash = 0 }
	else
		return NONE
	end
	if reduced then
		f.trauma = 0
		f.punch = 0
		f.slow = 0
	end
	return f
end

-- ===== the shake =====

SmashJuice.MAX_TRAUMA = 1
SmashJuice.DECAY = 1.6 -- trauma lost per second
SmashJuice.MAX_DEGREES = 2.4 -- tilt at full trauma (about 3% of a phone screen at FOV 70)
SmashJuice.NOISE_HZ = 16

function SmashJuice.addTrauma(now: number, add: number): number
	return math.clamp(now + add, 0, SmashJuice.MAX_TRAUMA)
end

function SmashJuice.decay(trauma: number, dt: number): number
	return math.max(0, trauma - SmashJuice.DECAY * dt)
end

-- noise speed: never more than 0.4 x the frame rate, so a 30 fps phone doesn't jitter
function SmashJuice.noiseHz(fps: number): number
	return math.min(SmashJuice.NOISE_HZ, 0.4 * math.max(fps, 1))
end

-- the tilt (pitch, yaw, roll) in degrees for this trauma; n1..n3 are noise in -1..1
function SmashJuice.tilt(trauma: number, n1: number, n2: number, n3: number): (number, number, number)
	local s = trauma * trauma * SmashJuice.MAX_DEGREES
	return s * n1, s * n2, s * 0.5 * n3
end

-- the zoom punch: in fast, hold `slow` seconds, ease back over 0.3 s. t = seconds since the smash
SmashJuice.PUNCH_IN = 0.05
SmashJuice.PUNCH_OUT = 0.3

function SmashJuice.punchAt(punch: number, slow: number, t: number): number
	if punch <= 0 or t < 0 then
		return 0
	end
	if t < SmashJuice.PUNCH_IN then
		return punch * (t / SmashJuice.PUNCH_IN)
	end
	t -= SmashJuice.PUNCH_IN
	if t < slow then
		return punch
	end
	t -= slow
	if t >= SmashJuice.PUNCH_OUT then
		return 0
	end
	local u = 1 - t / SmashJuice.PUNCH_OUT
	return punch * u * u
end

-- ===== how long the words stay =====

SmashJuice.WORDS_SECONDS = 1.6
SmashJuice.STREAK_SECONDS = 1.9
SmashJuice.SMASHED_BY_SECONDS = 2.2
SmashJuice.SHOW_LIMIT = 0.1 -- hard target: words on screen ≤ 0.1 s after the hit arrives

-- Palette for confetti (the low-poly look: grass, sky, sun, cherry, pink).
SmashJuice.CONFETTI = {
	{ 120, 200, 70 },
	{ 90, 180, 255 },
	{ 255, 210, 60 },
	{ 230, 50, 60 },
	{ 255, 90, 170 },
}

return SmashJuice
