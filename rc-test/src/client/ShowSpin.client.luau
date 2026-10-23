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

RunService.RenderStepped:Connect(function()
	local turn = CFrame.Angles(0, (os.clock() * SPEED) % (2 * math.pi), 0)
	for m, start in spinning do
		if m.Parent then
			m:PivotTo(start * turn)
		else
			spinning[m] = nil
		end
	end
end)
