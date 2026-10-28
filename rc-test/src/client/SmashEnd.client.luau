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

local function show(places: unknown, coins: unknown, nextAt: unknown, xp: unknown)
	shown += 1
	local mine = shown
	local view = MatchEnd.read(places, coins, nextAt, xp, player.UserId)
	local openedAt = workspace:GetServerTimeNow()
	local handle: any
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
			end
			shown += 1
			handle.close()
		end,
	})
	task.spawn(function()
		while shown == mine do
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

onRemote("MatchResult", function(r)
	r.OnClientEvent:Connect(show)
end)
