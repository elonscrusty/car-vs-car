--!strict
-- What the first-time tutorial draws (carter's L11-L17): a SKIP pill that is there at once, one plain
-- text bubble NEXT TO the button it talks about (the middle of the screen stays clear), a pulsing
-- ring and a bobbing arrow on that button, a green check with a little confetti when a step is done,
-- and a black fade. Look only: the steps are Tutorial (pure), where a bubble stands is BubbleLayout
-- (pure), what the client does is TutorialClient.
--
-- The bubble is put INSIDE the screen of the button it points at (the Champions menus, the practice
-- controls): then both share one coordinate system whatever the device's screen insets are.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BubbleLayout = require(ReplicatedStorage.Shared.BubbleLayout)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local TutorialConfig = require(ReplicatedStorage.Shared.TutorialConfig)

local TutorialUi = {}

export type Ui = {
	setView: (view: Tutorial.View?) -> (), -- what to show now (nil hides the bubble)
	celebrate: () -> (), -- a step is done: green check + small confetti at the bubble
	setSkipShown: (shown: boolean) -> (),
	fade: (toBlack: boolean, seconds: number) -> (), -- yields until the fade is over
	destroy: () -> (),
}

-- The look matches carter's Champions menus (Theme.luau).
local NAVY = Color3.fromRGB(5, 23, 45)
local INK = Color3.fromRGB(2, 10, 20)
local WHITE = Color3.fromRGB(251, 253, 255)
local GOLD = Color3.fromRGB(255, 201, 35)
local GREEN = Color3.fromRGB(136, 244, 27)
local CYAN = Color3.fromRGB(35, 216, 255)
local RED = Color3.fromRGB(238, 28, 49)
local PURPLE = Color3.fromRGB(181, 57, 243)
local FONT = Font.fromEnum(Enum.Font.Bangers)
local CONFETTI = { GOLD, GREEN, CYAN, RED, PURPLE, WHITE }

-- ScreenGuis whose buttons a bubble may point at (looked up by the button's name).
local ROOTS = { "CVC_ChampionsHud", "CVC_Champions", "TutorialPractice", "SteerGui" }

local BASE_TEXT = 28 -- bubble text size at scale 1
local TOP_GAP = 60 -- a "top" bubble stands this far down (under SKIP)
local KEYS_GAP = 96 -- a "keys" bubble stands this far above the bottom edge
local LOOKUP_SECONDS = 0.12 -- how often the button is looked for again

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Is the button on screen right now (every parent shown, its screen on, and not collapsed)?
local function isShown(obj: GuiObject): boolean
	local size = obj.AbsoluteSize
	if size.X < 4 or size.Y < 4 then
		return false
	end
	local node: Instance? = obj
	while node ~= nil do
		if node:IsA("GuiObject") then
			if not (node :: GuiObject).Visible then
				return false
			end
		elseif node:IsA("ScreenGui") then
			return (node :: ScreenGui).Enabled
		end
		node = node.Parent
	end
	return false
end

function TutorialUi.new(onSkip: () -> ()): Ui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui: ScreenGui = make("ScreenGui", {
		Name = "CVC_Tutorial",
		ResetOnSpawn = false,
		DisplayOrder = 40,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- SKIP: visible at once, small, top middle
	local skip: TextButton = make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(176, 44),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Text = "Skip tutorial",
		FontFace = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		ZIndex = 50,
	}, gui)
	corner(skip, 22)
	stroke(skip, WHITE, 3)
	skip.Activated:Connect(function()
		onSkip()
	end)

	-- the black fade (portal in, yard out)
	local fadeFrame: Frame = make("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 100,
	}, gui)

	-- Everything that points at a button lives in `holder`; it moves to the button's own screen.
	local holder: Frame = make("Frame", {
		Name = "TutorialBubbleHost",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 900,
		Visible = false,
	}, gui)

	local ring: Frame = make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, holder)
	corner(ring, 14)
	local ringStroke = stroke(ring, GOLD, 4)

	local bubble: Frame = make("Frame", {
		Name = "Bubble",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	local bubbleCorner: UICorner = make("UICorner", { CornerRadius = UDim.new(0, 16) }, bubble)
	stroke(bubble, WHITE, 3)
	local pad: UIPadding = make("UIPadding", {}, bubble)
	local label: TextLabel = make("TextLabel", {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextSize = BASE_TEXT,
		TextColor3 = WHITE,
		TextWrapped = true,
		RichText = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
		ZIndex = 3,
	}, bubble)
	local labelLimit: UISizeConstraint =
		make("UISizeConstraint", { MaxSize = Vector2.new(420, 10000) }, label)

	local arrow: TextLabel = make("TextLabel", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = "▶",
		TextSize = 30,
		TextColor3 = GOLD,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0,
		Visible = false,
		ZIndex = 4,
	}, holder)

	-- the green check (two bars in a circle)
	local check: Frame = make("Frame", {
		Name = "Check",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, holder)
	corner(check, 30)
	stroke(check, INK, 4)
	local checkScale: UIScale = make("UIScale", { Scale = 1 }, check)
	for _, bar in
		{
			{ cx = 22, cy = 35, len = 20, rot = 45 }, -- the short arm, down to the right
			{ cx = 35, cy = 29, len = 36, rot = -50 }, -- the long arm, up to the right
		}
	do
		local b: Frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(bar.cx, bar.cy),
			Size = UDim2.fromOffset(bar.len, 8),
			Rotation = bar.rot,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 7,
		}, check)
		corner(b, 4)
	end

	-- ---------- state ----------
	local view: Tutorial.View? = nil
	local target: GuiObject? = nil -- the button the bubble stands next to
	local text = ""
	local mode = "none" -- "button" | "top" | "keys" | "none" (waiting for a button to appear)
	local lookupIn = 0
	local textSize = BASE_TEXT
	local t = 0
	local skipShown = true

	local function findShown(name: string): GuiObject?
		for _, rootName in ROOTS do
			local root = playerGui:FindFirstChild(rootName)
			if root ~= nil then
				local first = root:FindFirstChild(name, true)
				if first ~= nil then
					if first:IsA("GuiObject") and isShown(first) then
						return first
					end
					-- another object with the same name may be the one on screen
					for _, d in root:GetDescendants() do
						if d.Name == name and d:IsA("GuiObject") and isShown(d) then
							return d
						end
					end
				end
			end
		end
		return nil
	end

	-- Which button does this step point at right now, and what does the bubble say?
	local function resolve(v: Tutorial.View)
		if v.targets ~= nil then
			for _, option in v.targets do
				local g = findShown(option.find)
				if g ~= nil then
					target, text, mode = g, option.text, "button"
					return
				end
			end
			-- the screen with the button has not opened yet: no bubble until it has
			target, text, mode = nil, "", "none"
			return
		end
		if v.anchor == "keys" then
			target, text, mode = nil, v.text, "keys"
		elseif v.anchor ~= "top" then
			local g = findShown(v.anchor)
			if g ~= nil then
				target, text, mode = g, v.text, "button"
			else
				target, text, mode = nil, v.text, "top"
			end
		else
			target, text, mode = nil, v.text, "top"
		end
	end

	local function update(dt: number)
		t += dt
		local v = view
		if v == nil then
			return
		end
		lookupIn -= dt
		if lookupIn <= 0 or (target ~= nil and (target.Parent == nil or not isShown(target))) then
			lookupIn = LOOKUP_SECONDS
			resolve(v)
		end
		if mode == "none" or text == "" then
			holder.Visible = false
			return
		end

		-- the screen the bubble is drawn in: the button's own, else ours
		local host: ScreenGui = gui
		local tg = target
		if tg ~= nil then
			local g = tg:FindFirstAncestorWhichIsA("ScreenGui")
			if g ~= nil then
				host = g
			end
		end
		local screenSize = host.AbsoluteSize
		if screenSize.X < 50 or screenSize.Y < 50 then
			holder.Visible = false
			return
		end
		if holder.Parent ~= host then
			holder.Parent = host
		end
		holder.Visible = true

		local s = math.clamp(math.min(screenSize.X / 1000, screenSize.Y / 560), 0.7, 1.15)
		local newSize = math.floor(BASE_TEXT * s + 0.5)
		if newSize ~= textSize then
			textSize = newSize
			label.TextSize = newSize
			local padPx = math.floor(12 * s + 0.5)
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, padPx), UDim.new(0, padPx)
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, padPx + 4), UDim.new(0, padPx + 4)
			bubbleCorner.CornerRadius = UDim.new(0, math.floor(16 * s + 0.5))
			labelLimit.MaxSize = Vector2.new(math.min(screenSize.X * 0.44, 420 * s), 10000)
		end
		if label.Text ~= text then
			label.Text = text
		end
		local screen: BubbleLayout.Size = { w = screenSize.X, h = screenSize.Y }
		local absolute = bubble.AbsoluteSize
		local size: BubbleLayout.Size = {
			w = if absolute.X > 8 then absolute.X else 260,
			h = if absolute.Y > 8 then absolute.Y else 70,
		}

		local placement: BubbleLayout.Placement
		if tg ~= nil and mode == "button" then
			local rel = tg.AbsolutePosition - host.AbsolutePosition
			local rect: BubbleLayout.Rect =
				{ x = rel.X, y = rel.Y, w = tg.AbsoluteSize.X, h = tg.AbsoluteSize.Y }
			placement = BubbleLayout.place(rect, screen, size)
			-- the ring pulses around the button
			local beat = 0.5 + 0.5 * math.sin(t * 6)
			local grow = 6 + 2 * beat
			ring.Position = UDim2.fromOffset(rect.x - grow, rect.y - grow)
			ring.Size = UDim2.fromOffset(rect.w + grow * 2, rect.h + grow * 2)
			ringStroke.Transparency = 0.05 + 0.35 * beat
			ringStroke.Thickness = 3 + 2 * beat
			ring.Visible = true
			-- the arrow sits in the gap between the bubble and the button, pointing at the button
			local side = placement.side
			local dirX, dirY, turn = 0, 0, 0
			if side == "left" then
				dirX, turn = 1, 0
			elseif side == "right" then
				dirX, turn = -1, 180
			elseif side == "above" then
				dirY, turn = 1, 90
			else
				dirY, turn = -1, 270
			end
			local reach = BubbleLayout.gap / 2 + math.sin(t * 7) * 3
			arrow.Position = UDim2.fromOffset(
				placement.x + placement.tailX + dirX * reach,
				placement.y + placement.tailY + dirY * reach
			)
			arrow.Rotation = turn
			arrow.Size = UDim2.fromOffset(30 * s, 30 * s)
			arrow.TextSize = math.floor(30 * s + 0.5)
			arrow.Visible = true
		else
			ring.Visible = false
			arrow.Visible = false
			if mode == "keys" then
				placement = BubbleLayout.bottom(screen, size, KEYS_GAP * s)
			else
				placement = BubbleLayout.top(screen, size, TOP_GAP * s)
			end
		end
		bubble.Position =
			UDim2.fromOffset(math.floor(placement.x + 0.5), math.floor(placement.y + 0.5))
	end

	local conn = RunService.RenderStepped:Connect(update)

	local self = {} :: Ui

	self.setView = function(newView: Tutorial.View?)
		view = newView
		gui:SetAttribute("Step", if newView then newView.id else "")
		lookupIn = 0
		if newView == nil then
			target, text, mode = nil, "", "none"
			holder.Visible = false
			ring.Visible = false
			arrow.Visible = false
		else
			resolve(newView)
		end
	end

	-- confetti: small pieces thrown out of (cx, cy), they fall and fade
	local function burst(cx: number, cy: number)
		for i = 1, 18 do
			local angle = math.random() * math.pi * 2
			local dist = 50 + math.random() * 90
			local piece: Frame = make("Frame", {
				Name = "Confetti",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(cx, cy),
				Size = UDim2.fromOffset(6 + math.random() * 5, 6 + math.random() * 5),
				BackgroundColor3 = CONFETTI[i % #CONFETTI + 1],
				BorderSizePixel = 0,
				Rotation = math.random() * 360,
				ZIndex = 8,
			}, holder)
			TweenService
				:Create(
					piece,
					TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Position = UDim2.fromOffset(
							cx + math.cos(angle) * dist,
							cy + math.sin(angle) * dist + 40
						),
						Rotation = piece.Rotation + (math.random() - 0.5) * 720,
						BackgroundTransparency = 1,
					}
				)
				:Play()
			Debris:AddItem(piece, 1.1)
		end
	end

	self.celebrate = function()
		if not holder.Visible then
			return
		end
		local p = bubble.Position
		local cx, cy = p.X.Offset, p.Y.Offset
		check.Position = UDim2.fromOffset(cx, cy)
		check.Visible = true
		checkScale.Scale = 0.2
		TweenService:Create(
			checkScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		burst(cx, cy)
		task.delay(TutorialConfig.celebrateSeconds, function()
			check.Visible = false
		end)
	end

	self.setSkipShown = function(shown: boolean)
		skipShown = shown
		skip.Visible = shown
	end

	self.fade = function(toBlack: boolean, seconds: number)
		fadeFrame.Visible = true
		TweenService:Create(
			fadeFrame,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad),
			{ BackgroundTransparency = if toBlack then 0 else 1 }
		):Play()
		task.wait(seconds)
		if not toBlack then
			fadeFrame.Visible = false
		end
	end

	self.destroy = function()
		conn:Disconnect()
		gui:Destroy()
		holder:Destroy()
		local _ = skipShown
	end

	return self
end

return TutorialUi
