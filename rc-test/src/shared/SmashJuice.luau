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
--   * Hit shake "C" (carter's pick, 10-29, camera/hit-shake.html): a hit shoves the camera away
--     (a spring that wobbles back), shakes it quickly, and pops the zoom. The numbers are the
--     page's, with 11 px of the page = 1 degree.
--   * Reduced motion keeps the words, colors, confetti and the killer camera (it's info), and
--     drops the shake, shove and zoom.
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
	flame = { verb = "burned", thing = "flamethrower", mine = "SMASHED" },
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
} :: { [string]: string }
-- no killer: the arena got you (fell off, no one to blame)
local FELL = { bump = true, fall = true, arena = true, [""] = true } :: { [string]: boolean }

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

-- The big gold pop word on your smash (match 1A, carter 10-29): "SMASH!" ("SHATTERED!" for a
-- freeze), the victim's name under it
function SmashJuice.popWord(weapon: string): string
	return if words(weapon).mine == "SHATTERED" then "SHATTERED!" else "SMASH!"
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

-- The "wrecked" card (carter 10-29, tries A): a big red verb, a name tag with the weapon on a
-- pink badge, and the 3-2-1 ring. `verb` is the shout ("MOWED DOWN!"), `tag` the line on the tag
-- ("by Zed's machine gun", "no one to blame" for a fall), `icon` the Icons.make name.
local WRECK_ICONS =
	{ rocket = "rocket", nuke = "nuke", gun = "gun", mine = "mine", freeze = "freeze" }
export type Wreck = { verb: string, tag: string, icon: string }
function SmashJuice.wreck(weapon: string, killer: string?): Wreck
	local key = string.lower(weapon or "")
	key = ALIAS[key] or key
	if not killer and FELL[key] then
		return { verb = "YOU FELL OUT!", tag = "no one to blame", icon = "arrow" }
	end
	local w = words(weapon)
	local icon = WRECK_ICONS[key] or "burst"
	if not killer then
		local a = if string.match(w.thing, "^[aeiou]") then "an" else "a"
		return { verb = string.upper(w.verb) .. "!", tag = `by {a} {w.thing}`, icon = icon }
	end
	return {
		verb = string.upper(w.verb) .. "!",
		tag = `by {SmashJuice.shortName(killer)}'s {w.thing}`,
		icon = icon,
	}
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
	punch: number, -- camera zoom-in, degrees of field of view (below 0 = zoom out)
	kick: number, -- camera shoved sideways, degrees (the side is picked when it plays)
	lift: number, -- camera shoved up (below 0 = down), degrees
	twist: number, -- camera rolled, degrees (the side is picked when it plays)
	slow: number, -- seconds the zoom holds before it eases back (the little slow-mo)
	confetti: number, -- pieces
	flash: number, -- 0..1 screen edge flash (red for hits, white for your smash)
}

local function none(): Feel
	return {
		trauma = 0,
		punch = 0,
		kick = 0,
		lift = 0,
		twist = 0,
		slow = 0,
		confetti = 0,
		flash = 0,
	}
end

-- `amount` = damage for "hit" and "myHit" (health 100), streak count for "mySmash", studs away for "boom"
function SmashJuice.feel(kind: Kind, amount: number?, reduced: boolean?): Feel
	local n = amount or 0
	local f: Feel
	if kind == "mySmash" then
		local streak = math.max(1, n)
		f = {
			trauma = math.min(0.6 + 0.08 * (streak - 1), 1),
			punch = 9,
			kick = 0,
			lift = -2, -- the camera dips, then bounces back
			twist = 0,
			slow = 0.16,
			confetti = math.min(24 + 8 * (streak - 1), 48),
			flash = 0.35,
		}
	elseif kind == "hit" then
		-- 10 damage is a nudge, 40+ (a rocket) is a real thump; the zoom pop starts above a nudge
		local s = math.clamp(n / 40, 0, 1)
		if s <= 0 then
			return none()
		end
		f = {
			trauma = 0.25 + 0.55 * s,
			punch = 3.5 * math.clamp((s - 0.25) / 0.75, 0, 1),
			kick = 0.3 + 2.8 * s,
			lift = 0.1 + 0.72 * s,
			twist = 0.2 + 2.2 * s,
			slow = 0.02,
			confetti = 0,
			flash = 0.2 + 0.35 * s,
		}
	elseif kind == "myHit" then
		-- your shot landed: a small kick, half a hit taken's, no flash
		local s = math.clamp(n / 40, 0, 1)
		if s <= 0 then
			return none()
		end
		f = none()
		f.trauma = 0.06 + 0.14 * s
	elseif kind == "smashed" then
		f = {
			trauma = 1,
			punch = -5, -- the view pulls out
			kick = 6.4,
			lift = 1.6,
			twist = 4,
			slow = 0.06,
			confetti = 0,
			flash = 0.6,
		}
	elseif kind == "boom" then
		-- a boom near you: full at 15 studs, nothing past 80 (smoothstep)
		local u = math.clamp((n - 15) / (80 - 15), 0, 1)
		local k = 1 - u * u * (3 - 2 * u)
		if k <= 0 then
			return none()
		end
		f = none()
		f.trauma = 0.5 * k
	else
		return none()
	end
	if reduced then
		f.trauma = 0
		f.punch = 0
		f.kick = 0
		f.lift = 0
		f.twist = 0
		f.slow = 0
	end
	return f
end

-- ===== the shake =====

SmashJuice.MAX_TRAUMA = 1
SmashJuice.DECAY = 3 -- trauma lost per second (a quick shake, not a long wobble)
SmashJuice.MAX_DEGREES = 1.1 -- look-around at full trauma (24 px of the 980 px preview)
SmashJuice.MAX_ROLL = 1.6 -- roll at full trauma
SmashJuice.NOISE_HZ = 24

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
	return s * n1, s * n2, trauma * trauma * SmashJuice.MAX_ROLL * n3
end

-- the shove: a spring that starts at full push and wobbles back to 0 (1 at t = 0), t seconds in
SmashJuice.KICK_HZ = 9
SmashJuice.KICK_DAMP = 0.34
SmashJuice.KICK_SECONDS = 1.2 -- past this it is under 1% and over

function SmashJuice.kickAt(t: number): number
	if t < 0 or t >= SmashJuice.KICK_SECONDS then
		return 0
	end
	local w = 2 * math.pi * SmashJuice.KICK_HZ
	local z = SmashJuice.KICK_DAMP
	return math.exp(-z * w * t) * math.cos(w * math.sqrt(1 - z * z) * t)
end

-- the zoom punch: in fast, hold `slow` seconds, ease back over 0.3 s. t = seconds since the smash
SmashJuice.PUNCH_IN = 0.05
SmashJuice.PUNCH_OUT = 0.3

function SmashJuice.punchAt(punch: number, slow: number, t: number): number
	if punch == 0 or t < 0 then
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
-- On a phone (carter 10-29: too cluttered): smaller, higher (just under the small HUD's clock and
-- health bar) and briefer: at most TOUCH_SECONDS, so the middle of the screen is only crossed by
-- a flash.
SmashJuice.WORDS_W_TOUCH = 0.26
-- (match 1A: a big gold SMASH! with the name under it)
SmashJuice.WORDS_TOUCH = {
	you = { y = 0.385, h = 0.12 },
	name = { y = 0.485, h = 0.06 },
	streak = { y = 0.55, h = 0.05 },
	by = { y = 0.41, h = 0.06 },
	count = { y = 0.5, h = 0.09 },
} :: { [string]: { y: number, h: number } }
SmashJuice.TOUCH_SECONDS = 1

-- The wrecked card's spots (same rule as the words: under the clock and health bar, clear of
-- FIRE). `w` = width of the verb / tag as a fraction of the screen; ring h = height fraction.
SmashJuice.WRECK = {
	verb = { y = 0.4, h = 0.08, w = 0.36 },
	tag = { y = 0.5, h = 0.07, w = 0.34 },
	ring = { y = 0.72, h = 0.22, w = 0 },
} :: { [string]: { y: number, h: number, w: number } }
SmashJuice.WRECK_TOUCH = {
	verb = { y = 0.385, h = 0.12, w = 0.3 },
	tag = { y = 0.49, h = 0.08, w = 0.26 },
	ring = { y = 0.7, h = 0.26, w = 0 },
} :: { [string]: { y: number, h: number, w: number } }
-- (the words pop in from at most 1.5x, so the pop never sweeps over the HUD for long)

-- The match start (carter's pick A1, 10-29): a giant 3, 2, 1 and GO! over the first seconds of a
-- round. It is only a show (the server starts the round at once; the spawn shield covers the
-- first 2 s). `startStep(t)` is the word to show t seconds after the round began.
SmashJuice.START_STEP = 1 -- seconds per number
SmashJuice.START_GO_SECONDS = 1.4 -- how long GO! stays
function SmashJuice.startStep(t: number): string?
	if t < 0 then
		return nil
	end
	local i = math.floor(t / SmashJuice.START_STEP)
	if i < 3 then
		return tostring(3 - i)
	end
	if t < 3 * SmashJuice.START_STEP + SmashJuice.START_GO_SECONDS then
		return "GO!"
	end
	return nil
end
-- where the number and the "GET READY!" line sit (the same rule as the words: clear of the HUD)
SmashJuice.START = {
	num = { y = 0.5, h = 0.34, w = 0.24 },
	ready = { y = 0.72, h = 0.05, w = 0.3 },
} :: { [string]: { y: number, h: number, w: number } }
SmashJuice.START_TOUCH = {
	num = { y = 0.5, h = 0.3, w = 0.2 },
	ready = { y = 0.7, h = 0.06, w = 0.26 },
} :: { [string]: { y: number, h: number, w: number } }

-- ROUND OVER! at 0:00 (carter's pick A, 10-29): the gold words play this long before the
-- between-rounds screen opens. Spots as above: clear of the HUD, under the clock and health bar.
SmashJuice.ROUND_OVER_SECONDS = 1.6
SmashJuice.ROUND_OVER = {
	word = { y = 0.56, h = 0.11, w = 0.36 },
	sub = { y = 0.66, h = 0.05, w = 0.2 },
} :: { [string]: { y: number, h: number, w: number } }
SmashJuice.ROUND_OVER_TOUCH = {
	word = { y = 0.52, h = 0.14, w = 0.38 },
	sub = { y = 0.64, h = 0.06, w = 0.2 },
} :: { [string]: { y: number, h: number, w: number } }

-- Palette for confetti (the low-poly look: grass, sky, sun, cherry, pink).
SmashJuice.CONFETTI = {
	{ 120, 200, 70 },
	{ 90, 180, 255 },
	{ 255, 210, 60 },
	{ 230, 50, 60 },
	{ 255, 90, 170 },
}

return SmashJuice
