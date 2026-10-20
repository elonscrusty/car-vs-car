--!strict
-- What counts in the practice yard (pure, tested): when a car smashes a box, when the car has left
-- the yard, when the practice runs out of time. The yard itself is PracticeLayout / PracticeYard.
-- Yard coordinates: x right, z toward the car's start, yaw 0 = nose toward -z (turning left is +).

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("TutorialConfig")
local Layout = sibling("PracticeLayout")

local PracticeRules = {}

export type Car = { x: number, z: number, yawDeg: number }
export type Spot = { x: number, z: number }

-- A car that only creeps against a box does not smash it: it must be rolling this fast (studs a second).
PracticeRules.minSmashSpeed = 12
-- The box the hit test uses for the car: its body is this wide, in car lengths.
PracticeRules.carWidthL = 0.5
-- A crate counts as touched a little beyond its true size (a corner brush smashes it too).
PracticeRules.crateReach = 1.2

-- The car's unit nose direction and unit right direction on the floor.
function PracticeRules.axes(yawDeg: number): (number, number, number, number)
	local t = math.rad(yawDeg)
	return -math.sin(t), -math.cos(t), math.cos(t), -math.sin(t)
end

-- Is the crate touched by the car's body (a box `carL` long)? Position only; speed is checked apart.
function PracticeRules.touches(crate: Spot, car: Car, carL: number): boolean
	local fx, fz, rx, rz = PracticeRules.axes(car.yawDeg)
	local dx, dz = crate.x - car.x, crate.z - car.z
	local along = math.abs(dx * fx + dz * fz)
	local across = math.abs(dx * rx + dz * rz)
	local gapAlong = math.max(along - carL / 2, 0)
	local gapAcross = math.max(across - carL * PracticeRules.carWidthL / 2, 0)
	local reach = Layout.crateSize / 2 * PracticeRules.crateReach
	return gapAlong * gapAlong + gapAcross * gapAcross <= reach * reach
end

-- The crates (by index) that this step smashes: alive ones the rolling car touches.
function PracticeRules.smashed(
	crates: { Spot },
	alive: { boolean },
	car: Car,
	carL: number,
	speed: number
): { number }
	local out: { number } = {}
	if speed < PracticeRules.minSmashSpeed then
		return out
	end
	for i, crate in crates do
		if alive[i] and PracticeRules.touches(crate, car, carL) then
			table.insert(out, i)
		end
	end
	return out
end

-- Has the car left the yard (thrown over a wall, fallen through)? Then it goes back to the start.
function PracticeRules.outside(x: number, y: number, z: number): boolean
	local slack = Layout.wall.thickness + 2
	return math.abs(x) > Layout.half.x + slack or math.abs(z) > Layout.half.z + slack or y < -15
end

-- Does the practice end by itself (L60)?
function PracticeRules.timeUp(elapsed: number): boolean
	return elapsed >= Config.practiceMaxSeconds
end

-- The car's heading as the yard's yaw (degrees) from its look vector on the floor.
function PracticeRules.yawOf(lookX: number, lookZ: number): number
	return math.deg(math.atan2(-lookX, -lookZ))
end

return PracticeRules
