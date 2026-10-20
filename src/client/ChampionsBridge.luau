--!strict
-- Connects carter's Champions UI (src/champions, mounted by its own LocalScript) to the game.
-- Server messages -> ChampionsAdapter (pure) -> snapshots for the UI. UI buttons -> the same
-- LobbyAction / Action remotes the old buttons used. The server stays in charge of everything.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local ChampionsAdapter = require(ReplicatedStorage.Shared.ChampionsAdapter)
local ModesConfig = require(ReplicatedStorage.Shared.ModesConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundFx = require(script.Parent.SoundFx)
local Types = require(ReplicatedStorage.Shared.Types)

local END_SCREEN_DELAY = 3.5 -- seconds of win/lose headline and confetti before the Results screen

local ChampionsBridge = {}

export type Bridge = {
	handleLobby: (u: Types.LobbyUpdate) -> (),
	handleUi: (u: Types.UiUpdate) -> (),
}

-- `onReplayTutorial` runs when the player asks for the tutorial again (Settings).
function ChampionsBridge.new(onReplayTutorial: (() -> ())?): Bridge
	local player = Players.LocalPlayer
	local remotes = Remotes.get()
	local namespace = ReplicatedStorage:WaitForChild("CVC_Champions")
	local actionsEvent = namespace:WaitForChild("Actions") :: BindableEvent
	local stateEvent = namespace:WaitForChild("State") :: BindableEvent
	local openEvent = namespace:WaitForChild("Open") :: BindableEvent
	local notifyEvent = namespace:WaitForChild("Notify") :: BindableEvent

	local model = ChampionsAdapter.new({
		maxSeconds = ModesConfig.LastStanding.maxSeconds,
		cars = ModesConfig.LastStanding.cars,
		isLive = function(id: string): boolean
			return CarConfig.isLive(id)
		end,
	})

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function readLevel()
		model.level(
			player:GetAttribute("PlayerLevel") or 1,
			player:GetAttribute("PlayerXp") or 0,
			player:GetAttribute("PlayerXpNeeded") or 1
		)
	end

	-- The UI sets UIReady once its bridge events are connected; a BindableEvent keeps nothing.
	local function push()
		if namespace:GetAttribute("UIReady") == true then
			stateEvent:Fire(model.snapshot())
		end
	end

	-- A screen the UI was asked to open before it was ready (the starter pick usually arrives first).
	local pendingOpen: string? = nil

	local function apply(fx: ChampionsAdapter.Effects)
		if fx.settings then
			SoundFx.setMuted(not fx.settings.music)
			SoundFx.setSfxMuted(not fx.settings.sfx)
		end
		if fx.notify then
			notifyEvent:Fire(fx.notify, fx.notifyOk)
		end
		push()
		if fx.open then
			if namespace:GetAttribute("UIReady") == true then
				openEvent:Fire(fx.open)
			else
				pendingOpen = fx.open
			end
		end
		if fx.tutorial and onReplayTutorial then
			onReplayTutorial() -- after the menu has closed, so the first bubble is not behind it
		end
	end

	-- Calls that get no answer from the server clear the UI's "waiting" state right away.
	local QUIET =
		{ boost = true, special = true, cancelPlay = true, rematch = true, leaveMatch = true }

	actionsEvent.Event:Connect(function(action: any, payload: any)
		if type(action) ~= "string" then
			return
		end
		local call, fx = model.intent(action, payload)
		if call then
			local remote = (remotes :: any)[call.remote] :: RemoteEvent
			if call.remote == "Action" then
				remote:FireServer(call.name)
			else
				remote:FireServer(call.name, call.arg)
			end
		end
		if call == nil or call.remote == "Action" or QUIET[call.name] then
			push()
		end
		apply(fx)
	end)

	namespace:GetAttributeChangedSignal("UIReady"):Connect(function()
		push()
		if pendingOpen and namespace:GetAttribute("UIReady") == true then
			local screen = pendingOpen
			pendingOpen = nil
			openEvent:Fire(screen)
		end
	end)
	for _, name in { "PlayerLevel", "PlayerXp", "PlayerXpNeeded" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			readLevel()
			push()
		end)
	end
	readLevel()
	push()

	-- The claw machine and the store counter in the lobby open their screens in the new UI.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "GachaPrompt" then
			openEvent:Fire("CLAW")
		elseif prompt.Name == "StorePrompt" then
			openEvent:Fire("SHOP")
		end
	end)

	-- Space = jump (keyboard only, no button; the server decides if it counts).
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local snapshot = model.snapshot()
		if
			not processed
			and input.KeyCode == Enum.KeyCode.Space
			and snapshot.match
			and snapshot.match.phase == "ACTIVE"
		then
			remotes.Action:FireServer("jump")
		end
		-- Keyboard: SHIFT = boost, E = your car's ability (touch players use the buttons).
		if not processed and snapshot.match and snapshot.match.phase == "ACTIVE" then
			if
				input.KeyCode == Enum.KeyCode.LeftShift
				or input.KeyCode == Enum.KeyCode.RightShift
			then
				remotes.Action:FireServer("boost")
			elseif input.KeyCode == Enum.KeyCode.E then
				remotes.Action:FireServer("special")
			end
		end
	end)

	local handle = {} :: Bridge

	handle.handleLobby = function(u: Types.LobbyUpdate)
		local any: any = u
		if u.kind == "profile" then
			readLevel()
			apply(model.profile(any, now()))
		else
			if u.kind == "toLobby" and any.coinsEarned > 0 then
				SoundFx.play("coin")
			end
			apply(model.lobby(any))
		end
	end

	handle.handleUi = function(u: Types.UiUpdate)
		local extra = nil
		if u.kind == "matchEnd" then
			extra =
				{ place = player:GetAttribute("MatchPlace"), kos = player:GetAttribute("MatchKos") }
		end
		local fx = model.ui(u, now(), extra)
		if u.kind == "matchEnd" then
			-- Let the win / lose headline and confetti play, then show the Results screen.
			task.delay(END_SCREEN_DELAY, function()
				apply(fx)
			end)
		else
			apply(fx)
		end
	end

	return handle
end

return ChampionsBridge
