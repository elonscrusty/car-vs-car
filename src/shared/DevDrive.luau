--!strict
-- Studio only: the Workspace attribute "DevDrive" = "steer,gas" drives YOUR car in a fight without a
-- keyboard, so a Studio test can drive the real client path (slope, wall bounce, camera, sparks, skid
-- marks). "0,1" is straight ahead at full gas, "0.3,1" a gentle right curve, "-1,1" a hard left turn,
-- "0,-1" reverse. Empty or anything else means the normal controls. BattleUi reads this only when
-- RunService:IsStudio(), so it does nothing on a live server.

local DevDrive = {}

export type Input = { steer: number, gas: number }

-- "0.5,1" -> { steer = 0.5, gas = 1 } (both held between -1 and 1); nil when `raw` is not two numbers.
function DevDrive.parse(raw: any): Input?
	if type(raw) ~= "string" then
		return nil
	end
	local a, b = string.match(raw, "^%s*(%-?%d*%.?%d+)%s*,%s*(%-?%d*%.?%d+)%s*$")
	local steer, gas = tonumber(a), tonumber(b)
	if steer == nil or gas == nil then
		return nil
	end
	return { steer = math.clamp(steer, -1, 1), gas = math.clamp(gas, -1, 1) }
end

return DevDrive
