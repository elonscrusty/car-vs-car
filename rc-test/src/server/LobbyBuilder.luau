--!strict
-- Builds the walking lobby (LobbyLayout, carter's picture): grass, the road with its
-- footpaths, the plaza, and per slot a small garden-size copy of a plot, a sign and a DRIVE pad
-- with a prompt; then the props (LobbyProps). Low-poly flat colours, no text or logos.
-- Run after TrackBuilder.build() (the RC plots are copied from workspace.Plots).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyProps = require(script.Parent.LobbyProps)
local LobbyWaterBuilder = require(script.Parent.LobbyWaterBuilder)
local PlazaBuilder = require(script.Parent.PlazaBuilder)
local SceneryBuilder = require(script.Parent.SceneryBuilder)

local LobbyBuilder = {}

export type Built = {
	prompts: { [number]: ProximityPrompt }, -- by slot index
	signs: { [number]: TextLabel },
}

local part = LobbyProps.part

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

	-- grass a hair under the small plots' floors so they never flicker, the light footpaths,
	-- the dark road on top. The plaza is PlazaBuilder's (water, shore, fences: LobbyWater, scenery)
	slab(folder, "Grass", LobbyLayout.ground(), -0.05, 2, Color3.fromRGB(116, 186, 82))
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
	local plots = workspace:WaitForChild("Plots")
	for _, slot in LobbyLayout.slots() do
		local turn = CFrame.Angles(0, slot.angle, 0)
		-- the small garden-size copy of this plot, front to the road (looks only: driving happens
		-- on the real one)
		local mini = (plots:WaitForChild(slot.id .. "_rc") :: Model):Clone()
		mini.Name = "Mini_" .. slot.index .. "_" .. slot.id
		mini:ScaleTo(LobbyLayout.MINI)
		mini:PivotTo(CFrame.new(slot.plotX, 0, slot.plotZ) * turn)
		mini.Parent = folder

		-- sign on the footpath edge at the plot's front corner: the plot, or who is driving it
		local toRoad = if slot.plotX < 0 then 1 else -1
		local board = part(
			folder,
			"Sign_" .. slot.index,
			Vector3.new(0.4, 3, 7),
			CFrame.new(slot.signX, 2.6, slot.signZ),
			Color3.fromRGB(245, 245, 245)
		)
		for _, sz in { -1, 1 } do
			part(
				folder,
				"SignPost",
				Vector3.new(0.4, 1.2, 0.4),
				CFrame.new(slot.signX, 0.6, slot.signZ + sz * 2.8),
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
		text.TextColor3 = Color3.fromRGB(30, 30, 34)
		text.Parent = gui
		built.signs[slot.index] = text

		-- DRIVE pad in front of it (E on a keyboard, a tap button on a phone)
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
		prompt:SetAttribute("Slot", slot.index)
		prompt.Parent = at
		CollectionService:AddTag(prompt, "DrivePrompt")
		built.prompts[slot.index] = prompt
	end

	-- props
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	-- plaza trees only: the rest of the lobby's trees, bushes, rocks and fences are SceneryBuilder's
	local plaza = LobbyLayout.PLAZA
	for i, t in LobbyLayout.trees() do
		if t.x >= plaza.minX and t.x <= plaza.maxX and t.z >= plaza.minZ and t.z <= plaza.maxZ then
			LobbyProps.tree(props, t.x, t.z, 0.9 + (i % 3) * 0.15)
		end
	end
	SceneryBuilder.build(folder)
	for _, l in LobbyLayout.lamps() do
		LobbyProps.lamp(props, l.x, l.z)
	end
	-- the plaza (paving, lamps, car shop, and the garage from Shared/Garage)
	local p = LobbyLayout.PLAZA
	PlazaBuilder.build(
		folder,
		CFrame.lookAt(Vector3.new(0, 0, p.minZ), Vector3.new(0, 0, p.minZ + 1))
	)

	-- start pad
	local sx, _, sz = LobbyLayout.spawn()
	local start = part(
		folder,
		"StartPad",
		Vector3.new(8, 0.2, 8),
		CFrame.new(sx, 0.12, sz),
		Color3.fromRGB(127, 214, 127)
	)
	start.CanCollide = false

	LobbyWaterBuilder.build(folder)
	return built
end

return LobbyBuilder
