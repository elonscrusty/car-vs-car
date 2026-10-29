--!strict
-- Car VS Car Smash: three things move in the lobby, on this screen only (auditor cheap tells #1):
-- the SMASH! portal ring turns slowly ("PortalSpin": each piece has SpinCentre and SpinAxis),
-- the balloon bunches bob ("LobbyBob", Phase), and the "?" box over the crate shop spins
-- ("LobbySpin"). The server built them anchored; this only moves this screen's copies, all in one
-- BulkMoveTo a frame. Paused while you're far off (in a match or the yard), so a phone does no
-- work it can't see.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnLobby = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpawnLobby"))

if not SpawnLobby.SMASH then
	return
end

local FAR = 400 -- studs from the camera: past this nothing here is worth moving
local SPIN = 0.35 -- portal ring, radians a second
local BOB = 0.5 -- balloons, studs up and down

type Moving = {
	base: CFrame,
	kind: string,
	centre: Vector3?, -- PortalSpin
	axis: Vector3?,
	phase: number, -- LobbyBob
}
local moving: { [BasePart]: Moving } = {}

local function watch(tag: string)
	local function add(inst: Instance)
		if not inst:IsA("BasePart") then
			return
		end
		local c, axis, phase =
			inst:GetAttribute("SpinCentre"),
			inst:GetAttribute("SpinAxis"),
			inst:GetAttribute("Phase")
		moving[inst] = {
			base = inst.CFrame,
			kind = tag,
			centre = if typeof(c) == "Vector3" then c else nil,
			axis = if typeof(axis) == "Vector3" then axis else nil,
			phase = if type(phase) == "number" then phase else 0,
		}
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
		moving[inst :: BasePart] = nil
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
end
watch("PortalSpin")
watch("LobbyBob")
watch("LobbySpin")

local parts: { BasePart } = {}
local cfs: { CFrame } = {}
RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam or next(moving) == nil then
		return
	end
	local eye = cam.CFrame.Position
	local t = os.clock()
	local turn: { [Vector3]: CFrame } = {} -- one rotation per ring middle, shared by its pieces
	table.clear(parts)
	table.clear(cfs)
	for p, m in moving do
		if (m.base.Position - eye).Magnitude > FAR then
			continue
		end
		local cf: CFrame
		if m.kind == "PortalSpin" then
			local c, axis = m.centre, m.axis
			if not c or not axis then
				continue
			end
			local r = turn[c]
			if not r then
				r = CFrame.new(c) * CFrame.fromAxisAngle(axis, t * SPIN) * CFrame.new(-c)
				turn[c] = r
			end
			cf = r * m.base
		elseif m.kind == "LobbyBob" then
			cf = m.base + Vector3.new(0, math.sin(t * 1.6 + m.phase) * BOB, 0)
		else
			cf = m.base * CFrame.new(0, math.sin(t * 1.2) * 0.4, 0) * CFrame.Angles(0, t * 1.4, 0)
		end
		table.insert(parts, p)
		table.insert(cfs, cf)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
