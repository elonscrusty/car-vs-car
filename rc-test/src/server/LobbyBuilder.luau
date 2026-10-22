--!strict
-- Builds the walking lobby (LobbyLayout): grass, the street, the start pad, and per plot a small
-- garden-size copy of it, a sign and a DRIVE pad with a prompt. Grey blocks only.
-- Run after TrackBuilder.build() (the RC plots are copied from workspace.Plots).

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

	-- grass sits a hair under the small plots' floors so they never flicker
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
		-- low sign on the street edge, beside the pad: who is driving this plot (kept knee high
		-- so it never hides the small plot behind it)
		local board = block(
			folder,
			"Sign_" .. slot.id,
			Vector3.new(8, 2.4, 0.4),
			Vector3.new(slot.signX, 1.2, slot.signZ),
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

		-- the small garden-size copy of this plot (looks only: driving happens on the real one)
		local mini = (plots:WaitForChild(slot.id .. "_rc") :: Model):Clone()
		mini.Name = "Mini_" .. slot.id
		mini:ScaleTo(LobbyLayout.MINI)
		mini:PivotTo(CFrame.new(slot.plotX, 0, slot.plotZ))
		mini.Parent = folder

		-- DRIVE pad in front of it (E on a keyboard, a tap button on a phone)
		local pad = block(
			folder,
			"DrivePad_" .. slot.id,
			Vector3.new(LobbyLayout.PAD, 0.3, LobbyLayout.PAD),
			Vector3.new(slot.padX, 0.15, slot.padZ),
			Color3.fromRGB(255, 207, 102)
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
		prompt:SetAttribute("Slot", slot.index)
		prompt.Parent = at
		CollectionService:AddTag(prompt, "DrivePrompt")
		built.prompts[slot.index] = prompt
	end
	return built
end

return LobbyBuilder
