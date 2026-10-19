--!strict
-- First-time hints: a rounded banner at the top-center with big text, plus a bouncing arrow
-- over the thing to use (match pads / claw machine). One hint at a time, ~12 seconds, gone as
-- soon as the player does the thing. The rules (what, order, seen flags) live in shared/Hints.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Hints = require(game:GetService("ReplicatedStorage").Shared.Hints)

local HintUi = {}

export type Handle = {
	-- Replace/merge the saved flags the server sent (never un-sees a hint shown this session).
	loadSeen: (ids: { string }) -> (),
	-- Show this hint now if the player has not seen it yet (and flags are loaded).
	trigger: (id: string) -> (),
	-- The player did the thing: hide the hint (if it is the one showing) and save the flag.
	done: (id: string) -> (),
	loaded: () -> boolean,
	-- Aim phase started: after Hints.AimNudgeSeconds with no drag, pulse an arrow on the car.
	startAimNudge: (carPos: Vector3?) -> (),
	-- The player dragged / launched / the phase ended: remove the arrow and cancel the timer.
	stopAimNudge: () -> (),
}

local NAVY = Color3.fromRGB(10, 14, 32)
local GOLD = Color3.fromRGB(255, 210, 70)
local WHITE = Color3.new(1, 1, 1)
local BOUNCE = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function arrowLabel(parent: Instance, size: UDim2): TextLabel
	local a = Instance.new("TextLabel")
	a.BackgroundTransparency = 1
	a.Size = size
	a.Text = "▼"
	a.TextScaled = true
	a.Font = Enum.Font.FredokaOne
	a.TextColor3 = GOLD
	a.TextStrokeTransparency = 0
	a.Parent = parent
	return a
end

-- Where the world arrow floats: above the pads, or above the claw machine.
local function targetPoints(kind: string): { Vector3 }
	local points: { Vector3 } = {}
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby == nil then
		return points
	end
	if kind == "pad" then
		for _, child in lobby:GetChildren() do
			if child:IsA("BasePart") and string.match(child.Name, "^MatchPad%d+$") then
				table.insert(points, child.Position + Vector3.new(0, 5, 0))
			end
		end
	elseif kind == "claw" then
		local claw = lobby:FindFirstChild("ClawMachine")
		if claw and claw:IsA("Model") then
			local cf, size = claw:GetBoundingBox()
			table.insert(points, cf.Position + Vector3.new(0, size.Y / 2 + 4, 0))
		else
			local body = lobby:FindFirstChild("GachaBody")
			if body and body:IsA("BasePart") then
				table.insert(points, body.Position + Vector3.new(0, body.Size.Y / 2 + 4, 0))
			end
		end
	end
	return points
end

function HintUi.new(onSeen: (id: string) -> ()): Handle
	local seen: Hints.Seen = {}
	local isLoaded = false
	local current: string? = nil
	local token = 0
	local worldParts: { Instance } = {}
	local tweens: { Tween } = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "HintUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The Champions menus cover the screen: hide the hint line while one is open.
	local champions = game:GetService("ReplicatedStorage"):FindFirstChild("CVC_Champions")
	if champions then
		gui.Enabled = champions:GetAttribute("MenuOpen") ~= true
		champions:GetAttributeChangedSignal("MenuOpen"):Connect(function()
			gui.Enabled = champions:GetAttribute("MenuOpen") ~= true
		end)
	end

	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 76)
	banner.Size = UDim2.fromScale(0.4, 0.07)
	banner.BackgroundColor3 = NAVY
	banner.BackgroundTransparency = 0.1
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui
	corner(banner, 0.3)
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = WHITE
	bannerStroke.Thickness = 3
	bannerStroke.Parent = banner
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(220, 46)
	limit.MaxSize = Vector2.new(440, 62)
	limit.Parent = banner
	local scale = Instance.new("UIScale")
	scale.Parent = banner

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.94, 0.76)
	text.Position = UDim2.fromScale(0.03, 0.12)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.5
	text.Parent = banner
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 18
	textLimit.MaxTextSize = 26
	textLimit.Parent = text

	-- Arrow hanging under the banner (only for hints that point at something).
	local pointer = arrowLabel(banner, UDim2.fromOffset(40, 36))
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.new(0.5, 0, 1, 2)
	pointer.Visible = false

	local function clearWorld()
		for _, t in tweens do
			t:Cancel()
		end
		table.clear(tweens)
		for _, p in worldParts do
			p:Destroy()
		end
		table.clear(worldParts)
	end

	local function bounce(obj: Instance, props: { [string]: any })
		local t = TweenService:Create(obj, BOUNCE, props)
		t:Play()
		table.insert(tweens, t)
	end

	local function hide()
		token += 1
		current = nil
		banner.Visible = false
		clearWorld()
	end

	local function mark(id: string)
		if Hints.markSeen(seen, id) then
			onSeen(id)
		end
	end

	local function done(id: string)
		if current == id then
			hide()
		end
		mark(id)
	end

	local function show(id: string)
		hide()
		current = id
		local myToken = token
		text.Text = Hints.text(id)
		banner.Visible = true
		task.delay(7, function() -- small and short: it goes away on its own
			if token == myToken then
				banner.Visible = false
			end
		end)
		scale.Scale = 0.7
		TweenService:Create(scale, POP, { Scale = 1 }):Play()

		local kind = Hints.target(id)
		pointer.Visible = kind ~= nil
		if kind then
			bounce(pointer, { Position = UDim2.new(0.5, 0, 1, 12) })
			for _, pos in targetPoints(kind) do
				local anchor = Instance.new("Part")
				anchor.Name = "HintAnchor"
				anchor.Anchored = true
				anchor.CanCollide = false
				anchor.CanQuery = false
				anchor.CanTouch = false
				anchor.Transparency = 1
				anchor.Size = Vector3.new(0.2, 0.2, 0.2)
				anchor.Position = pos
				anchor.Parent = workspace
				local board = Instance.new("BillboardGui")
				board.Adornee = anchor
				board.AlwaysOnTop = true
				board.Size = UDim2.fromOffset(64, 64)
				board.StudsOffset = Vector3.new(0, 0, 0)
				board.LightInfluence = 0
				board.Parent = anchor
				local arrow = arrowLabel(board, UDim2.fromScale(1, 1))
				arrow.Position = UDim2.fromOffset(0, -6)
				bounce(arrow, { Position = UDim2.fromOffset(0, 10) })
				table.insert(worldParts, anchor)
			end
		end

		task.delay(Hints.ShowSeconds, function()
			if token == myToken then
				done(id) -- timed out: counts as shown
			end
		end)
	end

	-- Pulsing arrow over the player's car (own token so it never clashes with the banner hint).
	local nudgeToken = 0
	local nudgeAnchor: Part? = nil
	local nudgeTween: Tween? = nil

	local function stopAimNudge()
		nudgeToken += 1
		if nudgeTween then
			nudgeTween:Cancel()
			nudgeTween = nil
		end
		if nudgeAnchor then
			nudgeAnchor:Destroy()
			nudgeAnchor = nil
		end
	end

	local function startAimNudge(carPos: Vector3?)
		stopAimNudge()
		if carPos == nil then
			return
		end
		local pos: Vector3 = carPos
		nudgeToken += 1
		local myToken = nudgeToken
		local startedAt = os.clock()
		task.delay(Hints.AimNudgeSeconds, function()
			if nudgeToken ~= myToken or not Hints.aimNudgeDue(os.clock() - startedAt, false) then
				return
			end
			local anchor = Instance.new("Part")
			anchor.Name = "AimNudgeAnchor"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.Position = pos + Vector3.new(0, 7, 0)
			anchor.Parent = workspace
			local board = Instance.new("BillboardGui")
			board.Adornee = anchor
			board.AlwaysOnTop = true
			board.Size = UDim2.fromOffset(64, 64)
			board.LightInfluence = 0
			board.Parent = anchor
			local arrow = arrowLabel(board, UDim2.fromScale(1, 1))
			arrow.Position = UDim2.fromOffset(0, -6)
			local pulse = TweenService:Create(arrow, BOUNCE, { Position = UDim2.fromOffset(0, 12) })
			pulse:Play()
			nudgeAnchor = anchor
			nudgeTween = pulse
		end)
	end

	local handle: Handle = {
		startAimNudge = startAimNudge,
		stopAimNudge = stopAimNudge,
		loadSeen = function(ids: { string })
			for _, id in ids do
				if Hints.isKnown(id) then
					seen[id] = true
				end
			end
			isLoaded = true
			local c = current
			if c and not Hints.shouldShow(seen, c) then
				hide()
			end
		end,
		trigger = function(id: string)
			if isLoaded and current == nil and Hints.shouldShow(seen, id) then
				show(id)
			end
		end,
		done = done,
		loaded = function()
			return isLoaded
		end,
	}
	return handle
end

return HintUi
