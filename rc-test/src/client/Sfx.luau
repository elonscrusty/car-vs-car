--!strict
-- Plays the game's sounds. Which sound each action makes lives in shared/SoundCues.luau:
-- a Studio-checked Creator Store file when there is one, else the built-in ping pitched into notes.
-- A file that fails to load falls back to the ping, so no action goes silent.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundCues = require(Shared:WaitForChild("SoundCues"))
local SoundLevels = require(Shared:WaitForChild("SoundLevels"))

local PING = "rbxasset://sounds/electronicpingshort.wav"

local Sfx = {}

-- files that failed to load: play the ping instead
local broken: { [string]: boolean } = {}

-- fetch every real file once, so the first coin is not late
task.spawn(function()
	local list = {}
	for _, cue in SoundCues.ACTIONS do
		local file = SoundCues.fileFor(cue)
		if file then
			local s = Instance.new("Sound")
			s.SoundId = file
			table.insert(list, s)
		end
	end
	if #list > 0 then
		ContentProvider:PreloadAsync(list, function(id: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				broken[id] = true
			end
		end)
	end
end)

local function one(id: string, pitch: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- play an action's cue. `up` lifts the pitch (a stream of coins climbs); `count` cuts the ping notes
local function play(name: string, up: number?, count: number?)
	local cue = SoundCues.get(name)
	if not cue then
		return
	end
	local lift = up or 1
	local file = SoundCues.fileFor(cue)
	if file and not broken[file] then
		one(file, (cue.pitch or 1) * lift, cue.volume)
		return
	end
	for i, pitch in SoundCues.notesFor(cue, count) do
		task.delay((i - 1) * cue.gap, one, PING, pitch * lift, cue.volume)
	end
end

-- one coin lands in the coins number; `i` counts up so a stream of them climbs
function Sfx.coin(i: number)
	play("coin", 1 + math.min(i - 1, 8) * 0.044)
end

-- coins spent: a crate, a car, an upgrade
function Sfx.buy()
	play("buy")
end

-- a car or plot level: four notes up
function Sfx.levelUp()
	play("levelUp")
end

-- a new training station opens on the plot
function Sfx.unlock()
	play("unlock")
end

-- your car crosses the line: a longer cue for a podium place
function Sfx.finish(place: number)
	play(if place <= 3 then "podium" else "finish")
end

-- a crate opens: the lid pops, then the car's sparkle (rarity 1..4: rarer = longer)
function Sfx.crate(rarity: number)
	play("crateOpen")
	task.delay(0.15, play, "reveal", nil, 2 + rarity)
end

-- a trophy for a podium place (1..3): a bigger run for gold
function Sfx.trophy(place: number)
	play(if place == 1 then "gold" else "trophy")
end

-- a car on a station gained points: one soft tick
function Sfx.train()
	play("train")
end

-- a crate shakes before it opens: rarer crates rattle more
function Sfx.shake(rarity: number)
	play("crateShake")
	if rarity >= 2 then
		task.delay(0.6, play, "crateShake", 1.15)
	end
end

-- a crowd cheer when someone wins the big race (no args)
function Sfx.cheer()
	play("cheer")
end

-- a bar went up (+1 SPEED etc): one bright ding
function Sfx.speedUp()
	play("speedUp")
end

-- a bar hit its cap (MAX!)
function Sfx.maxed()
	play("maxed")
end

-- 3-2-1-GO on the line: `step` 3, 2, 1 are low beeps, 0 is GO
function Sfx.count(step: number)
	play(if step <= 0 then "go" else "count")
end

-- a wall scrape: a tiny tick; call as often as you like, it skips ticks that are too close
local lastSpark = 0
function Sfx.spark()
	local now = os.clock()
	if now - lastSpark < SoundLevels.SPARK_GAP then
		return
	end
	lastSpark = now
	play("spark", 0.9 + math.random() * 0.25)
end

-- the league went up
function Sfx.fireworks()
	play("leagueUp")
end

return Sfx
