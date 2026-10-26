--!strict
-- The spawn lobby's play pads (SpawnLobby's "QueuePad" tags): drift, race, and build (your plot).
-- Stand on one for a moment and it sends you to an open plot of that kind, the same as tapping
-- that plot's own pad. Walking across a pad (on the way to the street) does nothing.
-- Plots, owners and the "open" tick are LobbyPlots'; this only watches the pads and asks it.

local QueuePads = {}

QueuePads.HOLD = 2 -- seconds on a pad before it sends you
QueuePads.STEP = 0.2 -- how often the pads are checked

export type Hooks = {
	-- the best plot of that kind for this player, or nil when none is free
	findOpen: (plotType: string, player: Player) -> number?,
	-- claims that plot and starts the drive; false when it could not
	sendTo: (player: Player, slot: number) -> boolean,
	-- the build pad: takes you to your own plot (on foot) instead of a drive
	build: ((player: Player) -> ())?,
	-- the race pad (JOIN RACE, tycoon plan): puts you in the next race instead of a plot. The
	-- race runner sets it; without it the race pad looks for an open race plot as before.
	join: ((player: Player) -> ())?,
}

type Timer = { kind: string, since: number }

-- One check for one person: `kind` is the pad they stand on (nil when on none). True once they
-- have stood on the same pad for HOLD seconds; the timer then restarts, so a try with no free
-- plot comes round again after another HOLD.
function QueuePads.tick(timers: { [any]: Timer }, who: any, kind: string?, now: number): boolean
	if kind == nil then
		timers[who] = nil
		return false
	end
	local t = timers[who]
	if t == nil or t.kind ~= kind then
		timers[who] = { kind = kind, since = now }
		return false
	end
	if now - t.since >= QueuePads.HOLD then
		t.since = now
		return true
	end
	return false
end

-- Is a point over a flat pad (its CFrame and size), feet anywhere up to a few studs above it?
function QueuePads.over(cf: CFrame, size: Vector3, pos: Vector3): boolean
	local p = cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2 and p.Y > -1 and p.Y < 6
end

-- Watches every QueuePad for good. Call once, after the lobby is built.
function QueuePads.start(hooks: Hooks)
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local Forever = require(game:GetService("ReplicatedStorage").Shared.Forever) :: any

	local timers: { [Player]: Timer } = {}
	Players.PlayerRemoving:Connect(function(player)
		timers[player] = nil
	end)

	task.spawn(function()
		local blink = false
		while true do
			task.wait(QueuePads.STEP)
			blink = not blink
			Forever.step("QueuePads", function()
				local now = os.clock()
				local pads = CollectionService:GetTagged("QueuePad")
				local busy: { [Instance]: boolean } = {}
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local kind: string? = nil
					local onPad: BasePart? = nil
					if root and root:IsA("BasePart") and not root.Anchored then
						for _, pad in pads do
							local plotType = pad:GetAttribute("PlotType")
							if
								pad:IsA("BasePart")
								and type(plotType) == "string"
								and QueuePads.over(pad.CFrame, pad.Size, root.Position)
							then
								kind, onPad = plotType, pad
								break
							end
						end
					end
					if onPad then
						busy[onPad] = true
					end
					if kind and QueuePads.tick(timers, player, kind, now) then
						if kind == "build" and hooks.build then
							hooks.build(player)
						elseif kind == "race" and hooks.join then
							hooks.join(player)
						else
							local slot = hooks.findOpen(kind, player)
							if slot then
								hooks.sendTo(player, slot)
							elseif onPad then
								-- every plot of that kind is taken: the pad's sign says ALL BUSY
								-- (PadWords) until the next try
								onPad:SetAttribute(
									"BusyUntil",
									workspace:GetServerTimeNow() + QueuePads.HOLD + 0.5
								)
							end
						end
					elseif kind == nil then
						QueuePads.tick(timers, player, nil, now)
					end
				end
				-- the rim blinks while someone waits on that pad
				for _, pad in pads do
					local rim = pad.Parent and pad.Parent:FindFirstChild("Rim")
					if rim and rim:IsA("BasePart") then
						rim.Transparency = if busy[pad] and blink then 0.6 else 0
					end
				end
			end)
		end
	end)
end

return QueuePads
