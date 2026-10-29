--!strict
-- Car VS Car SMASH: what a kart holds, floating over it (carter 10-28: no weapon models on karts).
-- The server puts Weapon / Ammo attributes on every kart model (workspace Car_<id>, bots too);
-- this draws a small icon above each one that holds something, seen by everyone, with a little
-- ammo count, and hides it when the ammo runs out. Icons are SCREENS' (Ui/Icons, Hud.weaponIcon).
local Ui = script.Parent:WaitForChild("Ui")
local Icons = require(Ui:WaitForChild("Icons"))
local Hud = require(Ui:WaitForChild("Screens"):WaitForChild("Hud"))

local SIZE = 40 -- pixels
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
		if name == "" or ammo <= 0 then
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
			g.Size = UDim2.fromOffset(SIZE, SIZE)
			-- Ui/Base sizes a drawing against its gui's design size (DW / DH)
			g:SetAttribute("DW", SIZE)
			g:SetAttribute("DH", SIZE)
			g.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
			g.SizeOffset = Vector2.new(0, RAISE)
			-- (not AlwaysOnTop: on carter's PC AlwaysOnTop billboards never drew)
			g.AlwaysOnTop = false
			g.MaxDistance = 1200
			g.ResetOnSpawn = false
			g.Adornee = body
			local count = Instance.new("TextLabel")
			count.Name = "Ammo"
			count.BackgroundTransparency = 1
			count.AnchorPoint = Vector2.new(1, 1)
			count.Position = UDim2.fromScale(1.15, 1.1)
			count.Size = UDim2.fromOffset(18, 18)
			count.Font = Enum.Font.LuckiestGuy
			count.TextScaled = true
			count.TextColor3 = Color3.new(1, 1, 1)
			count.TextStrokeTransparency = 0.2
			count.ZIndex = 6
			count.Parent = g
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
			Icons.make(g, key, 0, 0, SIZE, { z = 3 })
			shown = key
		end
		local count = g:FindFirstChild("Ammo") :: TextLabel?
		if count then
			-- one shot left (a nuke) needs no number
			count.Text = if ammo > 1 then tostring(ammo) else ""
		end
		g.Enabled = true
	end

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
