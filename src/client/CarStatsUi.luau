--!strict
-- Four small stat bars (speed, weight, turn, HP) for a car list card. The fill numbers and the
-- "Fast, slippery" words come from the pure CarTraits module (CarTraitsConfig has the ranges).
-- One call from LobbyUi where the card is built: CarStatsUi.attach(card, stats).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarTraits = require(ReplicatedStorage.Shared.CarTraits)

local CarStatsUi = {}

local WIDTH, ROW_H, GAP, LETTER_W = 66, 9, 3, 12
local TRACK = Color3.fromRGB(30, 34, 64)
local ROWS: { { key: string, letter: string, color: Color3 } } = {
	{ key = "speed", letter = "S", color = Color3.fromRGB(60, 240, 255) },
	{ key = "weight", letter = "W", color = Color3.fromRGB(255, 210, 70) },
	{ key = "turn", letter = "T", color = Color3.fromRGB(70, 255, 140) },
	{ key = "hp", letter = "H", color = Color3.fromRGB(255, 70, 190) },
}

-- Draws the bars in the top-right corner of `card` and returns the holder frame. `stats` is a
-- CarConfig car. Safe to call with nil stats (draws nothing).
function CarStatsUi.attach(card: GuiObject, stats: any): Frame?
	if stats == nil then
		return nil
	end
	local bars = CarTraits.bars(stats)
	local holder = Instance.new("Frame")
	holder.Name = "CarStats"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(WIDTH, #ROWS * (ROW_H + GAP))
	holder.Position = UDim2.new(1, -(WIDTH + 8), 0, 10)
	holder.ZIndex = card.ZIndex + 1
	holder.Parent = card

	for i, row in ROWS do
		local y = (i - 1) * (ROW_H + GAP)
		local letter = Instance.new("TextLabel")
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromOffset(LETTER_W, ROW_H)
		letter.Position = UDim2.fromOffset(0, y)
		letter.Font = Enum.Font.FredokaOne
		letter.Text = row.letter
		letter.TextSize = 11
		letter.TextColor3 = row.color
		letter.ZIndex = holder.ZIndex
		letter.Parent = holder

		local track = Instance.new("Frame")
		track.BackgroundColor3 = TRACK
		track.BorderSizePixel = 0
		track.Size = UDim2.new(1, -LETTER_W, 0, ROW_H)
		track.Position = UDim2.fromOffset(LETTER_W, y)
		track.ZIndex = holder.ZIndex
		track.Parent = holder
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0.5, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = row.color
		fill.BorderSizePixel = 0
		-- never fully empty, so a low stat still shows a stub
		fill.Size = UDim2.fromScale(math.max(0.08, (bars :: any)[row.key]), 1)
		fill.ZIndex = holder.ZIndex + 1
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
	end
	return holder
end

-- The short words under the role line, like "Fast, slippery".
function CarStatsUi.words(stats: any): string
	return CarTraits.describe(stats)
end

return CarStatsUi
