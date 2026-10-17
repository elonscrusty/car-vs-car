--!strict
-- Health bar floating above a car (BillboardGui). Server builds it, it replicates to clients.

local HpBar = {}

export type Bar = {
	set: (hp: number, maxHp: number) -> (),
	hide: () -> (),
}

function HpBar.create(adornee: BasePart, label: string, height: number, color: Color3): Bar
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Parent = adornee

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Text = label
	name.TextColor3 = color
	name.TextStrokeTransparency = 0
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.Parent = gui

	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Position = UDim2.new(0, 0, 0, 18)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromOffset(2, 2)
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.Parent = back

	local function set(hp: number, maxHp: number)
		local frac = math.clamp(hp / maxHp, 0, 1)
		fill.Size = UDim2.new(frac, -4 * frac, 1, -4)
		fill.BackgroundColor3 =
			Color3.fromRGB(255 * (1 - frac) + 80 * frac, 220 * frac + 40 * (1 - frac), 60)
	end

	local function hide()
		gui.Enabled = false
	end

	return { set = set, hide = hide }
end

return HpBar
