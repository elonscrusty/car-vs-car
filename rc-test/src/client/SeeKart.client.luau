--!strict
-- See your kart (auditor R7-5): an arena prop between the camera and your kart fades to
-- see-through (LocalTransparencyModifier, only on this screen) and comes back once it is out of
-- the way. Rules in shared/SeeKart. One ray a frame at most: each frame looks past what is
-- already faded, so a second prop behind the first is found the frame after. Runs after the
-- camera (chase +1, plot +2, SmashFx +3) and never moves it: driving and the camera stay LOCKED.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeeKart = require(Shared:WaitForChild("SeeKart"))

local player = Players.LocalPlayer
local carName = "Car_" .. player.UserId

local fader = SeeKart.fader() :: SeeKart.Fader<BasePart>
local before: { [BasePart]: number } = {} -- each faded part's own LocalTransparencyModifier

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local kart: Model? = nil
local lookedAt = -math.huge

local function myKart(): Model?
	if kart and kart.Parent then
		return kart
	end
	kart = nil
	if os.clock() - lookedAt < 1 then
		return nil
	end
	lookedAt = os.clock()
	local m = workspace:FindFirstChild(carName)
	if m and m:IsA("Model") then
		kart = m
	end
	return kart
end

-- part of any kart (tagged "Kart" or named Car_<id>) or any character
local function onKart(part: Instance): boolean
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m do
		if
			CollectionService:HasTag(m, "Kart")
			or string.sub(m.Name, 1, 4) == "Car_"
			or m:FindFirstChildOfClass("Humanoid")
		then
			return true
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

local function restore(part: BasePart)
	local was = before[part]
	before[part] = nil
	-- only put it back if nobody else changed it meanwhile
	if was and part.LocalTransparencyModifier == SeeKart.FADE then
		part.LocalTransparencyModifier = was
	end
end

local function fade(part: BasePart, now: number)
	if fader:add(part, now) then
		before[part] = part.LocalTransparencyModifier
		part.LocalTransparencyModifier = SeeKart.FADE
	end
end

local exclude: { Instance } = {}

RunService:BindToRenderStep("SeeKart", Enum.RenderPriority.Camera.Value + 4, function()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local m = myKart()
	local body = m and m.PrimaryPart
	if cam and m and body then
		local from = cam.CFrame.Position
		local to = body.Position
		-- what's faded: still in the way? (box maths, no ray)
		for part in fader.seen do
			if part.Parent == nil then
				fader:drop(part)
				before[part] = nil
			else
				local cf = part.CFrame
				local a = cf:PointToObjectSpace(from)
				local b = cf:PointToObjectSpace(to)
				local half = part.Size / 2
				if
					SeeKart.segmentHitsBox(
						{ x = a.X, y = a.Y, z = a.Z },
						{ x = b.X, y = b.Y, z = b.Z },
						{ x = half.X, y = half.Y, z = half.Z }
					)
				then
					fader:keep(part, now)
				end
			end
		end
		-- the one ray: past your kart, your character and what's already faded
		table.clear(exclude)
		table.insert(exclude, m)
		if player.Character then
			table.insert(exclude, player.Character)
		end
		for part in fader.seen do
			table.insert(exclude, part)
		end
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(from, to - from, params)
		if hit and hit.Instance:IsA("BasePart") then
			local part = hit.Instance :: BasePart
			local size = part.Size
			if
				not SeeKart.skip({
					normalY = hit.Normal.Y,
					hitY = hit.Position.Y,
					kartY = to.Y,
					size = { x = size.X, y = size.Y, z = size.Z },
					kart = onKart(part),
					terrain = part:IsA("Terrain"),
					transparency = part.Transparency,
				})
			then
				fade(part, now)
			end
		end
	end
	for _, part in fader:due(now) do
		restore(part)
	end
end)
