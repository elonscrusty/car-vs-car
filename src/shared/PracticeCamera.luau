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

-- How far ahead of the car the camera looks. `ahead` is the usual look-ahead, `have` how far behind
-- the car the camera really is and `want` how far it wants to be (both flat). A camera the walls
-- pulled in (the car starts a few studs from the south wall) would look past the car and lose it
-- under the bottom of the screen, so it looks less far ahead, down to `least`: never exactly at the
-- car (a camera straight above a point has no side to put at the top of the screen). The fight
-- camera does the same (BowlView.lookAhead).
local function lookAhead(ahead: number, have: number, want: number, least: number): number
	if want <= 1e-3 then
		return ahead
	end
	return math.clamp(ahead * math.clamp(have / want, 0, 1), math.min(least, ahead), ahead)
end

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
	local yaw = carYaw
	local last = state.yaw
	if last ~= nil then
		yaw = BattleFeel.trailYaw(last, carYaw, math.min(dt, 0.1))
	end
	state.yaw = yaw
	local lx, lz = math.sin(yaw), math.cos(yaw)
	local half = Layout.half
	local back = H.camDistL * carL
	local eye: Vec = {
		x = math.clamp(
			car.x - lx * back,
			-half.x + PracticeCamera.inset,
			half.x - PracticeCamera.inset
		),
		y = car.y + 0.3 * carL + H.camHeightL * carL,
		z = math.clamp(
			car.z - lz * back,
			-half.z + PracticeCamera.inset,
			half.z - PracticeCamera.inset
		),
	}
	local have = math.sqrt((eye.x - car.x) ^ 2 + (eye.z - car.z) ^ 2)
	local ahead = lookAhead(H.camLookL * carL, have, back, 0.5 * carL)
	local look: Vec = {
		x = car.x + lx * ahead,
		y = car.y,
		z = car.z + lz * ahead,
	}
	return eye, look
end

return PracticeCamera
