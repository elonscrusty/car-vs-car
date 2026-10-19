--!strict
-- The opening choice before a fight: where the car starts along its end of the arena and which
-- way it points (pure, unit tested). The server checks the numbers; the cars then fight on their own.
--
-- spot: -1 = far side (top of the screen), 0 = middle, 1 = near side (bottom of the screen)
-- aim:  -1 = point right, 0 = straight at the other end, 1 = point left (the driver's view)

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local BattleSetup = {}

BattleSetup.defaultSpot = 0
BattleSetup.defaultAim = 0
BattleSetup.spotNames = { [-1] = "FAR", [0] = "MIDDLE", [1] = "NEAR" } :: { [number]: string }
BattleSetup.aimNames = { [-1] = "RIGHT", [0] = "STRAIGHT", [1] = "LEFT" } :: { [number]: string }

-- Anything that is not exactly -1, 0 or 1 becomes the default.
function BattleSetup.clean(spot: any, aim: any): (number, number)
	local function one(v: any, default: number): number
		if v == -1 or v == 0 or v == 1 then
			return v
		end
		return default
	end
	return one(spot, BattleSetup.defaultSpot), one(aim, BattleSetup.defaultAim)
end

-- Arena-local start: x, z and a unit facing (fx, fz). `end` is "a" (left end) or "b" (right end).
function BattleSetup.place(
	end_: string,
	halfX: number,
	halfZ: number,
	inset: number,
	spot: number,
	aim: number
): (number, number, number, number)
	local cfg = BattleConfig.Setup
	local dir = if end_ == "a" then 1 else -1
	local x = -dir * (halfX - inset)
	local z = spot * cfg.spotStep * halfZ
	local ang = math.rad(aim * cfg.aimDeg)
	local fx = dir * math.cos(ang)
	local fz = -dir * math.sin(ang)
	return x, z, fx, fz
end

return BattleSetup
