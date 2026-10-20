--!strict
-- The practice yard's chase camera (pure, tested): behind and above the car, looking where it points,
-- trailing the nose like the fight camera (BattleUi) so the two feel the same. All numbers are
-- BattleConfig.Human. Positions are yard coordinates (y up from the floor).

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")
local BattleFeel = sibling("BattleFeel")
local Layout = sibling("PracticeLayout")

local PracticeCamera = {}

export type Vec = { x: number, y: number, z: number }
export type State = { yaw: number? } -- the heading the camera trails behind

-- The camera stays this far inside the walls: a camera above a low wall would look over it and the
-- wall would hide the car.
PracticeCamera.inset = 9

function PracticeCamera.new(): State
	return { yaw = nil }
end

-- `car` = the body's position, `carYaw` = atan2(look.X, look.Z) (the fight camera's own angle),
-- `carL` = the car's length. Returns the eye and the point it looks at.
function PracticeCamera.aim(
	state: State,
	car: Vec,
	carYaw: number,
	carL: number,
	dt: number
): (Vec, Vec)
	local H = BattleConfig.Human
	local yaw = state.yaw
	if yaw == nil then
		yaw = carYaw
	else
		yaw = BattleFeel.trailYaw(yaw, carYaw, math.min(dt, 0.1))
	end
	state.yaw = yaw
	local lx, lz = math.sin(yaw), math.cos(yaw)
	local half = Layout.half
	local eye: Vec = {
		x = math.clamp(
			car.x - lx * H.camDistL * carL,
			-half.x + PracticeCamera.inset,
			half.x - PracticeCamera.inset
		),
		y = car.y + 0.3 * carL + H.camHeightL * carL,
		z = math.clamp(
			car.z - lz * H.camDistL * carL,
			-half.z + PracticeCamera.inset,
			half.z - PracticeCamera.inset
		),
	}
	local look: Vec = {
		x = car.x + lx * H.camLookL * carL,
		y = car.y,
		z = car.z + lz * H.camLookL * carL,
	}
	return eye, look
end

return PracticeCamera
