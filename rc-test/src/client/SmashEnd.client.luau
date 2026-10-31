--!strict
-- Smash between-rounds screen glue (WINDOWS): ReplicatedStorage.MatchResult (MatchRunner,
-- FireClient(player, places, coins, nextAt, xp?)) opens Smash.matchEnd and counts down to the next
-- round; the screen closes by itself when it starts. LEAVE fires ReplicatedStorage.LeaveMatch (if
-- the server made it) and closes the screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchEnd = require(Shared:WaitForChild("MatchEnd"))
local Ui = script.Parent:WaitForChild("Ui")
local Smash = require(Ui:WaitForChild("Screens"):WaitForChild("Smash"))
local Screen = require(Ui:WaitForChild("Screen"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local MatchStart = require(script.Parent:WaitForChild("MatchStart"))
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))

local player = Players.LocalPlayer

-- call fn with the remote `name` once it exists (no endless WaitForChild warning while the match
-- game isn't on)
local function onRemote(name: string, fn: (RemoteEvent) -> ())
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		fn(r)
		return
	end
	local conn: RBXScriptConnection
	conn = ReplicatedStorage.ChildAdded:Connect(function(c)
		if c.Name == name and c:IsA("RemoteEvent") then
			conn:Disconnect()
			fn(c)
		end
	end)
end

local shown = 0 -- which result is on screen (a newer one stops the older count)
local lastLeave = 0
local leftAt = -math.huge -- when LEAVE took us out (a result already on its way is not shown)
local LEFT_QUIET = 20

local function show(places: unknown, coins: unknown, nextAt: unknown, xp: unknown)
	if os.clock() - leftAt < LEFT_QUIET then
		return
	end
	shown += 1
	local mine = shown
	local view = MatchEnd.read(places, coins, nextAt, xp, player.UserId)
	-- (the server set Xp before sending the result: the bar runs from Xp - this round's XP to Xp)
	local bar = MatchEnd.xpBar(player:GetAttribute("Xp"), view.xp)
	local openedAt = workspace:GetServerTimeNow()
	-- (the next round starting puts it away, even before the count gets there: no ROUND OVER under GO!)
	local round = workspace:GetAttribute("MatchRound")
	local handle: Screen.Handle
	handle = Smash.matchEnd(view, {
		leave = function()
			-- (one ask a second at most; the server rate-limits too)
			local now = os.clock()
			if now - lastLeave < 1 then
				return
			end
			lastLeave = now
			local r = ReplicatedStorage:FindFirstChild("LeaveMatch")
			if r and r:IsA("RemoteEvent") then
				r:FireServer()
				leftAt = now
			end
			shown += 1
			handle.close()
		end,
	}, bar, { coin = Sfx.coin, levelUp = Sfx.levelUp })
	task.spawn(function()
		while shown == mine do
			if workspace:GetAttribute("MatchRound") ~= round then
				shown += 1
				handle.close()
				return
			end
			local left = MatchEnd.left(view, openedAt, workspace:GetServerTimeNow())
			handle.set(left)
			if left <= 0 then
				task.wait(0.6) -- "GO!" for a moment, then the new round
				if shown == mine then
					handle.close()
				end
				return
			end
			task.wait(0.25)
		end
	end)
end

-- the clock hit 0:00: ROUND OVER! first (carter's pick A), then the screen; a newer result wins
local waiting = 0
onRemote("MatchResult", function(r)
	r.OnClientEvent:Connect(function(places: unknown, coins: unknown, nextAt: unknown, xp: unknown)
		waiting += 1
		local mine = waiting
		if MatchStart.roundOver() then
			task.delay(SmashJuice.ROUND_OVER_SECONDS, function()
				if waiting == mine then
					show(places, coins, nextAt, xp)
				end
			end)
		else
			show(places, coins, nextAt, xp)
		end
	end)
end)
