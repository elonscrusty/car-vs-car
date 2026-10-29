--!strict
-- Car VS Car SMASH: what a kart holds, floating over it (carter 10-28: no weapon models on karts).
-- The server puts Weapon / Ammo attributes on every kart model (workspace Car_<id>, bots too);
-- this draws a small icon above each one that holds something, seen by everyone, with a little
-- ammo count, and hides it when the ammo runs out. Icons are SCREENS' (Ui/Icons, Hud.weaponIcon).
-- UI kit v41 look (shared/KitWorld): a round pink bubble with an ink rim and a top shine, the icon
-- in it (carter's 3D picture once uploaded, KitWorld.WEAPON_IMAGES; the drawn one until then),
-- and a yellow ammo coin with an ink rim.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ui = script.Parent:WaitForChild("Ui")
local Icons = require(Ui:WaitForChild("Icons"))
local Hud = require(Ui:WaitForChild("Screens"):WaitForChild("Hud"))
local Base = require(Ui:WaitForChild("Base"))
local KitWorld = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KitWorld"))

local Players = game:GetService("Players")
-- a phone (carter 10-29: too cluttered): smaller icons, near karts only; and on every screen none
-- over your own kart (KitWorld.iconShown: its weapon and ammo are on FIRE)
local PHONE = require(Ui:WaitForChild("Base")).phone()
local MINE = "Car_" .. tostring(Players.LocalPlayer.UserId)

local SIZE = if PHONE then 26 else 40 -- pixels
local INSET = math.floor(SIZE * 0.14) -- the icon sits this far inside the bubble
local function kitColor(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
local INK = kitColor(KitWorld.INK)
-- just over the roof, where the YOU tag sits (Main), then lifted a little more than its own
-- height on screen so it floats above the YOU / name tag and never off the top under the chase cam
local LIFT = 0.4 -- studs over the kart's middle (a kart is about 1.4 studs long)
local RAISE = 1.4 -- icon heights up, on screen

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function watch(model: Model)
	local gui: BillboardGui? = nil
	local shown = ""

	local function refresh()
		local w = model:GetAttribute("Weapon")
		local a = model:GetAttribute("Ammo")
		local name = if type(w) == "string" then w else ""
		local ammo = if type(a) == "number" then a else 0
		if not KitWorld.iconShown(w, a, model.Name == MINE) then
			if gui then
				gui.Enabled = false
			end
			return
		end
		local g = gui
		if g and g.Parent == nil then
			g, shown = nil, "" -- its body was rebuilt
		end
		if not g then
			local body = bodyOf(model)
			if not body then
				return
			end
			g = Instance.new("BillboardGui")
			g.Name = "WeaponIcon"
			g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- (the shine stays under the icon)
			g.Size = UDim2.fromOffset(SIZE, SIZE)
			-- Ui/Base sizes a drawing against its gui's design size (DW / DH)
			g:SetAttribute("DW", SIZE)
			g:SetAttribute("DH", SIZE)
			g.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
			g.SizeOffset = Vector2.new(0, RAISE)
			-- (not AlwaysOnTop: on carter's PC AlwaysOnTop billboards never drew)
			g.AlwaysOnTop = false
			g.MaxDistance = if PHONE then 40 else 1200
			g.ResetOnSpawn = false
			g.Adornee = body
			-- the bubble: pink, ink rim, a soft shine on its top half
			local bubble = Instance.new("Frame")
			bubble.Name = "Bubble"
			bubble.BorderSizePixel = 0
			bubble.BackgroundColor3 = Color3.new(1, 1, 1)
			bubble.Size = UDim2.fromScale(1, 1)
			bubble.ZIndex = 1
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = bubble
			local face = Instance.new("UIGradient")
			face.Color = ColorSequence.new(kitColor(KitWorld.PINK), kitColor(KitWorld.PINK_DEEP))
			face.Rotation = 90
			face.Parent = bubble
			local rim = Instance.new("UIStroke")
			rim.Color = INK
			rim.Thickness = KitWorld.ICON_RIM_PX
			rim.Parent = bubble
			bubble.Parent = g
			local shine = Instance.new("Frame")
			shine.Name = "Shine"
			shine.BorderSizePixel = 0
			shine.BackgroundColor3 = Color3.new(1, 1, 1)
			shine.BackgroundTransparency = 0.6
			shine.Position = UDim2.fromScale(0.18, 0.07)
			shine.Size = UDim2.fromScale(0.64, 0.34)
			shine.ZIndex = 2
			local shineRound = Instance.new("UICorner")
			shineRound.CornerRadius = UDim.new(0.5, 0)
			shineRound.Parent = shine
			shine.Parent = bubble
			-- the ammo coin: yellow, ink rim, an ink number
			local coin = Instance.new("TextLabel")
			coin.Name = "Ammo"
			coin.BorderSizePixel = 0
			coin.BackgroundColor3 = kitColor(KitWorld.GO)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Position = UDim2.fromScale(0.92, 0.9)
			coin.Size = UDim2.fromScale(KitWorld.COIN, KitWorld.COIN)
			coin.Font = Base.FONT
			coin.TextScaled = true
			coin.TextColor3 = INK
			coin.ZIndex = 6
			local coinRound = Instance.new("UICorner")
			coinRound.CornerRadius = UDim.new(0.5, 0)
			coinRound.Parent = coin
			local coinRim = Instance.new("UIStroke")
			coinRim.Color = INK
			coinRim.Thickness = 2
			coinRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			coinRim.Parent = coin
			coin.Parent = g
			-- on the car's body, like the YOU tag (that one draws on your own kart; Studio 10-29 saw
			-- this icon parented to the model draw over bots but not over your own kart)
			g.Parent = body
			gui = g
		end
		assert(g)
		local key = Hud.weaponIcon(name)
		if key ~= shown then
			local old = g:FindFirstChild("Icon")
			if old then
				old:Destroy()
			end
			local image = KitWorld.weaponImage(key)
			if image then
				local pic = Instance.new("ImageLabel")
				pic.Name = "Icon"
				pic.BackgroundTransparency = 1
				pic.ScaleType = Enum.ScaleType.Fit
				pic.Image = image
				pic.Position = UDim2.fromOffset(INSET, INSET)
				pic.Size = UDim2.fromOffset(SIZE - 2 * INSET, SIZE - 2 * INSET)
				pic.ZIndex = 3
				pic.Parent = g
			else
				Icons.make(g, key, INSET, INSET, SIZE - 2 * INSET, { z = 3 })
			end
			shown = key
		end
		local count = g:FindFirstChild("Ammo") :: TextLabel?
		if count then
			-- one shot left (a nuke) needs no number (and no coin)
			count.Text = if ammo > 1 then tostring(ammo) else ""
			count.Visible = ammo > 1
		end
		g.Enabled = true
	end

	-- (streaming: the kart can arrive before its parts; try again as they come)
	model.DescendantAdded:Connect(function(d: Instance)
		if (gui == nil or gui.Parent == nil) and d:IsA("BasePart") then
			refresh()
		end
	end)
	model:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	model:GetAttributeChangedSignal("Ammo"):Connect(refresh)
	refresh()
end

local function maybe(c: Instance)
	if c:IsA("Model") and string.sub(c.Name, 1, 4) == "Car_" then
		watch(c)
	end
end

workspace.ChildAdded:Connect(maybe)
for _, c in workspace:GetChildren() do
	maybe(c)
end
