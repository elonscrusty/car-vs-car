--!strict
-- Name pill and health bar floating above a car (BillboardGui). Server builds it, it replicates
-- to clients. Fixed pixel size, so it stays the same size on screen at any distance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudStyle = require(ReplicatedStorage.Shared.HudStyle)

local HpBar = {}

export type Bar = {
	set: (hp: number, maxHp: number) -> (),
	hide: () -> (),
}

local PILL_H = 24
local TRACK_H = 14

function HpBar.create(adornee: BasePart, label: string, height: number, color: Color3): Bar
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(150, PILL_H + TRACK_H + 4)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Parent = adornee

	local pill = Instance.new("Frame")
	pill.Name = "NamePill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.new(0.8, 0, 0, PILL_H)
	pill.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	pill.Parent = gui
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0.5, 0)
	pillCorner.Parent = pill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = color
	pillStroke.Thickness = 2
	pillStroke.Parent = pill

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 1)
	name.Text = label
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 16
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = pill

	local back = Instance.new("Frame")
	back.Name = "Track"
	back.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
	back.BorderSizePixel = 0
	back.Position = UDim2.new(0, 0, 0, PILL_H + 4)
	back.Size = UDim2.new(1, 0, 0, TRACK_H)
	back.Parent = gui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.5, 0)
	backCorner.Parent = back
	local backStroke = Instance.new("UIStroke")
	backStroke.Color = Color3.fromRGB(235, 240, 250)
	backStroke.Thickness = 2
	backStroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(HudStyle.hpColor(1))
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromOffset(2, 2)
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	local function set(hp: number, maxHp: number)
		local frac = HudStyle.fillSize(if maxHp > 0 then hp / maxHp else 0)
		fill.Size = UDim2.new(frac, -4 * frac, 1, -4)
		fill.BackgroundColor3 = Color3.fromRGB(HudStyle.hpColor(frac))
	end

	local function hide()
		gui.Enabled = false
	end

	return { set = set, hide = hide }
end

return HpBar
