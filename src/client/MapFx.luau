--!strict
-- Turns the decoration models the server tags "MapSpin" (the big wheel behind the battle arena) on
-- this player's own screen, so the movement costs no network traffic. The server never moves them.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MapFx = {}

local spinning: { [Model]: { base: CFrame, center: Vector3, speed: number } } = {}

local function add(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local pivot = inst:GetPivot()
	local speed = inst:GetAttribute("SpinSpeed")
	spinning[inst] = {
		base = pivot,
		center = pivot.Position,
		speed = if type(speed) == "number" then speed else 0.2,
	}
end

function MapFx.start()
	for _, inst in CollectionService:GetTagged("MapSpin") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("MapSpin"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("MapSpin"):Connect(function(inst)
		spinning[inst :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, s in spinning do
			if model.Parent then
				-- turns about the wheel's own axle (the x axis, through the hub)
				model:PivotTo(
					CFrame.new(s.center)
						* CFrame.Angles(t * s.speed, 0, 0)
						* CFrame.new(-s.center)
						* s.base
				)
			else
				spinning[model] = nil
			end
		end
	end)
end

return MapFx
