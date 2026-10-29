--!strict
-- Smash juice numbers (JUICE row): what each smash moment looks like, as pure data so Lune can
-- test it. client/SmashFx plays it.
--   * The words (carter's video, VIDEO-STUDY.md): "You SMASHED <name>" on your smash (a freeze
--     kill "SHATTERED"); "DOUBLE SMASH!" for 2 quick ones, "TRIPLE SMASH!" for 3; "SMASH STREAK
--     x3!" for 3+ in a row without being smashed. Smashed yourself: "You were smashed by X's
--     rocket" (mowed down by a machine gun, shattered by a freeze, ...), the camera shows X with
--     3-2-1, and hands back when you respawn.
--   * One strength ladder drives the shake, the zoom punch and the confetti (vault "Hit-Stop
--     and Screen Shake Tuning by Numbers": shake = trauma squared, so small hits only add up;
--     trauma is capped and decays).
--   * Reduced motion keeps the words, colors, confetti and the killer camera (it's info), and
--     drops the shake and zoom.
local SmashJuice = {}

-- ===== the words =====

SmashJuice.NAME_MAX = 14 -- longer names get cut, so the words fit a phone

function SmashJuice.shortName(name: string): string
	local clean = string.match(string.gsub(name, "%s+", " "), "^ ?(.-) ?$") :: string
	local n = utf8.len(clean)
	if n == nil or n == 0 then
		return "?"
	end
	if n <= SmashJuice.NAME_MAX then
		return clean
	end
	local cut = utf8.offset(clean, SmashJuice.NAME_MAX) :: number
	return string.sub(clean, 1, cut - 1) .. "…"
end

-- Weapon names on SmashFeed (lower case: MatchRunner sends Weapons.feedWord, "rocket", "nuke",
-- "machine gun", "mine", "freeze ray", or "bump"). Every death line names the thing that got you
-- (audit round 12 #9): "You were smashed by X's rocket", never just "by X".
--   killer = how you got it ("You were <verb> by X's <thing>"), mine = your smash word
type WeaponWords = { verb: string, thing: string, mine: string }
SmashJuice.WEAPONS = {
	rocket = { verb = "smashed", thing = "rocket", mine = "SMASHED" },
	nuke = { verb = "smashed", thing = "nuke", mine = "SMASHED" },
	gun = { verb = "mowed down", thing = "machine gun", mine = "SMASHED" },
	mine = { verb = "blown up", thing = "mine", mine = "SMASHED" },
	freeze = { verb = "shattered", thing = "freeze ray", mine = "SHATTERED" },
	bump = { verb = "bumped out", thing = "bump", mine = "SMASHED" },
} :: { [string]: WeaponWords }
-- the server's feed words and other spellings, to the rows above
local ALIAS = {
	rockets = "rocket",
	["machine gun"] = "gun",
	["freeze ray"] = "freeze",
	mines = "mine",
	ram = "bump",
	[""] = "bump", -- (MatchRunner's own default: no weapon word = a bump)
}
-- no killer: the arena got you (fell off, no one to blame)
local FELL = { bump = true, fall = true, arena = true, [""] = true }

local function words(weapon: string): WeaponWords
	local key = string.lower(weapon)
	key = ALIAS[key] or key
	local w = SmashJuice.WEAPONS[key]
	if w then
		return w
	end
	-- a weapon this list doesn't know yet still names itself (cut short: two feed rows)
	local thing = string.sub(key, 1, 14)
	return { verb = "smashed", thing = thing, mine = "SMASHED" }
end

-- "You SMASHED" / "You SHATTERED" (the name goes on the big line under it)
function SmashJuice.smashLine(weapon: string): string
	return "You " .. words(weapon).mine
end

-- "You were smashed by Botty's rocket"; no killer: "You fell out of the arena!" for a fall or a
-- bump, else "You were smashed by a rocket!" (whoever fired it has left)
function SmashJuice.deathLine(weapon: string, killer: string?): string
	local key = string.lower(weapon or "")
	if not killer then
		if FELL[ALIAS[key] or key] then
			return "You fell out of the arena!"
		end
		local w = words(weapon)
		local a = if string.match(w.thing, "^[aeiou]") then "an" else "a"
		return `You were {w.verb} by {a} {w.thing}!`
	end
	local w = words(weapon)
	return `You were {w.verb} by {SmashJuice.shortName(killer)}'s {w.thing}`
end

-- ===== who did what (the SmashFeed remote) =====

-- SmashFeed:FireAllClients(attacker, victim, weapon). Each side can be a Player, a bot's name
-- (string), or a table { name = string, userId = number?, kart = Model? }. nil attacker = the
-- arena got you (fell off). `kart` lets the killer camera find a bot's kart.
export type Side = { name: string, me: boolean, userId: number?, kart: Instance? }
export type Feed = { attacker: Side?, victim: Side, weapon: string }

local function side(v: unknown, meId: number): Side?
	if typeof(v) == "Instance" and v:IsA("Player") then
		return { name = v.DisplayName, me = v.UserId == meId, userId = v.UserId }
	elseif type(v) == "string" then
		return { name = string.sub(v, 1, 40), me = false }
	elseif type(v) == "table" then
		local t = v :: { [any]: unknown }
		local name, id, kart = t.name, t.userId, t.kart
		if type(name) == "string" then
			local uid = if type(id) == "number" then id else nil
			return {
				name = string.sub(name, 1, 40),
				me = uid ~= nil and uid == meId and meId ~= 0,
				userId = uid,
				kart = if typeof(kart) == "Instance" then kart else nil,
			}
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
-- quick: smashes within QUICK seconds of the one before (Double / Triple Smash)
-- run: smashes since you were last smashed (Smash Streak)

SmashJuice.QUICK = 4

export type Streak = {
	quick: number,
	run: number,
	last: number,
	smash: (self: Streak, now: number) -> string?,
	reset: (self: Streak) -> (),
}

local Streak = {}
Streak.__index = Streak

-- counts one smash at time `now` and gives the streak word (nil = just "You SMASHED X")
function Streak.smash(self: Streak, now: number): string?
	self.quick = if now - self.last <= SmashJuice.QUICK then self.quick + 1 else 1
	self.last = now
	self.run += 1
	if self.quick == 2 then
		return "DOUBLE SMASH!"
	elseif self.quick >= 3 then
		return "TRIPLE SMASH!"
	elseif self.run >= 3 then
		return `SMASH STREAK x{self.run}!`
	end
	return nil
end

function Streak.reset(self: Streak)
	self.quick = 0
	self.run = 0
	self.last = -math.huge
end

function SmashJuice.streak(): Streak
	return setmetatable({ quick = 0, run = 0, last = -math.huge }, Streak) :: any
end

-- ===== the killer camera =====
-- After you're smashed the camera flies to the killer and counts 3-2-1, then hands back when
-- you respawn (server: 3 s) or after KILLCAM_MAX at the latest, so it can never get stuck.

SmashJuice.KILLCAM_FLY = 0.35 -- seconds to swing over to the killer
SmashJuice.KILLCAM_MAX = 3.5
SmashJuice.KILLCAM_BACK = 16 -- studs behind the killer
SmashJuice.KILLCAM_UP = 9 -- studs above

-- the number to show t seconds after the smash (3, 2, 1, then nil)
function SmashJuice.countdown(t: number, respawn: number?): number?
	local total = respawn or 3
	if t < 0 or t >= total then
		return nil
	end
	return math.ceil(total - t)
end

-- how far (0..1) the camera has swung over to the killer
function SmashJuice.flyAlpha(t: number): number
	local u = math.clamp(t / SmashJuice.KILLCAM_FLY, 0, 1)
	return u * u * (3 - 2 * u)
end

-- ===== how hard each moment hits =====

export type Kind = "mySmash" | "hit" | "myHit" | "smashed" | "boom"
export type Feel = {
	trauma: number, -- added to the shake (0..1)
	punch: number, -- camera zoom-in, degrees of field of view
	slow: number, -- seconds the zoom holds before it eases back (the little slow-mo)
	confetti: number, -- pieces
	flash: number, -- 0..1 screen edge flash (red for hits, white for your smash)
}

local function none(): Feel
	return { trauma = 0, punch = 0, slow = 0, confetti = 0, flash = 0 }
end

-- `amount` = damage for "hit" and "myHit" (health 100), streak count for "mySmash", studs away for "boom"
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
			return none()
		end
		f = { trauma = 0.12 + 0.28 * s, punch = 0, slow = 0, confetti = 0, flash = 0.2 + 0.35 * s }
	elseif kind == "myHit" then
		-- your shot landed: a small kick, half a hit taken's, no flash
		local s = math.clamp(n / 40, 0, 1)
		if s <= 0 then
			return none()
		end
		f = { trauma = 0.06 + 0.14 * s, punch = 0, slow = 0, confetti = 0, flash = 0 }
	elseif kind == "smashed" then
		f = { trauma = 0.6, punch = 0, slow = 0, confetti = 0, flash = 0.6 }
	elseif kind == "boom" then
		-- a boom near you: full at 15 studs, nothing past 80 (smoothstep)
		local u = math.clamp((n - 15) / (80 - 15), 0, 1)
		local k = 1 - u * u * (3 - 2 * u)
		if k <= 0 then
			return none()
		end
		f = { trauma = 0.25 * k, punch = 0, slow = 0, confetti = 0, flash = 0 }
	else
		return none()
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
function SmashJuice.tilt(
	trauma: number,
	n1: number,
	n2: number,
	n3: number
): (number, number, number)
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

-- Where the words sit, as fractions of the whole phone screen (centre x 0.5, `y` = middle of the
-- line). Under the clock and health bar, over the car, between the scoreboard and FIRE (Lead,
-- Studio 10-28: they covered the clock and health at the top). Tested against the match HUD.
SmashJuice.WORDS_W = 0.36
-- (moved down after review: on a phone the HUD sits under Roblox's top bar, about 58 px, so its
-- health bar ends lower than the 390 px design says; the test checks with and without it)
SmashJuice.WORDS = {
	you = { y = 0.4, h = 0.07 },
	name = { y = 0.49, h = 0.1 },
	streak = { y = 0.59, h = 0.08 },
	by = { y = 0.43, h = 0.08 },
	count = { y = 0.54, h = 0.13 },
} :: { [string]: { y: number, h: number } }
-- (the words pop in from at most 1.5x, so the pop never sweeps over the HUD for long)

-- Palette for confetti (the low-poly look: grass, sky, sun, cherry, pink).
SmashJuice.CONFETTI = {
	{ 120, 200, 70 },
	{ 90, 180, 255 },
	{ 255, 210, 60 },
	{ 230, 50, 60 },
	{ 255, 90, 170 },
}

return SmashJuice
