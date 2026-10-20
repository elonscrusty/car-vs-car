--!strict
-- Small client pieces of the Car Battle Lobby: a glowing arrow that points new players at the PLAY
-- pads, a black fade into (and out of) the fight, and the rare gumball pulls shown in chat to
-- everyone. Look and feel only: the server decides everything.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Quality = require(script.Parent.Quality)

local LobbyClient = {}

local ORANGE = Color3.fromRGB(245, 130, 32)
local LIKE_REMINDER_SECONDS = 300 -- carter G46: reminder only
local NEWBIE_LEVEL = 1 -- the arrow shows at this level or lower, until the first pad
local ARROW_Z = 44 -- where the arrow floats: on the front path, between the spawn and the pads
local FADE_IN = 0.9

-- An arrow made of a shaft and a head, built from parts, pointing at -Z (toward the pads).
local function buildArrow(origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PlayArrow"
	local function piece(name: string, size: Vector3, offset: Vector3, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = ORANGE
		p.CFrame = CFrame.new(origin + offset)
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local shaft = piece("Shaft", Vector3.new(2.4, 1, 6), Vector3.new(0, 0, 3))
	model.PrimaryPart = shaft
	-- the head: a square turned 45 degrees, its corner points at -Z
	local head = piece("Head", Vector3.new(5, 1, 5), Vector3.new(0, 0, -2.2))
	head.CFrame = head.CFrame * CFrame.Angles(0, math.pi / 4, 0)
	-- a label that says what to do
	local anchor = piece("LabelAnchor", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 4.5, 2))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 28
	text.Text = "STEP ON A PAD!"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(37, 141, 221)
	text.Parent = gui
	return model
end

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
	local origin: Vector3 = LobbyConfig.Lobby.origin

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

	-- arrow for new players: bobs up and down, gone for good after the first pad
	local arrow: Model? = nil
	local arrowBase: CFrame? = nil
	local done = false
	local function wantArrow(): boolean
		local level = player:GetAttribute("PlayerLevel")
		return not done and (type(level) ~= "number" or level <= NEWBIE_LEVEL)
	end
	local function showArrow()
		if arrow == nil and wantArrow() then
			arrow = buildArrow(origin + Vector3.new(LobbyLayout.spawn.x, 7, ARROW_Z))
			arrow.Parent = workspace
			arrowBase = arrow:GetPivot()
		end
	end
	local function hideArrow()
		if arrow then
			arrow:Destroy()
			arrow = nil
			arrowBase = nil
		end
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
		if arrow and arrowBase then
			arrow:PivotTo(
				arrowBase + Vector3.new(0, math.sin(t * 3) * 0.8, math.sin(t * 1.5) * 1.5)
			)
		end
	end)
	task.delay(2, showArrow)
	player:GetAttributeChangedSignal("PlayerLevel"):Connect(function()
		if not wantArrow() then
			hideArrow()
		end
	end)

	remotes.BattleUpdate.OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.kind == "queue" and m.searching == true then
			done = true -- stepped on a pad: the arrow has done its job
			hideArrow()
		elseif m.kind == "prep" or m.kind == "end" then
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

	remotes.LobbyUpdate.OnClientEvent:Connect(function(u: any)
		if type(u) == "table" and u.kind == "announce" and type(u.text) == "string" then
			say(u.text)
		end
	end)
end

return LobbyClient
