--!strict
-- Turns the best car on each plot's car show podium (PlotStandsBuilder tags it "ShowSpin"; its
-- pivot is the podium's top middle). Only on this screen: the server copy stays still.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPEED = 0.6 -- radians a second

local spinning: { [Model]: CFrame } = {} -- each car and where it started

local function add(m: Instance)
	if m:IsA("Model") then
		spinning[m] = m:GetPivot()
	end
end
for _, m in CollectionService:GetTagged("ShowSpin") do
	add(m)
end
CollectionService:GetInstanceAddedSignal("ShowSpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("ShowSpin"):Connect(function(m: Instance)
	spinning[m :: Model] = nil
end)

local NEAR = 150 -- farther than this the turn can't be seen: that car waits (phone speed)

RunService.RenderStepped:Connect(function()
	local turn = CFrame.Angles(0, (os.clock() * SPEED) % (2 * math.pi), 0)
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for m, start in spinning do
		if m.Parent then
			if (start.Position - eye).Magnitude < NEAR then
				m:PivotTo(start * turn)
			end
		else
			spinning[m] = nil
		end
	end
end)
