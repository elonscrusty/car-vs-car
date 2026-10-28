--!strict
-- On-screen words: track buttons, timer, speed, drift score, short messages.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

export type Hud = {
	gui: ScreenGui,
	setActiveTrack: (index: number) -> (),
	setTimer: (text: string) -> (),
	setSpeed: (n: number) -> (),
	setDrift: (chain: number, total: number, visible: boolean, combo: number?) -> (),
	popScore: (points: number) -> (),
	flash: (text: string, gold: boolean?) -> (), -- gold: the big finish words
	setRace: (on: boolean) -> (), -- server race: no speed or plot word, just place and lap
}

local Hud = {}

local function label(
	parent: Instance,
	name: string,
	anchor: Vector2,
	pos: UDim2,
	size: UDim2
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = anchor
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = parent
	return l
end

-- The top row names the plot being driven (plots are picked by walking to them in the lobby).
function Hud.new(gui: ScreenGui, trackLabels: { string }): Hud
	local buttons: { TextLabel } = {}
	local row = Instance.new("Frame")
	row.Name = "TrackRow"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 64) -- below the Roblox top bar (58 px)
	row.Size = UDim2.fromScale(0.44, 0.1) -- clear of the timer (left) and CAM / VIEW / SIZE (right)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row
	-- one word: what to do here (carter: "DRIVE!" / "BUILD!", not names)
	local GOAL: { [string]: string } = { DRIFT = "DRIFT!", RACE = "RACE!", SHOW = "DRIVE!" } -- (rocks are gone)
	for i, text in trackLabels do
		local b = Instance.new("TextLabel")
		b.Name = "Track" .. i
		b.Size = UDim2.fromScale(0.23, 1)
		b.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		b.BackgroundTransparency = 0.25
		b.Font = Enum.Font.LuckiestGuy
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = GOAL[text] or text
		b.Visible = false
		b.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = b
		table.insert(buttons, b)
	end

	local timer = label(
		gui,
		"Timer",
		Vector2.new(0, 0),
		UDim2.new(0.02, 0, 0, 64),
		UDim2.fromScale(0.24, 0.14)
	)
	timer.TextXAlignment = Enum.TextXAlignment.Left
	timer.TextYAlignment = Enum.TextYAlignment.Top
	-- one word size for 1, 2 or 3 lines, never wrapped (it jumped between "LAP 1/1 0:08.7" on
	-- one line and on two, phone 10-28): a set size from the box's height, not TextScaled (a size
	-- cap read the box before it had a size and stuck at 8, Studio pr816)
	timer.TextScaled = false
	timer.TextWrapped = false
	timer.RichText = true -- (the place line is gold, Main.client)
	local function fitTimer()
		local h = timer.AbsoluteSize.Y
		timer.TextSize = if h > 0 then math.clamp(math.floor(h / 3.3), 14, 40) else 18
	end
	timer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTimer)
	fitTimer()

	-- top right, under the CAM / VIEW / SIZE buttons, so it never sits on the car
	local speed = label(
		gui,
		"Speed",
		Vector2.new(1, 0),
		UDim2.new(0.98, 0, 0.12, 68), -- = HudLayout "Speed"
		UDim2.fromScale(0.1, 0.05)
	)
	speed.TextTransparency = 0.2

	local drift = label(
		gui,
		"Drift",
		Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0.12, 72), -- under the plot buttons (= HudLayout "DriftScore")
		UDim2.fromScale(0.32, 0.1)
	)
	drift.TextColor3 = Color3.fromRGB(255, 205, 80)
	drift.Visible = false

	local msg = label(
		gui,
		"Message",
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.32),
		UDim2.fromScale(0.5, 0.14)
	)
	msg.TextTransparency = 1
	msg.TextStrokeTransparency = 1
	-- over the buttons (AUTO GAS sat on the finish time, phone 10-28)
	msg.ZIndex = 10

	-- the big number that pops up when a slide ends
	local pop = label(
		gui,
		"DriftPop",
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.45),
		UDim2.fromScale(0.5, 0.16)
	)
	pop.TextColor3 = Color3.fromRGB(255, 205, 80)
	pop.TextTransparency = 1
	pop.TextStrokeTransparency = 1
	local popScale = Instance.new("UIScale")
	popScale.Parent = pop

	local flashId = 0
	local hud = {} :: Hud
	hud.gui = gui

	local inRace = false -- a server race: the plot word stays hidden
	function hud.setActiveTrack(index: number)
		for i, b in buttons do
			b.Visible = i == index and not inRace
			b.BackgroundColor3 = Color3.fromRGB(235, 120, 40)
		end
	end

	function hud.setRace(on: boolean)
		if on == inRace then
			return
		end
		inRace = on
		speed.Visible = not on
		for _, b in buttons do
			if on then
				b.Visible = false
			end
		end
	end

	function hud.setTimer(text: string)
		fitTimer()
		timer.Text = text
	end

	function hud.setSpeed(n: number)
		speed.Text = `{math.floor(n + 0.5)} MPH`
	end

	function hud.setDrift(chain: number, total: number, visible: boolean, combo: number?)
		drift.Visible = visible
		if chain > 0 then
			local c = combo or 1
			drift.Text = if c > 1
				then `DRIFT  {math.floor(chain)}  x{c}`
				else `DRIFT  {math.floor(chain)}`
		else
			drift.Text = `SCORE  {math.floor(total)}`
		end
	end

	local popId = 0
	function hud.popScore(points: number)
		popId += 1
		local mine = popId
		pop.Text = `+{math.floor(points)}`
		pop.TextTransparency = 0
		pop.TextStrokeTransparency = 0.3
		popScale.Scale = 0.5
		TweenService:Create(
			popScale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.3 }
		):Play()
		task.delay(1.4, function()
			if mine == popId then
				TweenService:Create(pop, TweenInfo.new(0.5), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
		end)
	end

	function hud.flash(text: string, gold: boolean?)
		flashId += 1
		local mine = flashId
		msg.Text = text
		-- (white FINISH! on the light grey walls hardly showed: gold, phone 10-28)
		msg.TextColor3 = if gold
			then Color3.fromRGB(255, 205, 40)
			else Color3.fromRGB(255, 255, 255)
		-- the big FINISH! in the middle; the small words (BACK ON TRACK, LAP 2/3) higher and
		-- smaller, over the sky and not the road ahead (Studio batch-2035 6)
		msg.Position = UDim2.fromScale(0.5, if gold then 0.32 else 0.28)
		msg.Size = UDim2.fromScale(0.5, if gold then 0.14 else 0.08)
		msg.TextTransparency = 0
		msg.TextStrokeTransparency = 0.5
		task.delay(1.6, function()
			if mine == flashId then
				msg.TextTransparency = 1
				msg.TextStrokeTransparency = 1
			end
		end)
	end

	return hud
end

function Hud.createGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "RCControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return Hud
