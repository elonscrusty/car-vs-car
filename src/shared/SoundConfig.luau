--!strict
-- Every game sound. ALL ids are EMPTY on purpose: empty = silent, nothing plays, nothing errors.
-- Carter fills `id` with a Roblox licensed-library sound ("rbxassetid://123..."), see docs/sounds-needed.md.
-- Never put a guessed id here. Volume is 0..1 (placeholder levels), pitchVariance is +/- around 1.0.

export type Entry = {
	id: string,
	volume: number,
	pitchVariance: number,
	looped: boolean?,
	music: boolean?,
}

local SoundConfig = {}

SoundConfig.HitHardAt = 0.5 -- hit strength (0..1) at or above this plays hitHard, below it hitSoft
SoundConfig.MaxVolume = 1 -- volume is clamped to 0..MaxVolume
SoundConfig.MusicVolumeMult = 1 -- extra scale for music entries (placeholder)

SoundConfig.Events = {
	hitSoft = { id = "", volume = 0.5, pitchVariance = 0.1 },
	hitHard = { id = "", volume = 0.8, pitchVariance = 0.1 },
	boost = { id = "", volume = 0.6, pitchVariance = 0.05 },
	ability = { id = "", volume = 0.7, pitchVariance = 0.05 },
	win = { id = "", volume = 0.8, pitchVariance = 0 },
	lose = { id = "", volume = 0.7, pitchVariance = 0 },
	click = { id = "", volume = 0.4, pitchVariance = 0.05 },
	claw = { id = "", volume = 0.7, pitchVariance = 0 },
	coin = { id = "", volume = 0.6, pitchVariance = 0.05 },
	music_lobby = { id = "", volume = 0.25, pitchVariance = 0, looped = true, music = true },
	music_arena = { id = "", volume = 0.25, pitchVariance = 0, looped = true, music = true },
} :: { [string]: Entry }

return SoundConfig
