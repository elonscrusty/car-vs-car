--!strict
-- Builds the walking lobby (LobbyLayout, carter's plan v5): grass, the road with its
-- footpaths, and per lobby plot a name sign and a DRIVE pad with a prompt (the plots themselves
-- are the real tracks, TrackBuilder's); then the props (LobbyProps, MeshProps), the spawn lobby
-- (SpawnLobby), the scenery and the water. Low-poly flat colours, no text or logos.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local SpawnLobby = require(ReplicatedStorage.Shared.SpawnLobby)
local LobbyProps = require(script.Parent.LobbyProps)
local MeshProps = require(script.Parent.MeshProps)
local LobbyWaterBuilder = require(script.Parent.LobbyWaterBuilder)
local LobbyPerf = require(script.Parent.LobbyPerf)
local LobbyHillsBuilder = require(script.Parent.LobbyHillsBuilder)
local DecorBuilder = require(script.Parent.DecorBuilder)

local LobbyBuilder = {}

export type Built = {
	prompts: { [number]: ProximityPrompt }, -- by slot index
	signs: { [number]: TextLabel },
	spawn: CFrame?, -- where people appear (the spawn lobby's spot, once it is built)
}

local part = LobbyProps.part

-- Smash (LOOK-BIBLE): the bible palette on the ground, ARENA's PropKit for trees, cones, tyres
local SMASH = SpawnLobby.SMASH
local GRASS = if SMASH then Color3.fromRGB(91, 209, 91) else Color3.fromRGB(116, 186, 82)
local GRASS_STRIPE = Color3.fromRGB(78, 192, 82)
local SAND, SAND_LIP = Color3.fromRGB(242, 217, 166), Color3.fromRGB(214, 180, 120)
local ROAD = if SMASH then Color3.fromRGB(141, 141, 150) else Color3.fromRGB(58, 58, 64)
local NAVY, YELLOW = Color3.fromRGB(30, 42, 90), Color3.fromRGB(255, 210, 63)
local function propKit(): any
	if not SMASH then
		return nil
	end
	local m = ReplicatedStorage.Shared:FindFirstChild("PropKit")
	local ok, kit = pcall(function()
		return require(m :: ModuleScript)
	end)
	return if ok and type(kit) == "table" then kit else nil
end

-- name sign colours by plot kind (the arch colours on the plots: race red, drift purple, rocks
-- brown)
local SIGN_COLORS: { [string]: Color3 } = {
	race = Color3.fromRGB(200, 45, 45),
	drift = Color3.fromRGB(110, 60, 180),
	rock = Color3.fromRGB(130, 90, 50),
}

-- a slab whose top is at `top`
local function slab(
	parent: Instance,
	name: string,
	b: LobbyLayout.Box,
	top: number,
	thick: number,
	color: Color3
): Part
	return part(
		parent,
		name,
		Vector3.new(b.maxX - b.minX, thick, b.maxZ - b.minZ),
		CFrame.new((b.minX + b.maxX) / 2, top - thick / 2, (b.minZ + b.maxZ) / 2),
		color
	)
end

function LobbyBuilder.build(): Built
	if SMASH then
		-- a realistic AI-made test car saved in the place (Studio r3: Workspace.PurpleSportsCoupe,
		-- no script makes it) sits on the hill by the plaza: mixed styles (LOOK-BIBLE rule 6).
		-- Moved out of the world, not deleted, so carter keeps it.
		local stray = workspace:FindFirstChild("PurpleSportsCoupe")
		if stray then
			stray.Parent = game:GetService("ServerStorage")
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	-- grass a hair under the plots' floors so they never flicker, the light footpaths, the dark
	-- road on top (the spawn lobby is SpawnLobby's; water, shore, hills: LobbyWater, scenery)
	slab(folder, "Grass", LobbyLayout.ground(), -0.05, 2, GRASS)
	-- a wide field a hair lower, under the hills round the street and the spawn end, so nothing
	-- stands over the sky (the lake end has its own ground)
	local g = LobbyLayout.ground()
	slab(
		folder,
		"Field",
		{ minX = g.minX - 190, maxX = g.maxX + 190, minZ = g.minZ - 220, maxZ = g.maxZ },
		-0.15,
		2,
		GRASS
	)
	if SMASH then
		-- mowed stripes across the grass (LOOK-BIBLE rule 5: a second tone on big flat areas)
		local gz = g.minZ + 8
		while gz < g.maxZ - 8 do
			local stripe = part(
				folder,
				"GrassStripe",
				Vector3.new(g.maxX - g.minX, 0.04, 10),
				CFrame.new((g.minX + g.maxX) / 2, -0.04, gz + 5),
				GRASS_STRIPE
			)
			stripe.CanCollide = false
			stripe.CanQuery = false
			stripe.CastShadow = false
			gz += 24
		end
	end
	local walks = LobbyLayout.walks()
	slab(
		folder,
		"Footpath",
		walks,
		0.05,
		1,
		if SMASH then SAND else Color3.fromRGB(196, 184, 166) -- warm grey
	)
	local road = LobbyLayout.road()
	if SMASH then
		-- a darker sand lip where the footpath meets the grass
		for _, sx in { -1, 1 } do
			local lip = part(
				folder,
				"FootpathLip",
				Vector3.new(0.8, 0.3, road.maxZ - road.minZ),
				CFrame.new(sx * (LobbyLayout.EDGE - 0.4), 0.1, (road.minZ + road.maxZ) / 2),
				SAND_LIP
			)
			lip.CanCollide = false
		end
	end
	slab(folder, "Road", road, 0.1, 1, ROAD)
	-- dashed white middle line
	local z = road.minZ + 4
	while z < road.maxZ - 4 do
		local dash = part(
			folder,
			"RoadLine",
			Vector3.new(0.5, 0.05, 4),
			CFrame.new(0, 0.12, z + 2),
			Color3.fromRGB(245, 245, 245)
		)
		dash.CanCollide = false
		z += 10
	end
	if SMASH then
		-- road paint (auditor cheap tells #2): a sunny edge line down each side and a zebra
		-- crossing where the plaza's walk meets the street
		for _, sx in { -1, 1 } do
			local edge = part(
				folder,
				"RoadEdge",
				Vector3.new(0.6, 0.05, road.maxZ - road.minZ - 2),
				CFrame.new(
					sx * ((road.maxX - road.minX) / 2 - 0.9),
					0.12,
					(road.minZ + road.maxZ) / 2
				),
				YELLOW
			)
			edge.CanCollide = false
		end
		for k = -2, 2 do
			local bar = part(
				folder,
				"Zebra",
				Vector3.new(1.1, 0.05, 3),
				CFrame.new(k * 2.4, 0.12, road.minZ + 2.3), -- (before the first middle dash)
				Color3.fromRGB(245, 245, 245)
			)
			bar.CanCollide = false
		end
	end

	local built: Built = { prompts = {}, signs = {} }
	for _, slot in LobbyLayout.slots() do
		-- name sign on the footpath edge by the plot's front, in the plot kind's colour: who is
		-- driving it, or the kind when nobody is
		local toRoad = if slot.plotX < 0 then 1 else -1
		local board = part(
			folder,
			"Sign_" .. slot.index,
			Vector3.new(0.4, 3, 10),
			CFrame.new(slot.signX, 4, slot.signZ),
			SIGN_COLORS[slot.id] or Color3.fromRGB(60, 60, 66)
		)
		for _, sz in { -1, 1 } do
			part(
				folder,
				"SignPost",
				if SMASH then Vector3.new(0.9, 2.5, 0.9) else Vector3.new(0.4, 2.5, 0.4),
				CFrame.new(slot.signX, 1.25, slot.signZ + sz * 4.2),
				if SMASH then NAVY else Color3.fromRGB(140, 98, 60) -- (no wood in Smash)
			)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = if toRoad > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		-- one canvas pixel per 1/50 stud, so the letters keep their shape on a long thin board
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		-- (Smash: the UI's chunky font with a navy outline, auditor cheap tells #4)
		text.Font = if SMASH then Enum.Font.Oswald else Enum.Font.Oswald
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		if SMASH then
			text.TextStrokeColor3 = NAVY
			text.TextStrokeTransparency = 0
		end
		text.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.06, 0)
		padding.PaddingRight = UDim.new(0.06, 0)
		padding.PaddingTop = UDim.new(0.1, 0)
		padding.PaddingBottom = UDim.new(0.1, 0)
		padding.Parent = text
		built.signs[slot.index] = text
		-- the same words on the plot side too (a blank red back looked unfinished)
		local back = gui:Clone()
		back.Face = if toRoad > 0 then Enum.NormalId.Left else Enum.NormalId.Right
		back.Parent = board
		local backText = back:FindFirstChildOfClass("TextLabel") :: TextLabel
		text:GetPropertyChangedSignal("Text"):Connect(function()
			backText.Text = text.Text
		end)

		-- DRIVE pad at the plot's entrance (E on a keyboard, the DRIVE button on a phone)
		local pad = part(
			folder,
			"DrivePad_" .. slot.index,
			Vector3.new(LobbyLayout.PAD, 0.3, LobbyLayout.PAD),
			CFrame.new(slot.padX, 0.2, slot.padZ),
			Color3.fromRGB(255, 210, 63)
		)
		pad.Material = Enum.Material.Neon -- glows: "stand here"
		local at = Instance.new("Attachment")
		at.Name = "DriveSpot"
		at.Position = Vector3.new(0, 2.5, 0)
		at.Parent = pad
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DrivePrompt"
		prompt.ActionText = "Drive"
		prompt.ObjectText = slot.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = LobbyLayout.REACH
		prompt.RequiresLineOfSight = false
		-- no Roblox prompt box: our own DRIVE (E) button stands in for it (one button on a phone)
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Slot", slot.index)
		prompt.Parent = at
		CollectionService:AddTag(prompt, "DrivePrompt")
		built.prompts[slot.index] = prompt
	end

	-- props
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	-- hills and their trees round the lobby
	LobbyHillsBuilder.build(folder)
	-- street lamps, cones by the pads, tyres where the road stops: carter's meshes once they
	-- are imported (MeshProps), block stand-ins until then
	local function spot(s: LobbyLayout.Spot): CFrame
		return CFrame.lookAt(
			Vector3.new(s.x, 0.1, s.z),
			Vector3.new(s.x + s.faceX, 0.1, s.z + s.faceZ)
		)
	end
	local kit = propKit()
	for _, l in LobbyLayout.lamps() do
		if SMASH then
			-- a chunky navy post with a sunny ball on top (no realistic lantern)
			local post = part(
				props,
				"LampPost",
				Vector3.new(9, 1.1, 1.1),
				CFrame.new(l.x, 4.5, l.z) * CFrame.Angles(0, 0, math.pi / 2),
				NAVY
			)
			post.Shape = Enum.PartType.Cylinder
			local foot = part(
				props,
				"LampFoot",
				Vector3.new(0.8, 2.2, 2.2),
				CFrame.new(l.x, 0.4, l.z) * CFrame.Angles(0, 0, math.pi / 2),
				NAVY
			)
			foot.Shape = Enum.PartType.Cylinder
			local bulb = part(
				props,
				"LampBall",
				Vector3.new(2.2, 2.2, 2.2),
				CFrame.new(l.x, 9.8, l.z),
				Color3.fromRGB(255, 226, 110)
			)
			bulb.Shape = Enum.PartType.Ball
			bulb.CanCollide = false
			-- a soft glow, not Neon (Neon bloomed into big yellow blobs up close)
			local glow = Instance.new("PointLight")
			glow.Range = 12
			glow.Brightness = 1.2 -- (as the plaza lamps)
			glow.Color = bulb.Color
			glow.Parent = bulb
			continue
		end
		local lamp = MeshProps.place(props, "StreetLamp", spot(l), 9)
		if lamp then
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 1.2
			glow.Color = Color3.fromRGB(255, 220, 160)
			glow.Parent = lamp:FindFirstChildWhichIsA("BasePart", true)
		else
			LobbyProps.lamp(props, l.x, l.z)
		end
	end
	-- trees in the grass gaps between plots (pine and leafy in turn, a little turned and sized)
	for i, t in LobbyLayout.trees() do
		if SMASH then
			if kit then
				pcall(
					kit.tree,
					props,
					Vector3.new(t.x, 0, t.z),
					12 + (i * 7) % 5,
					if i % 3 == 0 then "pink" else "green",
					100 + i
				)
			end
			continue
		end
		local mesh = if i % 2 == 1 then "PineTree" else "LeafyTree"
		local turn = CFrame.Angles(0, math.rad((i * 67) % 360), 0)
		local tree = MeshProps.place(props, mesh, spot(t) * turn, 12 + (i * 7) % 5)
		if tree then
			for _, d in tree:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
		else
			LobbyProps.tree(props, t.x, t.z, 1.3)
		end
	end
	for _, c in LobbyLayout.cones() do
		if SMASH then
			if kit then
				pcall(kit.cone, props, Vector3.new(c.x, 0, c.z), 2.2)
			end
			continue
		end
		if not MeshProps.place(props, "Cone", spot(c), 1.4) then
			LobbyProps.cone(props, c.x, c.z)
		end
	end
	for _, t in LobbyLayout.tires() do
		if SMASH then
			if kit then
				pcall(kit.tyreStack, props, Vector3.new(t.x, 0, t.z), 3)
			end
			continue
		end
		if not MeshProps.place(props, "TireStack", spot(t), 2.4) then
			LobbyProps.tires(props, t.x, t.z)
		end
	end
	-- the spawn lobby at the top of the road, looking down it (shop, upgrades, car stands, race
	-- pads)
	local p = LobbyLayout.PLAZA
	-- SpawnLobby's origin: its footprint runs from 45 behind it to 36 in front, so the open front
	-- meets the road
	local origin = Vector3.new(0, 0, p.maxZ - 36)
	local at = CFrame.lookAt(origin, origin + Vector3.new(0, 0, 1))
	SpawnLobby.build(folder, at)
	built.spawn = SpawnLobby.spawnCFrame(at)

	LobbyWaterBuilder.build(folder)
	-- street decorations: bunting, planters, flags, road paint, the giant RC corners
	DecorBuilder.build(folder)

	-- phone speed pass over everything above (shadows/collisions off on small bits)
	local before, after = LobbyPerf.apply(folder)
	print(
		string.format(
			"Lobby: %d parts; shadows %d -> %d, colliding %d -> %d",
			after.parts,
			before.shadows,
			after.shadows,
			before.collide,
			after.collide
		)
	)
	return built
end

return LobbyBuilder
