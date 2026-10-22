--!strict
-- Builds the walking lobby around the RC-size plots (LobbyLayout): grass under everything, the
-- street in front, the start pad, a sign per plot, and a DRIVE prompt on each driver stand.
-- Grey blocks only. Run after TrackBuilder.build() (the plots must exist).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyBuilder = {}

export type Built = {
	prompts: { [number]: ProximityPrompt }, -- by slot index
	signs: { [number]: TextLabel },
}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- box -> centre and size of a slab whose top is at `top`
local function slab(
	parent: Instance,
	name: string,
	b: { minX: number, maxX: number, minZ: number, maxZ: number },
	top: number,
	thick: number,
	color: Color3
): Part
	return block(
		parent,
		name,
		Vector3.new(b.maxX - b.minX, thick, b.maxZ - b.minZ),
		Vector3.new((b.minX + b.maxX) / 2, top - thick / 2, (b.minZ + b.maxZ) / 2),
		color
	)
end

function LobbyBuilder.build(): Built
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	-- grass sits a hair under the plot floors so they never flicker
	slab(folder, "Grass", LobbyLayout.ground(), -0.05, 2, Color3.fromRGB(120, 150, 110))
	slab(folder, "Street", LobbyLayout.street(), 0, 1, Color3.fromRGB(140, 140, 144))

	local sx, _, sz = LobbyLayout.spawn()
	block(
		folder,
		"StartPad",
		Vector3.new(10, 0.2, 10),
		Vector3.new(sx, 0.1, sz),
		Color3.fromRGB(127, 214, 127)
	).CanCollide =
		false

	local built: Built = { prompts = {}, signs = {} }
	local plots = workspace:WaitForChild("Plots")
	for _, slot in LobbyLayout.slots() do
		-- sign on the street edge: who is driving this plot
		for _, side in { -1, 1 } do
			block(
				folder,
				"SignPost",
				Vector3.new(0.4, 5, 0.4),
				Vector3.new(slot.signX + side * 4.5, 2.5, slot.signZ),
				Color3.fromRGB(190, 190, 195)
			)
		end
		local board = block(
			folder,
			"Sign_" .. slot.id,
			Vector3.new(10, 3.5, 0.4),
			Vector3.new(slot.signX, 5.5, slot.signZ),
			Color3.fromRGB(235, 235, 235)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- faces the street (+Z)
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(30, 30, 34)
		text.Parent = gui
		built.signs[slot.index] = text

		-- DRIVE prompt at the foot of the tall driver stand, on the street side (E on a keyboard,
		-- a tap button on a phone); driving puts the person on top
		local plot = plots:WaitForChild(slot.id .. "_rc")
		local stand = plot:WaitForChild("StandPad") :: BasePart
		local at = Instance.new("Attachment")
		at.Name = "DriveSpot"
		at.Parent = stand
		at.WorldPosition = Vector3.new(slot.standX, 2.5, slot.standZ + stand.Size.Z / 2 + 1)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DrivePrompt"
		prompt.ActionText = "Drive"
		prompt.ObjectText = slot.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = LobbyLayout.REACH
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Slot", slot.index)
		prompt.Parent = at
		CollectionService:AddTag(prompt, "DrivePrompt")
		built.prompts[slot.index] = prompt
	end
	return built
end

return LobbyBuilder
