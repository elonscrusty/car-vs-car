--!strict
-- Shows a new player the way, on their screen only: glowing arrows on the road from the spawn
-- lobby to their own plot's pad (a wave of light runs along them toward the plot), and one line
-- at the bottom saying what to do next. Both go once they have driven their plot; they hide
-- while driving or building. Looks only (no collide, query or touch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

export type PlotGuide = {
	setSlot: (slot: number) -> (),
	setDriving: (on: boolean) -> (),
}

local PlotGuide = {}

local COLOR = Color3.fromRGB(255, 220, 60)
local STEP = 8 -- road studs between arrows
local ARM = 2.2
local NEAR = 14 -- this close to the pad: the arrows have done their job

-- one ">" on the floor at (x, z) pointing along (dx, dz)
local function chevron(parent: Instance, x: number, z: number, dx: number, dz: number): { BasePart }
	local yaw = math.atan2(-dx, -dz) -- CFrame look direction
	local base = CFrame.new(x, 0.17, z) * CFrame.Angles(0, yaw, 0)
	local arms: { BasePart } = {}
	for _, side in { -1, 1 } do
		local p = Instance.new("Part")
		p.Name = "GuideArrow"
		p.Size = Vector3.new(0.5, 0.05, ARM)
		-- each arm leans back from the tip (local -z is forward)
		p.CFrame = base
			* CFrame.new(side * 0.7, 0, 0.75)
			* CFrame.Angles(0, side * math.rad(-40), 0)
		p.Color = COLOR
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = parent
		table.insert(arms, p)
	end
	return arms
end

function PlotGuide.new(building: () -> boolean): PlotGuide
	local player = Players.LocalPlayer
	local slot: number? = nil
	local driving = false
	local driven = false -- drove their own plot once: the guide is done
	local folder: Model? = nil
	local rows: { { BasePart } } = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlotGuide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = HudLayout.HUD
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local line = Instance.new("TextLabel")
	line.Name = "Goal"
	HudLayout.place(line, "Goal")
	line.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	line.BackgroundTransparency = 0.25
	line.TextColor3 = COLOR
	line.Font = Enum.Font.GothamBlack
	line.TextScaled = true
	line.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = line
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = line

	local function build(s: LobbyLayout.Slot)
		if folder then
			folder:Destroy()
		end
		rows = {}
		local m = Instance.new("Model")
		m.Name = "PlotGuideArrows"
		local road = LobbyLayout.road()
		-- down the middle of the road to the plot's row, then across to its pad
		local z = road.minZ + 4
		while z < s.padZ - 6 do
			table.insert(rows, chevron(m, 0, z, 0, 1))
			z += STEP
		end
		local dir = if s.padX < 0 then -1 else 1
		local x = dir * 3
		while math.abs(x) < math.abs(s.padX) - 3 do
			table.insert(rows, chevron(m, x, s.padZ, dir, 0))
			x += dir * 3
		end
		folder = m
	end

	local function padDistance(): number
		local s = slot and LobbyLayout.slots()[slot]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (s and root and root:IsA("BasePart")) then
			return math.huge
		end
		local p = root.Position
		return math.sqrt((p.X - s.padX) ^ 2 + (p.Z - s.padZ) ^ 2)
	end

	RunService.RenderStepped:Connect(function()
		local m = folder
		local busy = driving or driven or building() or slot == nil
		local near = padDistance() < NEAR
		-- after the first drive the arrows are done, but on your pad the line still says DRIVE
		gui.Enabled = not busy or (near and not driving and not building() and slot ~= nil)
		line.Text = if near then "TAP DRIVE!" else "FOLLOW THE ARROWS"
		if m then
			local show = not busy and not near
			m.Parent = if show then workspace else nil
			if show then
				-- a wave of light running toward the plot
				local t = os.clock() * 5
				for i, arms in rows do
					local glow = 0.5 + 0.5 * math.sin(t - i * 0.7)
					for _, p in arms do
						p.Transparency = 0.55 - glow * 0.5
					end
				end
			end
		end
	end)

	local guide = {} :: PlotGuide
	function guide.setSlot(s: number)
		if s ~= slot then
			slot = s
			local info = LobbyLayout.slots()[s]
			if info then
				build(info)
			end
		end
	end
	function guide.setDriving(on: boolean)
		driving = on
		if on and padDistance() < NEAR * 2 then
			driven = true -- drove from their own pad
		end
	end
	return guide
end

return PlotGuide
