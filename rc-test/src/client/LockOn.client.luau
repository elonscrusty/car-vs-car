--!strict
-- LOCK-ON marker (carter picked "2 Corner Brackets" 10-31): four red corner brackets float
-- round a kart while a rocket chases it, turn slowly, and pulse. The server (WeaponServer's
-- ctx.mark, from server/weapons/Flight) tags the kart's model "LockedOn" while any rocket
-- chases it; this only draws what the tag says. Preview: car-vs-car/lockon-preview/lockon.html
-- Look rule: low-poly, Neon, no text.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))

local TAG = "LockedOn"
local K = Weapons.KART
local RED = Color3.fromRGB(227, 23, 30)
local HALF = 0.62 * K -- the frame is a square this far from the kart's middle (half-side)
local ARM = 0.3 * K -- length of each bracket arm
local THICK = 0.05 * K
local LIFT = 0.28 * K -- the frame floats a little above the kart's middle

type Mark = { model: Model, folder: Folder, bars: { Part }, age: number }
local marks: { [Instance]: Mark } = {}

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

local function bar(parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = "LockBar"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Size = Vector3.new(ARM, THICK, THICK)
	p.Parent = parent
	return p
end

local function add(inst: Instance)
	if not inst:IsA("Model") or marks[inst] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "LockOn"
	folder.Parent = bits
	local bars = {}
	for _ = 1, 8 do
		table.insert(bars, bar(folder))
	end
	marks[inst] = { model = inst, folder = folder, bars = bars, age = 0 }
end

local function remove(inst: Instance)
	local m = marks[inst]
	if m then
		marks[inst] = nil
		m.folder:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
for _, inst in CollectionService:GetTagged(TAG) do
	add(inst)
end

RunService.RenderStepped:Connect(function(dt: number)
	for inst, m in marks do
		if not inst.Parent then
			remove(inst)
			continue
		end
		m.age += dt
		local mid = inst:GetPivot().Position + Vector3.new(0, LIFT, 0)
		-- big -> snug when it arrives, then a pulse
		local arrive = math.min(m.age / 0.5, 1)
		local size = HALF * (1.5 - 0.5 * arrive) * (1 + 0.04 * math.sin(m.age * 14))
		local spin = CFrame.new(mid) * CFrame.Angles(0, m.age * 0.9, 0)
		for corner = 0, 3 do
			local turn = CFrame.Angles(0, corner * math.pi / 2, 0)
			local a, b = m.bars[corner * 2 + 1], m.bars[corner * 2 + 2]
			-- one arm along each side of the corner
			a.CFrame = spin * turn * CFrame.new(size - ARM / 2, 0, size)
			b.CFrame = spin * turn * CFrame.new(size, 0, size - ARM / 2) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end
end)
