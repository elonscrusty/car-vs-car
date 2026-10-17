--!strict
-- Level badge on a car: a small colored plate on the roof showing the level, plus a shinier
-- trim from level 4 (Metal), 7 (gold Metal) and 10 (Neon). Visual only: massless, no collisions.
-- Owned by the progression worker. CarBuilder calls `apply` after Appearance.apply.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressConfig = require(ReplicatedStorage.Shared.ProgressConfig)

local Badge = {}

local TIER_COLOR = {
	Color3.fromRGB(205, 127, 50), -- bronze plate (levels 1-3)
	Color3.fromRGB(205, 215, 230), -- silver (4-6)
	Color3.fromRGB(255, 210, 70), -- gold (7-9)
	Color3.fromRGB(60, 240, 255), -- cyan neon (10)
}

local function tierOf(level: number): number
	local tier = 1
	for _, from in ProgressConfig.TrimLevels do
		if level >= from then
			tier += 1
		end
	end
	return math.min(tier, #TIER_COLOR)
end

local function decor(
	model: Model,
	body: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = true -- stays anchored until launch, like the other car parts
	p.CFrame = body.CFrame * offset
	p:SetAttribute("CarIdx", body:GetAttribute("CarIdx"))
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	return p
end

function Badge.apply(model: Model, body: BasePart, level: number?)
	local lv = math.max(1, math.floor(level or 1))
	local tier = tierOf(lv)
	local color = TIER_COLOR[tier]
	local size = body.Size

	-- Roof plate with the level number.
	local side = math.clamp(math.min(size.X, size.Z) * 0.45, 1.2, 2.4)
	local plate = decor(
		model,
		body,
		"LevelBadge",
		Vector3.new(side, 0.15, side),
		CFrame.new(0, size.Y / 2 + 0.08, 0)
	)
	plate.Color = color
	plate.Material = if tier >= 4
		then Enum.Material.Neon
		elseif tier >= 2 then Enum.Material.Metal
		else Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.CanvasSize = Vector2.new(side * 50, side * 50)
	gui.Parent = plate
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(20, 20, 30)
	text.Text = tostring(lv)
	text.Parent = gui

	-- Trim band around the body: shinier with every tier.
	if tier >= 2 then
		local trim = decor(
			model,
			body,
			"LevelTrim",
			Vector3.new(size.X + 0.12, 0.25, size.Z * 0.92),
			CFrame.new(0, -size.Y * 0.1, 0)
		)
		trim.Color = color
		trim.Material = if tier >= 4 then Enum.Material.Neon else Enum.Material.Metal
		if tier >= 3 then
			-- Second, thin accent stripe.
			local accent = decor(
				model,
				body,
				"LevelAccent",
				Vector3.new(size.X + 0.14, 0.12, size.Z * 0.6),
				CFrame.new(0, size.Y * 0.2, 0)
			)
			accent.Color = color
			accent.Material = Enum.Material.Neon
		end
	end
end

return Badge
