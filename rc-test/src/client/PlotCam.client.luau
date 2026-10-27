--!strict
-- Car VS Car: while you stand on your own plot's pad, the camera goes up over the stand and looks
-- down your stations (PlotTraining.STAND_CAM), so the pads and cars fill the screen. Step off the
-- pad and the walking camera comes back. Never while driving or racing, and it lets go if
-- something else takes the camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
if not Features.CVC then
	return
end

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotTraining = require(ReplicatedStorage.Shared.PlotTraining)

local me = Players.LocalPlayer
local C = PlotTraining.STAND_CAM
local BLEND = 0.5 -- seconds to swing up into the plot view

local slots = LobbyLayout.slots()
local on = false
local blend = 0
local placed: CFrame? -- where this script last put the camera
local fovWas = 70

-- my plot's slot, if I own one
local function mySlot(): LobbyLayout.Slot?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, s in slots do
		local plot = plots:FindFirstChild(s.index .. "_" .. s.id)
		if plot and tonumber(plot:GetAttribute("OwnerId")) == me.UserId then
			return s
		end
	end
	return nil
end

local function release(cam: Camera)
	if on then
		on = false
		placed = nil
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = fovWas
	end
end

RunService:BindToRenderStep("PlotCam", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local cam = workspace.CurrentCamera
	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local slot = mySlot()
	if
		not (root and root:IsA("BasePart") and slot)
		or me:GetAttribute("Driving") == true
		or me:GetAttribute("Racing") == true
	then
		release(cam)
		return
	end
	-- something else moved the camera since last frame (a race, a shop view): leave it be
	if
		on
		and placed
		and (
			cam.CameraType ~= Enum.CameraType.Scriptable
			or (cam.CFrame.Position - placed.Position).Magnitude > 0.05
		)
	then
		on = false
		placed = nil
		return
	end
	local p = root.Position
	local dx, dz = p.X - slot.padX, p.Z - slot.padZ
	local reach = LobbyLayout.REACH + (if on then C.off else 0)
	if dx * dx + dz * dz > reach * reach then
		release(cam)
		return
	end
	if not on then
		if cam.CameraType ~= Enum.CameraType.Custom then
			return -- someone else has the camera
		end
		on = true
		blend = 0
		fovWas = cam.FieldOfView
		cam.CameraType = Enum.CameraType.Scriptable
	end
	local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
	local eye = pivot:PointToWorldSpace(Vector3.new(C.eye.x, C.eye.y, C.eye.z))
	local look = pivot:PointToWorldSpace(Vector3.new(C.look.x, C.look.y, C.look.z))
	local want = CFrame.lookAt(eye, look)
	blend = math.min(1, blend + dt / BLEND)
	local a = blend * blend * (3 - 2 * blend) -- ease in and out
	cam.CFrame = cam.CFrame:Lerp(want, a)
	cam.FieldOfView = fovWas + (C.fov - fovWas) * a
	placed = cam.CFrame
end)
