--!strict
-- The Lucky Spin button, window and the LEVEL UP popup (Smash plan, REWARDS row). Only with
-- Features.SMASH on. A SPIN tile on the right (a dot while today's free spin waits) opens the spin
-- window (Ui/Screens/Spin); the server (SpinServer, RemoteEvent LuckySpin) rolls and pays.
-- LevelUp (XpServer) shows "LEVEL n!" with the coins, after the match if you're in one.
-- Lobby only: the tile shows with the lobby HUD (Ui_plot) and never while InMatch (MatchRunner).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.SMASH then
	return
end
local Hats = require(Shared:WaitForChild("Hats"))
local LuckySpin = require(Shared:WaitForChild("LuckySpin"))
local Ui = script.Parent:WaitForChild("Ui")
local Screens = Ui:WaitForChild("Screens")
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))
local Screen = require(Ui:WaitForChild("Screen"))
local Spin = require(Screens:WaitForChild("Spin"))
local Windows = require(Screens:WaitForChild("Windows"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("LuckySpin") :: RemoteEvent
local levelUp = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent

local TILE_X, TILE_Y = 682, 120 -- design px: the right edge, under the coins

local function inMatch(): boolean
	return player:GetAttribute("InMatch") == true
end

local tileGui = Base.screen("Ui_spinTile", Base.ORDER.hud, false)
local tile = Kit.side(tileGui.canvas, "Spin", TILE_X, TILE_Y, "SPIN", "gift", 4)

-- The tile is part of the lobby HUD: it shows only while that HUD (CvcScreens' Ui_plot) shows,
-- so it leaves with it in the arena, the warm-up yard and under windows; and never while InMatch
-- (Studio round 4: it stayed on in the arena over the "GRAB A ?" tip).
local playerGui = player:WaitForChild("PlayerGui")
local function lobbyHudUp(): boolean
	local hud = playerGui:FindFirstChild("Ui_plot")
	return hud ~= nil and hud:IsA("ScreenGui") and hud.Enabled
end
local function showTile()
	local on = not inMatch() and lobbyHudUp()
	if tileGui.gui.Enabled ~= on then
		Base.show(tileGui, on)
	end
end
local function showDot()
	tile.setDot(if player:GetAttribute("SpinReady") == true then -1 else nil)
end
player:GetAttributeChangedSignal("InMatch"):Connect(showTile)
player:GetAttributeChangedSignal("SpinReady"):Connect(showDot)
-- follow the lobby HUD the moment it turns on or off
local function watchHud(child: Instance)
	if child.Name == "Ui_plot" and child:IsA("ScreenGui") then
		child:GetPropertyChangedSignal("Enabled"):Connect(showTile)
		showTile()
	end
end
playerGui.ChildAdded:Connect(watchHud)
for _, child in playerGui:GetChildren() do
	watchHud(child)
end
showTile()
showDot()
-- (and a slow look again, in case something else turns the tile's gui on)
task.spawn(function()
	while true do
		task.wait(1)
		showTile()
	end
end)

local prizes: { { [string]: any } } = {}
for _, p in LuckySpin.PRIZES do
	table.insert(prizes, { label = p.label, chance = p.chance, rarity = p.rarity, kind = p.kind })
end

local handle: Screen.Handle? = nil
-- a match started: the spin window and its prize card step away (the prize is already paid)
local prizeCard: Screen.Handle? = nil -- the won card, if it's ours
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if not inMatch() then
		return
	end
	if Screen.isOpen("spin") and handle then
		handle.close()
		handle = nil
	end
	if prizeCard then
		prizeCard.close() -- (safe if it's closed already or another card took its place)
		prizeCard = nil
	end
end)
local waitLeft, waitAt = 0, os.clock()

local function hatRows(owned: { string }, on: string): { { [string]: any } }
	local out = {}
	for _, id in owned do
		local h = Hats.get(id)
		if h then
			table.insert(out, { id = id, name = h.name, rarity = h.rarity, on = id == on })
		end
	end
	return out
end

local function isOpen(): boolean
	return handle ~= nil and Screen.isOpen("spin")
end

local function open()
	handle = Spin.window({ prizes = prizes, wait = waitLeft, hats = {} }, {
		spin = function()
			remote:FireServer("spin")
		end,
		equip = function(id: string)
			remote:FireServer("equip", id)
		end,
		close = function()
			if handle then
				handle.close()
			end
			handle = nil
		end,
	})
	remote:FireServer("open")
end
tile.button.Activated:Connect(open)

-- the clock on the button ticks down while the window is open
task.spawn(function()
	while true do
		task.wait(1)
		local h = handle
		if h and isOpen() and waitLeft > 0 then
			local left = math.max(waitLeft - (os.clock() - waitAt), 0)
			h.api.setWait(left)
		end
	end
end)

local function prizeWords(index: number, coins: number, hat: string?): (string, string)
	if hat then
		local h = Hats.get(hat)
		return "NEW HAT!", (if h then h.name else "A hat") .. " for your kart"
	end
	local p = LuckySpin.PRIZES[index]
	if p and p.kind == "hat" then
		return "+" .. coins .. " COINS", "You had that hat, so here are coins!"
	end
	return "+" .. coins .. " COINS", "Come back tomorrow for another free spin!"
end

remote.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
	if kind == "state" and type(a) == "table" then
		waitLeft, waitAt = tonumber(a.wait) or 0, os.clock()
		local h = handle
		if h and isOpen() then
			h.api.setWait(waitLeft)
			h.api.setHats(hatRows(a.hats or {}, a.hat or ""))
		end
	elseif kind == "won" then
		local index, coins, hat = tonumber(a) or 1, tonumber(b) or 0, c
		waitLeft, waitAt = tonumber(d) or 0, os.clock()
		local function reveal()
			local title, text = prizeWords(index, coins, hat)
			prizeCard = Windows.popup({
				kind = "coins",
				icon = if hat then "gift" else "coin",
				title = title,
				text = text,
				yes = if hat then { "WEAR IT", "lime" } else { "AWESOME!", "lime" },
				no = false,
			}, {
				yes = function()
					if prizeCard then
						prizeCard.close()
						prizeCard = nil
					end
					if hat then
						remote:FireServer("equip", hat)
					end
				end,
			})
		end
		local h = handle
		if h and isOpen() then
			h.api.spinTo(index, function()
				h.api.setWait(waitLeft)
				task.wait(0.3)
				reveal()
			end)
		else
			reveal()
		end
	end
end)

-- LEVEL UP: right away out of a match, else when it ends
local pending: { { number } } = {}
local levelCard: Screen.Handle? = nil
local shownLevels: { { number } } = {} -- what the card on screen holds (put back if it must go)
local calmFor = 0
-- Only in the garage (the lobby HUD is up), never in a match, the warm-up yard / its countdown,
-- or under the match end, a crate reveal or another window (Studio round 10: LEVEL 5! popped
-- up at GO after a re-join, over the kart).
local function levelsCalm(): boolean
	return not inMatch()
		and player:GetAttribute("MatchQueued") ~= true
		and not Screen.anyOver()
		and lobbyHudUp()
end
local function showLevels()
	if #pending == 0 or levelCard ~= nil or not levelsCalm() or calmFor < 3 then
		return
	end
	local top, coins = 0, 0
	for _, l in pending do
		top = math.max(top, l[1])
		coins += l[2]
	end
	shownLevels = table.clone(pending)
	table.clear(pending)
	local card: Screen.Handle? = nil
	card = Windows.popup({
		kind = "coins",
		icon = "trophy",
		title = "LEVEL " .. top .. "!",
		text = "+" .. coins .. " coins",
		yes = { "AWESOME!", "lime" },
		no = false,
	}, {
		yes = function()
			if card then
				card.close()
			end
			levelCard, shownLevels = nil, {}
		end,
	})
	levelCard = card
end
-- a match or the yard started with the card up: it goes, and comes back in the garage
local function levelsStepAway()
	local card = levelCard
	if card and not levelsCalm() and (inMatch() or player:GetAttribute("MatchQueued") == true) then
		card.close()
		for _, l in shownLevels do
			table.insert(pending, l)
		end
		levelCard, shownLevels = nil, {}
	elseif card and not Screen.isOpen("popup") then
		-- another window or card closed it before AWESOME!: the levels wait for the next calm
		for _, l in shownLevels do
			table.insert(pending, l)
		end
		levelCard, shownLevels = nil, {}
	end
end
levelUp.OnClientEvent:Connect(function(level: any, coins: any)
	table.insert(pending, { tonumber(level) or 1, tonumber(coins) or 0 })
end)
player:GetAttributeChangedSignal("InMatch"):Connect(levelsStepAway)
player:GetAttributeChangedSignal("MatchQueued"):Connect(levelsStepAway)
-- calm for 2 s in a row first (the moments between rounds flicker)
task.spawn(function()
	while true do
		task.wait(1)
		calmFor = if levelsCalm() then calmFor + 1 else 0
		levelsStepAway()
		showLevels()
	end
end)
