--!strict
-- Camera: fixed overview of the bowl, then film the crash dummy when a round ends.

local RunService = game:GetService("RunService")

local CameraDirector = {}

export type Director = {
	overview: (center: Vector3) -> (),
	focus: (target: BasePart?) -> (),
}

function CameraDirector.new(): Director
	local target: BasePart? = nil
	local conn: RBXScriptConnection? = nil

	local function cam(): Camera
		return workspace.CurrentCamera :: Camera
	end

	local function stopFollow()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		target = nil
	end

	local function overview(center: Vector3)
		stopFollow()
		local c = cam()
		c.CameraType = Enum.CameraType.Scriptable
		c.FieldOfView = 65
		c.CFrame = CFrame.lookAt(center + Vector3.new(0, 100, 88), center)
	end

	local function focus(part: BasePart?)
		stopFollow()
		if part == nil then
			return
		end
		target = part
		conn = RunService.RenderStepped:Connect(function()
			local t = target
			if t == nil or t.Parent == nil then
				return
			end
			local c = cam()
			local goal = CFrame.lookAt(t.Position + Vector3.new(0, 18, 34), t.Position)
			c.CFrame = c.CFrame:Lerp(goal, 0.12)
		end)
	end

	return { overview = overview, focus = focus }
end

return CameraDirector
