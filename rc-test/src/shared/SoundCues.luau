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
-- (Studio search 10-28, sounds/found.txt: all loaded. Only Pro Sound Effects, DailySoundsFX, Roblox and
-- licensed music-library stings: no voice lines, no clips from other games.)
SoundCues.CHECKED = {
	["rbxassetid://130378474223829"] = "Coin Pickup - Daily Sounds (DailySoundsFX)",
	["rbxassetid://10066947742"] = "RBLX UI Purchase (SFX) (Roblox)",
	["rbxassetid://9114895481"] = "Junk Rattle Box Of Miscellaneous Items 1 (SFX) (Pro Sound Effects)",
	["rbxassetid://9120872602"] = "Wooden Chest Open Close Cedar Box 2 (SFX) (Pro Sound Effects)",
	["rbxassetid://9120686092"] = "Whistle Ta Da 2 (SFX) (Pro Sound Effects)",
	["rbxassetid://9117885276"] = "Power Up Sweeteners 14 (SFX) (Pro Sound Effects)",
	["rbxassetid://9117060347"] = "Nasa Transmission Beep 1 (SFX) (Pro Sound Effects)",
	["rbxassetid://9043512323"] = "Move to the Finish Line (sting a) (Juice Music)",
	["rbxassetid://1844584807"] = "Glamour Fanfare 4 (Milan Pilar)",
	["rbxassetid://9114329395"] = "Energy Cloud Whooshing By Very Fast 1 (SFX) (Pro Sound Effects)",
	["rbxassetid://9125401226"] = "Boom Impact Deep Distant Thumping Hits (Pro Sound Effects)",
	["rbxassetid://9119382002"] = "Solenoid Clunks 10 (SFX) (Pro Sound Effects)",
	["rbxassetid://9113500221"] = "Body Hit Metal Impact 9 (SFX) (Pro Sound Effects)",
	["rbxassetid://9119051578"] = "Shale Burst Smashing Rock With A Big Stone 4 (Pro Sound Effects)",
	["rbxassetid://9119075972"] = "Shield Impacts 20 (SFX) (Pro Sound Effects)",
	["rbxassetid://9039712090"] = "Family Friendly Tag - Sting 2 (Michael R Rado)",
	["rbxassetid://9113071895"] = "Air Horn Various Lengths 3 (SFX) (Pro Sound Effects)",
	-- (search 2, sounds/found2.txt)
	["rbxassetid://9117886252"] = "Power Up Sweeteners 12 (SFX) (Pro Sound Effects)",
	["rbxassetid://9117399569"] = "Pistol Single Shots 1 (SFX) (Pro Sound Effects)",
	["rbxassetid://115842676995967"] = "Laser Zap - Daily Sounds (DailySoundsFX)",
	["rbxassetid://9114862833"] = "Ice Cube Pour 2 (SFX) (Pro Sound Effects)",
	["rbxassetid://9114855870"] = "Ice Block Drop To Concrete Shatter 1 (SFX) (Pro Sound Effects)",
	["rbxassetid://9125648149"] = "Magic Zoom Up Sharp Tubular Whoosh Fast Hiss (SFX) (Pro Sound Effects)",
	["rbxassetid://9114302200"] = "Elevator Bell Synth Chimes 4 (SFX) (Pro Sound Effects)",
	-- (search 3, sounds/found3.txt)
	["rbxassetid://9114360486"] = "Excited Foreign Crowd 3 (SFX) (Pro Sound Effects)",
	["rbxassetid://17208361335"] = "Roblox GUI - Notification High (Roblox)",
	["rbxassetid://9126073001"] = "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX) (Pro Sound Effects)",
	["rbxassetid://9116911070"] = "Metal Zing By Bright Scrape Ringy Pass By 2 (SFX) (Pro Sound Effects)",
	["rbxassetid://16480568294"] = "Audio/Roblox_Pinball_Bumper_Soft_Click_04 (Roblox)",
} :: { [string]: string }

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
	"flame",
	"shatter",
	"hit",
	"bump",
	"smash",
	"respawn",
	"shield",
	"matchStart",
	"matchEnd",
	"tap",
}

SoundCues.ACTIONS = {
	-- one coin lands in the coins number (Sfx climbs the pitch for a stream of them)
	coin = { id = "rbxassetid://130378474223829", notes = { 1.6 }, gap = 0, volume = L.COIN },
	-- coins spent on a crate, a car or an upgrade: a quick "ka-ching"
	buy = { id = "rbxassetid://10066947742", notes = { 1.2, 1.8 }, gap = 0.06, volume = L.BUY },
	-- the crate rattles before it opens: low thumps
	crateShake = {
		id = "rbxassetid://9114895481",
		notes = { 0.75, 0.6, 0.75, 0.6, 0.75 },
		gap = 0.12,
		volume = L.CRATE,
	},
	-- the lid pops
	crateOpen = {
		id = "rbxassetid://9120872602",
		notes = { 0.9, 1.4 },
		gap = 0.05,
		volume = L.CRATE,
	},
	-- the new car shows: a sparkly run, longer for rarer cars (Sfx cuts it by rarity)
	reveal = {
		id = "rbxassetid://9120686092",
		notes = { 1, 1.25, 1.5, 1.88, 2, 2.5 },
		gap = 0.09,
		volume = L.CRATE,
	},
	-- a car or plot level went up: four notes up
	levelUp = {
		id = "rbxassetid://9117885276",
		notes = { 1, 1.25, 1.5, 2 },
		gap = 0.1,
		volume = L.LEVEL_UP,
	},
	-- a new training station opens on the plot: a bright three-note "ta-da"
	unlock = {
		id = "rbxassetid://9114302200",
		notes = { 1.5, 1.88, 2.25, 3 },
		gap = 0.08,
		volume = L.UNLOCK,
	},
	-- 3, 2, 1 on the start line: one low beep each
	count = { id = "rbxassetid://9117060347", notes = { 1 }, gap = 0, volume = L.COUNT },
	-- GO: high and a little longer
	go = {
		id = "rbxassetid://9117060347",
		pitch = 1.6,
		notes = { 2, 2.5 },
		gap = 0.12,
		volume = L.COUNT,
	},
	-- your car crosses the line (4th or worse)
	finish = {
		id = "rbxassetid://9120686092",
		pitch = 0.85,
		notes = { 1, 1.25 },
		gap = 0.14,
		volume = L.FINISH,
	},
	-- your car crosses the line in the top 3
	podium = {
		id = "rbxassetid://9043512323",
		notes = { 1, 1.25, 1.5, 1.25, 2 },
		gap = 0.11,
		volume = L.FINISH,
	},
	-- the league went up: a rising run with sparkles on top
	leagueUp = {
		id = "rbxassetid://1844584807",
		notes = { 1, 1.25, 1.5, 2, 2.5, 2, 2.67, 2.2, 3 },
		gap = 0.1,
		volume = L.FIREWORKS,
	},
	-- ===== Smash arena =====
	-- you grabbed a "?" box: a quick rising blip
	pickup = {
		id = "rbxassetid://9117886252",
		notes = { 1.5, 2.25 },
		gap = 0.05,
		volume = L.PICKUP,
	},
	-- a rocket launches: a low-to-high whoosh
	rocket = {
		id = "rbxassetid://9114329395",
		notes = { 0.6, 0.9, 1.3 },
		gap = 0.04,
		volume = L.ROCKET,
	},
	-- a rocket or mine goes off: a deep thump
	boom = { id = "rbxassetid://9125401226", notes = { 0.35, 0.3 }, gap = 0.06, volume = L.BOOM },
	-- one machine-gun shot (Sfx spaces a burst out)
	gun = { id = "rbxassetid://9117399569", notes = { 2.8 }, gap = 0, volume = L.GUN },
	-- a mine drops behind you: a low clunk then the arming tick
	mine = { id = "rbxassetid://9119382002", notes = { 0.7, 2 }, gap = 0.5, volume = L.MINE },
	-- the freeze gun fires: a cold high zap
	freezeShot = {
		id = "rbxassetid://115842676995967",
		notes = { 3, 2.5 },
		gap = 0.04,
		volume = L.FREEZE,
	},
	-- a kart freezes in ice: a crackle settling down
	freeze = {
		id = "rbxassetid://9114862833",
		notes = { 2.5, 2.2, 1.9, 1.7 },
		gap = 0.05,
		volume = L.FREEZE,
	},
	-- a Flame Nozzle burst: one long low whoosh (a single slow note, so no ticking; carter 10-30)
	flame = { id = "rbxassetid://9114329395", notes = { 0.4 }, gap = 0, volume = L.FLAME },
	-- the ice bursts (and the kart is smashed): a bright glassy run down
	shatter = {
		id = "rbxassetid://9114855870",
		notes = { 3, 2.67, 2.25, 1.5 },
		gap = 0.035,
		volume = L.FREEZE,
	},
	-- a kart took damage: a short low knock
	hit = { id = "rbxassetid://9113500221", notes = { 0.8 }, gap = 0, volume = L.HIT },
	-- two karts bump (it hurts too): a dull double thud
	bump = {
		id = "rbxassetid://9113500221",
		pitch = 0.75,
		notes = { 0.55, 0.45 },
		gap = 0.05,
		volume = L.BUMP,
	},
	-- a kart got smashed: thump then a bright crash run
	smash = {
		id = "rbxassetid://9119051578",
		notes = { 0.4, 1.5, 2, 2.67 },
		gap = 0.06,
		volume = L.SMASH,
	},
	-- the Big Boom (carter picked it, 10-29): the deep boom, a metal crunch, the crowd "oooh" and a
	-- small second pop play together with the crash above (Sfx.smash times them)
	smashBoom = {
		id = "rbxassetid://9125401226",
		pitch = 0.8,
		notes = { 0.3, 0.25 },
		gap = 0.06,
		volume = L.SMASH_BOOM,
	},
	smashMetal = {
		id = "rbxassetid://9113500221",
		pitch = 0.9,
		notes = { 1.2, 0.8 },
		gap = 0.05,
		volume = L.SMASH_METAL,
	},
	smashCrowd = {
		id = "rbxassetid://9114360486",
		pitch = 0.9,
		notes = { 1, 1.25, 1.5 },
		gap = 0.1,
		volume = L.SMASH_CROWD,
	},
	smashPop = {
		id = "rbxassetid://9125401226",
		pitch = 1.3,
		notes = { 0.5 },
		gap = 0,
		volume = L.SMASH_POP,
	},
	-- you are back in the arena: three notes up
	respawn = {
		id = "rbxassetid://9125648149",
		notes = { 1, 1.33, 1.78 },
		gap = 0.07,
		volume = L.RESPAWN,
	},
	-- the shield goes up: a shimmer
	shield = {
		id = "rbxassetid://9119075972",
		notes = { 2, 2.5, 2, 2.5 },
		gap = 0.05,
		volume = L.SHIELD,
	},
	-- the match starts (after the 3-2-1): a bright fanfare
	matchStart = {
		id = "rbxassetid://9039712090",
		notes = { 1, 1.5, 2 },
		gap = 0.1,
		volume = L.MATCH,
	},
	-- the match ends: a long low horn, two notes down
	matchEnd = { id = "rbxassetid://9113071895", notes = { 1, 0.75 }, gap = 0.25, volume = L.MATCH },
	-- (older cues the screens already call)
	trophy = {
		id = "rbxassetid://9120686092",
		pitch = 1.1,
		notes = { 1, 1.5, 2 },
		gap = 0.1,
		volume = L.TROPHY,
	},
	gold = {
		id = "rbxassetid://1844584807",
		notes = { 1, 1.25, 1.5, 2, 1.5, 2, 2.5 },
		gap = 0.1,
		volume = L.TROPHY,
	},
	cheer = {
		id = "rbxassetid://9114360486",
		notes = { 1, 1.5, 1.25, 1.88, 1.5, 2, 2.5 },
		gap = 0.08,
		volume = L.TROPHY,
	},
	train = { id = "rbxassetid://16480568294", notes = { 1.3 }, gap = 0, volume = L.TRAIN },
	speedUp = { id = "rbxassetid://17208361335", notes = { 1.9 }, gap = 0, volume = L.DING },
	maxed = {
		id = "rbxassetid://9126073001",
		notes = { 1.5, 2, 2.67 },
		gap = 0.09,
		volume = L.DING,
	},
	spark = { id = "rbxassetid://9116911070", notes = { 2.5 }, gap = 0, volume = L.SPARK },
	-- any button tapped: a soft round click (carter picked A "Soft click" 10-30)
	tap = { id = "rbxassetid://16480568294", pitch = 1.15, notes = { 2 }, gap = 0, volume = L.TAP },
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
