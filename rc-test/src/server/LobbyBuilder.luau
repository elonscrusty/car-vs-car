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

local LobbyBuilder = {}

export type Built = {
	prompts: { [number]: ProximityPrompt }, -- by slot index
	signs: { [number]: TextLabel },
	spawn: CFrame?, -- where people appear (the spawn lobby's spot, once it is built)
}

local part = LobbyProps.part

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
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	-- grass a hair under the plots' floors so they never flicker, the light footpaths, the dark
	-- road on top (the spawn lobby is SpawnLobby's; water, shore, hills: LobbyWater, scenery)
	slab(folder, "Grass", LobbyLayout.ground(), -0.05, 2, Color3.fromRGB(116, 186, 82))
	-- a wide field a hair lower, under the hills round the street and the spawn end, so nothing
	-- stands over the sky (the lake end has its own ground)
	local g = LobbyLayout.ground()
	slab(
		folder,
		"Field",
		{ minX = g.minX - 190, maxX = g.maxX + 190, minZ = g.minZ - 220, maxZ = g.maxZ },
		-0.15,
		2,
		Color3.fromRGB(116, 186, 82)
	)
	slab(folder, "Footpath", LobbyLayout.walks(), 0.05, 1, Color3.fromRGB(217, 214, 207))
	local road = LobbyLayout.road()
	slab(folder, "Road", road, 0.1, 1, Color3.fromRGB(58, 58, 64))
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
				Vector3.new(0.4, 2.5, 0.4),
				CFrame.new(slot.signX, 1.25, slot.signZ + sz * 4.2),
				Color3.fromRGB(140, 98, 60)
			)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = if toRoad > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = gui
		built.signs[slot.index] = text

		-- DRIVE pad at the plot's entrance (E on a keyboard, the DRIVE button on a phone)
		local pad = part(
			folder,
			"DrivePad_" .. slot.index,
			Vector3.new(LobbyLayout.PAD, 0.3, LobbyLayout.PAD),
			CFrame.new(slot.padX, 0.2, slot.padZ),
			Color3.fromRGB(255, 210, 63)
		)
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
	for _, l in LobbyLayout.lamps() do
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
	for _, c in LobbyLayout.cones() do
		if not MeshProps.place(props, "Cone", spot(c), 1.4) then
			LobbyProps.cone(props, c.x, c.z)
		end
	end
	for _, t in LobbyLayout.tires() do
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
