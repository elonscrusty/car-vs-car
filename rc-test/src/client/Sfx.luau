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

-- play one sound: on your screen, or at `at` in the world (fades with distance).
-- Always cleaned up, even if the file never loads (then it is marked broken: the ping plays next time)
local function one(id: string, pitch: number, volume: number, at: Vector3?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch
	s.Volume = volume
	local root: Instance = s
	if at then
		local a = Instance.new("Attachment")
		a.Position = at -- (Terrain sits at the world origin)
		a.Parent = workspace.Terrain
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 250
		s.Parent = a
		root = a
	else
		s.Parent = SoundService
	end
	s:Play()
	s.Ended:Once(function()
		root:Destroy()
	end)
	task.delay(10, function() -- (longer than any cue: the longest files run about 4 s)
		if id ~= PING and not s.IsLoaded then
			broken[id] = true
		end
		root:Destroy()
	end)
end

-- play an action's cue. `up` lifts the pitch (a stream of coins climbs); `count` cuts the ping
-- notes; `at` places it in the world (other karts' rockets and booms)
local function play(name: string, up: number?, count: number?, at: Vector3?)
	local cue = SoundCues.get(name)
	if not cue then
		return
	end
	local lift = up or 1
	local file = SoundCues.fileFor(cue)
	if file and not broken[file] then
		one(file, (cue.pitch or 1) * lift, cue.volume, at)
		return
	end
	for i, pitch in SoundCues.notesFor(cue, count) do
		task.delay((i - 1) * cue.gap, one, PING, pitch * lift, cue.volume, at)
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

-- ===== Smash arena (pass `at` for things that happen to other karts) =====

-- you grabbed a "?" box
function Sfx.pickup()
	play("pickup")
end

-- a rocket launches
function Sfx.rocket(at: Vector3?)
	play("rocket", nil, nil, at)
end

-- a rocket or mine goes off
function Sfx.boom(at: Vector3?)
	play("boom", 0.9 + math.random() * 0.2, nil, at)
end

-- one machine-gun shot; call it per shot, it skips shots that are too close together
-- (your own and everyone else's have their own timer, so other karts never swallow yours)
local lastGun = { mine = 0, others = 0 }
function Sfx.gun(at: Vector3?)
	local now = os.clock()
	local who = if at then "others" else "mine"
	if now - lastGun[who] < SoundLevels.GUN_GAP then
		return
	end
	lastGun[who] = now
	play("gun", 0.95 + math.random() * 0.1, nil, at)
end

-- a mine is dropped (and arms)
function Sfx.mine(at: Vector3?)
	play("mine", nil, nil, at)
end

-- (GUNMINE's names: a mine dropping, a mine going off)
Sfx.mineDrop = Sfx.mine
Sfx.mineBoom = Sfx.boom

-- the freeze gun fires
function Sfx.freezeShot(at: Vector3?)
	play("freezeShot", nil, nil, at)
end

-- a kart is frozen in ice
function Sfx.freeze(at: Vector3?)
	play("freeze", nil, nil, at)
end

-- the Flame Nozzle sends a burst of fire
function Sfx.flame(at: Vector3?)
	play("flame", nil, nil, at)
end

-- the ice bursts and the kart is smashed
function Sfx.shatter(at: Vector3?)
	play("shatter", nil, nil, at)
end

-- a kart took damage; call per hit, it skips hits that are too close together
-- (your own and everyone else's have their own timer, so other karts never swallow yours)
local lastHit = { mine = 0, others = 0 }
function Sfx.hit(at: Vector3?)
	local now = os.clock()
	local who = if at then "others" else "mine"
	if now - lastHit[who] < SoundLevels.HIT_GAP then
		return
	end
	lastHit[who] = now
	play("hit", 0.9 + math.random() * 0.2, nil, at)
end

-- two karts bump (bumps hurt too); the hit timer keeps a scrape from buzzing
local lastBump = { mine = 0, others = 0 }
function Sfx.bump(at: Vector3?)
	local now = os.clock()
	local who = if at then "others" else "mine"
	if now - lastBump[who] < SoundLevels.HIT_GAP * 3 then
		return
	end
	lastBump[who] = now
	play("bump", 0.9 + math.random() * 0.2, nil, at)
end

-- a kart got smashed
function Sfx.smash(at: Vector3?)
	play("smash", nil, nil, at)
end

-- you are back in the arena
function Sfx.respawn()
	play("respawn")
end

-- the shield goes up
function Sfx.shield(at: Vector3?)
	play("shield", nil, nil, at)
end

-- the match starts (play after Sfx.count(0) = GO, or on its own)
function Sfx.matchStart()
	play("matchStart")
end

-- the match ends
function Sfx.matchEnd()
	play("matchEnd")
end

return Sfx
