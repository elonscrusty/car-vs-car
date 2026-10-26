--!strict
-- The tag over a car (Car VS Car, carter 10-26): its name, its kind in the kind's colour and
-- three bars (SPD, TURN, BOOST) with numbers. Built from CarStats.view, so the same tag works
-- over a car on a station, on the line or in a crate card. Read-only: it only draws.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local CarStats = require(Shared:WaitForChild("CarStats"))
local L = require(Shared:WaitForChild("CarTagLayout"))

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
	l.TextStrokeTransparency = 0
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
	tag.Size = UDim2.fromOffset(L.WIDTH, L.HEIGHT)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	tag.Parent = adornee
	-- a dark plate behind everything, so white words read on grass, tile or sky
	local plate = Instance.new("Frame")
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
	plate.BackgroundTransparency = 0.25
	plate.BorderSizePixel = 0
	plate.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = plate
	label(
		tag,
		string.upper(if info then info.name else car.id),
		UDim2.fromScale(0.02, L.NAME.y),
		UDim2.fromScale(0.96, L.NAME.h),
		Color3.new(1, 1, 1)
	)
	local c = kind.color
	label(
		tag,
		kind.label,
		UDim2.fromScale(0.02, L.KIND.y),
		UDim2.fromScale(0.96, L.KIND.h),
		Color3.fromRGB(c[1], c[2], c[3])
	)
	for i, b in CarStats.view(car) do
		local y = L.barY(i)
		local w = label(
			tag,
			b.label,
			UDim2.fromScale(L.LABEL_X, y),
			UDim2.fromScale(L.LABEL_W, L.BAR_ROW),
			Color3.new(1, 1, 1)
		)
		w.TextXAlignment = Enum.TextXAlignment.Left
		local track = Instance.new("Frame")
		track.Position = UDim2.fromScale(L.TRACK_X, y + L.BAR_ROW * 0.12)
		track.Size = UDim2.fromScale(L.TRACK_W, L.BAR_ROW * 0.76)
		track.BackgroundColor3 = Color3.fromRGB(60, 60, 84)
		track.BorderSizePixel = 0
		track.Parent = tag
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(b.fill, 1)
		fill.BackgroundColor3 = BAR_COLORS[b.bar]
		fill.BorderSizePixel = 0
		fill.Parent = track
		-- a tick where this car's top is, so you see how far it can still grow
		local top = Instance.new("Frame")
		top.Position = UDim2.fromScale(math.clamp(b.cap / 100, 0, 1), -0.15)
		top.Size = UDim2.new(0, 2, 1.3, 0)
		top.BackgroundColor3 = Color3.new(1, 1, 1)
		top.BorderSizePixel = 0
		top.Parent = track
		local v = label(
			tag,
			tostring(b.value),
			UDim2.fromScale(L.VALUE_X, y),
			UDim2.fromScale(L.VALUE_W, L.BAR_ROW),
			Color3.new(1, 1, 1)
		)
		v.TextXAlignment = Enum.TextXAlignment.Right
	end
	return tag
end

return CarTag
