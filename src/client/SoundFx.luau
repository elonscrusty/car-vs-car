--!strict
-- Client sound player. Sounds are created lazily under SoundService from SoundConfig; an empty id
-- means silent, and every call is safe (never errors). Music loops one track at a time.
-- The mute choice lives in a client-only attribute on SoundService (not saved, not replicated).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage.Shared.SoundConfig)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local MUTE_ATTR = "MusicMuted"

local SoundFx = {}

local folder: Folder? = nil
local cache: { [string]: Sound } = {}
local currentMusic: string? = nil

local function getFolder(): Folder
	local f = folder
	if f == nil or f.Parent == nil then
		f = Instance.new("Folder")
		f.Name = "SoundFx"
		f.Parent = SoundService
		folder = f
		cache = {}
	end
	return f :: Folder
end

local function getSound(event: string, spec: Sounds.Spec): Sound
	local s = cache[event]
	if s == nil or s.Parent == nil then
		s = Instance.new("Sound")
		s.Name = event
		s.RollOffMaxDistance = 0
		s.Parent = getFolder()
		cache[event] = s
	end
	local sound = s :: Sound
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.Looped = spec.looped
	sound.PlaybackSpeed = spec.pitch
	return sound
end

function SoundFx.isMuted(): boolean
	return SoundService:GetAttribute(MUTE_ATTR) == true
end

-- One-shot effect by event name ("boost", "win", ...). Silent when the id is empty.
function SoundFx.play(event: string)
	pcall(function()
		local spec = Sounds.resolve(event, math.random())
		if spec == nil then
			return
		end
		if spec.music then
			SoundFx.music(event)
			return
		end
		getSound(event, spec):Play()
	end)
end

-- Hit strength 0..1 picks hitSoft or hitHard.
function SoundFx.hit(strength: number?)
	SoundFx.play(Sounds.hitEvent(strength))
end

-- Switches the looping music track ("music_lobby" / "music_arena"). Silent when muted or id empty;
-- the track is remembered so un-muting resumes it.
function SoundFx.music(event: string)
	currentMusic = event
	pcall(function()
		for name, s in cache do
			if name ~= event and SoundConfig.Events[name].music == true then
				s:Stop()
			end
		end
		if SoundFx.isMuted() then
			return
		end
		local spec = Sounds.resolve(event)
		if spec == nil or not spec.music then
			return
		end
		local sound = getSound(event, spec)
		if not sound.IsPlaying then
			sound:Play()
		end
	end)
end

function SoundFx.setMuted(muted: boolean)
	SoundService:SetAttribute(MUTE_ATTR, muted)
	if muted then
		for name, s in cache do
			if SoundConfig.Events[name] and SoundConfig.Events[name].music == true then
				pcall(function()
					s:Stop()
				end)
			end
		end
	elseif currentMusic then
		SoundFx.music(currentMusic)
	end
end

function SoundFx.toggleMute(): boolean
	SoundFx.setMuted(not SoundFx.isMuted())
	return SoundFx.isMuted()
end

return SoundFx
