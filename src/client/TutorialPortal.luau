--!strict
-- The blue portal that leads to the practice yard (carter's L6 and L59). A glowing ring with a
-- swirl inside stands on the front path between the spawn and the PLAY pads. It is built on the
-- screen of a player who is in the tutorial only (no other player sees it) and is taken away when the
-- tutorial moves on. Walking into it calls `onEnter` once. Look only: the server knows nothing of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TutorialConfig = require(ReplicatedStorage.Shared.TutorialConfig)

local TutorialPortal = {}

export type Portal = {
	show: () -> (),
	hide: () -> (),
	destroy: () -> (),
}

local BLUE = Color3.fromRGB(0, 140, 255)
local CYAN = Color3.fromRGB(35, 216, 255)
local DEEP = Color3.fromRGB(20, 90, 255)
local BLOCKS = 20
local HEIGHT = 5.4 -- the middle of the ring above the asphalt
local POOL_LIFT = 0.36 -- the glow pad's middle above the plaza top

local function newPart(name: string, size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	return p
end

-- `origin` is the lobby origin; `getPosition` gives where the player's character is (nil = none yet).
function TutorialPortal.new(origin: Vector3, getPosition: () -> Vector3?, onEnter: () -> ()): Portal
	local cfg = TutorialConfig.portal
	local radius: number = cfg.radius
	local folder = Instance.new("Folder")
	folder.Name = "TutorialPortal"
	local center = Vector3.new(origin.X + cfg.x, origin.Y + HEIGHT, origin.Z + cfg.z)
	local base = CFrame.new(center)

	-- the ring: blocks around a circle, standing upright (the opening faces the spawn)
	local blocks: { Part } = {}
	for i = 1, BLOCKS do
		local a = (i - 1) / BLOCKS * math.pi * 2
		local b =
			newPart("RingBlock", Vector3.new(1.7, 1.2, 0.9), if i % 2 == 0 then CYAN else BLUE, 0.1)
		b.CFrame = base
			* CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
			* CFrame.Angles(0, 0, a)
		b.Parent = folder
		table.insert(blocks, b)
	end

	-- the face: a thin glowing disc with two sets of bars turning against each other
	local inner = radius - 0.9
	local disc = newPart("Face", Vector3.new(0.25, inner * 2, inner * 2), DEEP, 0.55)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = base * CFrame.Angles(0, math.pi / 2, 0)
	disc.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 24
	light.Brightness = 2
	light.Parent = disc
	local bars: { Part } = {}
	for i = 1, 4 do
		local bar = newPart("Swirl", Vector3.new(inner * 1.9, 0.45, 0.18), CYAN, 0.35)
		bar.CFrame = base * CFrame.Angles(0, 0, i * (math.pi / 4)) -- in place from the first frame
		bar.Parent = folder
		bars[i] = bar
	end

	-- a glowing pad under it; it floats over the light path (0.2) and the yellow dashes (0.27), or the
	-- path would hide it
	local pool = newPart("Pool", Vector3.new(0.14, radius * 2.8, radius * 2.8), BLUE, 0.6)
	pool.Shape = Enum.PartType.Cylinder
	pool.CFrame = CFrame.new(origin.X + cfg.x, origin.Y + POOL_LIFT, origin.Z + cfg.z)
		* CFrame.Angles(0, 0, math.pi / 2)
	pool.Parent = folder

	local clock = 0
	local entered = false
	local shown = false
	local conn: RBXScriptConnection? = nil

	local function step(dt: number)
		clock += dt
		for i, b in blocks do
			b.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(clock * 4 - i * 0.7))
		end
		for i, bar in bars do
			local spin = clock * (if i % 2 == 0 then 1.6 else -1.1) + i * (math.pi / 4)
			bar.CFrame = base * CFrame.Angles(0, 0, spin)
		end
		local p = getPosition()
		if p ~= nil and not entered then
			local dx, dz = p.X - center.X, p.Z - center.Z
			if
				math.sqrt(dx * dx + dz * dz) <= cfg.enterRadius
				and math.abs(p.Y - center.Y) < 10
			then
				entered = true
				onEnter()
			end
		end
	end

	local self = {} :: Portal

	self.show = function()
		if shown then
			return
		end
		shown = true
		entered = false
		folder.Parent = workspace
		if conn == nil then
			conn = RunService.RenderStepped:Connect(step)
		end
	end

	self.hide = function()
		shown = false
		folder.Parent = nil
		if conn ~= nil then
			conn:Disconnect()
			conn = nil
		end
	end

	self.destroy = function()
		self.hide()
		folder:Destroy()
	end

	return self
end

return TutorialPortal
