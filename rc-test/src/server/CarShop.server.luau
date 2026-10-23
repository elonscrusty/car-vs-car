--!strict
-- The car shops and the gumball machine (CarCatalog's rules, the player's save from PlayerData).
-- Looks only: a car changes how you look, never how fast you go.
-- Client -> server (RemoteFunction CarShop): ("state") / ("buy", id) / ("equip", id) /
-- ("spin") / ("buyTile", id) / ("spinTile"). Every call answers with the player's state:
--   { coins, owned = { id }, equipped = { mode = id }, tiles = { tile id }, stars, ok, why?,
--     car? (spin), tile? (spinTile), new? (spin, spinTile) }
-- Track tiles are TileShop's (the build screen asks TileShop.owns / count on the save).
-- Each player's chosen car per mode is also on the Player as attributes Car_drift, Car_race and
-- Car_rock (car ids), for whoever draws the cars, and the shop cars owned are in "Cars"
-- ("<kind>:<index>" into Garage.SHOPS, comma separated: the plot stands show them).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local TileShop = require(ReplicatedStorage.Shared.TileShop)
local PlayerData = require(script.Parent.PlayerData)

local GAP = 0.3 -- seconds between calls from one player

local remote = Instance.new("RemoteFunction")
remote.Name = "CarShop"
remote.Parent = ReplicatedStorage

local last: { [Player]: number } = {}

local function setAttributes(player: Player, data: CarCatalog.Save)
	local shown = {}
	for _, mode in CarCatalog.MODES do
		player:SetAttribute("Car_" .. mode, CarCatalog.equipped(data, mode).id)
		for i, c in CarCatalog.SHOP[mode] do
			if CarCatalog.owns(data, c.id) then
				table.insert(shown, mode .. ":" .. i)
			end
		end
	end
	player:SetAttribute("Cars", table.concat(shown, ","))
end

local function state(data: any): { [string]: any }
	local owned = {}
	for _, list in CarCatalog.SHOP do
		for _, c in list do
			if CarCatalog.owns(data, c.id) then
				table.insert(owned, c.id)
			end
		end
	end
	for _, g in CarCatalog.GUMBALL do
		if CarCatalog.owns(data, g.car.id) then
			table.insert(owned, g.car.id)
		end
	end
	local equipped = {}
	for _, mode in CarCatalog.MODES do
		equipped[mode] = CarCatalog.equipped(data, mode).id
	end
	return {
		coins = data.coins,
		owned = owned,
		equipped = equipped,
		tiles = TileShop.owned(data),
		stars = data.stars or 0,
		ok = true,
	}
end

-- The coin chip on screen is Stars' (StarsEvent "coins"): keep it right after a spend.
local function showCoins(player: Player, coins: number)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "coins", coins)
	end
end

remote.OnServerInvoke = function(player: Player, action: unknown, id: unknown): any
	local data = PlayerData.get(player) :: any
	if data == nil then
		return { ok = false, why = "loading" }
	end
	local now = os.clock()
	if now - (last[player] or 0) < GAP then
		local busy = state(data)
		busy.ok, busy.why = false, "busy"
		return busy
	end
	last[player] = now

	if action == "state" then
		return state(data)
	elseif action == "buy" then
		local ok, why = CarCatalog.buy(data, id)
		if ok then
			PlayerData.touch(player)
			showCoins(player, data.coins)
			setAttributes(player, data)
		end
		local out = state(data)
		out.ok, out.why = ok, why
		return out
	elseif action == "equip" then
		local ok = CarCatalog.equip(data, id)
		if ok then
			PlayerData.touch(player)
			setAttributes(player, data)
		end
		local out = state(data)
		out.ok, out.why = ok, if ok then nil else "not owned"
		return out
	elseif action == "spin" then
		local car, new = CarCatalog.spin(data, math.random() * 100)
		if car then
			PlayerData.touch(player)
			showCoins(player, data.coins)
		end
		local out = state(data)
		out.ok, out.why = car ~= nil, if car then nil else "coins"
		out.car, out.new = if car then car.id else nil, new
		return out
	elseif action == "buyTile" then
		local ok, why = TileShop.buy(data, id)
		if ok then
			PlayerData.touch(player)
			showCoins(player, data.coins)
		end
		local out = state(data)
		out.ok, out.why = ok, why
		return out
	elseif action == "spinTile" then
		local tile, new = TileShop.spin(data, math.random() * 100)
		if tile then
			PlayerData.touch(player)
			showCoins(player, data.coins)
		end
		local out = state(data)
		out.ok, out.why = tile ~= nil, if tile then nil else "coins"
		out.tile, out.new = if tile then tile.id else nil, new
		return out
	end
	return { ok = false, why = "unknown" }
end

PlayerData.loaded:Connect(function(player: Player, data: any)
	setAttributes(player, data)
end)
for _, player in Players:GetPlayers() do
	local data = PlayerData.get(player)
	if data then
		setAttributes(player, data :: any)
	end
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
