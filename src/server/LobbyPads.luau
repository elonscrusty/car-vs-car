--!strict
-- The four mini PLAY pads in the middle of the Car Battle Lobby and everything that goes with
-- stepping on one. `build` makes the pads (orange/blue rings that glow and spin, a "1/2" counter);
-- `start` watches where players stand (4 times a second), tells BattleService, shows the counts,
-- walks the PLAY button's player onto a pad, parks a fighter out of sight and puts them back next to
-- the pads afterwards. All numbers come from LobbyLayout / PadSlots.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)
local PadSlots = require(ReplicatedStorage.Shared.PadSlots)

local LobbyPads = {}

export type Pads = {
	group: Folder,
	setCount: (index: number, count: number) -> (),
	top: (index: number) -> Vector3, -- world position of the middle of a pad's top
}

export type Handle = {
	play: (player: Player) -> (),
	cancel: (player: Player) -> (),
	park: (player: Player) -> (),
	returnToLobby: (player: Player) -> (),
	remove: (player: Player) -> (), -- the player left the game
	stop: () -> (),
}

local rgb, part, can, group = MapParts.rgb, MapParts.part, MapParts.can, MapParts.group
local C = LobbyLayout.colors
local TOP = 0.5 -- a pad's top above the plaza
local SEGMENTS = 10 -- ring segments, alternating orange and blue
local POLL = 0.25
local COOLDOWN = 2 -- seconds after CANCEL before standing on a pad counts again
local PARK_DEPTH = -60 -- where a fighter waits (under the lobby, anchored)

function LobbyPads.build(folder: Folder, origin: Vector3): Pads
	local grp = group(folder, "Pads")
	local positions = LobbyLayout.pads()
	local radius = LobbyLayout.padRadius
	local counters: { TextLabel } = {}
	local glows: { { Part } } = {}
	for i, p in positions do
		local center = origin + Vector3.new(p.x, 0, p.z)
		local pad = group(grp, "Pad" .. i)
		pad:SetAttribute("PadIndex", i)
		-- white rim, dark base, lighter inner disc
		can(pad, "Rim", radius * 2 + 1.4, TOP - 0.05, center, rgb(C.marking), false)
		local base = can(
			pad,
			"Base",
			radius * 2,
			TOP,
			center + Vector3.new(0, 0.05, 0),
			rgb(C.asphaltDark),
			false
		)
		base.Name = "PadBase"
		can(
			pad,
			"Inner",
			radius * 1.2,
			TOP + 0.06,
			center + Vector3.new(0, 0.06, 0),
			Color3.fromRGB(30, 36, 52),
			false
		)
		-- the spinning ring of alternating orange / blue blocks
		local ring = Instance.new("Model")
		ring.Name = "Ring"
		local glow: { Part } = {}
		local ringR = radius * 0.8
		local arc = (2 * math.pi * ringR / SEGMENTS) * 0.92
		for k = 1, SEGMENTS do
			local a = (k - 1) / SEGMENTS * 2 * math.pi
			local pos = center + Vector3.new(math.cos(a) * ringR, TOP + 0.35, math.sin(a) * ringR)
			local seg = part(
				ring,
				"Seg" .. k,
				Vector3.new(1.3, 0.6, arc),
				CFrame.new(pos) * CFrame.Angles(0, -a, 0),
				rgb(if k % 2 == 1 then C.orange else C.blue),
				false,
				nil,
				Enum.Material.Neon
			)
			seg.CastShadow = false
			table.insert(glow, seg)
		end
		-- an invisible hub in the middle is the pivot, so the ring turns round the pad
		local hub = part(
			ring,
			"Hub",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(center + Vector3.new(0, TOP + 0.35, 0)),
			rgb(C.marking),
			false
		)
		hub.Transparency = 1
		ring.PrimaryPart = hub
		-- the clients turn it (a server loop would send every part's position all the time)
		CollectionService:AddTag(ring, "LobbySpin")
		ring:SetAttribute("SpinSpeed", 1.2)
		ring:SetAttribute("SpinCenter", hub.Position)
		ring:SetAttribute("SpinMode", "world")
		ring.Parent = pad
		table.insert(glows, glow)
		-- PLAY on the pad and the counter above it
		local face = part(
			pad,
			"Face",
			Vector3.new(radius * 1.2, 0.1, radius * 1.2),
			CFrame.new(center + Vector3.new(0, TOP + 0.13, 0)),
			Color3.fromRGB(30, 36, 52),
			false
		)
		face.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0
		gui.Parent = face
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "PLAY"
		label.TextColor3 = rgb(C.marking)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = rgb(C.blue)
		label.Parent = gui
		local post = part(
			pad,
			"CounterAnchor",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(center + Vector3.new(0, 7.5, 0)),
			rgb(C.marking),
			false
		)
		post.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(48, 22)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 32
		bb.LightInfluence = 0
		bb.Parent = post
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.Size = UDim2.fromScale(1, 1)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.FredokaOne
		count.TextSize = 18
		count.Text = `0/{LobbyLayout.padMax}`
		count.TextColor3 = rgb(C.marking)
		count.TextStrokeTransparency = 0
		count.TextStrokeColor3 = Color3.fromRGB(20, 26, 40)
		count.Parent = bb
		table.insert(counters, count)
	end

	return {
		group = grp,
		setCount = function(index: number, count: number)
			local label = counters[index]
			if label then
				label.Text = `{count}/{LobbyLayout.padMax}`
				label.TextColor3 = if count > 0 then rgb(C.gold) else rgb(C.marking)
			end
			for _, seg in glows[index] or {} do
				seg.Transparency = if count > 0 then 0 else 0.15
			end
		end,
		top = function(index: number): Vector3
			local p = positions[index]
			return origin + Vector3.new(p.x, TOP, p.z)
		end,
	}
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	if char == nil then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum == nil or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

type Deps = {
	pads: Pads,
	origin: Vector3,
	battle: {
		padSync: (observed: { [Player]: number }) -> { number },
		padCounts: () -> { number },
		cancel: (player: Player) -> (),
		isBusy: (player: Player) -> boolean,
	},
	remotes: { BattleUpdate: RemoteEvent },
}

function LobbyPads.start(deps: Deps): Handle
	local origin = deps.origin
	local running = true
	local cooldown: { [Player]: number } = {}
	local pending: { [Player]: number } = {} -- PLAY pressed a moment ago (ignore repeats)
	local lastPad: { [Player]: number } = {} -- where each player stood on the previous poll
	local returns = 0

	-- What each pad shows, and the spin.
	local function showCounts(counts: { number })
		for i, n in counts do
			deps.pads.setCount(i, n)
		end
	end

	local function observe(): { [Player]: number }
		local out: { [Player]: number } = {}
		local seen: { [Player]: number } = {}
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if
				root
				and (cooldown[player] or 0) <= now
				and player:GetAttribute("InBattle") ~= true
			then
				local rel = root.Position - origin
				if rel.Y < 8 and rel.Y > -3 then
					local pad = LobbyLayout.padAt(rel.X, rel.Z)
					if pad then
						seen[player] = pad
						-- a pad counts after two polls in a row: running past one must not match anyone
						if lastPad[player] == pad then
							out[player] = pad
						end
					end
				end
			end
		end
		lastPad = seen
		return out
	end

	task.spawn(function()
		while running do
			task.wait(POLL)
			-- one bad tick must never end the loop: the pads would stop matching for the whole server
			local ok, err = pcall(function()
				showCounts(deps.battle.padSync(observe()))
			end)
			if not ok then
				warn("[LobbyPads] pad tick failed: " .. tostring(err))
			end
		end
	end)

	local handle = {} :: Handle

	-- The PLAY button: walk the player onto the best pad (one that already has someone waiting,
	-- else an empty one). The pad watcher above then counts them like anyone who stepped on.
	handle.play = function(player: Player)
		if deps.battle.isBusy(player) or player:GetAttribute("InBattle") == true then
			return
		end
		local now = os.clock()
		if (pending[player] or 0) > now then
			return
		end
		local root = rootOf(player)
		if root == nil then
			return
		end
		pending[player] = now + 1
		local pad = PadSlots.suggestFromCounts(deps.battle.padCounts(), LobbyLayout.padMax)
		if pad == nil then
			deps.remotes.BattleUpdate:FireClient(
				player,
				{ kind = "error", text = "Every pad is full right now." }
			)
			return
		end
		cooldown[player] = nil
		local p = LobbyLayout.pads()[pad]
		local spot = Vector3.new(p.x, 0, p.z)
		-- a little to one side so two players do not stand in the same place
		local count = deps.battle.padCounts()[pad] or 0
		local dx = if count > 0 then 1.6 else -1.6
		local target = origin + spot + Vector3.new(dx, TOP + 3.2, 0)
		root.CFrame = CFrame.lookAt(
			target,
			origin + Vector3.new(LobbyLayout.ring.x, target.Y - origin.Y, LobbyLayout.ring.z)
		)
	end

	-- CANCEL (or LEAVE): off the pad and a few steps away so the watcher does not take them back.
	handle.cancel = function(player: Player)
		deps.battle.cancel(player)
		cooldown[player] = os.clock() + COOLDOWN
		local root = rootOf(player)
		if
			root and LobbyLayout.padAt(root.Position.X - origin.X, root.Position.Z - origin.Z, 1)
		then
			returns += 1
			local s = LobbyLayout.returnSpot(returns)
			root.CFrame = CFrame.new(origin + Vector3.new(s.x, 4, s.z))
		end
	end

	-- A fight begins: the character waits under the lobby, frozen (the screen shows the arena).
	handle.park = function(player: Player)
		local root = rootOf(player)
		if root then
			root.CFrame =
				CFrame.new(origin + Vector3.new(LobbyLayout.ring.x, PARK_DEPTH, LobbyLayout.ring.z))
			root.Anchored = true
		end
	end

	-- The fight is over: back among the pads, next to them and not on one.
	handle.returnToLobby = function(player: Player)
		returns += 1
		cooldown[player] = os.clock() + COOLDOWN
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			local s = LobbyLayout.returnSpot(returns)
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(
				origin + Vector3.new(s.x, 4, s.z),
				origin + Vector3.new(LobbyLayout.ring.x, 4, LobbyLayout.ring.z)
			)
		end
	end

	handle.stop = function()
		running = false
	end
	handle.remove = function(player: Player)
		cooldown[player] = nil
		pending[player] = nil
	end
	return handle
end

return LobbyPads
