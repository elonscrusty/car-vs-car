--!strict
-- Pure rules for tire marks and smoke: how sideways a car is sliding, and when it counts as a skid.

local SkidRules = {}

export type Config = {
	minSlip: number, -- sideways speed (studs/s) that starts a skid
	minSpeed: number, -- total flat speed needed (a car spinning on the spot leaves no marks)
	fullSlip: number, -- sideways speed that gives full smoke
	maxRate: number, -- most smoke puffs per second
}

SkidRules.Config = {
	minSlip = 14,
	minSpeed = 12,
	fullSlip = 50,
	maxRate = 40,
} :: Config

-- Sideways speed: how fast the car moves across the way it points, ignoring height.
function SkidRules.slipSpeed(vx: number, vz: number, lookX: number, lookZ: number): number
	local len = math.sqrt(lookX * lookX + lookZ * lookZ)
	if len < 1e-3 then
		return 0
	end
	local fx, fz = lookX / len, lookZ / len
	local along = vx * fx + vz * fz
	local sx, sz = vx - fx * along, vz - fz * along
	return math.sqrt(sx * sx + sz * sz)
end

function SkidRules.isSkidding(slip: number, speed: number, grounded: boolean, cfg: Config?): boolean
	local c = cfg or SkidRules.Config
	return grounded and speed >= c.minSpeed and slip >= c.minSlip
end

-- Smoke puffs per second: 0 below the skid threshold, up to maxRate at fullSlip.
function SkidRules.smokeRate(slip: number, cfg: Config?): number
	local c = cfg or SkidRules.Config
	if slip < c.minSlip then
		return 0
	end
	local t = math.clamp((slip - c.minSlip) / math.max(c.fullSlip - c.minSlip, 1e-3), 0, 1)
	return c.maxRate * (0.25 + 0.75 * t)
end

return SkidRules
