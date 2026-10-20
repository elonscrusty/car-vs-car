--!strict
-- Small client pieces of the Car Battle Lobby: a black fade into (and out of) the fight, the turning
-- PLAY pad rings, the far scenery cut on a slow phone, a plain like reminder, and the rare gumball
-- pulls shown at the top of everyone's screen. The first-time guide (green line, blue portal) is
-- TutorialClient. Look and feel only: the server decides everything.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local LobbyCars = require(ReplicatedStorage.Shared.LobbyCars)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Quality = require(script.Parent.Quality)
-- The rare-pull message is a nicety: if it cannot load, the rest of the lobby client still starts.
local loaded, RareBanner: any = pcall(require, script.Parent.RareBanner)
if not loaded then
	warn("[LobbyClient] rare pull banner not loaded: " .. tostring(RareBanner))
	RareBanner = nil
end

local LobbyClient = {}

local ORANGE = Color3.fromRGB(245, 130, 32)
local LIKE_REMINDER_SECONDS = 300 -- carter G46: reminder only
local FADE_IN = 0.9
local GOLD_RGB = { 255, 205, 64 }

local function say(text: string)
	local ok = pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = if channels then channels:FindFirstChild("RBXGeneral") else nil
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(text)
		else
			error("no chat channel")
		end
	end)
	if not ok then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = ORANGE })
		end)
	end
end

function LobbyClient.start()
	local player = Players.LocalPlayer
	local remotes = Remotes.get()

	-- fade layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyFade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	local black = Instance.new("Frame")
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundTransparency = 1
	black.Active = false
	black.Parent = gui
	local function fadeIn() -- black -> clear
		black.BackgroundTransparency = 0
		TweenService:Create(
			black,
			TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	-- Things the server tagged "LobbySpin" (the pad rings) turn on this screen only, so the server
	-- does not send their position all the time. Attributes: SpinSpeed (rad/s), SpinCenter.
	local spinning: { [Instance]: CFrame } = {}
	local function addSpin(inst: Instance)
		if inst:IsA("Model") then
			spinning[inst] = inst:GetPivot()
		end
	end
	for _, inst in CollectionService:GetTagged("LobbySpin") do
		addSpin(inst)
	end
	CollectionService:GetInstanceAddedSignal("LobbySpin"):Connect(addSpin)
	CollectionService:GetInstanceRemovedSignal("LobbySpin"):Connect(function(inst: Instance)
		spinning[inst] = nil
	end)

	local t = 0
	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		for inst, base in spinning do
			local speed = inst:GetAttribute("SpinSpeed")
			if inst:IsA("Model") and type(speed) == "number" then
				inst:PivotTo(base * CFrame.Angles(0, t * speed, 0))
			end
		end
	end)

	remotes.BattleUpdate.OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.kind == "prep" or m.kind == "end" then
			fadeIn() -- into the fight, and back out of it
		end
	end)

	-- A slow phone cuts the far trees first (carter): only on this player's screen, only once.
	task.spawn(function()
		while true do
			task.wait(3)
			if Quality.level() >= 2 then
				local lobby = workspace:FindFirstChild("Lobby")
				local far = if lobby then lobby:FindFirstChild("FarScenery") else nil
				if far then
					far:Destroy()
				end
				-- lights cost the most on a weak phone: turn the lobby's point lights off too
				if lobby then
					for _, d in lobby:GetDescendants() do
						if d:IsA("PointLight") or d:IsA("SpotLight") then
							d.Enabled = false
						end
					end
				end
				return
			end
		end
	end)

	-- a plain reminder to like the game, once per visit, never a reward and never a pop-up
	task.delay(LIKE_REMINDER_SECONDS, function()
		say("Having fun? Tap the thumbs up on the game page!")
	end)

	-- a rare pull (Epic or Legendary) from the gumball machine: a small message at the top, for everyone
	local made, banner: any = false, nil
	if RareBanner ~= nil then
		made, banner = pcall(RareBanner.new)
		if not made then
			warn("[LobbyClient] rare pull banner not built: " .. tostring(banner))
		end
	end
	remotes.LobbyUpdate.OnClientEvent:Connect(function(u: any)
		if made and type(u) == "table" and u.kind == "announce" and type(u.text) == "string" then
			local rgb = if type(u.carId) == "string"
				then LobbyCars.rarityColor(u.carId)
				else GOLD_RGB
			pcall(banner.show, u.text, rgb)
		end
	end)
end

return LobbyClient
