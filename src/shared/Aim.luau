--!strict
-- Shared aim math: client draws the arrow with it, server launches with it. Same answer both sides.

local Aim = {}

-- Turn the flat "toward center" direction by angleDeg (positive = left, seen from above).
function Aim.direction(base: Vector3, angleDeg: number): Vector3
	local flat = Vector3.new(base.X, 0, base.Z)
	if flat.Magnitude < 1e-4 then
		return Vector3.zAxis
	end
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(angleDeg)):VectorToWorldSpace(flat.Unit)
end

return Aim
