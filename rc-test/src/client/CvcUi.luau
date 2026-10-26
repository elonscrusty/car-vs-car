--!strict
-- Car VS Car screen pieces in the Kart Party look (KartStyle; KartSkin adds the gloss and the
-- pop-ins): words, buttons, a car's picture, and the car card with its 3 bars and numbers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Garage = require(Shared:WaitForChild("Garage"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Training = require(Shared:WaitForChild("Training"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))

local INK, WHITE = KartStyle.INK, KartStyle.WHITE

local CvcUi = {}

-- each bar's word and colour on the card
CvcUi.BAR_WORDS = { speed = "SPEED", turn = "TURNING", boost = "BOOST" }
CvcUi.BAR_COLORS = {
	speed = KartStyle.RED,
	turn = KartStyle.SKY,
	boost = KartStyle.YELLOW,
}

function CvcUi.corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

function CvcUi.rim(parent: Instance, thick: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or INK
	s.Thickness = thick
	s.Parent = parent
	return s
end

function CvcUi.label(parent: Instance, text: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = KartStyle.FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

function CvcUi.button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = KartStyle.FONT
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.Text = text
	b.Parent = parent
	CvcUi.corner(b, 0.3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.16, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	return b
end

-- a yellow ribbon title over a panel's top edge
function CvcUi.ribbon(panel: GuiObject, text: string): TextLabel
	local t = CvcUi.label(panel, text, INK)
	t.Name = "Ribbon"
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0)
	t.Size = UDim2.fromScale(0.6, 0.13)
	t.BackgroundColor3 = KartStyle.YELLOW
	t.BackgroundTransparency = 0
	t.ZIndex = 3
	CvcUi.corner(t, 0.3)
	CvcUi.rim(t, KartStyle.BUTTON_RIM)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = t
	return t
end

-- Big words in the middle of a ScreenGui: pop in, rise and fade.
function CvcUi.bigWords(gui: Instance, text: string, color: Color3, y: number?)
	local at = y or 0.4
	local w = CvcUi.label(gui, text, color)
	w.Name = "Kart_Words"
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Position = UDim2.fromScale(0.5, at)
	w.Size = UDim2.fromScale(0.6, 0.14)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 4
	s.Parent = w
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = w
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.3, function()
		TweenService:Create(w, TweenInfo.new(0.5), {
			Position = UDim2.fromScale(0.5, at - 0.12),
			TextTransparency = 1,
		}):Play()
		TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.delay(0.5, function()
			w:Destroy()
		end)
	end)
end

-- A ScreenGui over the popups for big words and confetti, with a Kart_Fall layer (returned
-- second) so the confetti falls under the words and cards.
function CvcUi.topGui(name: string, order: number, parent: Instance): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order
	gui.Parent = parent
	local fall = Instance.new("Frame")
	fall.Name = "Kart_Fall"
	fall.BackgroundTransparency = 1
	fall.Size = UDim2.fromScale(1, 1)
	fall.ZIndex = 0
	fall.Active = false
	fall.Parent = gui
	return gui, fall
end

function CvcUi.rarityColor(id: string): Color3
	local c = CarCatalog.rarity(id).color
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The car itself in a little window (the toy car the shop draws), front left, a bit above.
function CvcUi.carPic(parent: Instance, id: string): ViewportFrame
	local pic = Instance.new("ViewportFrame")
	pic.Name = "Car"
	pic:SetAttribute("NoKart", true) -- a picture: no gloss over it
	pic.BackgroundColor3 = CvcUi.rarityColor(id):Lerp(INK, 0.4)
	pic.Ambient = Color3.fromRGB(200, 200, 200)
	pic.LightColor = WHITE
	pic.Parent = parent
	CvcUi.corner(pic, 0.15)
	local car = CarCatalog.get(id)
	if car then
		local pieces = {}
		Garage.toyCar(
			Garage.adder(pieces),
			"Car",
			{ x = 0, y = 0, z = 0 },
			0,
			car.color,
			1,
			car.style
		)
		local model = Instance.new("Model")
		Garage.makeParts(pieces, model, CFrame.identity)
		model.Parent = pic
		local cf, size = model:GetBoundingBox()
		local cam = Instance.new("Camera")
		local d = size.Magnitude * 0.8
		cam.CFrame =
			CFrame.lookAt(cf.Position + Vector3.new(-d * 0.55, d * 0.4, -d * 0.7), cf.Position)
		cam.FieldOfView = 40
		cam.Parent = pic
		pic.CurrentCamera = cam
	end
	return pic
end

export type Bars = { frame: Frame, set: (car: CvcState.Car) -> () }

-- The 3 bars of a car, one row each: the word, the bar (filled to its value, a faint mark at the
-- car's top) and the number. set() moves the fills smoothly.
function CvcUi.bars(parent: Instance): Bars
	local frame = Instance.new("Frame")
	frame.Name = "Bars"
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local fills: { [string]: Frame } = {}
	local tops: { [string]: Frame } = {}
	local nums: { [string]: TextLabel } = {}
	for i, b in Training.BARS do
		local y = (i - 1) / 3
		local word = CvcUi.label(frame, CvcUi.BAR_WORDS[b], INK)
		word.Position = UDim2.fromScale(0, y + 0.03)
		word.Size = UDim2.fromScale(0.34, 0.27)
		word.TextXAlignment = Enum.TextXAlignment.Left
		local track = Instance.new("Frame")
		track.Name = "Track"
		track:SetAttribute("NoKart", true) -- (drawn here: no gloss on the bars)
		track.Position = UDim2.fromScale(0.36, y + 0.06)
		track.Size = UDim2.fromScale(0.44, 0.21)
		track.BackgroundColor3 = Color3.fromRGB(210, 216, 230)
		track.Parent = frame
		CvcUi.corner(track, 0.5)
		CvcUi.rim(track, 2)
		local top = Instance.new("Frame")
		top.Name = "Top"
		top:SetAttribute("NoKart", true)
		top.AnchorPoint = Vector2.new(0.5, 0)
		top.Size = UDim2.new(0, 3, 1, 0)
		top.BackgroundColor3 = INK
		top.BackgroundTransparency = 0.5
		top.BorderSizePixel = 0
		top.ZIndex = 3
		top.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill:SetAttribute("NoKart", true)
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = CvcUi.BAR_COLORS[b]
		fill.BorderSizePixel = 0
		fill.ZIndex = 2
		fill.Parent = track
		CvcUi.corner(fill, 0.5)
		local num = CvcUi.label(frame, "0", INK)
		num.Position = UDim2.fromScale(0.82, y + 0.03)
		num.Size = UDim2.fromScale(0.18, 0.27)
		num.TextXAlignment = Enum.TextXAlignment.Right
		fills[b], tops[b], nums[b] = fill, top, num
	end
	local function set(car: CvcState.Car)
		for _, b in Training.BARS do
			local v, top = CvcState.bar(car, b)
			local f = v / Training.MAX_BAR
			TweenService:Create(fills[b], TweenInfo.new(0.4, Enum.EasingStyle.Quart), {
				Size = UDim2.fromScale(math.clamp(f, 0, 1), 1),
			}):Play()
			tops[b].Position = UDim2.fromScale(top / Training.MAX_BAR, 0)
			tops[b].Visible = top < Training.MAX_BAR
			nums[b].Text = tostring(math.floor(v))
		end
	end
	return { frame = frame, set = set }
end

export type Card = { frame: Frame, set: (car: CvcState.Car) -> (), pic: ViewportFrame }

-- A car card: its picture, name and rarity on top, the 3 bars under. White with an ink rim (and
-- a rarity colour rim for rare and up).
function CvcUi.card(parent: Instance, car: CvcState.Car): Card
	local frame = Instance.new("Frame")
	frame.Name = "CarCard"
	frame.BackgroundColor3 = Color3.fromRGB(244, 247, 255)
	frame.Parent = parent
	CvcUi.corner(frame, 0.08)
	local rarity = CarCatalog.rarity(car.id)
	local edge = CvcUi.rim(frame, KartStyle.BUTTON_RIM)
	if rarity.id ~= "common" then
		edge.Color = CvcUi.rarityColor(car.id)
		edge.Thickness = 4
	end
	local pic = CvcUi.carPic(frame, car.id)
	pic.Position = UDim2.fromScale(0.05, 0.04)
	pic.Size = UDim2.fromScale(0.9, 0.42)
	local name = CvcUi.label(frame, CvcState.name(car.id), INK)
	name.Name = "CarName"
	name.Position = UDim2.fromScale(0.05, 0.47)
	name.Size = UDim2.fromScale(0.9, 0.11)
	local tag = CvcUi.label(frame, rarity.label, CvcUi.rarityColor(car.id):Lerp(INK, 0.45))
	tag.Name = "Rarity"
	tag.Position = UDim2.fromScale(0.05, 0.58)
	tag.Size = UDim2.fromScale(0.9, 0.07)
	local bars = CvcUi.bars(frame)
	bars.frame.Position = UDim2.fromScale(0.06, 0.66)
	bars.frame.Size = UDim2.fromScale(0.88, 0.31)
	bars.set(car)
	return { frame = frame, set = bars.set, pic = pic }
end

return CvcUi
