--!strict
-- Client entry point. Lobby UI (menu bar, quests, paint, build, hints) plus the 1v1 Battle screens (BattleUi).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local BuildUi = require(script.BuildUi)
require(script.OwnRing).start() -- glow ring under my own car
require(script.MapFx).start() -- turns the big wheel behind the battle arena
local HintUi = require(script.HintUi)
local ChampionsBridge = require(script.ChampionsBridge)
local BotLevelUi = require(script.BotLevelUi)
local MenuBar = require(script.MenuBar)
local Quality = require(script.Quality)
local QuestUi = require(script.QuestUi)
local SaveNotice = require(script.SaveNotice)
local SpinUi = require(script.SpinUi)
local PaintUi = require(script.PaintUi)
local SoundFx = require(script.SoundFx)
local BattleUi = require(script.BattleUi)
local TutorialClient = require(script.TutorialClient)

require(script.LobbyClient).start() -- fade into the fight, the lobby spin, rare pulls for the whole server
BattleUi.start() -- 1v1 auto-battle screens and camera (server: BattleService)
Quality.start() -- low-end phones: fewer particles when the frame time is high
local remotes = Remotes.get()
-- The first-time tutorial (portal, practice drive, green line, free pull); also run again from Settings.
local tutorial = TutorialClient.new({ remotes = remotes })
local menu = MenuBar.new() -- features add their own lobby buttons here (see MenuBar.luau)
-- Launch cuts live behind FeatureFlags: the UI is simply not built while a flag is off.
local botLevelUi = if FeatureFlags.enabled("botLevelButton")
	then BotLevelUi.new(menu, function(level: string)
		remotes.LobbyAction:FireServer("setBotLevel", level)
	end)
	else nil
SaveNotice.new()

local questUi = QuestUi.new(menu, function(action: string, arg: any?)
	remotes.LobbyAction:FireServer(action, arg)
end)
local spinUi = if FeatureFlags.enabled("dailySpin")
	then SpinUi.new(menu, function(action: string, arg: any?)
		remotes.LobbyAction:FireServer(action, arg)
	end)
	else nil
local paintUi = if FeatureFlags.enabled("paintShop") then PaintUi.new(menu) else nil
local buildUi = BuildUi.new(menu)
menu.setShown("quests", false) -- until the first profile update says the player has played enough
menu.setShown("garage", false)

-- First-time hints: the server saves which ones were shown (profile.hintsSeen).
local hints = HintUi.new(function(id: string)
	remotes.LobbyAction:FireServer("hintSeen", id)
end)

-- Standing on a pad (or the fight starting) is the first-time hint "Tap PLAY or step on a pad" done: it must
-- not stay on screen behind the VS screen.
remotes.BattleUpdate.OnClientEvent:Connect(function(m: any)
	if type(m) == "table" and ((m.kind == "queue" and m.searching == true) or m.kind == "prep") then
		hints.done("pad")
	end
	tutorial.handleBattle(m)
end)

-- Carter's Champions UI (src/champions) draws every lobby and match screen; the bridge feeds it.
local champions = ChampionsBridge.new(tutorial.replay)

-- Back at the lobby: lobby music and the next hint.
local function onToLobby()
	ProximityPromptService.Enabled = true
	menu.setVisible(true)
	SoundFx.music("music_lobby")
	hints.trigger("claw") -- after a fight: point at the claw machine
end
remotes.LobbyUpdate.OnClientEvent:Connect(function(u: Types.LobbyUpdate)
	champions.handleLobby(u)
	tutorial.handleLobby(u) -- before the pad hint below: a new player gets the tutorial instead
	if u.kind == "toLobby" then
		onToLobby()
	end
	questUi.handleUpdate(u)
	if spinUi then
		spinUi.handleUpdate(u)
	end
	if paintUi then
		paintUi.handleUpdate(u)
	end
	buildUi.handleUpdate(u)
	if u.kind == "profile" then
		hints.loadSeen(u.hintsSeen)
		if botLevelUi then
			botLevelUi.handleProfile(u.botLevel)
		end
		-- The lobby screen has only PLAY, CARS, SHOP and the daily GIFT (carter): QUESTS and
		-- GARAGE stay hidden (the customize garage in the lobby opens the paint / garage screen).
		menu.setShown("quests", false)
		menu.setShown("garage", false)
		if not tutorial.active() then
			hints.trigger("pad") -- no-op once seen
		end
	elseif u.kind == "countdown" and u.seconds > 0 then
		hints.done("pad") -- stepped on a pad
	end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	tutorial.promptTriggered(prompt.Name)
	if prompt.Name == "GachaPrompt" and hints.loaded() then
		hints.done("claw")
	elseif
		prompt.Name == "CustomizePrompt"
		or (
			prompt.Name == "BayPrompt"
			and prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		)
	then
		buildUi.open() -- the paint / customize booth, or your own bay
	end
end)

SoundFx.music("music_lobby") -- silent until carter fills the id in SoundConfig
