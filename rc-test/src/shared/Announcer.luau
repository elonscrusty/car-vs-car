--!strict
-- The announcer (missing.md #11): a few big shouts, rarely, so the arena never gets noisy.
--   * FIRST SMASH!  once per round, the first smash anyone gets.
--   * DOUBLE SMASH! / TRIPLE SMASH!  your quick smashes (words come from SmashJuice.streak).
--   * UNSTOPPABLE!  your 5th smash in a row without being smashed.
-- Words only, no voice clips: there is no checked voice sound id, so the shout gets a short
-- stinger (SoundCues "announce") on the same big word. A real voice goes in later as one id.
-- Pure data + counting, so Lune can test it. client/SmashFx shows the word and plays the sound.

local Announcer = {}

Announcer.MIN_GAP = 6 -- seconds between shouts that only the announcer adds (FIRST, UNSTOPPABLE)
Announcer.ROUND_GAP = 60 -- no smash for this long = a new round (FIRST SMASH! can happen again)
Announcer.UNSTOPPABLE_AT = 5 -- your smashes in a row

export type Shout = { text: string, sound: boolean }

export type State = {
	first: boolean, -- FIRST SMASH! already shouted this round
	lastAny: number, -- time of the last smash anyone got
	lastShout: number, -- time of the last announcer-only shout
	shout: (self: State, now: number, mine: boolean, streakWord: string?, run: number) -> Shout?,
}

local State = {}
State.__index = State

-- Shouts that get the stinger. A plain "SMASH STREAK x3!" stays a silent word.
local LOUD: { [string]: boolean } = {
	["FIRST SMASH!"] = true,
	["DOUBLE SMASH!"] = true,
	["TRIPLE SMASH!"] = true,
	["UNSTOPPABLE!"] = true,
}

-- One smash at time `now`. `mine`: you got it. `streakWord`: SmashJuice's word for it (or nil).
-- `run`: your smashes since you were last smashed. Gives the word to show and whether it is loud
-- (nil = show nothing extra).
function State.shout(
	self: State,
	now: number,
	mine: boolean,
	streakWord: string?,
	run: number
): Shout?
	if now - self.lastAny > Announcer.ROUND_GAP then
		self.first = false
	end
	self.lastAny = now

	local text: string? = if mine then streakWord else nil
	local added: string? = nil -- a word only the announcer adds
	if mine and run == Announcer.UNSTOPPABLE_AT then
		added = "UNSTOPPABLE!"
	elseif not self.first and text == nil then
		added = "FIRST SMASH!"
	end
	self.first = true

	if added then
		if now - self.lastShout < Announcer.MIN_GAP then
			return if text then { text = text, sound = LOUD[text] == true } else nil
		end
		self.lastShout = now
		text = added
	end
	if text == nil then
		return nil
	end
	return { text = text, sound = LOUD[text] == true }
end

function Announcer.new(): State
	return setmetatable(
			{ first = false, lastAny = -math.huge, lastShout = -math.huge },
			State
		) :: any
end

return Announcer
