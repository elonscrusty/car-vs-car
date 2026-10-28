--!strict
-- Every game action and the sound it makes, in one place. client/Sfx.luau plays them.
-- `id`: a Creator Store sound that loaded in Studio (listed in CHECKED, from sounds/found.txt).
--   No id = the built-in ping, played as `notes`. A real file plays once; if it fails to load,
--   Sfx falls back to the ping, so an action is never silent.
-- `notes`: PlaybackSpeed steps for the ping, `gap` seconds apart. `volume`: from SoundLevels.
-- tests/sound_cues.test.luau checks every action has a cue and every id is a checked one.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local L = sibling("SoundLevels")

export type Cue = {
	id: string?,
	pitch: number?, -- PlaybackSpeed for the real file (default 1)
	notes: { number },
	gap: number,
	volume: number,
}

local SoundCues = {}

-- Studio-checked Creator Store sounds: id -> its store name. Only ids here may be used.
SoundCues.CHECKED = {} :: { [string]: string }

-- The actions the game must give a sound (FINISH-JOBS SOUNDS row), in play order.
SoundCues.MUST = {
	"coin",
	"buy",
	"crateShake",
	"crateOpen",
	"reveal",
	"levelUp",
	"unlock",
	"count",
	"go",
	"finish",
	"podium",
	"leagueUp",
	-- Smash arena
	"pickup",
	"rocket",
	"boom",
	"gun",
	"mine",
	"freezeShot",
	"freeze",
	"shatter",
	"hit",
	"bump",
	"smash",
	"respawn",
	"shield",
	"matchStart",
	"matchEnd",
}

SoundCues.ACTIONS = {
	-- one coin lands in the coins number (Sfx climbs the pitch for a stream of them)
	coin = { notes = { 1.6 }, gap = 0, volume = L.COIN },
	-- coins spent on a crate, a car or an upgrade: a quick "ka-ching"
	buy = { notes = { 1.2, 1.8 }, gap = 0.06, volume = L.BUY },
	-- the crate rattles before it opens: low thumps
	crateShake = { notes = { 0.75, 0.6, 0.75, 0.6, 0.75 }, gap = 0.12, volume = L.CRATE },
	-- the lid pops
	crateOpen = { notes = { 0.9, 1.4 }, gap = 0.05, volume = L.CRATE },
	-- the new car shows: a sparkly run, longer for rarer cars (Sfx cuts it by rarity)
	reveal = { notes = { 1, 1.25, 1.5, 1.88, 2, 2.5 }, gap = 0.09, volume = L.CRATE },
	-- a car or plot level went up: four notes up
	levelUp = { notes = { 1, 1.25, 1.5, 2 }, gap = 0.1, volume = L.LEVEL_UP },
	-- a new training station opens on the plot: a bright three-note "ta-da"
	unlock = { notes = { 1.5, 1.88, 2.25, 3 }, gap = 0.08, volume = L.UNLOCK },
	-- 3, 2, 1 on the start line: one low beep each
	count = { notes = { 1 }, gap = 0, volume = L.COUNT },
	-- GO: high and a little longer
	go = { notes = { 2, 2.5 }, gap = 0.12, volume = L.COUNT },
	-- your car crosses the line (4th or worse)
	finish = { notes = { 1, 1.25 }, gap = 0.14, volume = L.FINISH },
	-- your car crosses the line in the top 3
	podium = { notes = { 1, 1.25, 1.5, 1.25, 2 }, gap = 0.11, volume = L.FINISH },
	-- the league went up: a rising run with sparkles on top
	leagueUp = {
		notes = { 1, 1.25, 1.5, 2, 2.5, 2, 2.67, 2.2, 3 },
		gap = 0.1,
		volume = L.FIREWORKS,
	},
	-- ===== Smash arena =====
	-- you grabbed a "?" box: a quick rising blip
	pickup = { notes = { 1.5, 2.25 }, gap = 0.05, volume = L.PICKUP },
	-- a rocket launches: a low-to-high whoosh
	rocket = { notes = { 0.6, 0.9, 1.3 }, gap = 0.04, volume = L.ROCKET },
	-- a rocket or mine goes off: a deep thump
	boom = { notes = { 0.35, 0.3 }, gap = 0.06, volume = L.BOOM },
	-- one machine-gun shot (Sfx spaces a burst out)
	gun = { notes = { 2.8 }, gap = 0, volume = L.GUN },
	-- a mine drops behind you: a low clunk then the arming tick
	mine = { notes = { 0.7, 2 }, gap = 0.5, volume = L.MINE },
	-- the freeze gun fires: a cold high zap
	freezeShot = { notes = { 3, 2.5 }, gap = 0.04, volume = L.FREEZE },
	-- a kart freezes in ice: a crackle settling down
	freeze = { notes = { 2.5, 2.2, 1.9, 1.7 }, gap = 0.05, volume = L.FREEZE },
	-- the ice bursts (and the kart is smashed): a bright glassy run down
	shatter = { notes = { 3, 2.67, 2.25, 1.5 }, gap = 0.035, volume = L.FREEZE },
	-- a kart took damage: a short low knock
	hit = { notes = { 0.8 }, gap = 0, volume = L.HIT },
	-- two karts bump (it hurts too): a dull double thud
	bump = { notes = { 0.55, 0.45 }, gap = 0.05, volume = L.BUMP },
	-- a kart got smashed: thump then a bright crash run
	smash = { notes = { 0.4, 1.5, 2, 2.67 }, gap = 0.06, volume = L.SMASH },
	-- you are back in the arena: three notes up
	respawn = { notes = { 1, 1.33, 1.78 }, gap = 0.07, volume = L.RESPAWN },
	-- the shield goes up: a shimmer
	shield = { notes = { 2, 2.5, 2, 2.5 }, gap = 0.05, volume = L.SHIELD },
	-- the match starts (after the 3-2-1): a bright fanfare
	matchStart = { notes = { 1, 1.5, 2 }, gap = 0.1, volume = L.MATCH },
	-- the match ends: a long low horn, two notes down
	matchEnd = { notes = { 1, 0.75 }, gap = 0.25, volume = L.MATCH },
	-- (older cues the screens already call)
	trophy = { notes = { 1, 1.5, 2 }, gap = 0.1, volume = L.TROPHY },
	gold = { notes = { 1, 1.25, 1.5, 2, 1.5, 2, 2.5 }, gap = 0.1, volume = L.TROPHY },
	cheer = { notes = { 1, 1.5, 1.25, 1.88, 1.5, 2, 2.5 }, gap = 0.08, volume = L.TROPHY },
	train = { notes = { 1.3 }, gap = 0, volume = L.TRAIN },
	speedUp = { notes = { 1.9 }, gap = 0, volume = L.DING },
	maxed = { notes = { 1.5, 2, 2.67 }, gap = 0.09, volume = L.DING },
	spark = { notes = { 2.5 }, gap = 0, volume = L.SPARK },
} :: { [string]: Cue }

-- the cue for an action (nil if there is none)
function SoundCues.get(name: string): Cue?
	return SoundCues.ACTIONS[name]
end

-- the real file for a cue, only if Studio checked it; else nil (play the ping)
function SoundCues.fileFor(cue: Cue): string?
	local id = cue.id
	if id and SoundCues.CHECKED[id] then
		return id
	end
	return nil
end

-- the ping notes for a cue, cut to the first `count` (at least 1)
function SoundCues.notesFor(cue: Cue, count: number?): { number }
	local n = math.clamp(math.floor(count or #cue.notes), 1, #cue.notes)
	return table.move(cue.notes, 1, n, 1, {})
end

return SoundCues
