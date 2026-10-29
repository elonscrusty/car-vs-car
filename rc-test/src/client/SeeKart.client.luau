--!strict
-- See your kart (auditor R7-5): an arena prop between the camera and your kart fades to
-- see-through (LocalTransparencyModifier, only on this screen) and comes back once it is out of
-- the way. Rules in shared/SeeKart. No rays: the arena's props (SeeKart.PROPS, in
-- workspace.SmashArena only, so the lobby and plots are never touched) are checked with box
-- maths, a quick ball test first. Runs after the camera (chase +1, plot +2, SmashFx +3) and
-- never moves it: driving and the camera stay LOCKED.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeeKart = require(Shared:WaitForChild("SeeKart"))

local player = Players.LocalPlayer
local carName = "Car_" .. player.UserId

type Prop = { part: BasePart, x: number, y: number, z: number, r: number }

local fader = SeeKart.fader() :: SeeKart.Fader<BasePart>
local before: { [BasePart]: number } = {} -- each faded part's own LocalTransparencyModifier

local arena: Instance? = nil
local props: { Prop } = {}
local kart: Model? = nil
local lookedAt = -math.huge

local function restore(part: BasePart)
	local was = before[part]
	before[part] = nil
	-- only put it back if it still shows our fade (nobody else changed it meanwhile)
	if was and SeeKart.ours(part.LocalTransparencyModifier) then
		part.LocalTransparencyModifier = was
	end
end

local addedConn: RBXScriptConnection? = nil

local function addProp(d: Instance)
	if d:IsA("BasePart") and SeeKart.PROPS[d.Name] then
		local p = d.Position
		table.insert(props, {
			part = d,
			x = p.X,
			y = p.Y,
			z = p.Z,
			-- (wide enough for the whole beside-the-camera box, corners too)
			r = (d.Size / 2 + Vector3.one * SeeKart.NEAR_CAM).Magnitude + SeeKart.PAD,
		})
	end
end

-- once a second at most: find your kart and the arena (rebuilt arena → new prop list)
local function look()
	if os.clock() - lookedAt < 1 then
		return
	end
	lookedAt = os.clock()
	if not (kart and kart.Parent) then
		local m = workspace:FindFirstChild(carName)
		kart = if m and m:IsA("Model") then m else nil
	end
	local a = workspace:FindFirstChild("SmashArena")
	if a ~= arena then
		for part in fader.seen do
			restore(part)
		end
		fader = SeeKart.fader() :: SeeKart.Fader<BasePart>
		arena = a
		table.clear(props)
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		if a then
			for _, d in a:GetDescendants() do
				addProp(d)
			end
			-- parts that arrive after the first look (the client can start mid-replication)
			addedConn = a.DescendantAdded:Connect(addProp)
		end
	end
end

RunService:BindToRenderStep("SeeKart", Enum.RenderPriority.Camera.Value + 4, function()
	look()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local body = if kart and kart.Parent then kart.PrimaryPart else nil
	if cam and body and #props > 0 then
		local from = cam.CFrame.Position
		local to = body.Position
		local ax, ay, az = from.X, from.Y, from.Z
		local bx, by, bz = to.X, to.Y, to.Z
		for _, pr in props do
			local part = pr.part
			if SeeKart.near(ax, ay, az, bx, by, bz, pr.x, pr.y, pr.z, pr.r) and part.Parent then
				local cf = part.CFrame
				local a = cf:PointToObjectSpace(from)
				local b = cf:PointToObjectSpace(to)
				local s = part.Size
				if SeeKart.blocks(a.X, a.Y, a.Z, b.X, b.Y, b.Z, s.X / 2, s.Y / 2, s.Z / 2) then
					local m = part.LocalTransparencyModifier
					if fader.seen[part] ~= nil then
						fader:keep(part, now)
						-- another script put it back to solid while it still blocks: fade again
						if m < SeeKart.FADE - 1e-3 then
							part.LocalTransparencyModifier = SeeKart.FADE
						end
					elseif not SeeKart.hiddenAlready(m) and fader:add(part, now) then
						before[part] = m
						part.LocalTransparencyModifier = SeeKart.FADE
					end
				end
			end
		end
	end
	for _, part in fader:due(now) do
		restore(part)
	end
end)
