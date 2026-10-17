--!strict
-- Knocks a car. A normal ApplyImpulse does nothing to a part a player's device owns (the driver
-- owns their own car, so it answers instantly), so for those cars the speed is changed directly.

local Impulse = {}

local function isDriven(body: BasePart): boolean
	local ok, owner = pcall(function()
		return body:GetNetworkOwner()
	end)
	return ok and owner ~= nil
end

-- Same as body:ApplyImpulse(impulse), also for player-owned cars.
function Impulse.linear(body: BasePart, impulse: Vector3)
	if isDriven(body) then
		body.AssemblyLinearVelocity += impulse / body.AssemblyMass
	else
		body:ApplyImpulse(impulse)
	end
end

-- Same as body:ApplyAngularImpulse(impulse); a box's turning weight is estimated from its size.
function Impulse.angular(body: BasePart, impulse: Vector3)
	if isDriven(body) then
		local s = body.Size
		local inertia = body.AssemblyMass * (s.X * s.X + s.Z * s.Z) / 12
		body.AssemblyAngularVelocity += impulse / math.max(inertia, 1)
	else
		body:ApplyAngularImpulse(impulse)
	end
end

return Impulse
