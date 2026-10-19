--!strict
-- The fight stadium: tiered stands with a seated blocky crowd, a striped fence, light towers and
-- a bright ground around the flat floor. Looks only: nothing here is solid.

local ArenaStadium = {}

local SEGMENTS = 40
local TIERS = 4
local PER_SEAT = 3
local TIER_DEPTH = 7
local TIER_RISE = 3.2

local SHIRTS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(120, 230, 110),
	Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 50),
}
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function ArenaStadium.build(model: Model, origin: Vector3, arenaCfg: any)
	local folder = Instance.new("Folder")
	folder.Name = "Stadium"
	folder.Parent = model
	local rng = Random.new(7)
	local rimR = arenaCfg.rimRadius
	local FIRST_R = rimR + 12

	-- Bright ground all around the stands.
	local ground = part(
		folder,
		"Ground",
		Vector3.new(2, 380, 380),
		CFrame.new(origin + Vector3.new(0, -1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(110, 205, 120),
		false
	)
	ground.Shape = Enum.PartType.Cylinder

	-- A striped fence between the floor and the first row (not solid: a car that goes off still falls out).
	local segW = 2 * math.pi * (FIRST_R - 3) / SEGMENTS * 1.03
	for i = 0, SEGMENTS - 1 do
		local phi = i / SEGMENTS * math.pi * 2
		local base = CFrame.new(origin) * CFrame.Angles(0, phi, 0)
		local fence = if i % 2 == 0
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(235, 60, 60)
		part(
			folder,
			"Fence",
			Vector3.new(segW, 5, 1.5),
			base * CFrame.new(0, 2.5, -(rimR + 4)),
			fence,
			false
		)
		-- Stands: stepped rows, each a little higher and further out, with seated people.
		for t = 1, TIERS do
			local r = FIRST_R + (t - 1) * TIER_DEPTH
			local h = t * TIER_RISE
			local stepColor = if t % 2 == 0
				then Color3.fromRGB(70, 110, 190)
				else Color3.fromRGB(90, 135, 215)
			part(
				folder,
				"Tier",
				Vector3.new(2 * math.pi * r / SEGMENTS * 1.03, h, TIER_DEPTH),
				base * CFrame.new(0, h / 2 - 1.6, -(r + TIER_DEPTH / 2)),
				stepColor,
				false
			)
			for k = 1, PER_SEAT do
				local across = (k - 0.5) / PER_SEAT - 0.5
				local x = across * segW * 0.9
				local z = -(r + TIER_DEPTH * (0.35 + rng:NextNumber() * 0.3))
				local top = h - 1.6
				-- Just a coloured dot per fan.
				local dot = part(
					folder,
					"Fan",
					Vector3.new(2.4, 2.4, 2.4),
					base * CFrame.new(x, top + 1.4, z),
					SHIRTS[rng:NextInteger(1, #SHIRTS)],
					false
				)
				dot.Shape = Enum.PartType.Ball
			end
		end
		-- A tall back wall with team-colour blocks behind the top row.
		local backR = FIRST_R + TIERS * TIER_DEPTH
		part(
			folder,
			"BackWall",
			Vector3.new(2 * math.pi * backR / SEGMENTS * 1.03, TIERS * TIER_RISE + 8, 1.5),
			base * CFrame.new(0, (TIERS * TIER_RISE + 8) / 2 - 1.6, -(backR + 1)),
			if i % 4 < 2 then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(45, 80, 150),
			false
		)
	end

	-- Light towers: bright toy lamps standing around the top of the stands.
	local towerR = FIRST_R + TIERS * TIER_DEPTH + 6
	for i = 0, 7 do
		local base = CFrame.new(origin) * CFrame.Angles(0, (i + 0.5) / 8 * math.pi * 2, 0)
		local post = base * CFrame.new(0, 24, -towerR)
		part(folder, "TowerPost", Vector3.new(3, 48, 3), post, Color3.fromRGB(60, 70, 90), false)
		local lamp = part(
			folder,
			"TowerLamp",
			Vector3.new(14, 7, 2),
			base * CFrame.new(0, 50, -(towerR - 2)) * CFrame.Angles(math.rad(-18), 0, 0),
			Color3.fromRGB(255, 244, 190),
			false
		)
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("SpotLight")
		light.Brightness = 10
		light.Range = 140
		light.Angle = 70
		light.Face = Enum.NormalId.Front
		light.Parent = lamp
	end
end

return ArenaStadium
