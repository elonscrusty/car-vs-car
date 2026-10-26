--!strict
-- The tag over a car (Car VS Car, carter 10-26): its name, its kind in the kind's colour and
-- three bars (SPD, TURN, BOOST) with numbers. Built from CarStats.view, so the same tag works
-- over a car on a station, on the line or in a crate card. Read-only: it only draws.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local CarStats = require(Shared:WaitForChild("CarStats"))

local CarTag = {}

local BAR_COLORS = {
	speed = Color3.fromRGB(255, 120, 60),
	turn = Color3.fromRGB(70, 190, 255),
	boost = Color3.fromRGB(255, 210, 50),
}

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, color: Color3)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = parent
	return l
end

-- A tag for `car` (a garage entry: uid, id, speed, turn, boost), hung from `adornee`. Call
-- again with new numbers to refresh it (the old tag of that name is replaced).
function CarTag.make(
	adornee: BasePart,
	car: { uid: string, id: string, speed: number, turn: number, boost: number }
): BillboardGui
	local old = adornee:FindFirstChild("CarTag")
	if old then
		old:Destroy()
	end
	local info = CarCatalog.get(car.id)
	local kind = CarCatalog.rarity(car.id)
	local tag = Instance.new("BillboardGui")
	tag.Name = "CarTag"
	tag.Size = UDim2.fromOffset(170, 78)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	tag.MaxDistance = 60
	tag.LightInfluence = 0
	tag.Parent = adornee
	label(
		tag,
		string.upper(if info then info.name else car.id),
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0.3),
		Color3.new(1, 1, 1)
	)
	local c = kind.color
	label(
		tag,
		kind.label,
		UDim2.fromScale(0, 0.3),
		UDim2.fromScale(1, 0.18),
		Color3.fromRGB(c[1], c[2], c[3])
	)
	for i, b in CarStats.view(car) do
		local y = 0.5 + (i - 1) * 0.17
		label(tag, b.label, UDim2.fromScale(0, y), UDim2.fromScale(0.26, 0.15), Color3.new(1, 1, 1))
		local track = Instance.new("Frame")
		track.Position = UDim2.fromScale(0.28, y + 0.02)
		track.Size = UDim2.fromScale(0.48, 0.11)
		track.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		track.BorderSizePixel = 0
		track.Parent = tag
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(b.fill, 1)
		fill.BackgroundColor3 = BAR_COLORS[b.bar]
		fill.BorderSizePixel = 0
		fill.Parent = track
		label(
			tag,
			tostring(b.value),
			UDim2.fromScale(0.78, y),
			UDim2.fromScale(0.22, 0.15),
			Color3.new(1, 1, 1)
		)
	end
	return tag
end

return CarTag
