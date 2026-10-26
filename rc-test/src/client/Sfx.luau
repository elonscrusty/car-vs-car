--!strict
-- Little game sounds made from the one built-in ping, pitched up and down (no new sound ids).
-- Real sound files come later: the wanted list is in SOUNDS.md.
local SoundService = game:GetService("SoundService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundLevels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundLevels"))

local PING = "rbxasset://sounds/electronicpingshort.wav"

local Sfx = {}

-- notes are PlaybackSpeed steps, played `gap` seconds apart
local function notes(pitches: { number }, gap: number, volume: number)
	for i, pitch in pitches do
		task.delay((i - 1) * gap, function()
			local s = Instance.new("Sound")
			s.SoundId = PING
			s.PlaybackSpeed = pitch
			s.Volume = volume
			s.Parent = SoundService
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end)
	end
end

-- one coin lands in the coins number; `i` counts up so a stream of them climbs
function Sfx.coin(i: number)
	notes({ 1.6 + math.min(i - 1, 8) * 0.07 }, 0, SoundLevels.COIN)
end

-- a plot level: four notes up
function Sfx.levelUp()
	notes({ 1, 1.25, 1.5, 2 }, 0.1, SoundLevels.LEVEL_UP)
end

-- your car crosses the line: a short rising run, longer for a podium place
function Sfx.finish(place: number)
	if place <= 3 then
		notes({ 1, 1.25, 1.5, 1.25, 2 }, 0.11, SoundLevels.FINISH)
	else
		notes({ 1, 1.25 }, 0.14, SoundLevels.FINISH)
	end
end

return Sfx
