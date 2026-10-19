--!strict
-- The fight stadium: concrete stands in team-colour blocks with a dot crowd, railings, a striped
-- fence with tyre stacks and bunting, truss light towers and a lit apron round the flat floor.
-- Looks only: nothing here is solid.

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
local SECTIONS = {
	Color3.fromRGB(235, 70, 65),
	Color3.fromRGB(250, 200, 50),
	Color3.fromRGB(70, 150, 235),
	Color3.fromRGB(100, 210, 120),
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
	local TIER_R = FIRST_R + TIERS * TIER_DEPTH

	-- Dark night grass all around, a lit concrete apron, and a painted ring on it.
	local ground = part(
		folder,
		"Ground",
		Vector3.new(2, 380, 380),
		CFrame.new(origin + Vector3.new(0, -1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(70, 135, 95),
		false
	)
	ground.Shape = Enum.PartType.Cylinder
	local apron = part(
		folder,
		"Apron",
		Vector3.new(0.2, FIRST_R * 2, FIRST_R * 2),
		CFrame.new(origin + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(105, 112, 138),
		false
	)
	apron.Shape = Enum.PartType.Cylinder
	local ring = part(
		folder,
		"ApronRing",
		Vector3.new(0.2, (rimR + 7) * 2, (rimR + 7) * 2),
		CFrame.new(origin + Vector3.new(0, -0.45, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(250, 205, 60),
		false
	)
	ring.Shape = Enum.PartType.Cylinder
	local ringIn = part(
		folder,
		"ApronRingIn",
		Vector3.new(0.2, (rimR + 6) * 2, (rimR + 6) * 2),
		CFrame.new(origin + Vector3.new(0, -0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(105, 112, 138),
		false
	)
	ringIn.Shape = Enum.PartType.Cylinder

	local segW = 2 * math.pi * (FIRST_R - 3) / SEGMENTS * 1.03
	local fenceR = rimR + 4
	for i = 0, SEGMENTS - 1 do
		local phi = i / SEGMENTS * math.pi * 2
		local base = CFrame.new(origin) * CFrame.Angles(0, phi, 0)
		local section = SECTIONS[math.floor(i / (SEGMENTS / #SECTIONS)) + 1]
		-- Fence: red/white barrier with a glowing top rail.
		local fence = if i % 2 == 0
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(235, 60, 60)
		part(
			folder,
			"Fence",
			Vector3.new(segW, 5, 1.5),
			base * CFrame.new(0, 2.5, -fenceR),
			fence,
			false
		)
		part(
			folder,
			"FenceRail",
			Vector3.new(segW, 0.3, 1.2),
			base * CFrame.new(0, 5.2, -fenceR),
			Color3.fromRGB(120, 215, 255),
			false
		)
		-- Tyre stack against the fence, every other piece.
		if i % 2 == 0 then
			for k = 0, 2 do
				local tyre = part(
					folder,
					"Tyre",
					Vector3.new(1.2, 3.4, 3.4),
					base
						* CFrame.new(0, 0.6 + k * 1.2, -(fenceR - 1.4))
						* CFrame.Angles(0, 0, math.pi / 2),
					if k == 1 then Color3.fromRGB(60, 62, 78) else Color3.fromRGB(34, 34, 42),
					false
				)
				tyre.Shape = Enum.PartType.Cylinder
			end
		end
		-- Bunting: a pole, a rope to the next pole and three little flags.
		part(
			folder,
			"BuntingPole",
			Vector3.new(0.5, 12, 0.5),
			base * CFrame.new(-segW / 2, 6, -(fenceR + 1.6)),
			Color3.fromRGB(230, 232, 245),
			false
		)
		part(
			folder,
			"BuntingRope",
			Vector3.new(segW, 0.15, 0.15),
			base * CFrame.new(0, 11.4, -(fenceR + 1.6)),
			Color3.fromRGB(230, 232, 245),
			false
		)
		for k = 1, 3 do
			part(
				folder,
				"Flag",
				Vector3.new(segW / 4.5, 2.2, 0.12),
				base * CFrame.new((k / 4 - 0.5) * segW, 10.2, -(fenceR + 1.6)),
				SHIRTS[(i * 3 + k) % #SHIRTS + 1],
				false
			)
		end
		-- Stands: stepped concrete rows, each a little higher and further out.
		for t = 1, TIERS do
			local r = FIRST_R + (t - 1) * TIER_DEPTH
			local h = t * TIER_RISE
			local rowW = 2 * math.pi * r / SEGMENTS * 1.03
			local stepColor = if t % 2 == 0
				then Color3.fromRGB(88, 96, 125)
				else Color3.fromRGB(104, 112, 142)
			part(
				folder,
				"Tier",
				Vector3.new(rowW, h, TIER_DEPTH),
				base * CFrame.new(0, h / 2 - 1.6, -(r + TIER_DEPTH / 2)),
				stepColor,
				false
			)
			-- Seat strip in this block's team colour, with a lighter aisle every fourth piece.
			part(
				folder,
				"Seats",
				Vector3.new(rowW * 0.96, 0.5, TIER_DEPTH * 0.55),
				base * CFrame.new(0, h - 1.6 + 0.25, -(r + TIER_DEPTH * 0.55)),
				if i % 4 == 0 then Color3.fromRGB(235, 238, 250) else section,
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
		-- Railing along the front of the lowest row.
		part(
			folder,
			"StandRail",
			Vector3.new(segW, 0.4, 0.4),
			base * CFrame.new(0, TIER_RISE - 1.6 + 2.2, -(FIRST_R + 0.4)),
			Color3.fromRGB(235, 238, 250),
			false
		)
		-- A tall back wall in dark navy with a team-colour panel on every other piece.
		local backR = TIER_R
		local wallH = TIERS * TIER_RISE + 8
		part(
			folder,
			"BackWall",
			Vector3.new(2 * math.pi * backR / SEGMENTS * 1.03, wallH, 1.5),
			base * CFrame.new(0, wallH / 2 - 1.6, -(backR + 1)),
			Color3.fromRGB(38, 48, 88),
			false
		)
		if i % 2 == 0 then
			part(
				folder,
				"Banner",
				Vector3.new(2 * math.pi * backR / SEGMENTS * 0.6, wallH * 0.7, 0.4),
				base * CFrame.new(0, wallH * 0.45 - 1.6, -(backR - 0.1)),
				section,
				false
			)
		end
	end

	-- Light towers: a truss frame holding a grid of bright lamps, each tower with a real spotlight.
	local towerR = TIER_R + 6
	for i = 0, 7 do
		local base = CFrame.new(origin) * CFrame.Angles(0, (i + 0.5) / 8 * math.pi * 2, 0)
		for _, side in { -1, 1 } do
			part(
				folder,
				"TowerLeg",
				Vector3.new(1.6, 52, 1.6),
				base * CFrame.new(side * 3.4, 26, -towerR),
				Color3.fromRGB(60, 70, 90),
				false
			)
		end
		for k = 1, 5 do
			part(
				folder,
				"TowerBrace",
				Vector3.new(8, 0.8, 0.8),
				base * CFrame.new(0, k * 9 - 3, -towerR),
				Color3.fromRGB(95, 105, 128),
				false
			)
		end
		part(
			folder,
			"LampFrame",
			Vector3.new(18, 11, 1.2),
			base * CFrame.new(0, 53, -(towerR - 1.2)) * CFrame.Angles(math.rad(-18), 0, 0),
			Color3.fromRGB(40, 46, 62),
			false
		)
		local first: Part? = nil
		for gx = -1, 1 do
			for gy = 0, 1 do
				local lamp = part(
					folder,
					"TowerLamp",
					Vector3.new(5, 4, 0.8),
					base
						* CFrame.new(0, 53, -(towerR - 1.2))
						* CFrame.Angles(math.rad(-18), 0, 0)
						* CFrame.new(gx * 5.6, (gy - 0.5) * 4.8, -0.9),
					Color3.fromRGB(255, 246, 200),
					false
				)
				lamp.Material = Enum.Material.Neon
				first = first or lamp
			end
		end
		if first then
			local light = Instance.new("SpotLight")
			light.Brightness = 12
			light.Range = 150
			light.Angle = 75
			light.Face = Enum.NormalId.Front
			light.Color = Color3.fromRGB(255, 244, 215)
			light.Parent = first
		end
	end
end

return ArenaStadium
