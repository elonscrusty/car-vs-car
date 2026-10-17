--!strict
-- How one car LOOKS beyond its base stats: owner-chosen paint and sticker (paint shop) and the level badge.
-- CarBuilder calls `apply` once after building the body. Visual only: never touch physics or mass here.
-- The paint shop worker owns the paint/sticker half, the progression worker owns the badge half (Badge.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaintConfig = require(ReplicatedStorage.Shared.PaintConfig)

export type Appearance = {
	level: number?, -- car level, 1 and up (progression)
	paintColor: Color3?, -- body color override (paint shop)
	sticker: string?, -- sticker id (paint shop)
}

local Appearance = {}

local DARK = Color3.fromRGB(35, 35, 40)

-- Wheels, windows (Cabin is tinted dark), marker and per-type gear (bumper, ramp, spikes) keep their look.
local function paintBody(model: Model, body: BasePart, color: Color3)
	body.Color = color
	local cabin = model:FindFirstChild("Cabin")
	if cabin and cabin:IsA("BasePart") then
		cabin.Color = color:Lerp(DARK, 0.5)
	end
	-- A car with a real model (see CarBuilder) paints the whole mesh.
	local visual = model:FindFirstChild("Visual")
	if visual and visual:IsA("BasePart") then
		visual.Color = color
	end
end

local function addSticker(body: BasePart, text: string)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sticker"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.45, 0.8)
		label.Position = UDim2.fromScale(0.275, 0.1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
	end
end

-- Paints/decorates `model` (its heavy part is `body`). Safe to call with nil.
function Appearance.apply(model: Model, body: BasePart, look: Appearance?)
	if look == nil then
		return
	end
	if look.paintColor then
		paintBody(model, body, look.paintColor)
	end
	local sticker = PaintConfig.sticker(look.sticker)
	if sticker then
		addSticker(body, sticker.text)
	end
end

return Appearance
