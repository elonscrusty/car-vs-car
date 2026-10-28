--!strict
-- The Lucky Spin and kart hats on the server (Smash plan, REWARDS row). One free spin a day: the
-- server rolls (LuckySpin.spin), pays coins or a hat, and saves. The hat you pick sits on your
-- kart (workspace "Car_<UserId>") at its "Topper" attachment, so everyone sees it.
-- RemoteEvent ReplicatedStorage.LuckySpin.
--   client -> server: ("open") send me the state, ("spin"), ("equip", hatId or "")
--   server -> client: ("state", { wait, hats, hat }) and ("won", index, coins, hat or nil, wait)
-- Player attributes: SpinReady (the free spin is waiting: a dot on the button), Hat, Coins.
-- Every ask is rate-limited and checked; junk is dropped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hats = require(ReplicatedStorage.Shared.Hats)
local LuckySpin = require(ReplicatedStorage.Shared.LuckySpin)
local PlayerData = require(script.Parent.PlayerData)

local SpinServer = {}

local GAP = 0.5 -- seconds between asks from one player
local BASE_WIDTH = 3 -- Tuning.bodyX at full size: hats are drawn for a body this wide

local remote = Instance.new("RemoteEvent")
remote.Name = "LuckySpin"
remote.Parent = ReplicatedStorage

local lastAsk: { [Player]: number } = {}
local owed: { [Player]: boolean } = {} -- a too-quick ask: the state goes out once the gap is over
local rng = Random.new()

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function v3(t: { number }, k: number): Vector3
	return Vector3.new(t[1] * k, t[2] * k, t[3] * k)
end

-- One hat as a Model of welded, massless, no-collide parts on `body` at `at` (+Y up).
function SpinServer.buildHat(hat: Hats.Hat, body: BasePart, at: CFrame): Model
	local k = body.Size.X / BASE_WIDTH
	local m = Instance.new("Model")
	m.Name = "Hat"
	for i, b in hat.bits do
		local p: BasePart
		if b.shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = SHAPES[b.shape] or Enum.PartType.Block
			p = part
		end
		p.Name = "Bit" .. i
		p.Size = v3(b.size, k)
		local r = b.rot or { 0, 0, 0 }
		local turn = CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		if b.shape == "Cylinder" then
			turn *= CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's length is X: stand it up
		end
		p.CFrame = at * CFrame.new(v3(b.at, k)) * turn
		p.Color = Color3.fromRGB(b.rgb[1], b.rgb[2], b.rgb[3])
		p.Material = if b.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		p.Parent = m
	end
	return m
end

-- Put `player`'s hat on their kart (or take it off).
local function dress(player: Player)
	local kart = workspace:FindFirstChild("Car_" .. player.UserId)
	if not (kart and kart:IsA("Model")) then
		return
	end
	local old = kart:FindFirstChild("Hat")
	if old then
		old:Destroy()
	end
	local body = kart.PrimaryPart
	local hat = Hats.get(player:GetAttribute("Hat"))
	if not (hat and body) then
		return
	end
	local topper = kart:FindFirstChild("Topper", true)
	local at = if topper and topper:IsA("Attachment")
		then topper.WorldCFrame
		else body.CFrame * CFrame.new(0, body.Size.Y / 2, 0)
	SpinServer.buildHat(hat, body, at).Parent = kart
end

local function hatList(data: any): { string }
	local out: { string } = {}
	for _, h in Hats.LIST do
		if data.hats[h.id] then
			table.insert(out, h.id)
		end
	end
	return out
end

local function show(player: Player, data: any)
	player:SetAttribute("SpinReady", LuckySpin.wait(data, os.time()) == 0)
	player:SetAttribute("Hat", if data.hat ~= "" then data.hat else nil)
end

local function sendState(player: Player, data: any)
	remote:FireClient(player, "state", {
		wait = LuckySpin.wait(data, os.time()),
		hats = hatList(data),
		hat = data.hat,
	})
end

local function onAsk(player: Player, what: any, arg: any)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < GAP then
		if (what == "open" or what == "equip") and not owed[player] then
			owed[player] = true
			task.delay(GAP, function()
				owed[player] = nil
				local data = PlayerData.get(player)
				if data and player.Parent then
					sendState(player, data)
				end
			end)
		end
		return
	end
	lastAsk[player] = now
	local data: any = PlayerData.get(player)
	if not data or type(what) ~= "string" then
		return
	end
	if what == "open" then
		sendState(player, data)
	elseif what == "spin" then
		-- not while the visit is unsaved (the DataStore was down at join): the spin day can't be
		-- checked against the real save, so hopping servers would give a spin each time
		if PlayerData.isRetrying(player) then
			sendState(player, data)
			return
		end
		local won = LuckySpin.spin(data, os.time(), rng:NextNumber())
		if not won then
			sendState(player, data)
			return
		end
		PlayerData.touch(player)
		player:SetAttribute("Coins", data.coins)
		show(player, data)
		remote:FireClient(
			player,
			"won",
			won.index,
			won.coins,
			won.hat,
			LuckySpin.wait(data, os.time())
		)
		sendState(player, data) -- the new hat in the list
	elseif what == "equip" then
		if type(arg) ~= "string" or (arg ~= "" and not data.hats[arg]) then
			return
		end
		if data.hat ~= arg then
			data.hat = arg
			PlayerData.touch(player)
			show(player, data)
			dress(player)
		end
		sendState(player, data)
	end
end

function SpinServer.start()
	remote.OnServerEvent:Connect(onAsk)
	PlayerData.loaded:Connect(function(player: Player, data)
		show(player, data)
		dress(player)
	end)
	PlayerData.synced:Connect(function(player: Player, data)
		show(player, data)
		dress(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastAsk[player], owed[player] = nil, nil
	end)
	-- a kart was (re)built: put its owner's hat back on
	workspace.ChildAdded:Connect(function(child: Instance)
		local id = tonumber(string.match(child.Name, "^Car_(%d+)$"))
		local player = id and Players:GetPlayerByUserId(id)
		if player then
			task.defer(dress, player)
		end
	end)
	-- the free spin comes back at midnight (UTC) for players who stay
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data then
					player:SetAttribute("SpinReady", LuckySpin.wait(data, os.time()) == 0)
				end
			end
		end
	end)
end

return SpinServer
