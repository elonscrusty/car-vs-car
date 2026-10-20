--!strict
-- The first-time tutorial on this device (carter's L1-L20, L53-L60): the glue between the pure steps
-- (Tutorial), the screens (TutorialUi), the green line (GuideTrail), the blue portal
-- (TutorialPortal), the practice drive (PracticeClient) and what the game says (LobbyUpdate,
-- BattleUpdate, the gumball machine's prompt, the Champions menus).
--
--   portal -> practice drive (gas, steer, smash 3 boxes) -> green line to the gumball machine ->
--   the free pull -> green line to a PLAY pad (or the PLAY button) -> a small coin gift
--
-- The server saves the flags when the tutorial STARTS (so leaving half way never shows it again) and
-- pays the gift once (TutorialService); this side only shows. Anything that goes wrong here stops the
-- tutorial and gives the player the normal lobby back: it must never trap anyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local TutorialConfig = require(ReplicatedStorage.Shared.TutorialConfig)
local GuideTrail = require(script.Parent.GuideTrail)
local PracticeClient = require(script.Parent.PracticeClient)
local TutorialPortal = require(script.Parent.TutorialPortal)
local TutorialUi = require(script.Parent.TutorialUi)

local TutorialClient = {}

export type Deps = {
	remotes: { LobbyAction: RemoteEvent },
}

export type Handle = {
	handleLobby: (u: any) -> (), -- LobbyUpdate: the first profile of a new player starts the tutorial
	handleBattle: (m: any) -> (), -- BattleUpdate: queueing for a fight ends the tutorial
	promptTriggered: (promptName: string) -> (), -- the gumball machine's prompt
	replay: () -> (), -- Settings: show it again (no second gift)
	active: () -> boolean, -- running now (not finished, not skipped)
}

local PRACTICE: { [string]: boolean } = { gas = true, steer = true, smash = true }

function TutorialClient.new(deps: Deps): Handle
	local player = Players.LocalPlayer
	local remotes = deps.remotes
	local origin: Vector3 = LobbyConfig.Lobby.origin
	-- a keyboard without a touch screen is a PC; everything else gets the phone words (as Race.luau)
	local touch = not (UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled)

	local machine: Tutorial.Machine? = nil
	local ui: TutorialUi.Ui? = nil
	local trail: GuideTrail.Trail? = nil
	local portal: TutorialPortal.Portal? = nil
	local practice: PracticeClient.Practice? = nil

	local startedOnce = false -- the automatic start happens once per visit
	local freePull = true -- the profile says the first pull is still free
	local holdUntil = 0.0 -- a finished step stays on screen (check + confetti) until then
	local pendingLeave = false -- the practice steps are over: leave the yard after the hold
	local leaving = false -- the yard is being left: no bubble meanwhile
	local showingDone = false -- the last bubble (the coin gift) is up
	local giftCoins = 0
	local menuWasOpen = false
	local runId = 0

	local function characterPosition(): Vector3?
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			return (root :: BasePart).Position
		end
		return nil
	end

	local function refresh()
		local u, m = ui, machine
		if u == nil or m == nil or os.clock() < holdUntil then
			return
		end
		if showingDone then
			local text = if giftCoins > 0
				then Tutorial.text("done", touch, { coins = giftCoins })
				else Tutorial.text("doneNoGift", touch)
			u.setView({ id = "done", text = text, anchor = "top", practice = false })
			return
		end
		local v = m.view()
		local p = practice
		if v ~= nil and ((v.practice and (p == nil or not p.isReady())) or leaving) then
			v = nil -- the yard is not up yet / is being left: no bubble meanwhile
		end
		u.setView(v)
		-- the pieces that stand in the lobby
		local po, tr = portal, trail
		if po ~= nil then
			if m.current() == "portal" and not leaving then
				po.show()
			else
				po.hide()
			end
		end
		if tr ~= nil then
			if v ~= nil and v.path ~= nil then
				tr.show(if v.path == "gumball" then "gumball" else "pad")
			else
				tr.hide()
			end
		end
	end

	-- Everything off, the lobby as it was. Safe to call at any time, any number of times.
	local function shutDown(leaveYard: boolean)
		runId += 1
		machine = nil
		showingDone, leaving, pendingLeave, holdUntil = false, false, false, 0
		if portal ~= nil then
			portal.hide()
		end
		if trail ~= nil then
			trail.hide()
		end
		if ui ~= nil then
			ui.setView(nil)
			ui.setSkipShown(false)
		end
		local p = practice
		if p ~= nil and p.isActive() and leaveYard then
			p.leave(nil)
		end
	end

	local function abort(reason: string)
		warn("[Tutorial] stopped: " .. reason)
		local ok = pcall(shutDown, true)
		if not ok then
			pcall(function()
				remotes.LobbyAction:FireServer("practiceExit")
			end)
		end
	end

	local function safely(label: string, fn: () -> ())
		local ok, err = pcall(fn :: () -> any)
		if not ok then
			abort(label .. ": " .. tostring(err))
		end
	end

	local fire: (name: string, value: any?) -> ()

	local function onFinished()
		local m = machine
		if m == nil then
			return
		end
		local myRun = runId
		if m.wasSkipped() then
			shutDown(true)
			return
		end
		-- played to the end: the server pays the gift once, the last bubble tells
		remotes.LobbyAction:FireServer("tutorialDone")
		if portal ~= nil then
			portal.hide()
		end
		if trail ~= nil then
			trail.hide()
		end
		showingDone = true
		holdUntil = 0
		if ui ~= nil then
			ui.setSkipShown(false)
		end
		refresh()
		task.delay(TutorialConfig.finishSeconds, function()
			if runId == myRun then
				shutDown(false)
			end
		end)
	end

	fire = function(name: string, value: any?)
		local m = machine
		if m == nil or m.isFinished() then
			return
		end
		local before = m.current()
		local r = m.event(name, value)
		if r.done ~= nil and ui ~= nil then
			ui.celebrate()
			holdUntil = os.clock() + TutorialConfig.celebrateSeconds
		end
		local now = r.now
		if now ~= before then
			-- the portal leads into the practice yard
			if before == "portal" and now == "gas" and practice ~= nil then
				practice.enter()
			end
			-- the practice steps are over: leave the yard once the check has been seen
			if before ~= nil and PRACTICE[before] and (now == nil or not PRACTICE[now]) then
				pendingLeave = true
			end
		end
		if r.finished then
			onFinished()
		else
			refresh()
		end
	end

	local function onPracticeEvent(name: string, value: any?)
		local m = machine
		if m == nil then
			return
		end
		local cur = m.current()
		if name == "gas" or name == "steer" then
			if cur == name then
				fire(name, value)
			end
		elseif name == "boxes" then
			fire("boxes", value)
		elseif name == "practiceFailed" then
			fire("practiceFailed")
		elseif name == "timeUp" or name == "practiceBroken" then
			local p = practice
			if p ~= nil then
				leaving = true
				refresh()
				p.leave(function()
					leaving = false
					fire("practiceFailed")
				end)
			end
		end
	end

	local function ensureParts()
		if ui == nil then
			ui = TutorialUi.new(function()
				safely("skip", function()
					fire("skip")
				end)
			end)
		end
		if trail == nil then
			trail = GuideTrail.new(origin, characterPosition)
		end
		if portal == nil then
			portal = TutorialPortal.new(origin, characterPosition, function()
				safely("portal", function()
					fire("portal")
				end)
			end)
		end
		if practice == nil then
			practice = PracticeClient.new({
				remotes = remotes,
				fade = function(toBlack: boolean, seconds: number)
					if ui ~= nil then
						ui.fade(toBlack, seconds)
					else
						task.wait(seconds)
					end
				end,
				onEvent = function(name: string, value: any?)
					safely("practice", function()
						onPracticeEvent(name, value)
					end)
				end,
				touch = touch,
			})
		end
	end

	local function start()
		local current = machine
		if current ~= nil and not current.isFinished() then
			return
		end
		ensureParts()
		runId += 1
		showingDone, leaving, pendingLeave, holdUntil, giftCoins = false, false, false, 0, 0
		local m = Tutorial.new(touch)
		m.setFree(freePull)
		machine = m
		remotes.LobbyAction:FireServer("tutorialStart")
		if ui ~= nil then
			ui.setSkipShown(true)
		end
		refresh()
	end

	-- a step has been shown long enough, the lesson also watches the lobby every frame
	RunService.Heartbeat:Connect(function()
		local m = machine
		if m == nil then
			return
		end
		safely("tick", function()
			if holdUntil > 0 and os.clock() >= holdUntil then
				holdUntil = 0
				local p = practice
				if pendingLeave and p ~= nil then
					pendingLeave = false
					leaving = true
					p.leave(function()
						leaving = false
						refresh()
					end)
				end
				refresh()
			end
			local p = practice
			if m.current() == "gumballWalk" and not leaving and (p == nil or not p.isActive()) then
				local at = characterPosition()
				if at ~= nil then
					local machineAt = TutorialConfig.gumballMachine
					local dx, dz = at.X - (origin.X + machineAt.x), at.Z - (origin.Z + machineAt.z)
					if math.sqrt(dx * dx + dz * dz) <= TutorialConfig.gumballNearStuds then
						fire("nearMachine")
					end
				end
			end
			-- the Champions menu closing ends the claw / reveal screens
			local namespace = ReplicatedStorage:FindFirstChild("CVC_Champions")
			local open = namespace ~= nil and namespace:GetAttribute("MenuOpen") == true
			if menuWasOpen and not open then
				fire("menuClosed")
			end
			menuWasOpen = open
		end)
	end)

	local self = {} :: Handle

	self.handleLobby = function(u: any)
		if type(u) ~= "table" then
			return
		end
		safely("lobby", function()
			if u.kind == "profile" then
				freePull = u.freePullAvailable == true
				if machine ~= nil then
					machine.setFree(freePull)
					refresh()
				end
				if not startedOnce then
					startedOnce = true
					if Tutorial.isNew(u.hintsSeen) then
						start()
					end
				end
			elseif u.kind == "gacha" then
				fire("pulled")
			elseif u.kind == "countdown" and type(u.seconds) == "number" and u.seconds > 0 then
				fire("pad")
			elseif u.kind == "tutorial" and type(u.event) == "string" then
				if u.event == "gift" then
					giftCoins = if type(u.coins) == "number" then u.coins else 0
					if showingDone then
						refresh()
					end
				elseif practice ~= nil then
					practice.handleServer(u.event)
				end
			end
		end)
	end

	self.handleBattle = function(m: any)
		if
			type(m) == "table"
			and ((m.kind == "queue" and m.searching == true) or m.kind == "prep")
		then
			safely("battle", function()
				fire("pad")
			end)
		end
	end

	self.promptTriggered = function(promptName: string)
		if promptName == "GachaPrompt" then
			safely("prompt", function()
				fire("prompt")
			end)
		end
	end

	self.replay = function()
		safely("replay", start)
	end

	self.active = function(): boolean
		local m = machine
		return m ~= nil and not m.isFinished()
	end

	return self
end

return TutorialClient
