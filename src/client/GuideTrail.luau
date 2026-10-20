--!strict
-- The green glowing line that walks a new player to the gumball machine and to a PLAY pad (carter's
-- L1, L18 and L53; it replaces the old orange arrow). It is drawn on this player's screen only, from
-- their character along the route GuidePath finds around every bench and stand: a glowing strip,
-- little arrows that flow toward the goal, and a tall green light where the line ends so it can be
-- seen from far away. Look only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuidePath = require(ReplicatedStorage.Shared.GuidePath)

local GuideTrail = {}

export type Trail = {
	show: (kind: string) -> (), -- "gumball" | "pad"
	hide: () -> (),
	shown: () -> string?,
	destroy: () -> (),
}

local GREEN = Color3.fromRGB(70, 255, 100)
local LIME = Color3.fromRGB(190, 255, 120)

local STRIP_WIDTH = 1.5
local STRIP_HEIGHT = 0.12
local LIFT = 0.12 -- the strip floats this high above the asphalt
local CHEVRON_SPACING = 5.5
local CHEVRON_SPEED = 9 -- studs a second
local ARM_LENGTH = 1.9
local ARM_ANGLE = math.rad(42) -- each arm leans this far back from the direction of travel
local BEACON_HEIGHT = 26
local RECOMPUTE_SECONDS = 0.5
local RECOMPUTE_MOVED = 1.5 -- studs the player must have walked before the route is found again

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

-- `origin` is the lobby origin (the route is in studs from it); `getPosition` gives where the
-- player's character is, or nil while there is none.
function GuideTrail.new(origin: Vector3, getPosition: () -> Vector3?): Trail
	local folder = Instance.new("Folder")
	folder.Name = "GuideTrail"

	local kind: string? = nil
	local route: { GuidePath.Point } = {}
	local lastX, lastZ = math.huge, math.huge
	local sinceRoute = math.huge
	local clock = 0
	local segments: { Part } = {}
	local joints: { Part } = {}
	local arms: { Part } = {} -- two per arrow

	local beacon = newPart("Beacon", Vector3.new(BEACON_HEIGHT, 4, 4), GREEN, 0.62)
	beacon.Shape = Enum.PartType.Cylinder
	local pool = newPart("BeaconPool", Vector3.new(0.14, 8, 8), LIME, 0.45)
	pool.Shape = Enum.PartType.Cylinder

	local function ground(x: number, z: number): Vector3
		return Vector3.new(origin.X + x, origin.Y + LIFT, origin.Z + z)
	end

	-- the parts in use sit in the folder, the spare ones stay out of the world
	local function ensure(list: { Part }, count: number, make: () -> Part)
		while #list < count do
			table.insert(list, make())
		end
		for i, p in list do
			p.Parent = if i <= count then folder else nil
		end
	end

	local function hideAll()
		for _, list in { segments, joints, arms } do
			for _, p in list do
				p.Parent = nil
			end
		end
		beacon.Parent = nil
		pool.Parent = nil
	end

	local function draw()
		local n = #route
		if n < 2 then
			hideAll()
			return
		end
		ensure(segments, n - 1, function()
			return newPart("Strip", Vector3.new(STRIP_WIDTH, STRIP_HEIGHT, 1), GREEN, 0.3)
		end)
		for i = 1, n - 1 do
			local a, b = route[i], route[i + 1]
			local pa, pb = ground(a.x, a.z), ground(b.x, b.z)
			local len = (pb - pa).Magnitude
			local seg = segments[i]
			if len > 1e-3 then
				seg.Size = Vector3.new(STRIP_WIDTH, STRIP_HEIGHT, len)
				seg.CFrame = CFrame.lookAt((pa + pb) / 2, pb)
			end
		end
		-- round caps at every point, so a corner has no gap
		ensure(joints, n, function()
			local j =
				newPart("Cap", Vector3.new(STRIP_HEIGHT, STRIP_WIDTH, STRIP_WIDTH), GREEN, 0.3)
			j.Shape = Enum.PartType.Cylinder
			return j
		end)
		for i = 1, n do
			local at = ground(route[i].x, route[i].z)
			joints[i].CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		end

		-- arrows flowing toward the goal: two bars leaning back from each tip
		local marks =
			GuidePath.marks(route, CHEVRON_SPACING, (clock * CHEVRON_SPEED) % CHEVRON_SPACING)
		ensure(arms, #marks * 2, function()
			return newPart("Arrow", Vector3.new(0.5, STRIP_HEIGHT + 0.04, ARM_LENGTH), LIME, 0.1)
		end)
		for i, m in marks do
			local forward = Vector3.new(m.dx, 0, m.dz)
			local right = forward:Cross(Vector3.yAxis)
			local tip = ground(m.x, m.z) + forward * (ARM_LENGTH * 0.35) + Vector3.new(0, 0.05, 0)
			for k = 1, 2 do
				local sign = if k == 1 then 1 else -1
				local dir = -forward * math.cos(ARM_ANGLE) + right * (math.sin(ARM_ANGLE) * sign)
				local center = tip + dir * (ARM_LENGTH / 2)
				arms[(i - 1) * 2 + k].CFrame = CFrame.lookAt(center, center + dir)
			end
		end

		-- the green light at the goal
		local goal = route[n]
		local goalAt = ground(goal.x, goal.z)
		beacon.CFrame = CFrame.new(goalAt + Vector3.new(0, BEACON_HEIGHT / 2, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		local pulse = 1 + 0.12 * math.sin(clock * 4)
		pool.Size = Vector3.new(0.14, 8 * pulse, 8 * pulse)
		pool.CFrame = CFrame.new(goalAt + Vector3.new(0, 0.05, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		beacon.Parent = folder
		pool.Parent = folder
	end

	local function findRoute(x: number, z: number)
		if kind == "gumball" then
			route = (GuidePath.toGumball(x, z))
		else
			local _, r = GuidePath.toNearestPad(x, z)
			route = r
		end
		lastX, lastZ = x, z
		sinceRoute = 0
	end

	local conn: RBXScriptConnection? = nil
	local function step(dt: number)
		clock += dt
		sinceRoute += dt
		local p = getPosition()
		if kind == nil or p == nil then
			return
		end
		local x, z = p.X - origin.X, p.Z - origin.Z
		local moved = math.sqrt((x - lastX) ^ 2 + (z - lastZ) ^ 2)
		if sinceRoute >= RECOMPUTE_SECONDS and moved >= RECOMPUTE_MOVED or #route < 2 then
			findRoute(x, z)
		elseif #route >= 2 then
			route[1] = { x = x, z = z } -- the line always starts under the player
		end
		draw()
	end

	local self = {} :: Trail

	self.show = function(newKind: string)
		if kind == newKind then
			return
		end
		kind = newKind
		route = {}
		sinceRoute = math.huge
		folder.Parent = workspace
		if conn == nil then
			conn = RunService.RenderStepped:Connect(step)
		end
	end

	self.hide = function()
		kind = nil
		route = {}
		folder.Parent = nil
		if conn ~= nil then
			conn:Disconnect()
			conn = nil
		end
	end

	self.shown = function(): string?
		return kind
	end

	self.destroy = function()
		self.hide()
		folder:Destroy()
	end

	return self
end

return GuideTrail
