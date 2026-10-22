--!strict
-- On-screen words: track buttons, timer, speed, drift score, short messages.

local Players = game:GetService("Players")

export type Hud = {
	gui: ScreenGui,
	setActiveTrack: (index: number) -> (),
	setTimer: (text: string) -> (),
	setSpeed: (n: number) -> (),
	setDrift: (chain: number, total: number, visible: boolean) -> (),
	flash: (text: string) -> (),
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
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = parent
	return l
end

function Hud.new(gui: ScreenGui, trackLabels: { string }, onTrack: (index: number) -> ()): Hud
	local buttons: { TextButton } = {}
	local row = Instance.new("Frame")
	row.Name = "TrackRow"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0.03)
	row.Size = UDim2.fromScale(0.5, 0.1)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row
	for i, text in trackLabels do
		local b = Instance.new("TextButton")
		b.Name = "Track" .. i
		b.Size = UDim2.fromScale(0.3, 1)
		b.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		b.BackgroundTransparency = 0.25
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = `{i}  {text}`
		b.AutoButtonColor = true
		b.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = b
		b.Activated:Connect(function()
			onTrack(i)
		end)
		table.insert(buttons, b)
	end

	local timer = label(
		gui,
		"Timer",
		Vector2.new(0, 0),
		UDim2.fromScale(0.02, 0.16),
		UDim2.fromScale(0.24, 0.14)
	)
	timer.TextXAlignment = Enum.TextXAlignment.Left
	timer.TextYAlignment = Enum.TextYAlignment.Top

	local speed = label(
		gui,
		"Speed",
		Vector2.new(0.5, 1),
		UDim2.fromScale(0.5, 0.9),
		UDim2.fromScale(0.12, 0.06)
	)
	speed.TextTransparency = 0.2

	local drift = label(
		gui,
		"Drift",
		Vector2.new(0.5, 0),
		UDim2.fromScale(0.5, 0.15),
		UDim2.fromScale(0.34, 0.1)
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

	local flashId = 0
	local hud = {} :: Hud
	hud.gui = gui

	function hud.setActiveTrack(index: number)
		for i, b in buttons do
			b.BackgroundColor3 = if i == index
				then Color3.fromRGB(235, 120, 40)
				else Color3.fromRGB(40, 40, 46)
		end
	end

	function hud.setTimer(text: string)
		timer.Text = text
	end

	function hud.setSpeed(n: number)
		speed.Text = tostring(math.floor(n + 0.5))
	end

	function hud.setDrift(chain: number, total: number, visible: boolean)
		drift.Visible = visible
		if chain > 0 then
			drift.Text = `DRIFT  {math.floor(chain)}`
		else
			drift.Text = `SCORE  {math.floor(total)}`
		end
	end

	function hud.flash(text: string)
		flashId += 1
		local mine = flashId
		msg.Text = text
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
