--!strict
-- The plot looks shop's server side (shared/PlotShop has the items and rules). The client asks
-- with PlotShopEvent: ("open"), ("buy", id) or ("toggle", id); the server checks everything
-- (the coins, that the look exists, a short wait between asks), changes the save
-- (PlayerData.touch) and answers ("state", {coins, stars, have, on}). It puts each owned plot's
-- looks on the plot model as OwnerLooks ("night,balloons"), which PlotLooksBuilder shows, and
-- refreshes the coin chip and toasts through the Stars thread's StarsEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotShop = require(ReplicatedStorage.Shared.PlotShop)
local Forever = require(ReplicatedStorage.Shared.Forever)
local PlayerData = require(script.Parent.PlayerData)

local PlotShopServer = {}

local WAIT = 0.3 -- seconds between one player's asks
local SYNC = 1 -- seconds between looks at every plot (stars, owners and loads change it too)

local remote = Instance.new("RemoteEvent")
remote.Name = "PlotShopEvent"
remote.Parent = ReplicatedStorage

local last: { [Player]: number } = {}

local function plotModel(slotIndex: number, id: string): Instance?
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(slotIndex .. "_" .. id)
end

local function stars(player: Player, msg: string, ...: any)
	local ev = ReplicatedStorage:FindFirstChild("StarsEvent")
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg, ...)
	end
end

-- every plot's OwnerLooks from its owner's save (none while nobody owns it or it's loading)
local function sync()
	for _, slot in LobbyLayout.slots() do
		local m = plotModel(slot.index, slot.id)
		if not m then
			continue
		end
		local id = m:GetAttribute("OwnerId")
		local owner = if type(id) == "number" and id > 0 then Players:GetPlayerByUserId(id) else nil
		local data = owner and PlayerData.get(owner)
		local looks = if data then PlotShop.encode(PlotShop.shown(data)) else nil
		if m:GetAttribute("OwnerLooks") ~= looks then
			m:SetAttribute("OwnerLooks", looks)
		end
	end
end

local function send(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local have, on = {}, {}
	for _, it in PlotShop.ITEMS do
		if PlotShop.has(data, it.id) then
			table.insert(have, it.id)
			if not data.lookOff[it.id] then
				table.insert(on, it.id)
			end
		end
	end
	remote:FireClient(
		player,
		"state",
		{ coins = data.coins, stars = data.stars, have = have, on = on }
	)
end

local function onAsk(player: Player, what: any, id: any)
	local now = os.clock()
	if now - (last[player] or 0) < WAIT then
		return
	end
	last[player] = now
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if what == "buy" then
		local ok, why = PlotShop.buy(data, id)
		if ok then
			PlayerData.touch(player)
			stars(player, "coins", data.coins)
			local it = PlotShop.item(id) :: PlotShop.Item
			stars(player, "toast", `{it.icon} {it.name} is on your plot!`)
			print(`[PlotShop] {player.Name} bought {it.id} ({data.coins} coins left)`)
		elseif why == "coins" then
			stars(player, "toast", "Not enough coins yet")
		end
	elseif what == "toggle" then
		if PlotShop.toggle(data, id) ~= nil then
			PlayerData.touch(player)
		end
	elseif what ~= "open" then
		return
	end
	sync()
	send(player)
end

function PlotShopServer.start()
	remote.OnServerEvent:Connect(onAsk)
	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
	task.spawn(function()
		while true do
			Forever.step("PlotShop", sync)
			task.wait(SYNC)
		end
	end)
end

return PlotShopServer
