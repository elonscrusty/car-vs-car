--!strict
-- Smash CUSTOMIZE window glue (WINDOWS): ReplicatedStorage.OpenCustomize (a BindableEvent: the
-- garage sign or a HUD tile fires it) opens the garage (KitWindows.garage, carter's kit v41).
--   KARTS: your garage (CvcState); EQUIP asks the server through Garage ("racer", uid) (GARAGE).
--   HATS: shared/Hats (REWARDS) with the player attributes Hat (on) and HatsOwned (comma ids);
--     EQUIP fires ReplicatedStorage.LuckySpin ("equip", id), TAKE OFF ("equip", ""). Until Hats
--     lands the tab says SOON.
-- The server checks every ask; this only shows and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if (Features :: any).SMASH ~= true then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Ui = script.Parent:WaitForChild("Ui")
local Screen = require(Ui:WaitForChild("Screen"))
local KitWindows = require(Ui:WaitForChild("Screens"):WaitForChild("KitWindows"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))

local player = Players.LocalPlayer
CvcState.start()

-- shared/Hats once REWARDS adds it (nil until then)
local function hatsModule(): any
	local m = Shared:FindFirstChild("Hats")
	if m and m:IsA("ModuleScript") then
		local ok, got = pcall(require, m)
		if ok and type(got) == "table" and type(got.LIST) == "table" then
			return got
		end
	end
	return nil
end

local function owned(): { [string]: boolean }
	local out = {}
	local s = player:GetAttribute("HatsOwned")
	if type(s) == "string" then
		for id in string.gmatch(s, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

local function hatOn(): string
	local h = player:GetAttribute("Hat")
	return if type(h) == "string" then h else ""
end

-- (not in a round: the window would sit over the match and its X over the clock)
local function inMatch(): boolean
	return player:GetAttribute("InMatch") == true
end

local tab = 1
local kartUids: { string } = {}
local hatIds: { string } = {}
local lastAsk = 0

-- show the server's answer (a new racer, a hat put on or won) by building the window again while
-- it's open; only then (other garage news doesn't replay its entrance)
local seen = ""
local function look(): string
	return `{CvcState.racer}|{hatOn()}|{tostring(player:GetAttribute("HatsOwned"))}|{#CvcState.garage}`
end
local open: () -> ()
local current: Screen.Handle? = nil

-- (closes only this window: never a round's end screen or a pick/reveal)
local function shut()
	if current and Screen.isOpen("customize") then
		current.close()
	end
	current = nil
end

local function ask(fn: () -> ())
	local now = os.clock()
	if now - lastAsk < 0.5 then -- (the server takes one ask per 0.5 s)
		return
	end
	lastAsk = now
	fn()
end

function open()
	seen = look()
	local karts = {}
	table.clear(kartUids)
	local driving = nil
	for _, car in CvcState.garage do
		local on = car.uid == CvcState.racer
		local item = {
			id = car.id,
			name = CvcState.name(car.id),
			rarity = CarCatalog.rarity(car.id).id,
			own = true,
			on = on,
		}
		table.insert(karts, item)
		table.insert(kartUids, car.uid)
		if on then
			driving = item
		end
	end
	local Hats = hatsModule()
	local hats = nil
	local wearing = nil
	table.clear(hatIds)
	if Hats then
		hats = {}
		local mine, now = owned(), hatOn()
		for _, h in Hats.LIST do
			if type(h) == "table" and type(h.id) == "string" then
				local item = {
					name = if type(h.name) == "string" then h.name else h.id,
					rarity = if type(h.rarity) == "string" then h.rarity else "common",
					own = mine[h.id] == true,
					on = h.id == now,
				}
				table.insert(hats, item)
				table.insert(hatIds, h.id)
				if item.on then
					wearing = item
				end
			end
		end
	end
	current = KitWindows.garage({
		tab = tab,
		karts = karts,
		hats = hats,
		hatsSoon = Hats == nil,
		driving = driving,
		hatOn = wearing,
	}, {
		tab = function(i: number)
			tab = i
		end,
		equip = function(t: number, i: number)
			ask(function()
				if t == 1 then
					local uid = kartUids[i]
					if uid then
						CvcState.ask("racer", uid)
					end
				else
					local id = hatIds[i]
					local r = ReplicatedStorage:FindFirstChild("LuckySpin")
					if id and r and r:IsA("RemoteEvent") then
						-- (the hat already on comes off)
						r:FireServer("equip", if id == hatOn() then "" else id)
					end
				end
			end)
		end,
		close = function()
			shut()
		end,
	})
end

local pending = false
local function refresh()
	-- (one rebuild for news that comes together, e.g. a hat won and put on)
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		local now = look()
		if now ~= seen and Screen.isOpen("customize") then
			open()
		end
		seen = now
	end)
end
CvcState.changed:Connect(refresh)
player:GetAttributeChangedSignal("Hat"):Connect(refresh)
player:GetAttributeChangedSignal("HatsOwned"):Connect(refresh)

local ev = ReplicatedStorage:FindFirstChild("OpenCustomize")
if not (ev and ev:IsA("BindableEvent")) then
	local made = Instance.new("BindableEvent")
	made.Name = "OpenCustomize"
	made.Parent = ReplicatedStorage
	ev = made
end
(ev :: BindableEvent).Event:Connect(function()
	if not inMatch() then
		open()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if inMatch() then
		shut()
	end
end)
