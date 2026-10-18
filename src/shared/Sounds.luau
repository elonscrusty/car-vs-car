--!strict
-- Pure sound rules: event name -> playable spec (or nil = stay silent). No Instances here.

local SoundConfig = require("./SoundConfig")

export type Spec = {
	id: string,
	volume: number,
	pitch: number,
	looped: boolean,
	music: boolean,
}

local Sounds = {}

function Sounds.clampVolume(v: number): number
	if v ~= v then
		return 0
	end
	return math.clamp(v, 0, SoundConfig.MaxVolume)
end

-- Hit strength 0..1 -> "hitSoft" or "hitHard". Bad numbers count as soft.
function Sounds.hitEvent(strength: number?): string
	local s = strength or 0
	if s ~= s then
		s = 0
	end
	return if s >= SoundConfig.HitHardAt then "hitHard" else "hitSoft"
end

-- `roll` is a number in 0..1 (math.random()); 0.5 = exact base pitch. Returns nil when there is
-- no such event or its id is empty (silent).
function Sounds.resolve(
	event: string,
	roll: number?,
	events: { [string]: SoundConfig.Entry }?
): Spec?
	local entry = (events or SoundConfig.Events)[event]
	if entry == nil or entry.id == "" then
		return nil
	end
	local r = math.clamp(roll or 0.5, 0, 1)
	local volume = entry.volume
	if entry.music == true then
		volume *= SoundConfig.MusicVolumeMult
	end
	return {
		id = entry.id,
		volume = Sounds.clampVolume(volume),
		pitch = math.max(0.1, 1 + (r * 2 - 1) * entry.pitchVariance),
		looped = entry.looped == true,
		music = entry.music == true,
	}
end

return Sounds
