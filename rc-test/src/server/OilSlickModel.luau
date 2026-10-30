--!strict
-- Builds the oil slick puddle look (try A "Round Blob", carter 10-29) out of parts, from the numbers
-- in shared/OilSlick: a black wet puddle of flat discs, a rainbow shine swirl (a SurfaceGui with
-- ring outlines that carry a rainbow gradient, so no uploaded picture is needed) and glossy bubbles.
-- Looks only: it does nothing when a kart drives over it (the driving feel is locked). The client
-- grows the puddle (OilSlick.spread) and grows/pops the bubbles (OilSlick.bubbleSize); the bubbles
-- are named "Bubble1".."Bubble8" in OilSlick.BUBBLES order, each with Body, Shine and Rim parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OilSlick = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OilSlick"))

local OilSlickModel = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function still(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- at = the middle of the puddle on the floor; scale = studs per big unit (Mine.SCALE is 0.25).
function OilSlickModel.build(at: Vector3, scale: number): Model
	local S = scale
	local H = OilSlick.HEIGHT * S
	local x0, y0, z0 = at.X, at.Y, at.Z
	local model = Instance.new("Model")
	model.Name = "OilSlick"

	-- the puddle: one flat disc per lobe (Roblox cylinders lie along X, so turn 90 degrees)
	local black = rgb(OilSlick.COLOR)
	local first: BasePart? = nil
	for i, l in OilSlick.LOBES do
		local p = Instance.new("Part")
		p.Name = "Lobe" .. i
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(H, 2 * l.rz * S, 2 * l.rx * S)
		p.CFrame = CFrame.new(x0 + l.x * S, y0 + H / 2, z0 + l.z * S)
			* CFrame.Angles(0, l.rot, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		p.Color = black
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.35
		still(p)
		p.Parent = model
		first = first or p
	end
	model.PrimaryPart = first

	-- the rainbow shine: each sheet is a see-through square with ring outlines on top
	for i, sh in OilSlick.SHEETS do
		local p = Instance.new("Part")
		p.Name = "Sheen" .. i
		p.Size = Vector3.new(2 * sh.radius * S, 0.02 * S, 2 * sh.radius * S)
		p.CFrame = CFrame.new(x0 + sh.x * S, y0 + H + 0.01 * S * i, z0 + sh.z * S)
		p.Transparency = 1
		still(p)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20 / math.max(S, 0.05)
		gui.LightInfluence = 0
		gui.Brightness = 1.5
		gui.AlwaysOnTop = false
		gui.Parent = p
		local rainbow: { ColorSequenceKeypoint } = {}
		local n = #OilSlick.RAINBOW
		for k, c in OilSlick.RAINBOW do
			table.insert(rainbow, ColorSequenceKeypoint.new((k - 1) / n, rgb(c)))
		end
		table.insert(rainbow, ColorSequenceKeypoint.new(1, rgb(OilSlick.RAINBOW[1])))
		for r = 1, sh.rings do
			local f = (r + 1) / (sh.rings + 1) -- 0..1 across the sheet
			local ring = Instance.new("Frame")
			ring.Name = "Ring" .. r
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.Position =
				UDim2.fromScale(0.5 + (((r * 37) % 7) - 3) / 140, 0.5 + (((r * 53) % 7) - 3) / 140)
			ring.Size = UDim2.fromScale(f, f * (0.84 + ((r * 29) % 5) / 25))
			ring.BackgroundTransparency = 1
			ring.Rotation = (r * 71) % 180
			ring.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = ring
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 5 + ((r * 13) % 4) * 3
			stroke.Transparency = 0.35 + ((r * 7) % 3) * 0.08
			stroke.Parent = ring
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(rainbow)
			grad.Rotation = (r * 67) % 360
			grad.Parent = stroke
		end
		p.Parent = model
	end

	-- bubbles: dark glossy dome, a white glint, and a coloured ring round the foot
	for i, b in OilSlick.BUBBLES do
		local bx, bz = x0 + b.x * S, z0 + b.z * S
		local g = Instance.new("Model")
		g.Name = "Bubble" .. i
		local d = 2 * b.r * S
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(d, d * 0.78, d)
		body.CFrame = CFrame.new(bx, y0 + H + b.r * S * 0.25, bz)
		body.Color = Color3.fromRGB(26, 32, 66)
		body.Material = Enum.Material.Glass
		body.Reflectance = 0.4
		still(body)
		body.Parent = g
		local shine = Instance.new("Part")
		shine.Name = "Shine"
		shine.Shape = Enum.PartType.Ball
		shine.Size = Vector3.new(d * 0.2, d * 0.2, d * 0.2)
		shine.CFrame = CFrame.new(bx - b.r * S * 0.38, y0 + H + b.r * S * 0.85, bz + b.r * S * 0.35)
		shine.Color = Color3.new(1, 1, 1)
		shine.Material = Enum.Material.Neon
		still(shine)
		shine.Parent = g
		local rim = Instance.new("Part")
		rim.Name = "Rim"
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(0.02 * S, d * 1.3, d * 1.3)
		rim.CFrame = CFrame.new(bx, y0 + H + 0.005 * S, bz) * CFrame.Angles(0, 0, math.rad(90))
		rim.Color = rgb(OilSlick.RAINBOW[(b.hue + 1) % #OilSlick.RAINBOW + 1])
		rim.Material = Enum.Material.Neon
		rim.Transparency = 0.45
		still(rim)
		rim.Parent = g
		g.PrimaryPart = body
		g.Parent = model
	end

	local folder = workspace:FindFirstChild("OilSlicks")
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "OilSlicks"
		f.Parent = workspace
		folder = f
	end
	model.Parent = folder
	return model
end

return OilSlickModel
